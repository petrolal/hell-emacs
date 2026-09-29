;;; test-vc-gutter.el --- Tests for the :ui vc-gutter module (Phase 10.3) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. diff-hl itself isn't installed in the test
;; environment: its fringe, margin and Magit refresh are checked live (see
;; docs/roadmap.md, 10.3).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'vc)
(require 'hellmacs-modules)

(defvar diff-hl-update-async)
(defvar diff-hl-disable-on-remote)
(defvar magit-post-refresh-hook)

(defun test-vc-gutter--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:ui vc-gutter))
    (hellmacs-module--load '(:ui . vc-gutter) "config.el")
    mode-specific-map))

(defmacro test-vc-gutter--recording (&rest body)
  "Run BODY with diff-hl's modes faked; return the calls made, in order."
  (declare (indent 0))
  `(let (calls)
     (cl-letf (((symbol-function 'global-diff-hl-mode) (lambda (arg) (push (list 'global arg) calls)))
               ((symbol-function 'diff-hl-margin-mode) (lambda (arg) (push (list 'margin arg) calls)))
               ((symbol-function 'diff-hl-magit-post-refresh) (lambda () (push '(magit) calls))))
       ,@body)
     (nreverse calls)))

(ert-deftest test-vc-gutter/packages ()
  "diff-hl, and nothing else."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:ui vc-gutter))
    (hellmacs-module--load '(:ui . vc-gutter) "packages.el")
    (should (equal (mapcar #'car hellmacs-packages) '(diff-hl)))))

(ert-deftest test-vc-gutter/lazy ()
  "diff-hl turns on with the first file, not at startup."
  (let ((hellmacs-first-file-hook nil))
    (test-vc-gutter--load-config)
    (should (memq 'hellmacs-vc-gutter-enable hellmacs-first-file-hook))
    (should-not (featurep 'diff-hl))))

(ert-deftest test-vc-gutter/fringe-or-margin ()
  "The fringe in a graphical frame; the margin in a terminal, which has none."
  (test-vc-gutter--load-config)
  (cl-letf (((symbol-function 'display-graphic-p) #'always))
    (should (equal (test-vc-gutter--recording (hellmacs-vc-gutter-enable))
                   '((global 1) (margin -1)))))
  (cl-letf (((symbol-function 'display-graphic-p) #'ignore))
    (should (equal (test-vc-gutter--recording (hellmacs-vc-gutter-enable))
                   '((global 1) (margin 1))))))

(ert-deftest test-vc-gutter/after-magit ()
  "A Magit refresh (commit, stage, checkout) updates the gutters, once
diff-hl is loaded; before that there's nothing to update."
  (let ((magit-post-refresh-hook nil))
    (test-vc-gutter--load-config)
    (should (memq 'hellmacs-vc-gutter-magit-refresh-h magit-post-refresh-hook))
    (cl-letf (((symbol-function 'featurep) (lambda (f &rest _) (not (eq f 'diff-hl)))))
      (should-not (test-vc-gutter--recording (run-hooks 'magit-post-refresh-hook))))
    (cl-letf (((symbol-function 'featurep) (lambda (f &rest _) (eq f 'diff-hl))))
      (should (equal (test-vc-gutter--recording (run-hooks 'magit-post-refresh-hook))
                     '((magit)))))))

(ert-deftest test-vc-gutter/settings ()
  "Diffs run in the background (large repositories), and not over TRAMP."
  (let (diff-hl-update-async diff-hl-disable-on-remote)
    (test-vc-gutter--load-config)
    (should diff-hl-update-async)
    (should diff-hl-disable-on-remote)))

(ert-deftest test-vc-gutter/keys ()
  "No keys of the module's own. diff-hl's, as shipped, are the `C-x v'
keys Emacs leaves free; `C-x v =' is still Emacs' `vc-diff' outside it."
  (let ((map (test-vc-gutter--load-config)))
    (should (equal map (make-sparse-keymap))))
  (dolist (key '("[" "]" "*" "n" "S" "{" "}"))
    (should (equal (cons key (keymap-lookup vc-prefix-map key)) (cons key nil))))
  (should (eq (keymap-lookup global-map "C-x v =") 'vc-diff)))

(provide 'test-vc-gutter)
;;; test-vc-gutter.el ends here
