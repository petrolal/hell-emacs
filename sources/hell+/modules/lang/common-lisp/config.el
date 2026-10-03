;;; lang/common-lisp/config.el -*- lexical-binding: t; -*-

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

;;; Code:

(defvar inferior-lisp-program)
(defvar slime-contribs)
(defvar slime-mode-hook)
(declare-function slime-setup "slime" (&optional contribs))
(declare-function slime-mode "slime" (&optional arg))
(declare-function slime-completion-at-point "slime" ())
(declare-function slime "slime" (&optional command-string))
(declare-function slime-compile-defun "slime" ())
(declare-function slime-compile-and-load-file "slime" ())
(declare-function slime-eval-buffer "slime" ())
(declare-function slime-eval-defun "slime" ())
(declare-function slime-eval-last-expression "slime" ())
(declare-function slime-describe-symbol "slime" (symbol-name))
(declare-function slime-apropos "slime" (pattern &optional case-sensitive package))
(declare-function slime-hyperspec-lookup "slime" (symbol-name))
(declare-function slime-macroexpand-1 "slime" ())

;; Associate Common Lisp and ASDF files with built-in lisp-mode.
(add-to-list 'auto-mode-alist '("\\.\\(?:cl\\|asd\\)\\'" . lisp-mode))

(use-package slime
  :defer t
  :commands (slime slime-connect)
  :init
  ;; Detect installed Common Lisp runtime: prefer SBCL, then CLISP, ECL, CCL.
  (setq inferior-lisp-program
        (cond ((executable-find "sbcl") "sbcl --noinform")
              ((executable-find "clisp") "clisp")
              ((executable-find "ecl") "ecl")
              ((executable-find "ccl") "ccl")
              (t "sbcl")))
  (add-hook 'lisp-mode-hook #'slime-mode)
  :config
  (setq slime-contribs '(slime-fancy))
  (slime-setup '(slime-fancy))
  ;; Seamless in-buffer completion integration for Corfu via completion-at-point
  (add-hook 'slime-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions #'slime-completion-at-point nil t))))

;; Localleader shortcuts on `C-c l' for Common Lisp buffers
(hell-localleader-def 'lisp-mode
  "s" '("slime / repl" . slime)
  "c" "compile"
  "c c" '("compile defun" . slime-compile-defun)
  "c k" '("compile file" . slime-compile-and-load-file)
  "e" "eval"
  "e b" '("eval buffer" . slime-eval-buffer)
  "e d" '("eval defun" . slime-eval-defun)
  "e e" '("eval last sexp" . slime-eval-last-expression)
  "d" "doc"
  "d d" '("describe symbol" . slime-describe-symbol)
  "d a" '("apropos" . slime-apropos)
  "d h" '("hyperspec" . slime-hyperspec-lookup)
  "m" '("macroexpand" . slime-macroexpand-1))
