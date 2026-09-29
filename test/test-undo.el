;;; test-undo.el --- Tests for :editor undo module -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'hellmacs-modules)

(ert-deftest test-undo/package-declarations ()
  "Editor undo module registers undo-fu and vundo."
  (let ((hellmacs-packages nil))
    (package! undo-fu)
    (package! vundo)
    (should (assq 'undo-fu hellmacs-packages))
    (should (assq 'vundo hellmacs-packages))))

(ert-deftest test-undo/keybindings ()
  "Verifies keybindings for undo, redo, and visual undo tree."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-/") 'undo-fu-only-undo)
    (define-key map (kbd "C-?") 'undo-fu-only-redo)
    (define-key map (kbd "C-M-_") 'undo-fu-only-redo)
    (define-key map (kbd "C-x u") 'vundo)
    (should (eq (lookup-key map (kbd "C-/")) 'undo-fu-only-undo))
    (should (eq (lookup-key map (kbd "C-?")) 'undo-fu-only-redo))
    (should (eq (lookup-key map (kbd "C-x u")) 'vundo))))

(defvar undo-fu-session-file-limit)

(ert-deftest test-undo/session-files-are-capped ()
  "Undo history is saved for a bounded number of files, not one per file ever edited."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (undo-fu-session-file-limit nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:editor undo))
    (hellmacs-module--load '(:editor . undo) "config.el")
    (should (natnump undo-fu-session-file-limit))
    (should (> undo-fu-session-file-limit 0))))

(provide 'test-undo)
;;; test-undo.el ends here
