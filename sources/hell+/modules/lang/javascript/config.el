;;; lang/javascript/config.el -*- lexical-binding: t; -*-

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

;; JavaScript, TypeScript, JSX/TSX and ESLint support, all in Emacs' own
;; modes: `js-mode' (JavaScript, JSX), `typescript-ts-mode' and
;; `tsx-ts-mode' (their grammars built by sync).
;; LSP support runs through `:tools lsp' (`lsp-mode') with zero telemetry.

(use-package js
  :ensure nil
  :mode ("\\.[mc]?js\\'" . js-mode)
  :interpreter ("node" . js-mode)
  :init
  (setq js-indent-level 2)
  :config
  (add-hook 'js-mode-hook #'lsp-deferred)
  (when (fboundp 'js-ts-mode)
    (add-hook 'js-ts-mode-hook #'lsp-deferred)))

(use-package typescript-ts-mode
  :ensure nil
  :mode (("\\.[mc]?ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode))
  :init
  (setq typescript-ts-mode-indent-offset 2)
  (add-hook 'typescript-ts-mode-hook #'lsp-deferred)
  (add-hook 'tsx-ts-mode-hook #'lsp-deferred))

(add-to-list 'auto-mode-alist '("\\.jsx\\'" . js-mode))
