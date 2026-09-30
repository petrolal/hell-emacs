;;; editor/undo/config.el -*- lexical-binding: t; -*-

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

;; Undo is Emacs' own: `C-/' undoes, `C-?' (`undo-redo') redoes (`C-M-_'
;; in a terminal, which can't send `C-?'), and
;; `undo' in an active region undoes only within it.
;; `undo-fu-session' adds what Emacs lacks: undo history that survives
;; closing a file or restarting Emacs.

(setq undo-limit 400000
      undo-strong-limit 3000000
      undo-outer-limit 48000000)

(use-package undo-fu-session
  :defer 1
  :init
  (setq undo-fu-session-directory (hellmacs-state-file "undo-fu-session/")
        undo-fu-session-linear t
        ;; One file per file ever edited otherwise, forever: the oldest
        ;; are deleted past this many.
        undo-fu-session-file-limit 200)
  :config
  (global-undo-fu-session-mode 1))
