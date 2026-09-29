;;; test-reference.el --- Tests for the pinned reference projects (Phase 12.7) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The reference projects (the large public
;; codebases java-parity.el measures, test/integration/reference.el) are
;; pinned to a tag and its commit. Fetching is checked against a local
;; git repository standing in for the real remote: no network.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load (expand-file-name "test/integration/reference" hellmacs-dir) nil t)

(defun test-reference--git (dir &rest args)
  "Run git with ARGS in DIR; return its trimmed output, or signal on failure."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory dir)))
      (unless (zerop (apply #'call-process "git" nil t nil args))
        (error "git %S failed: %s" args (buffer-string)))
      (string-trim (buffer-string)))))

(defmacro test-reference--with-remote (&rest body)
  "Run BODY with `remote' a git repository holding tag v1.0 (commit `commit'),
and `store' an empty directory for the fetched copies."
  (declare (indent 0))
  `(let* ((remote (make-temp-file "hellmacs-ref-remote" t))
          (store (make-temp-file "hellmacs-ref-store" t))
          (process-environment
           (append '("GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@t" "GIT_COMMITTER_NAME=t"
                     "GIT_COMMITTER_EMAIL=t@t" "GIT_CONFIG_GLOBAL=/dev/null")
                   process-environment))
          commit)
     (unwind-protect
         (progn
           (test-reference--git remote "init" "-q" "-b" "main")
           (write-region "class A {}\n" nil (expand-file-name "A.java" remote))
           (test-reference--git remote "add" "A.java")
           (test-reference--git remote "commit" "-q" "-m" "one")
           (test-reference--git remote "tag" "-a" "v1.0" "-m" "release")
           (setq commit (test-reference--git remote "rev-parse" "HEAD"))
           ;; A later commit: the pin, not the branch head, is what's fetched.
           (write-region "class B {}\n" nil (expand-file-name "B.java" remote))
           (test-reference--git remote "add" "B.java")
           (test-reference--git remote "commit" "-q" "-m" "two")
           ,@body)
       (delete-directory remote t)
       (delete-directory store t))))

(ert-deftest test-reference/pins ()
  "Each reference project is pinned to an https URL, a tag and its full commit,
with the file to work in and a build command."
  (should e2e-reference-projects)
  (dolist (entry e2e-reference-projects)
    (let ((spec (cdr entry)))
      (should (symbolp (car entry)))
      (should (string-prefix-p "https://" (plist-get spec :url)))
      (should (stringp (plist-get spec :tag)))
      (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" (plist-get spec :commit)))
      (should (string-suffix-p ".java" (plist-get spec :file)))
      (should (stringp (plist-get spec :build))))))

(ert-deftest test-reference/spring-framework ()
  "Spring Framework is the reference monorepo (Gradle, mostly Java)."
  (let ((spec (e2e-reference 'spring-framework)))
    (should (equal (plist-get spec :url)
                   "https://github.com/spring-projects/spring-framework.git"))
    (should (plist-get spec :commit))
    (should-error (e2e-reference 'no-such-project))))

(ert-deftest test-reference/where-they-are-kept ()
  "In Hellmacs' cache, one directory per project and tag; $HELLMACS_REFERENCE_DIR
moves them (so throwaway runs don't fetch again)."
  (let ((spec '(:tag "v1.0")))
    (let ((process-environment (cons "HELLMACS_REFERENCE_DIR" process-environment)))
      (should (equal (e2e-reference-dir 'demo spec)
                     (expand-file-name "reference/demo-v1.0/" hellmacs-cache-dir))))
    (let ((process-environment (cons "HELLMACS_REFERENCE_DIR=/refs" process-environment)))
      (should (equal (e2e-reference-dir 'demo spec) "/refs/demo-v1.0/")))))

(ert-deftest test-reference/fetch ()
  "Fetching clones the pinned tag, checks its commit, and is kept for next time."
  (test-reference--with-remote
    (let* ((process-environment (cons (concat "HELLMACS_REFERENCE_DIR=" store)
                                      process-environment))
           (spec (list :url remote :tag "v1.0" :commit commit))
           (dir (e2e-reference-fetch 'demo spec)))
      (should (equal dir (e2e-reference-dir 'demo spec)))
      (should (file-exists-p (expand-file-name "A.java" dir)))
      (should-not (file-exists-p (expand-file-name "B.java" dir)))
      (should (equal (test-reference--git dir "rev-parse" "HEAD") commit))
      ;; Already there: not cloned again, even with the remote gone.
      (should (equal (e2e-reference-fetch 'demo (plist-put (copy-sequence spec) :url "/gone"))
                     dir)))))

(ert-deftest test-reference/fetch-checks-the-commit ()
  "A tag that doesn't point at the pinned commit (moved, or a different
repository) is an error, and nothing is kept."
  (test-reference--with-remote
    (let* ((process-environment (cons (concat "HELLMACS_REFERENCE_DIR=" store)
                                      process-environment))
           (spec (list :url remote :tag "v1.0" :commit (make-string 40 ?0))))
      (should-error (e2e-reference-fetch 'demo spec))
      (should-not (file-exists-p (e2e-reference-dir 'demo spec))))))

(ert-deftest test-reference/fetch-fails-cleanly ()
  "A clone that fails (no such tag) leaves nothing behind."
  (test-reference--with-remote
    (let* ((process-environment (cons (concat "HELLMACS_REFERENCE_DIR=" store)
                                      process-environment))
           (spec (list :url remote :tag "v9.9" :commit commit)))
      (should-error (e2e-reference-fetch 'demo spec))
      (should-not (file-exists-p (e2e-reference-dir 'demo spec))))))

(provide 'test-reference)
;;; test-reference.el ends here
