;;; lang/go/config.el -*- lexical-binding: t; -*-

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

;; Go support with gopls and go-mode.

(use-package go-mode
  :mode ("\\.go\\'" . go-mode)
  :config
  (add-hook 'go-mode-hook #'lsp-deferred)
  (when (fboundp 'go-ts-mode)
    (add-hook 'go-ts-mode-hook #'lsp-deferred)))

(hellmacs-localleader-def '(go-mode go-ts-mode)
  "b" '("build" . (lambda () (interactive) (compile "go build ./...")))
  "t" '("test" . (lambda () (interactive) (compile "go test ./...")))
  "r" '("run" . (lambda () (interactive) (compile "go run ."))))
