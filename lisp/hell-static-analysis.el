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

;; Pure Emacs Lisp static code analysis suite for Emacs Lisp configuration
;; and packages managed natively via Elpaca, running inside Emacs without
;; any external shell scripts or Makefiles.
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
;;   - `M-x hell-static-analysis-run':
;;     Scans project/config `.el' files, aggregates all diagnostics into a
;;     compilation-mode results buffer with clickable error locations, and
;;     emits native summary counts of errors, warnings, and code smells.
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
(require 'compile)
(require 'bytecomp)
(require 'eieio)

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

(defcustom hell-static-analysis-ignored-directories
  '(".git" ".svn" ".hg" "elpaca" "builds" "sources" "compiled"
    "eln-cache" ".cache" ".local" "node_modules" "target" "dist")
  "Directories to skip when scanning for Elisp files."
  :type '(repeat string)
  :group 'hell-static-analysis)

(defcustom hell-static-analysis-ignored-files
  '(".*-autoloads\\.el\\'" "loaddefs\\.el\\'" "custom\\.el\\'")
  "Regexps of files to skip during static analysis."
  :type '(repeat regexp)
  :group 'hell-static-analysis)

(defvar hell-static-analysis-buffer-name "*Static Analysis*"
  "Name of the buffer displaying static analysis results.")

(defvar hell-static-analysis-last-target nil
  "The last target directory or file analyzed.")

;;; File Discovery -----------------------------------------------------------

(defun hell-static-analysis--ignored-dir-p (dir)
  "Return non-nil if DIR matches any ignored directory names."
  (let ((name (file-name-nondirectory (directory-file-name dir))))
    (seq-some (lambda (ignored) (string= name ignored))
              hell-static-analysis-ignored-directories)))

(defun hell-static-analysis--ignored-file-p (file)
  "Return non-nil if FILE matches ignored patterns or is temporary/backup."
  (let ((basename (file-name-nondirectory file)))
    (or (string-prefix-p ".#" basename)
        (string-prefix-p "#" basename)
        (string-suffix-p "~" basename)
        (seq-some (lambda (re) (string-match-p re basename))
                  hell-static-analysis-ignored-files))))

(defun hell-static-analysis-find-files (target)
  "Discover all `.el' files under TARGET (file or directory).
Skips ignored directories and non-source files."
  (let ((target (expand-file-name target)))
    (cond
     ((file-regular-p target)
      (if (and (string-suffix-p ".el" target)
               (not (hell-static-analysis--ignored-file-p target)))
          (list target)
        nil))
     ((file-directory-p target)
      (let (result)
        (cl-labels ((scan-dir (dir)
                      (unless (hell-static-analysis--ignored-dir-p dir)
                        (let ((entries (directory-files dir t directory-files-no-dot-files-regexp t)))
                          (dolist (entry entries)
                            (cond
                             ((file-directory-p entry)
                              (scan-dir entry))
                             ((and (file-regular-p entry)
                                   (string-suffix-p ".el" entry)
                                   (not (hell-static-analysis--ignored-file-p entry)))
                              (push entry result))))))))
          (scan-dir target)
          (sort result #'string<))))
     (t nil))))

;;; 1. Byte Compilation Checker ----------------------------------------------

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
          ;; Intercept compiler warnings and errors
          (cl-letf (((symbol-function 'byte-compile-log-warning)
                     (lambda (string &optional pos fill level)
                       (let* ((line (cond
                                     ((and pos (markerp pos))
                                      (with-current-buffer (marker-buffer pos)
                                        (save-excursion (goto-char pos) (line-number-at-pos))))
                                     ((and pos (integerp pos))
                                      (with-current-buffer (find-file-noselect file)
                                        (save-excursion (goto-char pos) (line-number-at-pos))))
                                     ((and (boundp 'byte-compile-last-position)
                                           byte-compile-last-position)
                                      (if (markerp byte-compile-last-position)
                                          (with-current-buffer (marker-buffer byte-compile-last-position)
                                            (save-excursion (goto-char byte-compile-last-position) (line-number-at-pos)))
                                        (if (integerp byte-compile-last-position)
                                            (with-current-buffer (find-file-noselect file)
                                              (save-excursion (goto-char byte-compile-last-position) (line-number-at-pos)))
                                          1)))
                                     (t 1)))
                              (col (cond
                                    ((and pos (markerp pos))
                                     (with-current-buffer (marker-buffer pos)
                                       (save-excursion (goto-char pos) (1+ (current-column)))))
                                    ((and pos (integerp pos))
                                     (with-current-buffer (find-file-noselect file)
                                       (save-excursion (goto-char pos) (1+ (current-column)))))
                                    (t 1)))
                              (sev (if (or byte-compile-error-on-warn
                                           (eq fill :error)
                                           (eq level 'error))
                                       'error
                                     'warning)))
                         (push (list :file file
                                     :line line
                                     :col col
                                     :severity sev
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
    (let ((buf (find-file-noselect file))
          diags)
      (with-current-buffer buf
        (save-excursion
          (save-restriction
            (widen)
            (condition-case err
                (when (and (fboundp 'package-lint-looks-like-a-package-p)
                           (package-lint-looks-like-a-package-p))
                  (let ((raw (package-lint-buffer buf)))
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
    (let ((buf (find-file-noselect file))
          diags)
      (with-current-buffer buf
        (save-excursion
          (save-restriction
            (widen)
            ;; Ensure emacs-lisp-mode for relint AST inspection
            (unless (derived-mode-p 'emacs-lisp-mode)
              (emacs-lisp-mode))
            (condition-case err
                (let ((raw (relint-buffer buf)))
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

(defun hell-static-analysis-elsa-run-project (&optional dir)
  "Run Elsa static analysis across project at DIR and return diagnostics."
  (interactive "DProject directory to analyze with Elsa: ")
  (let* ((root (or dir
                   (when-let* ((proj (project-current))) (project-root proj))
                   default-directory))
         (files (hell-static-analysis-find-files root))
         all-diags)
    (dolist (file files)
      (setq all-diags (append all-diags (hell-static-analysis-elsa-run-file file))))
    all-diags))

(defun hell-static-analysis--check-elsa (file)
  "Execute Elsa checks on FILE."
  (hell-static-analysis-elsa-run-file file))

;;; Aggregation and Reporting ------------------------------------------------

(defvar hell-static-analysis-last-results nil
  "The plist returned by the most recent `hell-static-analysis-run'.")

(defvar hell-static-analysis-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map compilation-mode-map)
    (define-key map (kbd "g") #'hell-static-analysis-rerun)
    (define-key map (kbd "w") #'hell-static-analysis-save-report)
    (define-key map (kbd "s") #'hell-static-analysis-save-report)
    map)
  "Keymap for `hell-static-analysis-mode'.")

(define-compilation-mode hell-static-analysis-mode "Static-Analysis"
  "Major mode for displaying Emacs Lisp static code analysis results."
  ;; Add recognition for "info:" and "notice:" as info-level diagnostics
  (setq-local compilation-error-regexp-alist
              (append '(("^\\([^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:info\\|notice\\|smell\\):" 1 2 3 0))
                      compilation-error-regexp-alist)))

(defun hell-static-analysis--format-diagnostic (diag)
  "Format a DIAG plist into a standard compiler diagnostic line."
  (let ((file (plist-get diag :file))
        (line (or (plist-get diag :line) 1))
        (col (or (plist-get diag :col) 1))
        (sev (plist-get diag :severity))
        (tool (plist-get diag :tool))
        (msg (plist-get diag :message)))
    (format "%s:%d:%d: %s: [%s] %s\n"
            file line col
            (pcase sev
              ('error "error")
              ('warning "warning")
              (_ "info"))
            tool
            (string-trim (replace-regexp-in-string "\n[ \t]*" " " msg)))))

(defun hell-static-analysis-export-markdown (results &optional output-file)
  "Format RESULTS plist as a Markdown report and write to OUTPUT-FILE.
If OUTPUT-FILE is nil, return the generated Markdown string."
  (let* ((target (plist-get results :target))
         (files-count (plist-get results :files))
         (error-count (plist-get results :errors))
         (warning-count (plist-get results :warnings))
         (smell-count (plist-get results :smells))
         (total (+ error-count warning-count smell-count))
         (elapsed (or (plist-get results :elapsed) 0.0))
         (timestamp (or (plist-get results :timestamp) (current-time-string)))
         (diags (plist-get results :diagnostics))
         (tool-stats (plist-get results :tool-stats)))
    (with-temp-buffer
      (insert "# Static Code Analysis Report\n\n")
      (insert (format "**Generated:** %s  \n" timestamp))
      (insert (format "**Target:** `%s`  \n" (abbreviate-file-name target)))
      (insert (format "**Files Scanned:** %d  \n" files-count))
      (insert (format "**Execution Time:** %.2fs  \n\n" elapsed))

      (insert "## Executive Summary\n\n")
      (insert "| Metric | Count | Status |\n")
      (insert "|:-------|------:|:-------|\n")
      (insert (format "| **Total Issues** | %d | %s |\n"
                      total (if (zerop total) "PASS" (if (> error-count 0) "FAIL" "WARN"))))
      (insert (format "| **Errors** | %d | %s |\n"
                      error-count (if (zerop error-count) "PASS" "ACTION REQUIRED")))
      (insert (format "| **Warnings** | %d | %s |\n"
                      warning-count (if (zerop warning-count) "PASS" "REVIEW")))
      (insert (format "| **Code Smells** | %d | %s |\n\n"
                      smell-count (if (zerop smell-count) "PASS" "INFO")))

      (when tool-stats
        (insert "### Tool Breakdown\n\n")
        (insert "| Linter | Errors | Warnings | Code Smells |\n")
        (insert "|:-------|-------:|---------:|------------:|\n")
        (maphash (lambda (tool stats)
                   (insert (format "| `%s` | %d | %d | %d |\n"
                                   tool
                                   (plist-get stats :errors)
                                   (plist-get stats :warnings)
                                   (plist-get stats :smells))))
                 tool-stats)
        (insert "\n"))

      (insert "## Detailed Findings\n\n")
      (if (null diags)
          (insert "No issues detected. Codebase is clean.\n")
        (insert "| Location | Severity | Tool | Message |\n")
        (insert "|:---------|:---------|:-----|:--------|\n")
        (dolist (d diags)
          (let* ((file (plist-get d :file))
                 (line (or (plist-get d :line) 1))
                 (col (or (plist-get d :col) 1))
                 (sev (upcase (symbol-name (or (plist-get d :severity) 'info))))
                 (tool (or (plist-get d :tool) "unknown"))
                 (rel (file-relative-name file (if (file-directory-p target)
                                                   target
                                                 (file-name-directory target))))
                 (msg (replace-regexp-in-string "|" "\\\\|" (plist-get d :message))))
            (insert (format "| `%s:%d:%d` | **%s** | `%s` | %s |\n"
                            rel line col sev tool msg)))))
      (insert "\n---\n*Report generated natively by Hell Emacs Static Analysis Suite.*\n")

      (let ((content (buffer-string)))
        (when output-file
          (write-region content nil output-file nil 'quiet)
          (message "Static analysis report saved to %s" output-file))
        content))))

;;;###autoload
(defun hell-static-analysis-run (&optional target report-file)
  "Execute static analysis across TARGET (file or directory).
Collects all diagnostics from enabled linters, presents results in
`hell-static-analysis-buffer-name' with clickable error locations,
and emits summary metrics. If REPORT-FILE is non-nil, also exports
the full report to REPORT-FILE."
  (interactive
   (let* ((prompt-report (equal current-prefix-arg '(16)))
          (tgt (if current-prefix-arg
                   (read-file-name "File or directory to analyze: " nil default-directory t)
                 (or (when-let* ((proj (project-current))) (project-root proj))
                     default-directory)))
          (rep (when prompt-report
                 (read-file-name "Save report to: " tgt (expand-file-name "static-analysis-report.md" tgt)))))
     (list tgt rep)))
  (let* ((target (or target default-directory)))
    (setq hell-static-analysis-last-target target)
    (let* ((files (hell-static-analysis-find-files target))
         (active-linters hell-static-analysis-linters)
         (start-time (current-time))
         (all-diags nil)
         (tool-stats (make-hash-table :test 'equal))
         (error-count 0)
         (warning-count 0)
         (smell-count 0))

    ;; Initialize tool stats counters
    (dolist (linter active-linters)
      (puthash (symbol-name linter) (list :errors 0 :warnings 0 :smells 0) tool-stats))

    (message "Static analysis: scanning %d file(s) with %s..."
             (length files)
             (mapconcat #'symbol-name active-linters ", "))

    ;; Run linters on each target file
    (dolist (file files)
      (dolist (linter active-linters)
        (let ((diags (condition-case err
                         (pcase linter
                           ('byte-compile (hell-static-analysis--check-byte-compile file))
                           ('package-lint (hell-static-analysis--check-package-lint file))
                           ('relint (hell-static-analysis--check-relint file))
                           ('elsa (hell-static-analysis--check-elsa file))
                           (_ nil))
                       (error
                        (list (list :file file :line 1 :col 1 :severity 'warning
                                    :tool (symbol-name linter)
                                    :message (format "Linter execution failed: %s" err)))))))
          (dolist (d diags)
            (push d all-diags)
            (let* ((sev (plist-get d :severity))
                   (tool (or (plist-get d :tool) (symbol-name linter)))
                   (stats (or (gethash tool tool-stats)
                              (list :errors 0 :warnings 0 :smells 0))))
              (pcase sev
                ('error
                 (cl-incf error-count)
                 (cl-incf (plist-get stats :errors)))
                ('warning
                 (cl-incf warning-count)
                 (cl-incf (plist-get stats :warnings)))
                (_
                 (cl-incf smell-count)
                 (cl-incf (plist-get stats :smells))))
              (puthash tool stats tool-stats))))))

    ;; Sort diagnostics by file, line, column
    (setq all-diags
          (sort (nreverse all-diags)
                (lambda (a b)
                  (let ((file-a (plist-get a :file))
                        (file-b (plist-get b :file))
                        (line-a (or (plist-get a :line) 1))
                        (line-b (or (plist-get b :line) 1))
                        (col-a (or (plist-get a :col) 1))
                        (col-b (or (plist-get b :col) 1)))
                    (cond
                     ((not (string= file-a file-b)) (string< file-a file-b))
                     ((/= line-a line-b) (< line-a line-b))
                     (t (< col-a col-b)))))))

    (let* ((elapsed (float-time (time-subtract (current-time) start-time)))
           (buf (get-buffer-create hell-static-analysis-buffer-name))
           (results (list :target target
                          :files (length files)
                          :errors error-count
                          :warnings warning-count
                          :smells smell-count
                          :diagnostics all-diags
                          :elapsed elapsed
                          :timestamp (current-time-string start-time)
                          :tool-stats tool-stats)))
      (setq hell-static-analysis-last-results results)

      ;; Render to dedicated compilation buffer
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (hell-static-analysis-mode)
          (setq default-directory (if (file-directory-p target)
                                      target
                                    (file-name-directory target)))

          ;; Header
          (insert (format "-*- mode: compilation; default-directory: %S -*-\n" default-directory))
          (insert (format "Static Analysis started at %s\n" (current-time-string start-time)))
          (insert (format "Target: %s\n" (abbreviate-file-name target)))
          (insert (format "Files scanned: %d\n" (length files)))
          (insert (format "Linters: %s\n"
                          (mapconcat (lambda (l)
                                       (if (eq l 'byte-compile)
                                           "byte-compile (warnings-as-errors)"
                                         (symbol-name l)))
                                     active-linters ", ")))
          (insert (make-string 76 ?-) "\n\n")

          ;; Diagnostic entries
          (if (null all-diags)
              (insert "No static analysis issues found. Clean codebase!\n\n")
            (dolist (diag all-diags)
              (insert (hell-static-analysis--format-diagnostic diag)))
            (insert "\n"))

          ;; Summary Footer
          (insert (make-string 76 ?=) "\n")
          (insert (format "STATIC ANALYSIS SUMMARY (%.2fs)\n" elapsed))
          (insert (format "Total Diagnostics: %d  |  Errors: %d  |  Warnings: %d  |  Code Smells: %d\n\n"
                          (+ error-count warning-count smell-count)
                          error-count warning-count smell-count))
          (insert "Breakdown by Tool:\n")
          (maphash (lambda (tool stats)
                     (insert (format "  %-14s %2d errors, %2d warnings, %2d code smells\n"
                                     (concat tool ":")
                                     (plist-get stats :errors)
                                     (plist-get stats :warnings)
                                     (plist-get stats :smells))))
                   tool-stats)
          (insert (make-string 76 ?=) "\n")
          (insert "\n[Press 'w' or 's' to save report to file, 'g' to re-run]\n")
          (goto-char (point-min))
          (forward-line 6)))

      (display-buffer buf)

      ;; Optional save to report file
      (when report-file
        (hell-static-analysis-export-markdown results report-file))

      ;; Emit summary message natively
      (message "Static analysis complete: %d errors, %d warnings, %d code smells across %d file(s) (%.2fs)"
               error-count warning-count smell-count (length files) elapsed)

      results))))

(defun hell-static-analysis-rerun ()
  "Re-run static analysis on `hell-static-analysis-last-target'."
  (interactive)
  (if hell-static-analysis-last-target
      (hell-static-analysis-run hell-static-analysis-last-target)
    (call-interactively #'hell-static-analysis-run)))

;;;###autoload
(defun hell-static-analysis-save-report (&optional file)
  "Save the most recent static analysis results as a Markdown report FILE.
Defaults to `static-analysis-report.md' in the analyzed target's directory."
  (interactive
   (let* ((default-dir (if hell-static-analysis-last-target
                           (if (file-directory-p hell-static-analysis-last-target)
                               hell-static-analysis-last-target
                             (file-name-directory hell-static-analysis-last-target))
                         default-directory))
          (default-file (expand-file-name "static-analysis-report.md" default-dir)))
     (list (read-file-name "Save analysis report to: " default-dir default-file nil "static-analysis-report.md"))))
  (unless hell-static-analysis-last-results
    (user-error "No static analysis results available; run `hell-static-analysis-run' first"))
  (let ((out (expand-file-name (or file "static-analysis-report.md"))))
    (hell-static-analysis-export-markdown hell-static-analysis-last-results out)
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
