;;; lang/scheme/config.el -*- lexical-binding: t; -*-

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
;; Scheme dialect support with Geiser.

;;; Code:

(use-package scheme
  :ensure nil
  :mode ("\\.\(?:scm\\|ss\)\\'" . scheme-mode))

(use-package geiser
  :after scheme)

(defun hell-scheme-start-repl ()
  "Start a Geiser REPL."
  (interactive)
  (if (fboundp 'geiser) (geiser nil) (compile "guile")))

(defun hell-scheme-eval-buffer ()
  "Evaluate the current Scheme buffer."
  (interactive)
  (when (fboundp 'geiser-eval-buffer) (geiser-eval-buffer)))

(defun hell-scheme-eval-region ()
  "Evaluate the current Scheme region."
  (interactive)
  (when (fboundp 'geiser-eval-region) (call-interactively 'geiser-eval-region)))

(hell-localleader-def 'scheme-mode
  "s" '("start Geiser REPL" . hell-scheme-start-repl)
  "b" '("eval buffer" . hell-scheme-eval-buffer)
  "l" '("eval region" . hell-scheme-eval-region))

(provide 'lang-scheme-config)
;;; config.el ends here
