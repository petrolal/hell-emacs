;;; lang/go/config.el -*- lexical-binding: t; -*-

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

;; Go support with gopls and go-mode.

(use-package go-mode
  :mode ("\\.go\\'" . go-mode)
  :config
  (add-hook 'go-mode-hook #'lsp-deferred)
  (when (fboundp 'go-ts-mode)
    (add-hook 'go-ts-mode-hook #'lsp-deferred)))

(defun hell-go-build ()
  "Build the current Go module."
  (interactive)
  (compile "go build ./..."))

(defun hell-go-test ()
  "Run the current Go module's tests."
  (interactive)
  (compile "go test ./..."))

(defun hell-go-run ()
  "Run the current Go module."
  (interactive)
  (compile "go run ."))

(hell-localleader-def '(go-mode go-ts-mode)
  "b" '("build" . hell-go-build)
  "t" '("test" . hell-go-test)
  "r" '("run" . hell-go-run))
