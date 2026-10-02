;;; ui/vc-gutter/config.el -*- lexical-binding: t; -*-

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

;; Lines changed since the last commit, marked in the fringe (in the margin
;; in a terminal, which has no fringe), through diff-hl (Phase 10.3). The
;; marks follow your edits on save, and Magit's commits, stages and
;; checkouts.
;;
;; Keys: none of the module's own. diff-hl's are kept as it ships them, on
;; `C-x v' keys Emacs leaves free: `C-x v [' and `C-x v ]' previous and
;; next hunk, `C-x v *' show it, `C-x v n' revert it, `C-x v S' stage it.
;; `C-x v =' (`vc-diff') becomes a diff that jumps to the hunk at point.

(defvar diff-hl-update-async)
(defvar diff-hl-disable-on-remote)
(declare-function global-diff-hl-mode "diff-hl")
(declare-function diff-hl-margin-mode "diff-hl-margin")
(declare-function diff-hl-magit-post-refresh "diff-hl")

(setq diff-hl-update-async t            ; a large repository's diff doesn't block
      diff-hl-disable-on-remote t)      ; nor does TRAMP (docker, ssh)

(defun hell-vc-gutter-enable ()
  "Mark changed lines in every file: the fringe, or the margin in a terminal."
  (global-diff-hl-mode 1)
  (diff-hl-margin-mode (if (display-graphic-p) -1 1)))

(defun hell-vc-gutter-magit-refresh-h ()
  "Update the marks after Magit changes the repository.
diff-hl's own function isn't autoloaded: until diff-hl is, there are none."
  (when (featurep 'diff-hl)
    (diff-hl-magit-post-refresh)))

(add-hook 'hell-first-file-hook #'hell-vc-gutter-enable)
(add-hook 'magit-post-refresh-hook #'hell-vc-gutter-magit-refresh-h)
