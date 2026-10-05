;;; lang/haskell/config.el -*- lexical-binding: t; -*-

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
;; Haskell support with haskell-mode and Haskell Language Server.

;;; Code:

(use-package haskell-mode
  :mode ("\\.[gh]s\\'" . haskell-mode)
  :mode ("\\.l[gh]s\\'" . literate-haskell-mode)
  :mode ("\\.cabal\\'" . haskell-cabal-mode)
  :config
  (add-hook 'haskell-mode-hook #'lsp-deferred))

(defun hell-haskell-build ()
  "Build the current cabal project."
  (interactive)
  (compile "cabal build"))

(defun hell-haskell-test ()
  "Run the current cabal project's tests."
  (interactive)
  (compile "cabal test"))

(defun hell-haskell-run ()
  "Run the current cabal project."
  (interactive)
  (compile "cabal run"))

(hell-localleader-def 'haskell-mode
  "b" '("cabal build" . hell-haskell-build)
  "t" '("cabal test" . hell-haskell-test)
  "r" '("cabal run" . hell-haskell-run))

(provide 'lang-haskell-config)
;;; config.el ends here
