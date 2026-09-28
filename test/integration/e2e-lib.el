;;; e2e-lib.el --- Helpers for the integration scripts -*- lexical-binding: t; -*-

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

;; Shared by java-e2e.el and java-parity.el: waiting on JDTLS, reporting
;; checks, and small LSP and compilation helpers. Not a test by itself.

;;; Code:

(require 'cl-lib)

(defvar e2e--failures 0)
(defvar e2e--root (file-name-directory (or load-file-name buffer-file-name))
  "This directory, test/integration/.")

(defvar e2e-output nil
  "Where `e2e--say' prints when $HELLMACS_E2E_OUT isn't set.
A `princ' destination: nil for stdout. A suite running in a terminal,
where stdout is the screen, sets it to `external-debugging-output'.")

(defun e2e--say (fmt &rest args)
  "Report a line: appended to $HELLMACS_E2E_OUT if set, else to `e2e-output'."
  (let ((line (concat (apply #'format fmt args) "\n")))
    (if-let* ((out (getenv "HELLMACS_E2E_OUT")))
        (write-region line nil out 'append 'silent)
      (princ line e2e-output))))

(defun e2e--wait (pred secs)
  "Process output and timers until PRED returns non-nil; nil after SECS seconds."
  (let ((end (+ (float-time) secs)) result)
    (while (and (not (setq result (ignore-errors (funcall pred))))
                (< (float-time) end))
      (accept-process-output nil 0.2))
    result))

(defmacro e2e-check (desc &rest body)
  "Run BODY; report DESC as passed if it returns non-nil, failed otherwise."
  (declare (indent 1))
  `(let ((ok (condition-case err (progn ,@body)
               (error (e2e--say "     %S" err) nil))))
     (unless ok (cl-incf e2e--failures))
     (e2e--say "  %s  %s" (if ok "PASS" "FAIL") ,desc)
     ok))

(defun e2e--position-after (regexp)
  "Move point just after the first REGEXP in the buffer."
  (goto-char (point-min))
  (re-search-forward regexp)
  (point))

(defun e2e--lsp-uri-at-point (method)
  "Return the URIs of METHOD (a location request) at point."
  (let ((res (lsp-request method (lsp--text-document-position-params))))
    ;; A vector of locations (JDTLS), a list of them, or a single one (a plist).
    (mapcar (lambda (loc) (lsp-get loc :uri))
            (cond ((null res) nil)
                  ((vectorp res) (append res nil))
                  ((keywordp (car res)) (list res))
                  (t res)))))

(defun e2e--compile-and-wait (dir)
  "Run the project's build from DIR and return its finish message."
  (let ((default-directory dir) finished)
    (let ((hook (lambda (_buf msg) (setq finished msg))))
      (add-hook 'compilation-finish-functions hook)
      (unwind-protect
          (progn (compile compile-command)
                 (e2e--wait (lambda () finished) 300)
                 finished)
        (remove-hook 'compilation-finish-functions hook)))))

(defvar e2e--skipped 0)

(defmacro e2e-skip (desc why)
  "Report DESC as skipped for WHY."
  `(progn (cl-incf e2e--skipped)
          (e2e--say "  SKIP  %s (%s)" ,desc ,why)))

;;; Shared helpers ------------------------------------------------------------

(defvar e2e-parity-timeout (string-to-number (or (getenv "HELLMACS_PARITY_TIMEOUT") "600"))
  "Seconds the parity scripts wait for each slow step ($HELLMACS_PARITY_TIMEOUT).")

(defconst e2e--build-output-dirs '("build" "target" ".gradle" ".kotlin" ".settings" ".idea")
  "Directories left behind when a project is copied: build output and IDE state.")

(defvar e2e--copies nil
  "The temporary directories `e2e-copy-project' made: the only ones deleted at exit.")

(defun e2e-copy-project (src &optional name)
  "Copy directory SRC into a new temporary directory; return the copy.
The copy is named NAME, else like SRC; build output and IDE state stay
behind (`e2e--build-output-dirs'), so JDTLS and the build tool start clean."
  (let* ((src (directory-file-name (expand-file-name src)))
         (tmp (make-temp-file "hellmacs-e2e" t))
         (dst (expand-file-name (or name (file-name-nondirectory src)) tmp)))
    (push (file-name-as-directory tmp) e2e--copies)
    (copy-directory src dst nil t t)
    (dolist (d e2e--build-output-dirs)
      (let ((dir (expand-file-name d dst)))
        (when (file-directory-p dir) (delete-directory dir t))))
    dst))

(defun e2e-copy-fixture (fixture &optional name)
  "Copy test/fixtures/FIXTURE (like \"java/maven-demo\"); see `e2e-copy-project'."
  (e2e-copy-project (expand-file-name (concat "../fixtures/" fixture) e2e--root) name))

(defun e2e-rss-mb (pid what)
  "PID's WHAT (VmRSS, or VmHWM for the peak) in MB, from /proc."
  (with-temp-buffer
    (insert-file-contents (format "/proc/%d/status" pid))
    (when (re-search-forward (format "^%s:[ \t]+\\([0-9]+\\) kB" what) nil t)
      (/ (string-to-number (match-string 1)) 1024.0))))

(defun e2e-pick-file (proj files)
  "The file to work in: $HELLMACS_PARITY_FILE (relative to PROJ), else the biggest of FILES."
  (if-let* ((f (getenv "HELLMACS_PARITY_FILE")))
      (expand-file-name f proj)
    (car (sort (copy-sequence files)
               (lambda (a b) (> (file-attribute-size (file-attributes a))
                                (file-attribute-size (file-attributes b))))))))

(defun e2e-goto-identifier (regexp)
  "Put point on the first identifier REGEXP captures in group 1; t if found."
  (goto-char (point-min))
  (when (re-search-forward regexp nil t)
    (goto-char (match-beginning 1))
    t))

(defun e2e-code-action-titles (range &optional only)
  "Titles of the code actions the server offers for RANGE (kinds ONLY, if given)."
  (mapcar (lambda (a) (lsp-get a :title))
          (append (lsp-request "textDocument/codeAction"
                               (list :textDocument (lsp--text-document-identifier)
                                     :range range
                                     :context (append (list :diagnostics [])
                                                      (when only (list :only (vconcat only))))))
                  nil)))

(defun e2e-completion-items (res)
  "The items of completion response RES, a CompletionList or a plain array, as a list."
  (append (if (lsp-get res :items) (lsp-get res :items) res) nil))

(defun e2e-edit-changes (edit)
  "The per-document changes of workspace EDIT: :documentChanges, else :changes."
  (or (lsp-get edit :documentChanges) (lsp-get edit :changes)))

;;; Temporary projects -------------------------------------------------------

(defvar e2e--projects nil
  "Temporary project copies added with `e2e-add-project', undone at exit.")

(declare-function lsp-workspace-folders-add "ext:lsp-mode")
(declare-function lsp-workspace-folders-remove "ext:lsp-mode")
(declare-function dap--get-breakpoints "ext:dap-mode")
(declare-function dap--persist-breakpoints "ext:dap-mode")

(defun e2e-add-project (proj)
  "Add PROJ, a temporary copy of a fixture, to the lsp session; return PROJ.
It's the answer to lsp-mode's \"import this project?\". When Emacs
exits, PROJ is taken back out of the session and dap-mode's saved
breakpoints, and deleted (see `e2e--forget-projects-h'): left in, a
later run in the same install would find folders that no longer exist."
  (require 'lsp-mode)
  (lsp-workspace-folders-add proj)
  (push proj e2e--projects)
  proj)

(defun e2e--forget-projects-h ()
  "Undo `e2e-add-project' for every project, then delete the copies.
Set HELLMACS_E2E_KEEP to keep the copies (for a look after the run)."
  (dolist (proj e2e--projects)
    (let ((root (file-name-as-directory (expand-file-name proj))))
      (ignore-errors
        (when (fboundp 'dap--get-breakpoints)
          (let ((breakpoints (dap--get-breakpoints)))
            (dolist (file (hash-table-keys breakpoints))
              (when (string-prefix-p root (expand-file-name file))
                (remhash file breakpoints)))
            (dap--persist-breakpoints breakpoints))))
      (ignore-errors
        (let ((inhibit-message t))
          (lsp-workspace-folders-remove proj)))
      ;; The copy's own temporary directory, and only if `e2e-copy-project'
      ;; made it: a project added from anywhere else is left where it is.
      (let ((dir (file-name-directory (directory-file-name root))))
        (when (and (member (getenv "HELLMACS_E2E_KEEP") '(nil ""))
                   (member dir e2e--copies))
          (delete-directory dir t)))))
  (setq e2e--projects nil))

;; Before lsp-mode and dap-mode's own exit hooks, which save their state.
(add-hook 'kill-emacs-hook #'e2e--forget-projects-h -90)

(provide 'e2e-lib)
;;; e2e-lib.el ends here
