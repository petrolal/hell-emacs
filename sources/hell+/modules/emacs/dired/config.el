;;; emacs/dired/config.el -*- lexical-binding: t; -*-

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

;; Enhanced Dired: inline nerd-icons, batch editing (wdired),
;; and quick sorting (dired-quick-sort).

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :init
  (setq dired-listing-switches "-lah --group-directories-first"
        dired-dwim-target t
        dired-recursive-copies 'always
        dired-recursive-deletes 'top
        dired-kill-when-opening-new-dired-buffer t)
  :config
  (keymap-set dired-mode-map "r" #'wdired-change-to-wdired-mode)
  (keymap-set dired-mode-map "C-x C-q" #'wdired-change-to-wdired-mode))

(use-package wdired
  :ensure nil
  :after dired
  :init
  (setq wdired-allow-to-change-permissions t
        wdired-create-parent-directories t))

(use-package nerd-icons-dired
  :after dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package dired-quick-sort
  :after dired
  :config
  (dired-quick-sort-setup))
