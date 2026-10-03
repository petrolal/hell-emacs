;;; lang/emacs-lisp/config.el -*- lexical-binding: t; -*-

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
;; Emacs Lisp development extras: macrostep, elisp-demos, and evaluation keys.

;;; Code:

(declare-function macrostep-expand "macrostep" (&optional arg))
(declare-function elisp-demos-advice-describe-function-1 "elisp-demos" (function))

(use-package macrostep
  :defer t)

(use-package elisp-demos
  :defer t
  :init
  (advice-add 'describe-function-1 :after #'elisp-demos-advice-describe-function-1))

;; Localleader keybindings under C-c l
(hell-localleader-def 'emacs-lisp-mode
  "e b" '("eval buffer" . eval-buffer)
  "e d" '("eval defun" . eval-defun)
  "e e" '("eval last sexp" . eval-last-sexp)
  "e r" '("eval region" . eval-region)
  "d d" '("describe function" . describe-function)
  "d v" '("describe variable" . describe-variable)
  "m"   '("macroexpand" . macrostep-expand))

(provide 'lang-emacs-lisp-config)
;;; config.el ends here
