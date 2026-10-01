;;; lang/javascript/config.el -*- lexical-binding: t; -*-

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

;; JavaScript, TypeScript, JSX/TSX and ESLint support via built-in `js-mode',
;; `js-ts-mode', `typescript-mode', `typescript-ts-mode', and `tsx-ts-mode'.
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

(use-package typescript-mode
  :mode ("\\.ts\\'" . typescript-mode)
  :init
  (setq typescript-indent-level 2)
  :config
  (add-hook 'typescript-mode-hook #'lsp-deferred)
  (when (fboundp 'typescript-ts-mode)
    (add-hook 'typescript-ts-mode-hook #'lsp-deferred))
  (when (fboundp 'tsx-ts-mode)
    (add-hook 'tsx-ts-mode-hook #'lsp-deferred)))

(add-to-list 'auto-mode-alist '("\\.tsx\\'" . (if (fboundp 'tsx-ts-mode) 'tsx-ts-mode 'typescript-mode)))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . (if (fboundp 'js-ts-mode) 'js-ts-mode 'js-mode)))
