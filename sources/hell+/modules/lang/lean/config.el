;;; lang/lean/config.el -*- lexical-binding: t; -*-

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
;; Lean 4 theorem prover and functional programming language support.

;;; Code:

(use-package lean4-mode
  :mode ("\\.lean\\'" . lean4-mode)
  :config
  (add-hook 'lean4-mode-hook #'lsp-deferred))

(defun hell-lean-build ()
  "Build the current Lean project."
  (interactive)
  (compile "lake build"))

(defun hell-lean-test ()
  "Run the current Lean project's tests."
  (interactive)
  (compile "lake test"))

(defun hell-lean-run ()
  "Run the current Lean project."
  (interactive)
  (compile "lake run"))

(hell-localleader-def 'lean4-mode
  "b" '("lake build" . hell-lean-build)
  "t" '("lake test" . hell-lean-test)
  "r" '("lake run" . hell-lean-run))

(provide 'lang-lean-config)
;;; config.el ends here
