;;; kotlin-e2e.el --- End-to-end check of :lang kotlin -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Drives :lang kotlin against a real kotlin-language-server and Gradle:
;; the Phase 8.2 checks. Needs a synced profile with :tools build, :tools
;; lsp and :lang kotlin, a JDK 21+, and network access on the first run.
;;
;;   emacs --batch -l early-init.el -f hellmacs-start \
;;         -l test/integration/kotlin-e2e.el
;;
;; The fixture (test/fixtures/kotlin/gradle-demo) is copied to a temporary
;; directory first. Run it inside throwaway XDG_*_HOME/HELLMACSDIR
;; directories, like java-e2e.el. Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar kt--messages nil "Build announcements, newest first.")

(defun kt--last-message-matching (regexp)
  (seq-find (lambda (m) (string-match-p regexp m)) kt--messages))

(defun kt--checks (proj)
  (let* ((src (expand-file-name "src/main/kotlin/dev/hellmacs/demo/" proj))
         (app (expand-file-name "App.kt" src))
         (greeter (expand-file-name "Greeter.kt" src))
         (test (expand-file-name "src/test/kotlin/dev/hellmacs/demo/GreeterTest.kt" proj))
         (broken (expand-file-name "src/test/kotlin/dev/hellmacs/demo/BrokenTest.kt" proj))
         (app-buf (find-file-noselect app)))
    (advice-add 'hellmacs-forge-announce :filter-return
                (lambda (text) (push text kt--messages) text))
    (switch-to-buffer app-buf)

    (e2e--say "\n== :lang kotlin")
    (e2e-check "the file opens in a Kotlin mode"
      (memq major-mode '(kotlin-mode kotlin-ts-mode)))
    (e2e-check "the pinned server starts and reports ready"
      (e2e-add-project proj)
      (lsp)
      (e2e--wait (lambda () (eq (hellmacs-kotlin-state proj) 'ready)) 300))
    ;; `format-mode-line' renders nothing in batch mode: evaluate the segment.
    (e2e-check "the mode-line segment reads JVM:ready"
      (string-match-p "JVM:ready" (or (hellmacs-lsp-status-mode-line) "")))
    (e2e-check "go to definition: greeter.greet -> Greeter.kt"
      (e2e--position-after "greeter\\.gr")
      (cl-some (lambda (u) (string-suffix-p "Greeter.kt" u))
               (e2e--lsp-uri-at-point "textDocument/definition")))
    (e2e-check "go to definition on a data-class property: person.name -> Person.kt"
      (e2e--position-after "person\\.na")
      (cl-some (lambda (u) (string-suffix-p "Person.kt" u))
               (e2e--lsp-uri-at-point "textDocument/definition")))
    (e2e-check "completion after `greeter.' offers greet"
      (e2e--position-after "greeter\\.")
      (let* ((res (lsp-request "textDocument/completion" (lsp--text-document-position-params)))
             (items (e2e-completion-items res)))
        (cl-some (lambda (i) (string-prefix-p "greet" (lsp-get i :label))) items)))
    (e2e-check "hover on a call shows its signature"
      (e2e--position-after "greeter\\.gr")
      (lsp-request "textDocument/hover" (lsp--text-document-position-params)))
    (with-current-buffer (find-file-noselect greeter)
      (switch-to-buffer (current-buffer))
      (lsp))                            ; `lsp-deferred' waits for a redisplay
    (e2e-check "references of Greeter are found in App.kt and the test"
      (with-current-buffer (find-file-noselect greeter)
        (e2e--position-after "class \\(Gr\\)")
        (let ((uris (mapcar (lambda (l) (lsp-get l :uri))
                            (append (lsp-request "textDocument/references"
                                                 (append (lsp--text-document-position-params)
                                                         (list :context (list :includeDeclaration nil))))
                                    nil))))
          (and (cl-some (lambda (u) (string-suffix-p "App.kt" u)) uris)
               (cl-some (lambda (u) (string-suffix-p "GreeterTest.kt" u)) uris)))))
    (e2e-check "rename plans edits across files (not applied)"
      (with-current-buffer (find-file-noselect greeter)
        (e2e--position-after "fun \\(gr\\)")
        (let* ((edit (lsp-request "textDocument/rename"
                                  (append (lsp--text-document-position-params)
                                          (list :newName "welcome"))))
               (changes (e2e-edit-changes edit)))
          (> (if (hash-table-p changes) (hash-table-count changes) (length changes)) 1))))
    (e2e-check "a type error shows up as a flymake error"
      (with-current-buffer (find-file-noselect greeter)
        (goto-char (point-max)) (re-search-backward "}")
        (insert "val broken: Int = \"s\"\n")
        (prog1 (e2e--wait (lambda ()
                            (cl-some (lambda (d) (eq (flymake-diagnostic-type d) :error))
                                     (flymake-diagnostics)))
                          90)
          (set-buffer-modified-p nil)
          (revert-buffer t t t)
          (accept-process-output nil 3))))

    (e2e--say "\n== Build")
    (with-current-buffer app-buf
      (e2e-check "compile-command is the Gradle wrapper"
        (string-match-p "\\./gradlew" compile-command))
      (e2e-check "a good build says FORGE TEMPERED"
        (e2e--compile-and-wait proj)
        (kt--last-message-matching "FORGE TEMPERED\\|Build finished")))
    (with-current-buffer (find-file-noselect greeter)
      (goto-char (point-max)) (re-search-backward "}")
      (insert "val broken: Int = \"s\"\n")
      (save-buffer)
      (e2e-check "a broken build says BYTECODE PURGATORY with the Kotlin file and line"
        (e2e--compile-and-wait proj)
        (kt--last-message-matching "PURGATORY\\] Greeter.kt:[0-9]+"))
      (e2e-check "...and the server shows failed until a good build"
        (eq (hellmacs-kotlin-state proj) 'failed))
      (e2e-check "M-g n lands on the error in Greeter.kt"
        (next-error)
        (string-suffix-p "Greeter.kt"
                         (or (buffer-file-name (window-buffer (selected-window))) "")))
      (goto-char (point-min))
      (re-search-forward "val broken: Int = \"s\"\n")
      (replace-match "")
      (save-buffer))
    (with-current-buffer app-buf
      (e2e-check "the fixed build passes, and the server is ready again"
        (e2e--compile-and-wait proj)
        (and (kt--last-message-matching "FORGE TEMPERED")
             (eq (hellmacs-kotlin-state proj) 'ready))))

    (e2e--say "\n== Tests")
    (with-current-buffer (find-file-noselect test)
      (e2e-check "the test at point runs by its plain name"
        (e2e--position-after "assertEquals(\"Hello, Ann")
        (hellmacs-forge-test-at-point)
        (e2e--wait (lambda () (not (get-buffer-process (compilation-find-buffer)))) 300)
        (and (string-match-p "--tests dev\\.hellmacs\\.demo\\.GreeterTest\\.greetsByName\\_>" compile-command)
             (with-current-buffer (compilation-find-buffer)
               (save-excursion (goto-char (point-min)) (re-search-forward "BUILD SUCCESSFUL" nil t)))))
      (e2e-check "the test at point runs a backticked name"
        (e2e--position-after "assertEquals(\"Hello, Bob")
        (hellmacs-forge-test-at-point)
        (e2e--wait (lambda () (not (get-buffer-process (compilation-find-buffer)))) 300)
        ;; Gradle fails with "No tests found" if the filter matched nothing.
        (with-current-buffer (compilation-find-buffer)
          (save-excursion (goto-char (point-min)) (re-search-forward "BUILD SUCCESSFUL" nil t)))))
    (with-current-buffer (find-file-noselect broken)
      (e2e-check "a failing test says TEST DAMNATION and M-g n lands in BrokenTest.kt"
        (let ((default-directory proj)
              (finished nil))
          (add-hook 'compilation-finish-functions (lambda (_b m) (setq finished m)))
          (compile "./gradlew test -Dhellmacs.fail=true --console=plain")
          (e2e--wait (lambda () finished) 300)
          (and (kt--last-message-matching "DAMNATION\\] 1 of [0-9]+ tests (BrokenTest.kt:[0-9]+)")
               (progn (next-error)
                      (string-suffix-p "BrokenTest.kt"
                                       (or (buffer-file-name (window-buffer (selected-window))) "")))))))))

(let ((proj (e2e-copy-fixture "kotlin/gradle-demo" "kotlin-demo")))
  (e2e--say "Hellmacs Kotlin end-to-end in %s" proj)
  (kt--checks proj))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; kotlin-e2e.el ends here
