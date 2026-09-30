;;; test-ux.el --- Tests for modules/hellmacs/+ux.el -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'hellmacs-ux (expand-file-name "hellmacs/+ux" hellmacs-modules-dir))

(ert-deftest test-ux/routine-error-classification ()
  "Distinguishes routine user signals from unexpected fatal errors."
  (should (hellmacs-ux--routine-error-p '(user-error "Cannot find file")))
  (should (hellmacs-ux--routine-error-p '(quit)))
  (should (hellmacs-ux--routine-error-p '(beginning-of-buffer)))
  (should (hellmacs-ux--routine-error-p '(end-of-buffer)))
  (should (hellmacs-ux--routine-error-p '(buffer-read-only)))
  (should-not (hellmacs-ux--routine-error-p '(void-variable foo)))
  (should-not (hellmacs-ux--routine-error-p '(void-function bar)))
  (should-not (hellmacs-ux--routine-error-p '(error "Null pointer in JDTLS backend"))))

(ert-deftest test-ux/kill-prompt ()
  "Confirm kill emacs uses the Hellmacs thematic prompt."
  (should (equal hellmacs-ux-kill-prompt "Extinguish the forge and return to the void? ")))

(ert-deftest test-ux/kill-prompt-leaves-yours ()
  "The thematic quit prompt replaces Hellmacs' own default only: a
`confirm-kill-emacs' you set in config.el (nil, or your function) stays."
  (let ((noninteractive nil)
        (hellmacs-ux-enable t)
        (command-error-function command-error-function)
        (hellmacs-ux-jvm-output-hooks nil))
    (let ((confirm-kill-emacs #'y-or-n-p))       ; core's default
      (hellmacs-ux-activate)
      (should (eq confirm-kill-emacs #'hellmacs-ux-confirm-kill-emacs)))
    (dolist (yours '(nil yes-or-no-p))
      (let ((confirm-kill-emacs yours))
        (hellmacs-ux-activate)
        (should (eq confirm-kill-emacs yours))))))

(ert-deftest test-ux/format-fatality ()
  "Formats unhandled errors with the fatality prefix."
  (let ((hellmacs-ux-enable t))
    (should (string-match-p "\\[CRITICAL FATALITY\\]"
                            (format "[CRITICAL FATALITY]: %s" "Symbol's value as variable is void")))))

(ert-deftest test-ux/traces-highlighted-in-jvm-output-only ()
  "Stack traces are colored in builds, and in comint buffers running one
(`compilation-shell-minor-mode': :tools run's), not in every shell or SQLi."
  (should (memq 'compilation-mode-hook hellmacs-ux-jvm-output-hooks))
  (should (memq 'compilation-shell-minor-mode-hook hellmacs-ux-jvm-output-hooks))
  (should-not (memq 'comint-mode-hook hellmacs-ux-jvm-output-hooks)))

(ert-deftest test-ux/trace-highlighting-added-once ()
  "A buffer running one thing after another (:tools run's) gets the rules once."
  (with-temp-buffer
    (hellmacs-ux--highlight-jvm-exceptions-h)
    (let ((rules (length font-lock-keywords)))
      (hellmacs-ux--highlight-jvm-exceptions-h)
      (should (= (length font-lock-keywords) rules)))))

(provide 'test-ux)
;;; test-ux.el ends here
