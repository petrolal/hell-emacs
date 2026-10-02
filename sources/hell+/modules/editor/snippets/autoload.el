;;; editor/snippets/autoload.el -*- lexical-binding: t; -*-

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

;; What the JVM templates fill in from the file they're in: its package,
;; from where it sits in a Maven or Gradle layout, and its class. Your own
;; templates in $HELLDIR/templates/ can call them too.

;;;###autoload
(defun hell-snippets-package (&optional file)
  "The JVM package of FILE (the buffer's by default), from its path.
Read from the directories under src/<set>/<language>/ (src/main/java/,
src/test/kotlin/...): nil in the default package or outside that layout."
  (when-let* ((file (or file buffer-file-name))
              (dir (file-name-directory file))
              ;; Greedy: the innermost src/ wins.
              ((string-match ".*/src/[^/]+/\\(?:java\\|kotlin\\|scala\\|groovy\\)/\\(.*\\)\\'" dir))
              (package (string-trim (match-string 1 dir) "/+" "/+"))
              ((not (string-empty-p package))))
    (string-replace "/" "." package)))

;;;###autoload
(defun hell-snippets-package-line (terminator)
  "A template element for the package line, ending in TERMINATOR (\";\" in Java).
Nil when the file already has one or is in the default package. It's an
element, not a string, so it's inserted once rather than kept up to date."
  (when-let* ((package (hell-snippets-package))
              ((not (save-excursion
                      (goto-char (point-min))
                      (re-search-forward "^package[ \t]" nil t)))))
    `(l ,(concat "package " package terminator) n n)))

;;;###autoload
(defun hell-snippets-class ()
  "The class the file is named for: CartTest in CartTest.java.
Main in a buffer with no file."
  (if buffer-file-name (file-name-base buffer-file-name) "Main"))
