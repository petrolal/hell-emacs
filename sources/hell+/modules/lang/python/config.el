;;; lang/python/config.el -*- lexical-binding: t; -*-

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

;; Python editing and language server integration (pyright, basedpyright, ruff).

(use-package python
  :ensure nil
  :mode ("\\.py[iw]?\\'" . python-mode)
  :interpreter ("python\\([0-9.]+\\)?" . python-mode)
  :init
  (setq python-indent-offset 4)
  :config
  (add-hook 'python-mode-hook #'lsp-deferred)
  (when (fboundp 'python-ts-mode)
    (add-hook 'python-ts-mode-hook #'lsp-deferred)))

(hell-localleader-def '(python-mode python-ts-mode)
  "b" '("build/test" . (lambda () (interactive) (compile "pytest")))
  "r" '("run script" . (lambda () (interactive) (compile (format "python3 %s" (shell-quote-argument (buffer-file-name)))))))
