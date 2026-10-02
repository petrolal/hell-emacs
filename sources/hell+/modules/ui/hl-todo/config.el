;;; ui/hl-todo/config.el -*- lexical-binding: t; -*-

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

;; TODO, FIXME, HACK, NOTE and the like highlighted in comments (in code;
;; anywhere in plain text), through hl-todo (Phase 10.3). The colours are
;; the theme's own faces, so they follow whichever theme you load. Org
;; files keep their own TODO keywords.
;;
;; Keys: none. `M-x hl-todo-next' and `hl-todo-previous' move between
;; them, `M-x hl-todo-occur' lists them in the buffer, and
;; `M-x hl-todo-rgrep' across the project.

(defvar hl-todo-keyword-faces)
(declare-function global-hl-todo-mode "hl-todo")

(setq hl-todo-keyword-faces
      '(("TODO"       . warning)
        ("FIXME"      . error)
        ("BUG"        . error)
        ("XXX"        . error)          ; Eclipse and IntelliJ mark it too
        ("HACK"       . font-lock-constant-face)
        ("KLUDGE"     . font-lock-constant-face)
        ("NOTE"       . success)
        ("REVIEW"     . font-lock-keyword-face)
        ("DEPRECATED" . font-lock-doc-face)))

(add-hook 'hell-first-file-hook #'global-hl-todo-mode)
