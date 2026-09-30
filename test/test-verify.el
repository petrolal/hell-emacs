;;; test-verify.el --- Tests for bin/hellmacs verify (12.9) -*- lexical-binding: t; -*-

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
(require 'cl-lib)
(hellmacs-require 'hellmacs-cli 'verify)

(defvar hellmacs-cli--problems)
(defvar hellmacs-lock-file)

(defun test-verify--git (dir &rest args)
  (with-temp-buffer
    (unless (zerop (apply #'call-process "git" nil t nil "-C" dir
                          "-c" "user.name=t" "-c" "user.email=t@t" "-c" "commit.gpgsign=false" args))
      (error "git %s: %s" (string-join args " ") (buffer-string)))
    (string-trim (buffer-string))))

(defmacro test-verify--with-install (&rest body)
  "Run BODY over a fake installation: `data' (as `hellmacs-data-dir') holding a
server (lsp/tool/: two jars and a link) and a package (a git checkout,
`src', whose commit is `commit'); its manifest recorded in `manifest'."
  (declare (indent 0))
  `(let* ((data (file-name-as-directory (make-temp-file "hellmacs-test-verify" t)))
          (hellmacs-data-dir data)
          (manifest (expand-file-name "installed.eld" data))
          (lock (expand-file-name "packages.lock.eld" data))
          (src (expand-file-name "elpaca/sources/pkg" data))
          commit)
     (unwind-protect
         (progn
           (make-directory (expand-file-name "lsp/tool/lib" data) t)
           (with-temp-file (expand-file-name "lsp/tool/lib/a.jar" data) (insert "jar a"))
           (with-temp-file (expand-file-name "lsp/tool/lib/b.jar" data) (insert "jar b"))
           (make-symbolic-link "lib/a.jar" (expand-file-name "lsp/tool/current.jar" data))
           (make-directory src t)
           (test-verify--git src "init" "-q")
           (with-temp-file (expand-file-name "pkg.el" src) (insert "(provide 'pkg)\n"))
           (test-verify--git src "add" "pkg.el")
           (test-verify--git src "commit" "-q" "-m" "pkg")
           (setq commit (test-verify--git src "rev-parse" "HEAD"))
           (hellmacs-verify-record manifest '("lsp/tool") (list (list 'pkg src commit)))
           ,@body)
       (delete-directory data t))))

(ert-deftest test-verify/files-hashed-at-once ()
  "Many files' SHA-256 in one go (sha256sum, else Emacs), each as
`hellmacs-file-sha256' has it."
  (let ((dir (make-temp-file "hellmacs-test-verify" t)))
    (unwind-protect
        (let ((files (cl-loop for i below 5
                              for f = (expand-file-name (format "f%d" i) dir)
                              do (with-temp-file f (insert (format "content %d" i)))
                              collect f)))
          (let ((hashes (hellmacs-files-sha256 files)))
            (dolist (f files)
              (should (equal (gethash f hashes) (hellmacs-file-sha256 f)))))
          (cl-letf (((symbol-function 'executable-find) #'ignore))
            (let ((hashes (hellmacs-files-sha256 files)))
              (should (equal (gethash (car files) hashes) (hellmacs-file-sha256 (car files)))))))
      (delete-directory dir t))))

(ert-deftest test-verify/nothing-changed ()
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (should-not (hellmacs-verify-problems manifest))))

(ert-deftest test-verify/a-modified-jar ()
  "An installed file changed, missing or added since sync is named."
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (with-temp-file (expand-file-name "lsp/tool/lib/a.jar" data) (insert "jar a, patched"))
    (delete-file (expand-file-name "lsp/tool/lib/b.jar" data))
    (with-temp-file (expand-file-name "lsp/tool/lib/extra.jar" data) (insert "new"))
    (let ((problems (hellmacs-verify-problems manifest)))
      (should (seq-some (lambda (p) (string-match-p "lsp/tool/lib/a\\.jar.*changed" p)) problems))
      (should (seq-some (lambda (p) (string-match-p "lsp/tool/lib/b\\.jar.*missing" p)) problems))
      (should (seq-some (lambda (p) (string-match-p "lsp/tool/lib/extra\\.jar.*not installed by sync" p)) problems))
      (should (= (length problems) 3)))))

(ert-deftest test-verify/a-link-pointed-elsewhere ()
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (let ((link (expand-file-name "lsp/tool/current.jar" data)))
      (delete-file link)
      (make-symbolic-link "/tmp/evil.jar" link))
    (should (seq-some (lambda (p) (string-match-p "current\\.jar.*points to /tmp/evil\\.jar" p))
                      (hellmacs-verify-problems manifest)))))

(ert-deftest test-verify/packages-at-their-commits ()
  "A package moved off its commit, or edited in place, is named."
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (with-temp-file (expand-file-name "pkg.el" src) (insert "(provide 'pkg) ; edited\n"))
    (should (seq-some (lambda (p) (string-match-p "pkg: .*local changes" p))
                      (hellmacs-verify-problems manifest)))
    (test-verify--git src "commit" "-q" "-am" "moved")
    (should (seq-some (lambda (p) (string-match-p (concat "pkg: at [0-9a-f]\\{7\\}, not " (substring commit 0 7)) p))
                      (hellmacs-verify-problems manifest)))))

(ert-deftest test-verify/against-the-lock-file ()
  "With a lock file, a package installed at another commit than it locks is named."
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (with-temp-file lock
      (prin1 `((pkg :source "elpaca-menu-lock-file" :recipe (:package "pkg" :id pkg :ref ,commit))) (current-buffer)))
    (should-not (hellmacs-verify-problems manifest lock))
    (with-temp-file lock
      (prin1 `((pkg :source "elpaca-menu-lock-file" :recipe (:package "pkg" :id pkg :ref ,(make-string 40 ?a))))
             (current-buffer)))
    (should (seq-some (lambda (p) (string-match-p "pkg: .*lock file" p))
                      (hellmacs-verify-problems manifest lock)))))

(ert-deftest test-verify/no-manifest ()
  "Before any sync recorded one, verify says to sync, as a problem."
  (let ((problems (hellmacs-verify-problems (make-temp-name "/nonexistent/installed"))))
    (should (= (length problems) 1))
    (should (string-match-p "bin/hellmacs sync" (car problems)))))

(ert-deftest test-verify/what-sync-records ()
  "Sync records what a bundle carries, less Elpaca's git checkouts and cache:
git checks those, through the packages' commits."
  (should (equal (hellmacs-verify-installed-roots
                  '("elpaca/builds/pkg" "elpaca/cache" "elpaca/sources/pkg" "lsp/tool" "treesit/libtree-sitter-java.so"))
                 '("elpaca/builds/pkg" "lsp/tool" "treesit/libtree-sitter-java.so"))))

(ert-deftest test-verify/cli-command ()
  "`bin/hellmacs verify' reports each problem as an error (failing the command),
or that all is as sync left it."
  (require 'hellmacs-cli)
  (skip-unless (executable-find "git"))
  (test-verify--with-install
    (let ((said nil) (hellmacs-cli--problems 0))
      (cl-letf (((symbol-function 'hellmacs-cli--say)
                 (lambda (fmt &rest args) (push (apply #'format fmt args) said)))
                ((symbol-function 'hellmacs-profile-file) (lambda (_) manifest))
                (hellmacs-lock-file (expand-file-name "none.eld" data)))
        (hellmacs-cli-verify)
        (should (zerop hellmacs-cli--problems))
        (should (string-match-p "2 files and 1 package" (string-join said "\n")))
        (with-temp-file (expand-file-name "lsp/tool/lib/a.jar" data) (insert "patched"))
        (setq said nil)
        (hellmacs-cli-verify)
        (should (= hellmacs-cli--problems 1))
        (should (string-match-p "a\\.jar: changed" (string-join said "\n")))))))

(provide 'test-verify)
;;; test-verify.el ends here
