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

;; Emacs' own undo and redo keys are left alone; only undo-fu-session
;; is added.
(ert-deftest test-undo/package-declarations ()
  "The module declares undo-fu-session, and nothing that rebinds undo."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:editor undo))
    (hellmacs-modules-read-packages)
    (should (assq 'undo-fu-session hellmacs-packages))
    (should-not (assq 'undo-fu hellmacs-packages))
    (should-not (assq 'vundo hellmacs-packages))))

(ert-deftest test-undo/stock-keys ()
  "C-/ undoes and C-? redoes, with Emacs' own commands."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:editor undo))
    (hellmacs-module--load '(:editor . undo) "config.el")
    (should (eq (keymap-lookup global-map "C-/") 'undo))
    (should (eq (keymap-lookup global-map "C-?") 'undo-redo))))

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
