;;; tools/eglot/config.el -*- lexical-binding: t; -*-

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

;; Zero-overhead native LSP client via Emacs 29+ built-in `eglot'.
;; Integrates with `flymake', `xref', `eldoc', and `corfu'.

(defvar eglot-mode-map)

(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :init
  (setq eglot-autoshutdown t
        eglot-sync-connect nil
        eglot-events-buffer-size 0
        eglot-stay-out-of '(company))
  :config
  ;; The server's actions in the `C-c c' code group, only where eglot
  ;; runs (as `:tools lsp' does in lsp-mode's map), never globally.
  (keymap-set eglot-mode-map "C-c c a" (cons "code action" #'eglot-code-actions))
  (keymap-set eglot-mode-map "C-c c r" (cons "rename symbol" #'eglot-rename))
  (keymap-set eglot-mode-map "C-c c f" (cons "format buffer" #'eglot-format)))
