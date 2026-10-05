;;; lang/purescript/config.el -*- lexical-binding: t; -*-

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
;; PureScript strongly-typed functional web language.

;;; Code:

(use-package purescript-mode
  :mode ("\\.purs\\'" . purescript-mode)
  :config
  (add-hook 'purescript-mode-hook #'lsp-deferred))

(defun hell-purescript-build ()
  "Build the current spago project."
  (interactive)
  (compile "spago build"))

(defun hell-purescript-test ()
  "Run the current spago project's tests."
  (interactive)
  (compile "spago test"))

(defun hell-purescript-run ()
  "Run the current spago project."
  (interactive)
  (compile "spago run"))

(defun hell-purescript-repl ()
  "Start a spago REPL."
  (interactive)
  (compile "spago repl"))

(hell-localleader-def 'purescript-mode
  "b" '("spago build" . hell-purescript-build)
  "t" '("spago test" . hell-purescript-test)
  "r" '("spago run" . hell-purescript-run)
  "s" '("spago repl" . hell-purescript-repl))

(provide 'lang-purescript-config)
;;; config.el ends here
