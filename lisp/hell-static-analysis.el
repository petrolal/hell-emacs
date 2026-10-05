;;; hell-static-analysis.el --- Pure Elisp static code analysis suite -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; Version: 0.9.0
;; Package-Requires: ((emacs "29.1"))
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Emacs Lisp's static analysis tools: the quality gate's Emacs Lisp
;; checks (lisp/lib/check-tools.el, `bin/hell check'), and commands to run
;; them from Emacs.
;;
;; Tools integrated:
;;   1. `byte-compile': Programmatic byte compilation treating warnings as
;;      errors (`byte-compile-error-on-warn' set to t).
;;   2. `package-lint': Package metadata, header, and convention checks
;;      via `package-lint-buffer' and `package-lint-file'.
;;   3. `relint': Regular expression error, vulnerability, and mistake inspection
;;      via `relint-buffer', `relint-file', and `relint-current-buffer'.
;;   4. `elsa': Static analysis and gradual type verification via
;;      `hell-static-analysis-elsa-run-file' and `hell-static-analysis-elsa-run-project'.
;;
;; Entry points:
;;   - `M-x hell-static-analysis-run' (C-c c s):
;;     The quality gate limited to Emacs Lisp (`bin/hell check --only
;;     elisp'), in the background: diagnostics link in *hell-check*, and
;;     `hell-static-analysis-save-report' copies its Markdown report.
;;   - `M-x hell-static-analysis-run-current-buffer':
;;     Runs the full analysis suite on the current buffer's file.
;;   - `M-x hell-static-analysis-elsa-run-file', `M-x hell-static-analysis-elsa-run-project':
;;     Run Elsa on a single file or an entire project.
;;   - `M-x hell-static-analysis-package-lint-file':
;;     Run package-lint directly on a given file.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'project)
(require 'bytecomp)
(require 'eieio)
(require 'hell-lib)

;; Forward declarations for optional / third-party linters
(declare-function package-lint-buffer "package-lint" (&optional buffer))
(declare-function package-lint-looks-like-a-package-p "package-lint" (&optional buffer))
(declare-function relint-buffer "relint" (buffer))
(declare-function relint-file "relint" (file))
(declare-function relint-current-buffer "relint" ())
(declare-function relint-diag-message "relint" (diag))
(declare-function relint-diag-beg-pos "relint" (diag))
(declare-function relint-diag-severity "relint" (diag))
(declare-function elsa-analyse-file "elsa" (file global-state &optional already-loaded))
(declare-function elsa-error-p "elsa" (item))
(declare-function elsa-warning-p "elsa" (item))
(declare-function elsa-notice-p "elsa" (item))
(declare-function elsa-message-format "elsa" (item))
(defvar elsa-global-state)

(defgroup hell-static-analysis nil
  "Static code analysis for Emacs Lisp."
  :group 'tools
  :prefix "hell-static-analysis-")

(defcustom hell-static-analysis-linters '(byte-compile package-lint relint elsa)
  "List of linters to run in static analysis.
Supported symbols are `byte-compile', `package-lint', `relint', and `elsa'."
  :type '(repeat (choice (const :tag "Byte Compile (Warnings as Errors)" byte-compile)
                         (const :tag "Package-Lint (Metadata & Standards)" package-lint)
                         (const :tag "Relint (Regexp Vulnerability/Syntax)" relint)
                         (const :tag "Elsa (Static Analyzer & Type Checker)" elsa)))
  :group 'hell-static-analysis)

(defcustom hell-static-analysis-byte-compile-error-on-warn t
  "When non-nil, treat byte-compiler warnings as fatal errors during analysis."
  :type 'boolean
  :group 'hell-static-analysis)

;; Which files are checked is the quality gate's to say, for every language.
(define-obsolete-variable-alias 'hell-static-analysis-ignored-directories
  'hell-check-ignored-directories "1.1")
(define-obsolete-variable-alias 'hell-static-analysis-ignored-files
  'hell-check-ignored-files "1.1")

(defvar hell-static-analysis-last-target nil
  "The last target directory or file analyzed.")

(defvar hell-static-analysis--last-report nil
  "The report the last `hell-static-analysis-run' writes.")

;;; 1. Byte Compilation Checker ----------------------------------------------

(defmacro hell-static-analysis--with-file (file &rest body)
  "Run BODY in a temporary buffer holding FILE's text, in `emacs-lisp-mode'.
FILE isn't visited: no buffer is left behind, and neither its local
variables, its directory's .dir-locals.el nor mode hooks apply.
`buffer-file-name' is FILE while BODY runs, for checks that look at
the file's name (package-lint does)."
  (declare (indent 1) (debug t))
  (let ((name (make-symbol "file")))
    `(let ((,name (expand-file-name ,file)))
       (with-temp-buffer
         (insert-file-contents ,name)
         (setq buffer-file-name ,name)
         (delay-mode-hooks (emacs-lisp-mode))
         (set-buffer-modified-p nil)
         (unwind-protect (progn ,@body)
           (setq buffer-file-name nil)
           (set-buffer-modified-p nil))))))

(defvar byte-compile-current-buffer)
(defvar byte-compile-last-position)
(declare-function byte-compile--warning-source-offset "bytecomp" ())

(defun hell-static-analysis--warning-position ()
  "(LINE . COLUMN) of what the byte-compiler is warning about right now.
Counted in the buffer it compiles, as its own \"file:line:col:\" prefix
is; (1 . 1) when it can't say."
  (let ((offset (if (fboundp 'byte-compile--warning-source-offset)
                    (ignore-errors (byte-compile--warning-source-offset))
                  (and (integerp byte-compile-last-position) byte-compile-last-position))))
    (if (and (integerp offset) (buffer-live-p byte-compile-current-buffer))
        (with-current-buffer byte-compile-current-buffer
          (save-excursion
            (goto-char (max (point-min) (min offset (point-max))))
            (cons (line-number-at-pos) (1+ (current-column)))))
      '(1 . 1))))

(defun hell-static-analysis--check-byte-compile (file)
  "Run `byte-compile' on FILE programmatically, treating warnings as errors.
Returns a list of diagnostic plists:
  (:file FILE :line LINE :col COL :severity SEV :tool TOOL :message MSG)."
  (let ((temp-dest (make-temp-file "hell-static-bc-" nil ".elc"))
        (byte-compile-error-on-warn hell-static-analysis-byte-compile-error-on-warn)
        (byte-compile-verbose nil)
        (inhibit-message t)
        diags)
    (unwind-protect
        (let ((byte-compile-dest-file-function (lambda (_) temp-dest)))
          ;; Intercept compiler warnings and errors, where they are.
          (cl-letf (((symbol-function 'byte-compile-log-warning)
                     (lambda (string &optional _fill level)
                       (pcase-let ((`(,line . ,col) (hell-static-analysis--warning-position)))
                         (push (list :file file
                                     :line line
                                     :col col
                                     :severity (if (or byte-compile-error-on-warn (eq level :error))
                                                   'error
                                                 'warning)
                                     :tool "byte-compile"
                                     :message string)
                               diags)))))
            (condition-case err
                (let ((res (byte-compile-file file)))
                  ;; If byte-compile failed without warning hook caught (e.g. fatal syntax error)
                  (when (and (null res) (null diags))
                    (push (list :file file
                                :line 1
                                :col 1
                                :severity 'error
                                :tool "byte-compile"
                                :message "Byte-compilation failed")
                          diags)))
              (error
               (push (list :file file
                           :line 1
                           :col 1
                           :severity 'error
                           :tool "byte-compile"
                           :message (error-message-string err))
                     diags)))))
      (when (file-exists-p temp-dest)
        (delete-file temp-dest)))
    (nreverse diags)))

(defun hell-static-analysis--ensure-load-path ()
  "Ensure installed Elpaca build directories are present in `load-path'."
  (when (boundp 'hell-data-dir)
    (let ((builds-dir (expand-file-name "elpaca/builds/" hell-data-dir)))
      (when (file-directory-p builds-dir)
        (dolist (d (directory-files builds-dir t "\\`[^.]"))
          (when (file-directory-p d)
            (add-to-list 'load-path d)))))))

;;; 2. Package-Lint Checker --------------------------------------------------

(defun hell-static-analysis-package-lint-file (file)
  "Run `package-lint' across FILE and return structured diagnostics."
  (interactive "fPackage-lint file: ")
  (hell-static-analysis--ensure-load-path)
  (unless (featurep 'package-lint)
    (require 'package-lint nil t))
  (if (not (fboundp 'package-lint-buffer))
      (message "package-lint is not available")
    (let (diags)
      (hell-static-analysis--with-file file
        (save-excursion
          (save-restriction
            (widen)
            (condition-case err
                (when (and (fboundp 'package-lint-looks-like-a-package-p)
                           (package-lint-looks-like-a-package-p))
                  (let ((raw (package-lint-buffer (current-buffer))))
                    (dolist (item raw)
                      (pcase-let ((`(,line ,col ,type ,msg) item))
                        (push (list :file file
                                    :line (or line 1)
                                    :col (1+ (or col 0))
                                    :severity (pcase type
                                                ('error 'error)
                                                ('warning 'warning)
                                                (_ 'info))
                                    :tool "package-lint"
                                    :message msg)
                              diags)))))
              (error
               (push (list :file file
                           :line 1
                           :col 1
                           :severity 'warning
                           :tool "package-lint"
                           :message (format "package-lint error: %s" err))
                     diags))))))
      (nreverse diags))))

(defun hell-static-analysis--check-package-lint (file)
  "Execute `package-lint-buffer' on FILE if it is an Elisp package."
  (hell-static-analysis-package-lint-file file))

;;; 3. Relint Checker --------------------------------------------------------

(defun hell-static-analysis--check-relint (file)
  "Run `relint-buffer' / `relint-file' checks on FILE for regexp errors."
  (hell-static-analysis--ensure-load-path)
  (unless (featurep 'relint)
    (require 'relint nil t))
  (if (not (fboundp 'relint-buffer))
      nil
    (let (diags)
      (hell-static-analysis--with-file file
        (save-excursion
          (save-restriction
            (widen)
            (condition-case err
                (let ((raw (relint-buffer (current-buffer))))
                  (dolist (d raw)
                    (let* ((pos (and (fboundp 'relint-diag-beg-pos) (relint-diag-beg-pos d)))
                           (line (if pos (save-excursion (goto-char pos) (line-number-at-pos)) 1))
                           (col (if pos (save-excursion (goto-char pos) (1+ (current-column))) 1))
                           (sev (if (fboundp 'relint-diag-severity) (relint-diag-severity d) 'warning))
                           (msg (if (fboundp 'relint-diag-message) (relint-diag-message d) (format "%s" d))))
                      (push (list :file file
                                  :line line
                                  :col col
                                  :severity (pcase sev
                                              ('error 'error)
                                              ('warning 'warning)
                                              (_ 'info))
                                  :tool "relint"
                                  :message msg)
                            diags))))
              (error
               (push (list :file file
                           :line 1
                           :col 1
                           :severity 'warning
                           :tool "relint"
                           :message (format "package-lint error: %s" err))
                     diags))))))
      (nreverse diags))))

;;; 4. Elsa Static Analyzer --------------------------------------------------

(defun hell-static-analysis--slot (obj slot-name &optional default)
  "Retrieve slot SLOT-NAME from EIEIO object OBJ, or return DEFAULT."
  (condition-case nil
      (slot-value obj (intern (symbol-name slot-name)))
    (error default)))

(defun hell-static-analysis-elsa-run-file (file)
  "Run Elsa static analysis on FILE and return diagnostics."
  (interactive "fElsa analyze file: ")
  (hell-static-analysis--ensure-load-path)
  (unless (featurep 'elsa)
    (require 'elsa nil t))
  (unless (featurep 'elsa-startup)
    (require 'elsa-startup nil t))
  (if (not (fboundp 'elsa-analyse-file))
      (message "Elsa is not available")
    (let* ((cache-root (expand-file-name "elsa/" (if (boundp 'hell-cache-dir) hell-cache-dir temporary-file-directory)))
           (_ (make-directory (expand-file-name ".elsa" cache-root) t))
           (global-state (or (bound-and-true-p elsa-global-state)
                             (and (fboundp 'elsa-state) (elsa-state)))))
      (when global-state
        (condition-case nil
            (setf (slot-value global-state (intern "project-directory")) cache-root)
          (error nil)))
      (let* ((result (condition-case err
                         (elsa-analyse-file file global-state)
                       (error (list :error err))))
             (errors (and result
                          (not (plist-get result :error))
                          (hell-static-analysis--slot result 'errors)))
             diags)
        (dolist (item errors)
          (let ((line (hell-static-analysis--slot item 'line 1))
                (col (hell-static-analysis--slot item 'column 1))
                (sev (cond
                      ((and (fboundp 'elsa-error-p) (elsa-error-p item)) 'error)
                      ((and (fboundp 'elsa-warning-p) (elsa-warning-p item)) 'warning)
                      (t 'info)))
                (msg (if (fboundp 'elsa-message-format)
                         (elsa-message-format item)
                       (format "%s" item))))
            (push (list :file file
                        :line (or line 1)
                        :col (or col 1)
                        :severity sev
                        :tool "elsa"
                        :message msg)
                  diags)))
        (nreverse diags)))))

(defvar hell-check-only)
(declare-function hell-check-discover-files "lib/check-tools" (targets))

(defun hell-static-analysis-elsa-run-project (&optional dir)
  "Run Elsa static analysis across project at DIR and return diagnostics."
  (interactive "DProject directory to analyze with Elsa: ")
  (let* ((root (or dir
                   (when-let* ((proj (project-current))) (project-root proj))
                   default-directory))
         (files (progn
                  (hell-require 'hell-lib 'check-tools)
                  (let ((hell-check-only '(elisp)))
                    (plist-get (hell-check-discover-files (list root)) :files))))
         all-diags)
    (dolist (file files)
      (setq all-diags (append all-diags (hell-static-analysis-elsa-run-file file))))
    all-diags))

(defun hell-static-analysis--check-elsa (file)
  "Execute Elsa checks on FILE."
  (hell-static-analysis-elsa-run-file file))

;;; In Emacs: the quality gate, for Emacs Lisp ---------------------------------
;;
;; The checks above are the quality gate's Emacs Lisp tools
;; (lisp/lib/check-tools.el). Run from here, they're `hell-check' limited
;; to Emacs Lisp: `bin/hell check --only elisp' in the background, its
;; diagnostics links in *hell-check*, the same trust question and report.

(declare-function hell-check "cli/check" (&optional target only report-file))

(defun hell-static-analysis--report-file (target report-file)
  "Where the run on TARGET writes its report: REPORT-FILE, or under TARGET."
  (expand-file-name (or report-file ".hell/reports/lint-report.md")
                    (if (file-directory-p target) target (file-name-directory target))))

;;;###autoload
(defun hell-static-analysis-run (&optional target report-file)
  "Run the Emacs Lisp checks on TARGET (a file or directory), in the background.
That's `hell-check' limited to Emacs Lisp: the tools in
`hell-static-analysis-linters', diagnostics in *hell-check*. Its
Markdown report goes to REPORT-FILE, else .hell/reports/lint-report.md
in TARGET; `hell-static-analysis-save-report' copies it elsewhere.
Interactively, the current project; with \\[universal-argument], a file
or directory you choose; with two, also where the report goes."
  (interactive
   (let* ((tgt (if current-prefix-arg
                   (read-file-name "File or directory to analyze: " nil default-directory t)
                 (or (when-let* ((proj (project-current))) (project-root proj))
                     default-directory)))
          (rep (when (equal current-prefix-arg '(16))
                 (read-file-name "Save report to: " tgt
                                 (expand-file-name "static-analysis-report.md" tgt)))))
     (list tgt rep)))
  (let ((target (expand-file-name (or target default-directory))))
    (setq hell-static-analysis-last-target target
          hell-static-analysis--last-report (hell-static-analysis--report-file target report-file))
    (hell-check target '(elisp) hell-static-analysis--last-report)))

(defun hell-static-analysis-rerun ()
  "Re-run static analysis on `hell-static-analysis-last-target'."
  (interactive)
  (if hell-static-analysis-last-target
      (hell-static-analysis-run hell-static-analysis-last-target)
    (call-interactively #'hell-static-analysis-run)))

;;;###autoload
(defun hell-static-analysis-save-report (&optional file)
  "Copy the last static analysis's Markdown report to FILE.
Defaults to static-analysis-report.md in the analyzed target's directory."
  (interactive
   (let* ((default-dir (if hell-static-analysis-last-target
                           (if (file-directory-p hell-static-analysis-last-target)
                               hell-static-analysis-last-target
                             (file-name-directory hell-static-analysis-last-target))
                         default-directory))
          (default-file (expand-file-name "static-analysis-report.md" default-dir)))
     (list (read-file-name "Save analysis report to: " default-dir default-file nil "static-analysis-report.md"))))
  (unless (and hell-static-analysis--last-report (file-exists-p hell-static-analysis--last-report))
    (user-error "No static analysis report yet; run `hell-static-analysis-run' first, and let it finish"))
  (let ((out (expand-file-name (or file "static-analysis-report.md"))))
    (copy-file hell-static-analysis--last-report out t)
    (message "Static analysis report saved to %s" (abbreviate-file-name out))))

;;;###autoload
(defun hell-static-analysis-run-current-buffer (&optional report-file)
  "Run the static analysis suite on the current buffer's file.
If REPORT-FILE is provided, write the Markdown report to it."
  (interactive (list (when current-prefix-arg (read-file-name "Save report to: "))))
  (unless (buffer-file-name)
    (user-error "Current buffer is not visiting a file"))
  (hell-static-analysis-run (buffer-file-name) report-file))

(provide 'hell-static-analysis)
;;; hell-static-analysis.el ends here
