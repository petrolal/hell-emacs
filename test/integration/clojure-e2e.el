;;; clojure-e2e.el --- End-to-end check of :lang clojure -*- lexical-binding: t; -*-

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

;; Drives :lang clojure against a real clojure-lsp and a real CIDER REPL:
;; the Phase 8.3 checks. Needs a synced profile with :tools lsp and :lang
;; clojure, the Clojure CLI on the PATH (`clojure'), a JDK, and network
;; access on the first run (the REPL fetches nrepl and cider-nrepl).
;;
;;   emacs --batch -l early-init.el -f hellmacs-start \
;;         -l test/integration/clojure-e2e.el
;;
;; The fixture (test/fixtures/clojure/deps-demo) is copied to a temporary
;; directory first. Run it inside throwaway XDG_*_HOME/HELLMACSDIR
;; directories, like java-e2e.el. Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defun cj--eval (form)
  "Evaluate FORM in the connected REPL; return the printed value."
  (nrepl-dict-get (cider-nrepl-sync-request:eval form) "value"))

(defun cj--attach (file)
  "Open FILE, show it, and start clojure-lsp for it. Returns its buffer."
  (let ((buf (find-file-noselect file)))
    (switch-to-buffer buf)
    (with-current-buffer buf (lsp))     ; `lsp-deferred' waits for a redisplay
    buf))

(defun cj--checks (proj)
  (let* ((core (expand-file-name "src/demo/core.clj" proj))
         (core-test (expand-file-name "test/demo/core_test.clj" proj))
         (broken-test (expand-file-name "test/demo/broken_test.clj" proj))
         (core-buf (find-file-noselect core)))
    (switch-to-buffer core-buf)

    (e2e--say "\n== :lang clojure: clojure-lsp")
    (e2e-check "the file opens in a Clojure mode"
      (memq major-mode '(clojure-mode clojure-ts-mode)))
    (e2e-check "the pinned clojure-lsp starts and reports ready"
      (e2e-add-project proj)
      (lsp)
      (e2e--wait (lambda () (eq (hellmacs-clojure-state proj) 'ready)) 180))
    ;; `format-mode-line' renders nothing in batch mode: evaluate the segment.
    (e2e-check "the mode-line segment reads JVM:ready"
      (string-match-p "JVM:ready" (or (hellmacs-lsp-status-mode-line) "")))
    (e2e-check "go to definition: greet in -main -> its defn"
      (e2e--position-after "(greet (:na")
      (goto-char (match-beginning 0)) (forward-char 1)
      (cl-some (lambda (u) (string-suffix-p "core.clj" u))
               (e2e--lsp-uri-at-point "textDocument/definition")))
    (e2e-check "hover shows the docstring"
      (e2e--position-after "(greet (:na")
      (goto-char (match-beginning 0)) (forward-char 2)
      (let ((res (lsp-request "textDocument/hover" (lsp--text-document-position-params))))
        (string-match-p "Returns a greeting" (format "%S" res))))
    (e2e-check "completion inside a call offers greet"
      (e2e--position-after "(println greeting")
      (goto-char (match-beginning 0))
      (forward-char (length "(println "))
      (let ((inhibit-modification-hooks t)) (insert "gre"))
      (prog1 (let* ((res (lsp-request "textDocument/completion" (lsp--text-document-position-params)))
                    (items (e2e-completion-items res)))
               (cl-some (lambda (i) (string-prefix-p "greet" (lsp-get i :label))) items))
        (let ((inhibit-modification-hooks t)) (delete-char -3))
        (set-buffer-modified-p nil)))
    (e2e-check "references of greet include the test namespace"
      (e2e--position-after "(defn gr")
      (backward-char 2)
      (let ((uris (mapcar (lambda (l) (lsp-get l :uri))
                          (append (lsp-request "textDocument/references"
                                               (append (lsp--text-document-position-params)
                                                       (list :context (list :includeDeclaration nil))))
                                  nil))))
        (and (cl-some (lambda (u) (string-suffix-p "core_test.clj" u)) uris)
             (cl-some (lambda (u) (string-suffix-p "core.clj" u)) uris))))
    (e2e-check "rename is planned across files (not applied)"
      (e2e--position-after "(defn gr")
      (backward-char 2)
      (let* ((edit (lsp-request "textDocument/rename"
                                (append (lsp--text-document-position-params) (list :newName "welcome"))))
             (changes (e2e-edit-changes edit)))
        (> (if (hash-table-p changes) (hash-table-count changes) (length changes)) 1)))
    (e2e-check "an unresolved symbol shows up through flymake (clojure-lsp lints on save)"
      (goto-char (point-max))
      (insert "\n(undefined-thing 1)\n")
      (save-buffer)
      (prog1 (e2e--wait (lambda ()
                          (cl-some (lambda (d) (eq (flymake-diagnostic-type d) :error))
                                   (flymake-diagnostics)))
                        60)
        (goto-char (point-max))
        (re-search-backward "\n(undefined-thing 1)\n")
        (replace-match "")
        (save-buffer)
        (accept-process-output nil 2)))
    (e2e-check "workspace symbol search finds the greet function"
      (cl-some (lambda (s) (string-match-p "greet" (lsp-get s :name)))
               (append (lsp-request "workspace/symbol" (list :query "greet")) nil)))

    (e2e--say "\n== CIDER")
    (require 'cider)
    (e2e-check "jack-in starts an nREPL and connects"
      (with-current-buffer core-buf (cider-jack-in-clj nil))
      (e2e--wait #'cider-connected-p 300))
    (e2e-check "CIDER keeps its history in the state directory"
      (file-in-directory-p cider-repl-history-file hellmacs-state-dir))
    (e2e-check "evaluating code returns its value"
      (equal (cj--eval "(+ 1 2)") "3"))
    (e2e-check "loading the buffer makes its functions callable"
      (with-current-buffer core-buf (cider-load-buffer))
      (e2e--wait (lambda () (equal (cj--eval "(demo.core/greet \"Eval\")") "\"Hello, Eval, from Hellmacs!\"")) 30))
    (e2e-check "C-c h r (the Crucible) reloads a changed buffer into the REPL"
      (with-current-buffer core-buf
        (goto-char (point-min))
        (re-search-forward "Hello, ")
        (replace-match "Howdy, ")
        (save-buffer)
        (hellmacs-crucible-reload))
      (e2e--wait (lambda () (equal (cj--eval "(demo.core/greet \"X\")") "\"Howdy, X, from Hellmacs!\"")) 30))
    (with-current-buffer core-buf
      (goto-char (point-min)) (re-search-forward "Howdy, ") (replace-match "Hello, ") (save-buffer)
      (cider-load-buffer))
    (e2e-check "cider-nrepl's middleware is there (test, stacktrace, info)"
      (let ((ops (nrepl-dict-keys (nrepl-dict-get (nrepl-sync-request:describe (cider-current-repl)) "ops"))))
        (and (member "test-var-query" ops) (member "analyze-last-stacktrace" ops) (member "info" ops))))

    (e2e--say "\n== Tests")
    (setq cider-test-show-report-on-success nil)
    (e2e-check "the namespace's tests pass"
      (with-current-buffer (find-file-noselect core-test)
        (switch-to-buffer (current-buffer))
        (cider-mode 1)
        (cider-load-buffer)
        (e2e--wait (lambda () (equal (cj--eval "(resolve 'demo.core-test/greets-by-name)") "#'demo.core-test/greets-by-name")) 30)
        (cider-test-run-ns-tests nil)
        (e2e--wait (lambda () cider-test-last-summary) 60)
        (and (= 0 (nrepl-dict-get cider-test-last-summary "fail"))
             (= 0 (nrepl-dict-get cider-test-last-summary "error"))
             (>= (nrepl-dict-get cider-test-last-summary "pass") 2))))
    (e2e-check "a failing test is reported as a failure"
      (cj--eval "(System/setProperty \"hellmacs.fail\" \"true\")")
      (with-current-buffer (find-file-noselect broken-test)
        (switch-to-buffer (current-buffer))
        (cider-mode 1)
        (cider-load-buffer)
        (e2e--wait (lambda () (equal (cj--eval "(boolean (resolve 'demo.broken-test/fails-on-purpose))") "true")) 30)
        (setq cider-test-last-summary nil)
        (cider-test-run-ns-tests nil)
        (e2e--wait (lambda () cider-test-last-summary) 60)
        (= 1 (nrepl-dict-get cider-test-last-summary "fail"))))))

(let ((proj (e2e-copy-fixture "clojure/deps-demo")))
  (e2e--say "Hellmacs Clojure end-to-end in %s" proj)
  (cj--checks proj))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; clojure-e2e.el ends here
