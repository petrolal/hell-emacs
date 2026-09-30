;;; test-profiles.el --- Tests for lisp/hellmacs-profiles.el -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. Phase 16.7: as in Doom v3, there's no root
;; init.el. `sync' generates the profile's init file, and early-init.el
;; hands Emacs that, or lisp/hellmacs-start.el (the same, from source)
;; while it's missing or out of date.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-profiles)

(ert-deftest test-profiles/no-root-init ()
  "Hellmacs has no init.el of its own: early-init.el reroutes Emacs to the
profile's, as Doom v3's does, and `hellmacs-start' is the same for batch."
  (should-not (file-exists-p (expand-file-name "init.el" hellmacs-dir)))
  (should (file-exists-p (expand-file-name "hellmacs-start.el" hellmacs-core-dir)))
  (should (advice-member-p 'startup--load-user-init-file@hellmacs-profile
                           'startup--load-user-init-file))
  (should (fboundp 'hellmacs-start)))

(defmacro test-profiles--with-profile (&rest body)
  "Run BODY with `hellmacs-profile-dir' a temporary directory."
  (declare (indent 0))
  `(let ((hellmacs-profile-dir (file-name-as-directory (make-temp-file "test-profiles" t))))
     (unwind-protect (progn ,@body)
       (delete-directory hellmacs-profile-dir t))))

(ert-deftest test-profiles/generate-init ()
  "`hellmacs-profile-generate-init' writes the profile's init.el, part 05
(compiled core, its load-path) then lisp/hellmacs-start.el's forms, and
byte-compiles it."
  (test-profiles--with-profile
    (hellmacs-profile-generate-init)
    (let ((init (expand-file-name "init.el" hellmacs-profile-dir)))
      (should (file-exists-p init))
      (should (file-exists-p (concat init "c")))
      (with-temp-buffer
        (insert-file-contents init)
        (should (search-forward ";;; 05-hellmacs.init.el" nil t))
        (should (search-forward "(defvar hellmacs--compiled-core-p t)" nil t))
        (should (search-forward ";;; 10-hellmacs-start.init.el" nil t))
        (should (search-forward "(hellmacs-modules-startup)" nil t))))))

(ert-deftest test-profiles/init-file-choice ()
  "Emacs gets the generated init while it's current (compiled core current,
and newer than lisp/hellmacs-start.el); lisp/hellmacs-start otherwise."
  (let ((source (expand-file-name "hellmacs-start" hellmacs-core-dir)))
    (test-profiles--with-profile
      (let ((generated (expand-file-name "init" hellmacs-profile-dir)))
        (should (equal (hellmacs-init-file) source))
        (with-temp-file (concat generated ".elc") (insert ";; test\n"))
        (cl-letf (((symbol-function 'hellmacs-compiled-core-current-p) #'always))
          (should (equal (hellmacs-init-file) generated))
          (set-file-times (concat generated ".elc") '(0 0))
          (should (equal (hellmacs-init-file) source)))
        (cl-letf (((symbol-function 'hellmacs-compiled-core-current-p) #'ignore))
          (set-file-times (concat generated ".elc"))
          (should (equal (hellmacs-init-file) source)))))))

(provide 'test-profiles)
;;; test-profiles.el ends here
