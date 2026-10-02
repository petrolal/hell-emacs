;;; lang/cc/config.el -*- lexical-binding: t; -*-

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

;; C, C++, Objective-C editing with clangd.

(use-package cc-mode
  :ensure nil
  :mode ("\\.[ch]\\'" . c-mode)
  :mode ("\\.\\(?:cc\\|cpp\\|cxx\\|hpp\\|hxx\\|h\\+\\+\\)\\'" . c++-mode)
  :init
  (setq c-basic-offset 4)
  :config
  (add-hook 'c-mode-hook #'lsp-deferred)
  (add-hook 'c++-mode-hook #'lsp-deferred)
  (when (fboundp 'c-ts-mode)
    (add-hook 'c-ts-mode-hook #'lsp-deferred))
  (when (fboundp 'c++-ts-mode)
    (add-hook 'c++-ts-mode-hook #'lsp-deferred)))

(hell-localleader-def '(c-mode c++-mode c-ts-mode c++-ts-mode)
  "s" '("switch header/source" . ff-find-other-file)
  "b" '("build" . (lambda () (interactive) (compile "make -k"))))
