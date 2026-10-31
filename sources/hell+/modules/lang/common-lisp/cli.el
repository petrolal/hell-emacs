;;; lang/common-lisp/cli.el -*- lexical-binding: t; -*-

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

;; `bin/hell check' runner for Common Lisp files (sblint via native tool or SBCL).

;;; Code:

(require 'hell-lib)
(hell-require 'hell-lib 'check-tools)

(defun hell-common-lisp-check-run (files)
  "Execute Common Lisp analysis (sblint via SBCL batch runner) across FILES.
For `hell-check-register-runner'."
  (let (diags)
    (cond
     ;; Priority 1: Native `sblint' executable if present
     ((executable-find "sblint")
      (dolist (file files)
        (let* ((cmd-output (cdr (hell-process-output "sblint" file)))
               (lines (split-string cmd-output "\n" t)))
          (dolist (line lines)
            (if (string-match "\\`\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)\\'" line)
                (let ((f (match-string 1 line))
                      (l (string-to-number (match-string 2 line)))
                      (c (string-to-number (match-string 3 line)))
                      (sev (match-string 4 line))
                      (msg (match-string 5 line)))
                  (push (hell-check-make-diag "Common Lisp" "sblint" (or sev "Warning") f l c "sblint" msg) diags))
              (push (hell-check-make-diag "Common Lisp" "sblint" "Warning" file 1 1 "sblint" line) diags))))))

     ;; Priority 2: Headless SBCL batch runner
     ((executable-find "sbcl")
      (dolist (file files)
        (let* ((sbcl-script
                (format "(handler-bind ((style-warning (lambda (c)
                                                        (format t \"~A:1:1: [Warning] ~A~%%\" %S c)
                                                        (muffle-warning c)))
                                       (warning (lambda (c)
                                                  (format t \"~A:1:1: [Warning] ~A~%%\" %S c)
                                                  (muffle-warning c)))
                                       (error (lambda (c)
                                                (format t \"~A:1:1: [Error] ~A~%%\" %S c))))
                           (let ((fasl (compile-file %S :print nil :verbose nil)))
                             (when (and fasl (probe-file fasl))
                               (delete-file fasl))))"
                        file file file file))
               (res (cdr (hell-process-output "sbcl" "--noinform" "--non-interactive" "--eval" sbcl-script)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\`\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)\\'" line)
              (let ((f (match-string 1 line))
                    (l (string-to-number (match-string 2 line)))
                    (c (string-to-number (match-string 3 line)))
                    (sev (match-string 4 line))
                    (msg (match-string 5 line)))
                (push (hell-check-make-diag "Common Lisp" "sblint" (or sev "Warning") f l c "sbcl-sblint" msg) diags)))))))

     (t
      (dolist (file files)
        (push (hell-check-make-diag "Common Lisp" "sblint" "Info" file 1 1 "tool-missing"
                                    "sblint and sbcl executables not found on PATH")
              diags))))
    (list :diagnostics (nreverse diags) :tools '("sblint"))))

(hell-check-register-runner 'common-lisp #'hell-common-lisp-check-run)

(provide 'lang-common-lisp-cli)
;;; cli.el ends here
