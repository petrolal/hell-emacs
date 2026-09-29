;;; tools/editorconfig/config.el -*- lexical-binding: t; -*-

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

;; Projects' .editorconfig files apply: indentation, tabs, charset, line
;; endings, final newline and trailing whitespace, the same settings the
;; team's IntelliJ, Eclipse or VS Code use (Phase 10.3). Emacs' own
;; `editorconfig-mode' (Emacs 30+; the package on Emacs 29). A project's
;; .dir-locals.el still wins over it.
;;
;; Nothing is loaded at startup: it turns on with the first file you open,
;; and that file gets its settings too. Keys: none.

(defvar hack-dir-local-get-variables-functions)
(defvar auto-coding-file-name)
(declare-function editorconfig-mode "editorconfig")
(declare-function editorconfig-apply "editorconfig")
(declare-function editorconfig--get-dir-local-variables "editorconfig")
(declare-function editorconfig--get-coding-system "editorconfig")

(defun hellmacs-editorconfig--user-file-p (file)
  "Non-nil if FILE is one of yours, not Hellmacs' own state."
  (and file (not (seq-some (lambda (dir) (file-in-directory-p file dir))
                           (hellmacs--own-dirs)))))

(defun hellmacs-editorconfig--start ()
  "Turn EditorConfig on, in place of the hooks that wait for the first file."
  (remove-hook 'hack-dir-local-get-variables-functions #'hellmacs-editorconfig--start-h)
  (remove-hook 'auto-coding-functions #'hellmacs-editorconfig--coding-h)
  (editorconfig-mode 1))

;; Emacs 30+: EditorConfig works from two hooks run while a file is read,
;; before `find-file-hook' (so before `hellmacs-first-file-hook'). These
;; stand in for its own until the first file, then answer for it.

(defun hellmacs-editorconfig--start-h ()
  "The first file's EditorConfig settings, as dir-local variables."
  (when (hellmacs-editorconfig--user-file-p buffer-file-name)
    (hellmacs-editorconfig--start)
    (editorconfig--get-dir-local-variables)))

(defun hellmacs-editorconfig--coding-h (size)
  "The first file's EditorConfig charset (read before anything else).
`load' reads Lisp through this hook too: startup loading your config.el
isn't opening a file."
  (when (and (not load-in-progress)
             (hellmacs-editorconfig--user-file-p auto-coding-file-name))
    (hellmacs-editorconfig--start)
    (editorconfig--get-coding-system size)))

;; Emacs 29's package works from the major modes' hooks instead.
(defun hellmacs-editorconfig--start-29-h ()
  "Turn EditorConfig on, and apply it to the first file."
  (editorconfig-mode 1)
  (editorconfig-apply))

(if (boundp 'hack-dir-local-get-variables-functions)
    (progn
      (add-hook 'hack-dir-local-get-variables-functions #'hellmacs-editorconfig--start-h t)
      (add-hook 'auto-coding-functions #'hellmacs-editorconfig--coding-h))
  (add-hook 'hellmacs-first-file-hook #'hellmacs-editorconfig--start-29-h))
