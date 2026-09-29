;;; test-magit.el --- Tests for the :tools magit module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. Magit itself isn't installed in the test
;; environment; its status, log, blame and commit are checked by the
;; Phase 6.6 probes against a real repository (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'hellmacs-modules)

(defvar transient-history-file)
(defvar transient-levels-file)
(defvar transient-values-file)

(defun test-magit--enable ()
  "Enable :tools magit in a scratch module table."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools magit))
    (hellmacs-module--load '(:tools . magit) "packages.el")))

(ert-deftest test-magit/packages ()
  "Magit's shared dependencies are declared up front, once each."
  (let ((hellmacs-packages nil))
    (test-magit--enable)
    (should (equal (sort (mapcar #'car hellmacs-packages) #'string<)
                   '(cond-let llama magit)))))

(ert-deftest test-magit/entry-points-autoload ()
  "The commands behind `C-x g', `C-x M-g' and `C-c M-g' load Magit on demand."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools magit))
    (hellmacs-module--load '(:tools . magit) "config.el"))
  (dolist (cmd '(magit-status magit-dispatch magit-file-dispatch))
    (should (autoloadp (symbol-function cmd)))))

(ert-deftest test-magit/transient-state-in-state-dir ()
  "Transient's history, levels and values live in the state directory."
  (dolist (file (list transient-history-file transient-levels-file transient-values-file))
    (should (file-in-directory-p file hellmacs-state-dir))))

(provide 'test-magit)
;;; test-magit.el ends here
