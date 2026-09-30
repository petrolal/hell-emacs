;;; hellmacs-emacs.el --- Stock Emacs, with saner defaults -*- lexical-binding: t; -*-

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

;; The stock settings Hellmacs changes, in every session (Doom v3's
;; lisp/doom-emacs.el). Loaded right after hellmacs.el.

;;; Code:

;;; Sane global defaults --------------------------------------------------

(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 80
              cursor-in-non-selected-windows nil)

(setq ring-bell-function #'ignore
      visible-bell nil
      use-short-answers t            ; Emacs 28+: y/n instead of yes/no
      confirm-kill-emacs #'y-or-n-p
      create-lockfiles nil           ; TRAMP/CI mostly; local editing rarely needs them
      load-prefer-newer t
      sentence-end-double-space nil
      require-final-newline t
      help-window-select t           ; jump straight into *Help* buffers
      delete-by-moving-to-trash t
      large-file-warning-threshold (* 50 1024 1024))

(setq global-auto-revert-non-file-buffers t
      auto-revert-avoid-polling t)     ; file notifications, not a 5s stat of every buffer
(global-auto-revert-mode 1)
(delete-selection-mode 1)
(electric-pair-mode 1)

(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

(provide 'hellmacs-emacs)
;;; hellmacs-emacs.el ends here
