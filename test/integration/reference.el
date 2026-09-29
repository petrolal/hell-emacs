;;; reference.el --- Pinned reference projects for measurements -*- lexical-binding: t; -*-

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

;; Phase 12.7: the large public codebases Hellmacs is measured on, each
;; pinned to a release tag and that tag's commit, so every run (and every
;; machine) measures the same code. java-parity.el runs on one with
;; HELLMACS_PARITY_REFERENCE=spring-framework; the first run clones it
;; (shallow) into Hellmacs' cache, or $HELLMACS_REFERENCE_DIR.
;; Not a test by itself; test/test-reference.el checks it.

;;; Code:

(require 'hellmacs-net)

(defconst e2e-reference-projects
  '((spring-framework
     :url "https://github.com/spring-projects/spring-framework.git"
     :tag "v7.0.9"
     :commit "82a6b40b9366ec181ededdad282b307ee5381a52"
     ;; A big class at the center of the codebase.
     :file "spring-beans/src/main/java/org/springframework/beans/factory/support/DefaultListableBeanFactory.java"
     ;; The whole build runs every test for most of an hour; compiling
     ;; the main sources is what a working day repeats.
     :build "./gradlew --console=plain compileJava"))
  "The reference projects: (NAME :url :tag :commit :file :build).
:commit is what :tag must point at; :file is the Java file to work in,
relative to the project; :build is the build command to time.")

(defun e2e-reference (name)
  "The pinned spec of reference project NAME."
  (or (alist-get name e2e-reference-projects)
      (error "No reference project %s (known: %s)"
             name (mapconcat (lambda (e) (symbol-name (car e))) e2e-reference-projects ", "))))

(defun e2e-reference-dir (name spec)
  "Where reference project NAME, pinned by SPEC, is kept.
Under $HELLMACS_REFERENCE_DIR, else Hellmacs' cache: <NAME>-<TAG>/."
  (let ((store (getenv "HELLMACS_REFERENCE_DIR")))
    (file-name-as-directory
     (expand-file-name (format "%s-%s" name (plist-get spec :tag))
                       (if (and store (not (string-empty-p store)))
                           store
                         (expand-file-name "reference/" hellmacs-cache-dir))))))

(defun e2e-reference--git (dir &rest args)
  "Run git with ARGS in DIR: (STATUS . OUTPUT)."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory dir)))
      (cons (apply #'call-process "git" nil t nil args)
            (string-trim (buffer-string))))))

(defun e2e-reference-fetch (name &optional spec)
  "Return the directory of reference project NAME, cloning it the first time.
SPEC defaults to NAME's pin. The clone is shallow, of the pinned tag, and
must be at the pinned commit; if not, it's deleted and this signals."
  (let* ((spec (or spec (e2e-reference name)))
         (dir (e2e-reference-dir name spec))
         (commit (plist-get spec :commit)))
    (unless (file-directory-p dir)
      (make-directory (file-name-directory (directory-file-name dir)) t)
      (let ((clone (with-hellmacs-network
                     (e2e-reference--git temporary-file-directory
                                         "-c" "advice.detachedHead=false"
                                         "clone" "--quiet" "--depth" "1"
                                         "--branch" (plist-get spec :tag)
                                         (plist-get spec :url) dir))))
        (unless (zerop (car clone))
          (when (file-directory-p dir) (delete-directory dir t))
          (error "Cloning %s %s failed: %s" name (plist-get spec :tag) (cdr clone))))
      (let ((head (cdr (e2e-reference--git dir "rev-parse" "HEAD"))))
        (unless (equal head commit)
          (delete-directory dir t)
          (error "%s %s is at %s, not the pinned %s" name (plist-get spec :tag) head commit))))
    dir))

(provide 'e2e-reference)
;;; reference.el ends here
