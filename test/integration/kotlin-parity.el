;;; kotlin-parity.el --- Kotlin feature checklist and measurements -*- lexical-binding: t; -*-

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

;; Phase 8.5: the java-parity.el checklist for Kotlin, on any Gradle
;; project (a copy of it): what kotlin-language-server offers, how long it
;; takes to be ready, and how much memory it uses.
;;
;;   HELLMACS_PARITY_PROJECT=/path/to/project \
;;     emacs --batch -l early-init.el -f hellmacs-start \
;;           -l test/integration/kotlin-parity.el
;;
;; Optional: HELLMACS_PARITY_FILE (a .kt file relative to the project;
;; default the biggest under src/main), HELLMACS_PARITY_BUILD (the build
;; command; default the one `:tools build' proposes),
;; HELLMACS_PARITY_TIMEOUT (seconds per slow step, default 600),
;; HELLMACS_E2E_KEEP (keep the project copy, normally deleted at exit).
;; Run it inside throwaway XDG_*_HOME/HELLMACSDIR directories.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar kp--source (or (getenv "HELLMACS_PARITY_PROJECT")
                       (error "Set HELLMACS_PARITY_PROJECT to a Gradle project")))

(defun kp--jvm-pids (pid)
  "PID and its descendants (the launcher script starts the JVM)."
  (let ((all (list pid)) (queue (list pid)))
    (while queue
      (let ((p (pop queue)))
        (dolist (child (ignore-errors
                         (mapcar #'string-to-number
                                 (split-string (with-temp-buffer
                                                 (insert-file-contents (format "/proc/%d/task/%d/children" p p))
                                                 (buffer-string)))))) 
          (push child all) (push child queue))))
    all))

(defun kp--lsp-checks (proj file)
  (let ((buf (find-file-noselect file)) ready)
    (switch-to-buffer buf)
    (e2e--say "\n== Import and index")
    (let ((t0 (float-time)))
      (e2e-check "the server starts and reports ready"
        (e2e-add-project proj)
        (lsp)
        (setq ready (and (e2e--wait (lambda () (eq (hellmacs-kotlin-state proj) 'ready)) e2e-parity-timeout)
                         (- (float-time) t0)))))
    (e2e--say "     METRIC time until [DAEMON READY]: %s" (if ready (format "%.1fs" ready) "not reached"))
    (when ready
      (accept-process-output nil 5)
      (with-current-buffer buf
        (let ((class (file-name-sans-extension (file-name-nondirectory file))))
          (e2e--say "\n== Navigation")
          (e2e-check (format "workspace symbol search finds %s" class)
            (cl-some (lambda (s) (string-match-p (regexp-quote class) (lsp-get s :name)))
                     (append (lsp-request "workspace/symbol" (list :query class)) nil)))
          (e2e-check "document outline lists symbols"
            (> (length (lsp-request "textDocument/documentSymbol"
                                    (list :textDocument (lsp--text-document-identifier)))) 0))
          (e2e-check "hover on the first declaration"
            (and (e2e-goto-identifier "^[ \t]*\\(?:[a-z]+ \\)*\\(?:class\\|object\\|interface\\|fun\\)[ \t]+\\([A-Za-z_]+\\)")
                 (lsp-request "textDocument/hover" (lsp--text-document-position-params))))
          (e2e-check "references of that declaration"
            (and (e2e-goto-identifier "^[ \t]*\\(?:[a-z]+ \\)*\\(?:class\\|object\\|interface\\)[ \t]+\\([A-Za-z_]+\\)")
                 (let ((refs (lsp-request "textDocument/references"
                                          (append (lsp--text-document-position-params)
                                                  (list :context (list :includeDeclaration t))))))
                   (e2e--say "     %d reference(s)" (length refs))
                   (> (length refs) 0))))
          (e2e-check "definition of a library type (Spring/JDK) opens its source"
            (when (e2e-goto-identifier "^import[ \t]+\\(org\\.[A-Za-z0-9_.]+\\)")
              (goto-char (line-end-position))
              (backward-char 1)
              (let* ((loc (car (append (lsp-request "textDocument/definition"
                                                    (lsp--text-document-position-params)) nil)))
                     (uri (and loc (lsp-get loc :uri))))
                (e2e--say "     definition uri: %s" (and uri (substring uri 0 (min 70 (length uri)))))
                (and uri t)))))
        (e2e--say "\n== Editing")
        (e2e-check "no compile errors reported in the file"
          (null (cl-remove-if-not (lambda (d) (eq (flymake-diagnostic-type d) :error))
                                  (flymake-diagnostics))))
        (e2e-check "completion offers String inside a function"
          (goto-char (point-min))
          (when (re-search-forward "^[ \t]+\\(?:override \\)?fun [^\n]*{[ \t]*$" nil t)
            (end-of-line) (insert "\nval kp = Str")
            (let* ((res (lsp-request "textDocument/completion" (lsp--text-document-position-params)))
                   (items (e2e-completion-items res)))
              (delete-region (line-end-position 0) (point))
              (set-buffer-modified-p nil)
              (cl-some (lambda (i) (equal (lsp-get i :label) "String")) items))))
        (revert-buffer t t t)
        (accept-process-output nil 3)
        (e2e-check "rename is planned (not applied)"
          (when (e2e-goto-identifier "^[ \t]*\\(?:[a-z]+ \\)*fun[ \t]+\\([a-z][A-Za-z0-9_]*\\)")
            (let* ((edit (lsp-request "textDocument/rename"
                                      (append (lsp--text-document-position-params)
                                              (list :newName "renamedByParity"))))
                   (changes (e2e-edit-changes edit)))
              (e2e--say "     rename touches %d file(s)"
                        (if (hash-table-p changes) (hash-table-count changes) (length changes)))
              changes)))
        (e2e-check "code actions are offered for a declaration"
          (goto-char (point-min))
          (when (re-search-forward "^[ \t]*\\(?:[a-z]+ \\)*\\(?:class\\|fun\\)[ \t]+[A-Za-z]" nil t)
            (let ((titles (e2e-code-action-titles (lsp--region-to-range (line-beginning-position) (line-end-position)))))
              (e2e--say "     %d action(s), e.g. %s" (length titles) (car titles))
              titles)))
        (e2e-check "formatting request succeeds"
          (progn (lsp-request "textDocument/formatting"
                              (list :textDocument (lsp--text-document-identifier)
                                    :options (list :tabSize 4 :insertSpaces t)))
                 t)))
      (let ((pid (and (lsp-workspaces) (process-id (lsp--workspace-cmd-proc (car (lsp-workspaces)))))))
        (when pid
          (let ((now 0) (peak 0))
            (dolist (p (kp--jvm-pids pid))
              (cl-incf now (or (ignore-errors (e2e-rss-mb p "VmRSS")) 0))
              (cl-incf peak (or (ignore-errors (e2e-rss-mb p "VmHWM")) 0)))
            (e2e--say "     METRIC server memory: %.0f MB now, %.0f MB peak" now peak)))))))

(defun kp--build-checks (proj)
  (e2e--say "\n== Build")
  (let* ((default-directory proj)
         (cmd (or (getenv "HELLMACS_PARITY_BUILD")
                  (and (hellmacs-forge-build-tool proj) (hellmacs-forge--command 'build))))
         (t0 (float-time)) finished)
    (e2e--say "     build command: %s" cmd)
    (e2e-check "the project's build finishes successfully"
      (let ((hook (lambda (_b m) (setq finished m))))
        (add-hook 'compilation-finish-functions hook)
        (unwind-protect
            (progn (compile cmd)
                   (e2e--wait (lambda () finished) e2e-parity-timeout)
                   (and finished (string-match-p "^finished" finished)))
          (remove-hook 'compilation-finish-functions hook))))
    (unless (and finished (string-match-p "^finished" finished))
      (when-let* ((b (get-buffer "*compilation*")))
        (with-current-buffer b
          (e2e--say "     last build output:\n%s"
                    (mapconcat (lambda (l) (concat "       | " l))
                               (last (split-string (string-trim (buffer-string)) "\n") 12) "\n")))))
    (e2e--say "     METRIC build time: %.1fs" (- (float-time) t0))))

(defun kp--git-checks (proj file)
  (e2e--say "\n== Git")
  (if (not (locate-dominating-file proj ".git"))
      (e2e-skip "Magit status, log and blame" "not a git repository")
    (let ((default-directory (file-name-as-directory proj)))
      (e2e-check "status shows the working tree"
        (call-interactively (key-binding (kbd "C-x g")))
        (derived-mode-p 'magit-status-mode))
      (e2e-check "log lists the history"
        (magit-log-current nil nil)
        (> (count-lines (point-min) (point-max)) 0))
      (e2e-check "blame annotates the Kotlin file"
        (with-current-buffer (find-file-noselect file)
          (magit-blame-addition nil)
          (e2e--wait (lambda () (cl-some (lambda (o) (overlay-get o 'magit-blame-chunk))
                                         (overlays-in (point-min) (point-max))))
                     60))))))

(let* ((proj (e2e-copy-project kp--source))
       (file (e2e-pick-file proj (directory-files-recursively (expand-file-name "src/main" proj) "\\.kt\\'"))))
  (e2e--say "Hellmacs Kotlin parity run: %s (copied to %s)" (file-name-nondirectory (directory-file-name kp--source)) proj)
  (e2e--say "     METRIC Emacs startup (init.el done): %.2fs"
            (float-time (time-subtract (current-time) before-init-time)))
  (e2e--say "     working file: %s" (file-relative-name file proj))
  (kp--lsp-checks proj file)
  (with-current-buffer (find-file-noselect file) (kp--build-checks proj))
  (kp--git-checks proj file)
  (e2e--say "\n%s (%d skipped)" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)) e2e--skipped)
  (kill-emacs (if (zerop e2e--failures) 0 1)))

;;; kotlin-parity.el ends here
