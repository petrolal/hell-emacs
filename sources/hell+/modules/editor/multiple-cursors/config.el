;;; editor/multiple-cursors/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; Multi-cursor and simultaneous refactoring editing via multiple-cursors and iedit.

;;; Code:

(declare-function iedit-mode "iedit" (&optional arg))
(declare-function mc/mark-next-like-this "mc/mark-more" (arg))
(declare-function mc/mark-previous-like-this "mc/mark-more" (arg))
(declare-function mc/mark-all-like-this "mc/mark-more")

(use-package iedit
  :defer t
  :commands (iedit-mode)
  :init
  (define-key global-map (kbd "C-;") #'iedit-mode)
  (hell-leader-def
    "c e" '("edit all symbols" . iedit-mode)))

(use-package multiple-cursors
  :bind (("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this))
  :commands (mc/mark-all-like-this)
  :init
  ;; `C-c' followed by a control character is major modes' own
  ;; territory (13.5); `mark-all-like-this' goes on the leader instead.
  (hell-leader-def
    "c m" '("mark all like this" . mc/mark-all-like-this)))

(provide 'editor-multiple-cursors-config)
;;; config.el ends here
