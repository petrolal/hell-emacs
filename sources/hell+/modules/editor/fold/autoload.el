;;; editor/fold/autoload.el -*- lexical-binding: t; -*-

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

;;; Code:

(defvar treesit-fold-mode)
(defvar hs-minor-mode)
(declare-function treesit-fold-toggle "treesit-fold" ())
(declare-function treesit-fold-open-all "treesit-fold" ())
(declare-function treesit-fold-close-all "treesit-fold" ())
(declare-function hs-toggle-hiding "hideshow" (&optional e))
(declare-function hs-show-all "hideshow" ())
(declare-function hs-hide-all "hideshow" ())

;;;###autoload
(defun hell-fold-toggle ()
  "Toggle code folding at point.
Prefers `treesit-fold' when active in a tree-sitter buffer,
falling back to `hs-toggle-hiding' (`hs-minor-mode')."
  (interactive)
  (cond
   ((and (bound-and-true-p treesit-fold-mode)
         (fboundp 'treesit-fold-toggle))
    (treesit-fold-toggle))
   ((bound-and-true-p hs-minor-mode)
    (hs-toggle-hiding))
   (t
    (user-error "Neither treesit-fold-mode nor hs-minor-mode is active"))))

;;;###autoload
(defun hell-fold-open-all ()
  "Open (unfold) all folded blocks in the current buffer.
Prefers `treesit-fold' when active in a tree-sitter buffer,
falling back to `hs-show-all' (`hs-minor-mode')."
  (interactive)
  (cond
   ((and (bound-and-true-p treesit-fold-mode)
         (fboundp 'treesit-fold-open-all))
    (treesit-fold-open-all))
   ((bound-and-true-p hs-minor-mode)
    (hs-show-all))
   (t
    (user-error "Neither treesit-fold-mode nor hs-minor-mode is active"))))

;;;###autoload
(defun hell-fold-close-all ()
  "Close (fold) all foldable blocks in the current buffer.
Prefers `treesit-fold' when active in a tree-sitter buffer,
falling back to `hs-hide-all' (`hs-minor-mode')."
  (interactive)
  (cond
   ((and (bound-and-true-p treesit-fold-mode)
         (fboundp 'treesit-fold-close-all))
    (treesit-fold-close-all))
   ((bound-and-true-p hs-minor-mode)
    (hs-hide-all))
   (t
    (user-error "Neither treesit-fold-mode nor hs-minor-mode is active"))))
