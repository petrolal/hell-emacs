;;; groovy-e2e.el --- End-to-end check of :lang groovy -*- lexical-binding: t; -*-

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


;; Drives :lang groovy against a real groovy-language-server (built by
;; sync from its pinned commit) and Gradle: the Phase 8.4 checks. Needs
;; a synced profile with :tools build, :tools lsp and :lang groovy, a
;; JDK 17+, and network access on the first run.
;;
;;   emacs --batch -l early-init.el -l init.el \
;;         -l test/integration/groovy-e2e.el
;;
;; The fixture (test/fixtures/groovy/gradle-demo) is copied to a temporary
;; directory first. Run it inside throwaway XDG_*_HOME/HELLMACSDIR
;; directories, like java-e2e.el. Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar gv--messages nil "Build announcements, newest first.")

;; The server syncs whole documents, and lsp-mode sends those changes on
;; an idle timer, which never fires in batch Emacs (interactively, a second
;; after typing stops): here they go at once.
(setq lsp-debounce-full-sync-notifications nil)

(defun gv--last-message-matching (regexp)
  (seq-find (lambda (m) (string-match-p regexp m)) gv--messages))

(defun gv--errors (buffer)
  "BUFFER's flymake errors, as their texts."
  (with-current-buffer buffer
    (mapcar #'flymake-diagnostic-text
            (seq-filter (lambda (d) (eq (flymake-diagnostic-type d) :error)) (flymake-diagnostics)))))

(defun gv--checks (proj)
  (let* ((src (expand-file-name "src/main/groovy/dev/hellmacs/demo/" proj))
         (app (expand-file-name "App.groovy" src))
         (greeter (expand-file-name "Greeter.groovy" src))
         (test (expand-file-name "src/test/groovy/dev/hellmacs/demo/GreeterTest.groovy" proj))
         (broken (expand-file-name "src/test/groovy/dev/hellmacs/demo/BrokenTest.groovy" proj))
         (app-buf (find-file-noselect app)))
    (advice-add 'hellmacs-forge-announce :filter-return
                (lambda (text) (push text gv--messages) text))
    (switch-to-buffer app-buf)

    (e2e--say "\n== :lang groovy")
    (e2e-check "Groovy sources, build.gradle and a Jenkinsfile open in groovy-mode" :name modes
      (and (eq major-mode 'groovy-mode)
           (with-current-buffer (find-file-noselect (expand-file-name "build.gradle" proj))
             (eq major-mode 'groovy-mode))
           (let ((jenkinsfile (expand-file-name "Jenkinsfile" proj)))
             (with-temp-file jenkinsfile (insert "pipeline { agent any }\n"))
             (with-current-buffer (find-file-noselect jenkinsfile)
               (eq major-mode 'groovy-mode)))))
    (e2e-check "the built server starts, gets the classpath and reports ready" :name server :needs modes
      (e2e-add-project proj)
      (lsp)
      (e2e--wait (lambda () (eq (hellmacs-lsp-status-state 'groovy-ls proj) 'ready)) 300))
    (e2e-check "the mode-line segment reads JVM:ready" :needs server
      (string-match-p "JVM:ready" (or (hellmacs-lsp-status-mode-line) "")))
    (with-current-buffer (find-file-noselect test)
      (switch-to-buffer (current-buffer))
      (lsp))
    (e2e-check "with the build's classpath, JUnit resolves in the test: no errors" :needs server
      (with-current-buffer (find-file-noselect test)
        (e2e--wait (lambda () (flymake-diagnostics)) 5) ; the server's first, stale ones
        (e2e--wait (lambda () (null (gv--errors (current-buffer)))) 60)))
    (e2e-check "go to definition: .greet -> Greeter.groovy" :needs server
      (e2e--position-after "\\.gre")
      (cl-some (lambda (u) (string-suffix-p "Greeter.groovy" u))
               (e2e--lsp-uri-at-point "textDocument/definition")))
    (e2e-check "hover on a call shows something" :needs server
      (e2e--position-after "\\.gre")
      (lsp-request "textDocument/hover" (lsp--text-document-position-params)))
    (with-current-buffer (find-file-noselect greeter)
      (switch-to-buffer (current-buffer))
      (lsp))
    ;; A method's: for a class, groovy-language-server answers with its
    ;; declaration only.
    (e2e-check "references of greet are found in App.groovy and the test" :needs server
      (with-current-buffer (find-file-noselect greeter)
        (e2e--position-after "String \\(gr\\)")
        (let ((uris (mapcar (lambda (l) (lsp-get l :uri))
                            (append (lsp-request "textDocument/references"
                                                 (append (lsp--text-document-position-params)
                                                         (list :context (list :includeDeclaration nil))))
                                    nil))))
          (and (cl-some (lambda (u) (string-suffix-p "App.groovy" u)) uris)
               (cl-some (lambda (u) (string-suffix-p "GreeterTest.groovy" u)) uris)))))
    (e2e-check "a syntax error shows up as a flymake error" :needs server
      (with-current-buffer (find-file-noselect greeter)
        (goto-char (point-max)) (re-search-backward "}")
        (insert "    String broken( {\n")
        (prog1 (e2e--wait (lambda () (gv--errors (current-buffer))) 60)
          (set-buffer-modified-p nil)
          (revert-buffer t t t)
          (accept-process-output nil 2))))

    ;; Last of the editing checks: it changes App.groovy, and the server
    ;; answers the ones before it from the files as they are.
    (with-current-buffer app-buf (switch-to-buffer app-buf))
    (e2e-check "completion after `new Greeter('x').' offers greet" :needs server
      (goto-char (point-max))
      (re-search-backward "}")
      (insert "    static void probe() { new Greeter('x').gr }\n")
      (search-backward "').gr")
      (goto-char (match-end 0))
      (prog1 (let* ((res (lsp-request "textDocument/completion" (lsp--text-document-position-params)))
                    (items (e2e-completion-items res)))
               (cl-some (lambda (i) (string-prefix-p "greet" (lsp-get i :label))) items))
        (set-buffer-modified-p nil)
        (revert-buffer t t t)))
    (e2e--say "\n== Build")
    (with-current-buffer app-buf
      (e2e-check "compile-command is the Gradle wrapper" :name wrapper
        (string-match-p "\\./gradlew" compile-command))
      (e2e-check "a good build says FORGE TEMPERED" :name build :needs wrapper
        (e2e--compile-and-wait proj)
        (gv--last-message-matching "FORGE TEMPERED\\|Build finished")))
    (with-current-buffer (find-file-noselect greeter)
      (goto-char (point-max)) (re-search-backward "}")
      (insert "    String broken() { undefinedCall( }\n")
      (save-buffer)
      (e2e-check "a broken build says BYTECODE PURGATORY" :name broken :needs build
        (e2e--compile-and-wait proj)
        (gv--last-message-matching "PURGATORY"))
      (e2e-check "...naming Greeter.groovy and its line" :needs broken
        (gv--last-message-matching "PURGATORY\\] Greeter.groovy:[0-9]+"))
      (goto-char (point-min))
      (re-search-forward "    String broken() { undefinedCall( }\n")
      (replace-match "")
      (save-buffer))
    (with-current-buffer app-buf
      (e2e-check "the fixed build passes" :needs build
        (e2e--compile-and-wait proj)
        (gv--last-message-matching "FORGE TEMPERED")))

    (e2e--say "\n== Tests")
    (with-current-buffer (find-file-noselect test)
      (e2e-check "C-c l g t runs the test at point by name, and it passes" :needs build
        (e2e--position-after "assertEquals('Hello, Ann")
        (hellmacs-forge-test-at-point)
        (e2e--wait (lambda () (not (get-buffer-process (compilation-find-buffer)))) 300)
        (and (string-match-p "--tests dev\\.hellmacs\\.demo\\.GreeterTest\\.greetsByName\\_>" compile-command)
             (with-current-buffer (compilation-find-buffer)
               (save-excursion (goto-char (point-min)) (re-search-forward "BUILD SUCCESSFUL" nil t))))))
    (with-current-buffer (find-file-noselect broken)
      (e2e-check "a failing test says TEST DAMNATION and M-g n lands in BrokenTest.groovy" :needs build
        (let ((default-directory proj)
              (finished nil))
          (add-hook 'compilation-finish-functions (lambda (_b m) (setq finished m)))
          (compile "./gradlew test -Dhellmacs.fail=true --console=plain")
          (e2e--wait (lambda () finished) 300)
          (and (gv--last-message-matching "DAMNATION\\] 1 of [0-9]+ tests")
               (progn (next-error)
                      (string-suffix-p "BrokenTest.groovy"
                                       (or (buffer-file-name (window-buffer (selected-window))) "")))))))))

(defun gv--preconditions ()
  "Why this Emacs can't run the checks, or nil if it can.
Checked first: without them every check would wait out its time for a
server that can't start."
  (cond ((not (hellmacs-module-p :lang 'groovy))
         "`:lang groovy' isn't in this profile's hellmacs! block; add `groovy' under :lang, then `bin/hellmacs sync'")
        ((not (fboundp 'groovy-mode))
         "groovy-mode isn't installed; run `bin/hellmacs sync'")
        ((not (hellmacs-groovy-server-installed-p))
         "groovy-language-server isn't built; run `bin/hellmacs sync'")
        ((not (and (hellmacs-module-p :tools 'build) (hellmacs-module-p :tools 'lsp)))
         "`:tools build' and `:tools lsp' are needed too")))

(when-let* ((why (gv--preconditions)))
  (e2e--say "Can't run the Groovy end-to-end checks: %s." why)
  (kill-emacs 2))

(let ((proj (e2e-copy-fixture "groovy/gradle-demo" "groovy-demo")))
  (e2e--say "Hellmacs Groovy end-to-end in %s" proj)
  (gv--checks proj))

(e2e-finish)

;;; groovy-e2e.el ends here
