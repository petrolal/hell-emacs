;;; lang/scala/cli.el -*- lexical-binding: t; -*-

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

;;; `bin/hell check' (lisp/lib/check-tools.el) -----------------------------------

(hell-require 'hell-lib 'check-tools)

(defun hell-scala-check-run (files)
  "Run Scala quality checks on FILES: scalafmt & scalafix.
For `hell-check-register-runner'."
  (let (diags)
    ;; 1. scalafmt
    (if (executable-find "scalafmt")
        (let* ((res (cdr (apply #'hell-process-output "scalafmt" "--test" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\([^:\n]+\\):\\([0-9]+\\):\\(?:\\([0-9]+\\):\\)? \\(.*\\)" line)
              (push (hell-check-make-diag "Scala" "scalafmt" "Warning"
                                           (match-string 1 line)
                                           (string-to-number (match-string 2 line))
                                           (if (match-string 3 line) (string-to-number (match-string 3 line)) 1)
                                           "scalafmt" (match-string 4 line))
                    diags))))
      (dolist (f files)
        (push (hell-check-make-diag "Scala" "scalafmt" "Info" f 1 1 "tool-missing"
                                     "scalafmt not found on PATH")
              diags)))
    ;; 2. scalafix
    (if (executable-find "scalafix")
        (let* ((res (cdr (apply #'hell-process-output "scalafix" "--check" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:error\\|warning\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)" line)
              (push (hell-check-make-diag "Scala" "scalafix" "Error"
                                           (match-string 1 line)
                                           (string-to-number (match-string 2 line))
                                           (string-to-number (match-string 3 line))
                                           (or (match-string 4 line) "scalafix")
                                           (match-string 5 line))
                    diags))))
      (dolist (f files)
        (push (hell-check-make-diag "Scala" "scalafix" "Info" f 1 1 "tool-missing"
                                     "scalafix not found on PATH")
              diags)))
    (list :diagnostics diags :tools '("scalafmt" "scalafix"))))

(hell-check-register-runner 'scala #'hell-scala-check-run)

;;; lang/scala/cli.el ends here
