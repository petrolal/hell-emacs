;;; lisp/cli/check.el --- Static Analysis and Linting Quality Gate -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
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

;; `bin/hell check' (`lint'), the quality gate, and `hell-check', which
;; runs it from Emacs in the background. What it runs is in
;; lisp/lib/check-tools.el, its reports in lisp/lib/check-report.el; this
;; is the command: its options, its terminal summary, its exit code.
;;
;; Part `check' of `hell-cli': (hell-require 'hell-cli 'check).

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'compile)
(require 'hell-lib)
(eval-and-compile
  (hell-require 'hell-lib 'check-tools)
  (hell-require 'hell-lib 'check-report))

(defvar hell-cli--problems 0)

(declare-function hell-cli-help "hell-cli" (&optional command &rest _))
(declare-function hell-cli--say "hell-cli" (format-string &rest args))

;;; Terminal Output & Quality Gate --------------------------------------------

(defun hell-check-render-terminal (results report-file strict-p)
  "Render a terminal summary of RESULTS with clickable file locations and counts.
REPORT-FILE is where the full report went. Returns non-nil if the
quality gate passes (with STRICT-P, warnings fail it too), nil otherwise."
  (let* ((targets (plist-get results :targets))
         (tools (plist-get results :tools))
         (files-count (plist-get results :total-files))
         (errors (plist-get results :errors))
         (warnings (plist-get results :warnings))
         (info (plist-get results :info))
         (diags (plist-get results :diagnostics))
         (by-lang (plist-get results :by-language))
         (passed (and (zerop errors)
                      (or (not strict-p) (zerop warnings)))))

    (hell-cli--say "")
    (hell-cli--say "================================================================================")
    (hell-cli--say "Hell Quality Gate: Static Analysis & Linting")
    (hell-cli--say "================================================================================")
    (hell-cli--say "Targets:   %s" (mapconcat #'identity targets ", "))
    (if by-lang
        (let (lang-summaries)
          (dolist (pair by-lang)
            (let* ((spec (assq (car pair) hell-check-languages))
                   (name (or (plist-get (cdr spec) :name) (symbol-name (car pair)))))
              (push (format "%s (%d files)" name (length (cdr pair))) lang-summaries)))
          (hell-cli--say "Detected:  %s" (mapconcat #'identity (nreverse lang-summaries) ", ")))
      (hell-cli--say "Detected:  None"))
    (hell-cli--say "Tools:     %s" (if tools (mapconcat #'identity tools ", ") "none"))
    (hell-cli--say "--------------------------------------------------------------------------------")

    (if (null diags)
        (hell-cli--say "No issues found across %d scanned file(s)." files-count)
      (hell-cli--say "Diagnostics:")
      (dolist (d diags)
        (let* ((sev (plist-get d :severity))
               (loc (plist-get d :location))
               (lang (plist-get d :language))
               (tool (plist-get d :tool))
               (rule (plist-get d :rule-id))
               (msg (plist-get d :message))
               (mark (pcase sev ("Error" "✗") ("Warning" "!") (_ "·"))))
          ;; Clickable terminal location: file:line:col
          (hell-cli--say "  %s %s: [%s/%s] (%s) %s"
                         mark loc lang tool rule msg))))

    (hell-cli--say "--------------------------------------------------------------------------------")
    (hell-cli--say "Summary: Scanned Files: %d | Issues: %d (Errors: %d, Warnings: %d, Info: %d)"
                   files-count (+ errors warnings info) errors warnings info)
    (hell-cli--say "Report:  %s" (abbreviate-file-name report-file))
    (hell-cli--say "================================================================================")
    (if passed
        (hell-cli--say "Quality Gate: PASSED (all checks succeeded)")
      (hell-cli--say "Quality Gate: FAILED (%d error%s%s)"
                     errors
                     (if (= errors 1) "" "s")
                     (if (and strict-p (> warnings 0))
                         (format ", strict threshold violated: %d warning%s"
                                 warnings (if (= warnings 1) "" "s"))
                       "")))
    passed))

;;; CLI Command Entrypoint ----------------------------------------------------

(defun hell-cli-check (&rest args)
  "Static Analysis and Linting Quality Gate.
Evaluates code against surface style linters and deep AST/semantic analyzers.
ARGS are the command line's:

Options:
  -o, --output FILE   Write diagnostic report to FILE
                      (default: .hell/reports/lint-report.md)
  --format FORMAT     Report format: `markdown' (default) or `json'
  --strict            Fail quality gate on warnings as well as errors
  --only LANGS        Check only these languages, comma-separated (elisp,
                      java, kotlin, clojure, scala, groovy-gradle,
                      common-lisp); trunk and pre-commit then don't run
  --trust             Run the checks that execute the target's own code
                      (./gradlew, pre-commit, trunk, byte-compile, sblint)
                      without asking; else asked on a terminal, or skipped
  -h, --help          Show command usage"
  (let ((output-file nil)
        (format-type nil)
        (strict-p nil)
        (trust nil)
        (only nil)
        (targets nil)
        (rest args))
    (while rest
      (let ((arg (pop rest)))
        (cond
         ((or (string= arg "-o") (string= arg "--output"))
          (if (and rest (not (string-prefix-p "-" (car rest))))
              (setq output-file (pop rest))
            (user-error "%s requires a file path" arg)))
         ((string-prefix-p "--output=" arg)
          (setq output-file (substring arg (length "--output="))))
         ((or (string= arg "--format") (string= arg "-f"))
          (if (and rest (not (string-prefix-p "-" (car rest))))
              (setq format-type (intern (downcase (pop rest))))
            (user-error "%s requires a format (markdown or json)" arg)))
         ((string-prefix-p "--format=" arg)
          (setq format-type (intern (downcase (substring arg (length "--format="))))))
         ((string= arg "--strict")
          (setq strict-p t))
         ((string= arg "--trust")
          (setq trust t))
         ((or (string= arg "--only") (string-prefix-p "--only=" arg))
          (setq only (hell-check--parse-languages
                      (if (string= arg "--only")
                          (if (and rest (not (string-prefix-p "-" (car rest))))
                              (pop rest)
                            (user-error "--only requires languages, as in --only elisp,java"))
                        (substring arg (length "--only="))))))
         ((or (string= arg "-h") (string= arg "--help"))
          (hell-cli-help "check")
          (kill-emacs 0))
         ((string-prefix-p "-" arg)
          (user-error "Unknown option: %s" arg))
         (t
          (push arg targets)))))

    (setq targets (if targets (nreverse targets) (list default-directory)))

    ;; Auto-detect format from file extension if not explicitly specified
    (unless format-type
      (setq format-type (if (and output-file (string-suffix-p ".json" output-file))
                            'json
                          'markdown)))

    ;; Default report file if not provided
    (unless output-file
      (setq output-file (if (eq format-type 'json)
                            (expand-file-name ".hell/reports/lint-report.json" default-directory)
                          (expand-file-name ".hell/reports/lint-report.md" default-directory))))

    ;; Run quality gate
    (let* ((results (let ((hell-check-trust (or hell-check-trust trust))
                          (hell-check-only (or only hell-check-only)))
                       (hell-check-run-all targets)))
           (written-report (hell-check-write-report results output-file format-type))
           (passed (hell-check-render-terminal results written-report strict-p)))
      (if noninteractive
          (if passed
              (progn
                (setq hell-cli--problems 0)
                (kill-emacs 0))
            (setq hell-cli--problems (plist-get results :errors))
            (kill-emacs 1))
        (setq hell-cli--problems (if passed 0 (plist-get results :errors)))
        (when (file-exists-p written-report)
          (view-file written-report))
        passed))))

(defalias 'hell-cli-lint #'hell-cli-check
  "Alias for `hell-cli-check'.")

;;; In Emacs ---------------------------------------------------------------------

(defvar hell-dir)                       ; early-init.el
(defvar hell-profile)

(defconst hell-check--error-regexp
  '(hell-check "^  \\(?:✗\\|\\(!\\)\\|\\(·\\)\\) \\(.+?\\):\\([0-9]+\\):\\([0-9]+\\): \\["
               3 4 5 (1 . 2))
  "`hell-check-render-terminal''s diagnostic lines, for `compilation-mode'.")

(define-compilation-mode hell-check-mode "Hell-Check"
  "Output of `hell-check': each diagnostic links to its place."
  (setq-local compilation-error-regexp-alist-alist
              (cons hell-check--error-regexp compilation-error-regexp-alist-alist))
  (setq-local compilation-error-regexp-alist '(hell-check)))

(defun hell-check--parse-languages (spec)
  "SPEC, \"elisp,java\", as `hell-check-only' wants it; an error on a typo."
  (mapcar (lambda (name)
            (let ((lang (intern name)))
              (unless (assq lang hell-check-languages)
                (user-error "No such language `%s' for --only; it's one of %s" name
                            (mapconcat (lambda (l) (symbol-name (car l))) hell-check-languages ", ")))
              lang))
          (split-string spec "[, ]+" t)))

(defun hell-check--command (target trust &optional only report-file)
  "The `bin/hell check' command line for TARGET, with --trust if TRUST.
ONLY (languages) and REPORT-FILE become --only and -o."
  (mapconcat #'shell-quote-argument
             (append (list (expand-file-name "bin/hell" hell-dir))
                     (and hell-profile (list "--profile" hell-profile))
                     (list "check" target)
                     (and only (list "--only" (mapconcat #'symbol-name only ",")))
                     (and report-file (list "-o" (expand-file-name report-file)))
                     (and trust (list "--trust")))
             " "))

;;;###autoload
(defun hell-check (&optional target only report-file)
  "Run the unified Static Analysis and Linting Quality Gate on TARGET.
Interactively, the current project; with a prefix argument, a file or
directory you choose. It runs `bin/hell check' in the background, its
diagnostics links in *hell-check*. ONLY limits it to those languages
\(`hell-check-only'); REPORT-FILE is where its report goes. If TARGET's
own code would run (`hell-check--code-runners'), it asks first, unless
TARGET is trusted (`hell-check-trusted-directories')."
  (interactive
   (list (if current-prefix-arg
             (read-file-name "Target to check: " default-directory default-directory t)
           (or (when-let* ((proj (project-current))) (project-root proj))
               default-directory))))
  (let* ((target (expand-file-name (or target default-directory)))
         (dir (hell-check--target-dir (list target)))
         (runners (let ((hell-check-only only))
                    (hell-check--code-runners
                     (list target)
                     (plist-get (hell-check-discover-files (list target)) :by-language))))
         (trust (and runners
                     (or (hell-check--trusted-p dir)
                         (yes-or-no-p (format "Checking %s runs its own code: %s. Trust it? "
                                              (abbreviate-file-name dir)
                                              (string-join runners ", "))))))
         (default-directory dir))
    (compilation-start (hell-check--command target trust only report-file) #'hell-check-mode
                       (lambda (_) "*hell-check*"))))

;;;###autoload
(defalias 'hell-lint #'hell-check
  "Alias for `hell-check'.")

(hell-provide 'hell-cli 'check)
;;; check.el ends here
