;;; test-hl-todo.el --- Tests for the :ui hl-todo module (Phase 10.3) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. hl-todo itself isn't installed in the test
;; environment: the highlighting is checked live (see docs/roadmap.md, 10.3).

;;; Code:

(require 'ert)
(require 'hellmacs-modules)

(defvar hl-todo-keyword-faces)

(defun test-hl-todo--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:ui hl-todo))
    (hellmacs-module--load '(:ui . hl-todo) "config.el")
    mode-specific-map))

(ert-deftest test-hl-todo/packages ()
  "hl-todo, with cond-let declared up front (shared with Magit)."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:ui hl-todo))
    (hellmacs-module--load '(:ui . hl-todo) "packages.el")
    (should (equal (sort (mapcar #'car hellmacs-packages) #'string<) '(cond-let hl-todo)))))

(ert-deftest test-hl-todo/lazy ()
  "Highlighting turns on with the first file, not at startup."
  (let ((hellmacs-first-file-hook nil))
    (test-hl-todo--load-config)
    (should (memq 'global-hl-todo-mode hellmacs-first-file-hook))
    (should-not (featurep 'hl-todo))))

(ert-deftest test-hl-todo/keywords-follow-the-theme ()
  "TODO, FIXME, HACK and NOTE (and what Java IDEs mark: XXX) are highlighted,
each with a face, so the colours are the theme's."
  (let (hl-todo-keyword-faces)
    (test-hl-todo--load-config)
    (dolist (keyword '("TODO" "FIXME" "HACK" "NOTE" "XXX"))
      (let ((face (cdr (assoc keyword hl-todo-keyword-faces))))
        (should (equal (cons keyword (and (symbolp face) (facep face) t))
                       (cons keyword t)))))))

(ert-deftest test-hl-todo/no-keys ()
  "Nothing is bound: `M-x hl-todo-next', `hl-todo-previous', `hl-todo-occur'."
  (should (equal (test-hl-todo--load-config) (make-sparse-keymap))))

(provide 'test-hl-todo)
;;; test-hl-todo.el ends here
