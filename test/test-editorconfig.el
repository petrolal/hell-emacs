;;; test-editorconfig.el --- Tests for the :tools editorconfig module (Phase 10.3) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. EditorConfig is built into Emacs 30+, so
;; these tests read real .editorconfig files there.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)

(defvar editorconfig-mode)
(defvar hack-dir-local-get-variables-functions)
(defvar c-basic-offset)

(defun test-editorconfig--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools editorconfig))
    (hellmacs-module--load '(:tools . editorconfig) "config.el")
    mode-specific-map))

(defmacro test-editorconfig--with-project (files &rest body)
  "Run BODY in `dir', a project holding FILES ((NAME . CONTENT)...), with
the module loaded afresh and EditorConfig's global state restored after."
  (declare (indent 1))
  `(let* ((dir (file-name-as-directory (make-temp-file "hellmacs-test-ec" t)))
          (hack-dir-local-get-variables-functions
           (default-value 'hack-dir-local-get-variables-functions))
          (auto-coding-functions (default-value 'auto-coding-functions))
          (editorconfig-mode nil)
          (hellmacs-first-file-hook nil)
          (buffers nil))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((coding-system-for-write 'utf-8))
               (with-temp-file (expand-file-name (car f) dir) (insert (cdr f)))))
           (test-editorconfig--load-config)
           (cl-flet ((visit (name)
                       (let ((buffer (find-file-noselect (expand-file-name name dir))))
                         (push buffer buffers)
                         buffer)))
             ,@body))
       (dolist (b buffers) (with-current-buffer b (set-buffer-modified-p nil)) (kill-buffer b))
       (delete-directory dir t))))

(ert-deftest test-editorconfig/packages ()
  "EditorConfig is Emacs' own from 30 on: the package is only for Emacs 29."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:tools editorconfig))
    (hellmacs-module--load '(:tools . editorconfig) "packages.el")
    (should (equal (mapcar #'car hellmacs-packages) '(editorconfig)))
    (should (eq (plist-get (cdr (assq 'editorconfig hellmacs-packages)) :built-in) 'prefer))))

(ert-deftest test-editorconfig/lazy ()
  "Nothing is loaded at startup: EditorConfig starts with the first file."
  (skip-unless (boundp 'hack-dir-local-get-variables-functions))
  (test-editorconfig--with-project nil
    (should (memq 'hellmacs-editorconfig--start-h hack-dir-local-get-variables-functions))
    (should (memq 'hellmacs-editorconfig--coding-h auto-coding-functions))
    (should-not editorconfig-mode)))

(ert-deftest test-editorconfig/the-first-file-too ()
  "The first file opened gets its settings (indentation, charset), and so
does every one after it; EditorConfig is on, the start hooks gone."
  (skip-unless (boundp 'hack-dir-local-get-variables-functions))
  (test-editorconfig--with-project
      '((".editorconfig" . "root = true\n[*.java]\nindent_style = tab\nindent_size = 3\n[*.txt]\ncharset = latin1\n")
        ("A.java" . "class A {}\n") ("B.java" . "class B {}\n") ("notes.txt" . "caf\n"))
    (with-current-buffer (visit "A.java")
      (should (eq major-mode 'java-mode))
      (should (eql c-basic-offset 3))
      (should (eq indent-tabs-mode t)))
    (should editorconfig-mode)
    (should-not (memq 'hellmacs-editorconfig--start-h hack-dir-local-get-variables-functions))
    (should-not (memq 'hellmacs-editorconfig--coding-h auto-coding-functions))
    (with-current-buffer (visit "B.java")
      (should (eql c-basic-offset 3)))
    (with-current-buffer (visit "notes.txt")
      (should (eq (coding-system-base buffer-file-coding-system) 'iso-latin-1)))))

(ert-deftest test-editorconfig/charset-of-the-first-file ()
  "A charset is read before anything else: the first file gets it too."
  (skip-unless (boundp 'hack-dir-local-get-variables-functions))
  (test-editorconfig--with-project
      '((".editorconfig" . "root = true\n[*]\ncharset = latin1\n") ("notes.txt" . "caf\n"))
    (with-current-buffer (visit "notes.txt")
      (should (eq (coding-system-base buffer-file-coding-system) 'iso-latin-1)))))

(ert-deftest test-editorconfig/hellmacs-own-files-dont-start-it ()
  "Hellmacs reading its own state (bookmarks, the profile) at startup
doesn't load EditorConfig."
  (skip-unless (boundp 'hack-dir-local-get-variables-functions))
  (test-editorconfig--with-project '(("state.eld" . "()\n"))
    (let ((hellmacs-state-dir dir))
      (visit "state.eld"))
    (should-not editorconfig-mode)))

(ert-deftest test-editorconfig/loading-lisp-doesnt-start-it ()
  "Startup loading your config.el (read through the same coding hooks as
a file) doesn't load EditorConfig."
  (skip-unless (boundp 'hack-dir-local-get-variables-functions))
  (test-editorconfig--with-project '(("config.el" . ";;; -*- lexical-binding: t; -*-\n(ignore)\n"))
    (load (expand-file-name "config.el" dir) nil 'nomessage 'nosuffix)
    (should-not editorconfig-mode)))

(ert-deftest test-editorconfig/emacs-29 ()
  "Without Emacs 30's hooks, the package turns on with the first file and
applies to it."
  (let (calls hack-dir-local-get-variables-functions auto-coding-functions hellmacs-first-file-hook)
    (test-editorconfig--load-config)
    (cl-letf (((symbol-function 'editorconfig-mode) (lambda (arg) (push (list 'mode arg) calls)))
              ((symbol-function 'editorconfig-apply) (lambda () (push '(apply) calls))))
      (hellmacs-editorconfig--start-29-h))
    (should (equal (nreverse calls) '((mode 1) (apply))))))

(ert-deftest test-editorconfig/no-keys ()
  "Nothing is bound."
  (let (hack-dir-local-get-variables-functions auto-coding-functions)
    (should (equal (test-editorconfig--load-config) (make-sparse-keymap)))))

(provide 'test-editorconfig)
;;; test-editorconfig.el ends here
