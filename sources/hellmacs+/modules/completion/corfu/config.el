;;; completion/corfu/config.el -*- lexical-binding: t; -*-

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

;; In-buffer completion: a popup that appears as you type (corfu), fed
;; by extra completion sources (cape).
;;
;; Flags:
;;   +tab  Make TAB complete when there's nothing to indent
;;         (`tab-always-indent' = complete). Off by default, since
;;         stock Emacs TAB only indents; `C-M-i' completes either way.

(when (modulep! +tab)
  (setq tab-always-indent 'complete))

(use-package corfu
  :defer 1
  :init
  (setq corfu-auto t
        corfu-auto-delay 0.15
        corfu-auto-prefix 2
        corfu-cycle t
        corfu-preselect 'prompt)
  :config
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1))
;; Terminal (non-GUI) Emacs needs the separate `corfu-terminal' package
;; for popups to render (Emacs 31+ doesn't).

;; cape adds completion sources that work anywhere: file names
;; everywhere, and words from open buffers in prose. Modes with their
;; own completion (elisp, or a language server via `:tools lsp') still
;; come first; these are the fallbacks.
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'text-mode-hook
            (defun hellmacs-corfu--text-capfs-h ()
              (add-hook 'completion-at-point-functions #'cape-dabbrev 90 t))))
