;;; test-bundle.el --- Tests for offline bundles -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. Bundles are made from, and installed
;; into, small fake data directories; the lock file and the module list
;; are stubbed, so no package is installed and nothing is fetched.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-cli)
(require 'url)

(defun test-bundle--write (file &optional content)
  "Create FILE (and its directories) holding CONTENT."
  (make-directory (file-name-directory file) t)
  (with-temp-file file (insert (or content (file-name-nondirectory file)))))

(defun test-bundle--read (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defmacro test-bundle--with (&rest body)
  "Run BODY with a fake machine: `src' and `dst' data directories, a lock
file, one enabled module (:lang java +lombok), stubbed Elpaca lock writing."
  (declare (indent 0))
  `(let* ((tmp (make-temp-file "test-bundle" t))
          (src (file-name-as-directory (expand-file-name "src" tmp)))
          (dst (file-name-as-directory (expand-file-name "dst" tmp)))
          (hellmacs-data-dir src)
          (hellmacs-lock-file (expand-file-name "config/packages.lock.eld" tmp))
          (hellmacs-bundle-functions nil)
          (inhibit-message t))
     (ignore dst)
     (unwind-protect
         (cl-letf (((symbol-function 'elpaca-write-lock-file)
                    (lambda (file) (test-bundle--write file "((pkg :source \"lock\" :recipe (:ref \"abc\")))")))
                   ((symbol-function 'hellmacs-module-list) (lambda () '((:lang . java))))
                   ((symbol-function 'hellmacs-module-get)
                    (lambda (_key prop) (and (eq prop :flags) '(+lombok))))
                   ((symbol-function 'hellmacs-sync--log) #'ignore))
           ,@body)
       (delete-directory tmp t))))

(defun test-bundle--populate (dir)
  "A data directory like a synced one: a package's source and its build
\(a link into the source), a server, an empty directory, a grammar."
  (test-bundle--write (expand-file-name "elpaca/sources/pkg/pkg.el" dir) "(provide 'pkg)")
  (test-bundle--write (expand-file-name "elpaca/sources/pkg/.git/HEAD" dir) "ref: refs/heads/main")
  (make-directory (expand-file-name "elpaca/builds/pkg/" dir) t)
  (make-symbolic-link (expand-file-name "elpaca/sources/pkg/pkg.el" dir)
                      (expand-file-name "elpaca/builds/pkg/pkg.el" dir))
  (test-bundle--write (expand-file-name "lsp/kotlin/server/bin/kls" dir) "#!/bin/sh\n")
  (set-file-modes (expand-file-name "lsp/kotlin/server/bin/kls" dir) #o755)
  (make-directory (expand-file-name "lsp/kotlin/empty/" dir) t)
  (test-bundle--write (expand-file-name "treesit/libtree-sitter-java.so" dir) "ELF")
  (test-bundle--write (expand-file-name "jvm/workspace/state" dir) "not bundled"))

(defun test-bundle--paths ()
  (list (expand-file-name "elpaca/sources/pkg/" hellmacs-data-dir)
        (expand-file-name "elpaca/builds/pkg/" hellmacs-data-dir)
        (expand-file-name "lsp/kotlin/" hellmacs-data-dir)
        (expand-file-name "lsp/kotlin/server/" hellmacs-data-dir) ; inside the one above
        (expand-file-name "treesit/libtree-sitter-java.so" hellmacs-data-dir)
        (expand-file-name "treesit/missing.so" hellmacs-data-dir)
        nil))

(ert-deftest test-bundle/roots ()
  "Missing paths and paths inside another are dropped; outside the data dir is an error."
  (test-bundle--with
    (test-bundle--populate src)
    (add-hook 'hellmacs-bundle-functions #'test-bundle--paths)
    (should (equal (hellmacs-bundle--roots)
                   '("elpaca/builds/pkg" "elpaca/sources/pkg" "lsp/kotlin"
                     "treesit/libtree-sitter-java.so")))
    (add-hook 'hellmacs-bundle-functions (lambda () (list tmp)))
    (should-error (hellmacs-bundle--roots))))

(ert-deftest test-bundle/entries ()
  "Every file with its size and sum; the holding directories; links into the data dir made relative."
  (test-bundle--with
    (test-bundle--populate src)
    (let ((entries (hellmacs-bundle--entries '("elpaca/builds/pkg" "elpaca/sources/pkg" "lsp/kotlin"))))
      (should (equal (assoc "elpaca" entries) '("elpaca" :dir)))
      (should (equal (assoc "elpaca/builds" entries) '("elpaca/builds" :dir)))
      (should (equal (assoc "elpaca/builds/pkg/pkg.el" entries)
                     '("elpaca/builds/pkg/pkg.el" :data-link "elpaca/sources/pkg/pkg.el")))
      (should (equal (assoc "elpaca/sources/pkg/pkg.el" entries)
                     (list "elpaca/sources/pkg/pkg.el" :file 14
                           (secure-hash 'sha256 "(provide 'pkg)"))))
      (should (assoc "elpaca/sources/pkg/.git/HEAD" entries))
      (should (equal (assoc "lsp/kotlin/empty" entries) '("lsp/kotlin/empty" :dir)))
      (should-not (assoc "jvm/workspace/state" entries))
      (should (equal (mapcar #'car entries) (sort (mapcar #'car entries) #'string<))))))

(ert-deftest test-bundle/round-trip ()
  "A bundle made on one machine installs on another: files, modes, links, the lock file.
Roots already there are replaced whole; everything else is left alone."
  (test-bundle--with
    (test-bundle--populate src)
    (add-hook 'hellmacs-bundle-functions #'test-bundle--paths)
    (let* ((bundle (expand-file-name "out/b.tar.gz" tmp))
           (made (hellmacs-bundle-create bundle)))
      (should (file-exists-p bundle))
      (should-not (directory-files (file-name-directory bundle) nil "partial"))
      (should (equal (plist-get made :roots)
                     '("elpaca/builds/pkg" "elpaca/sources/pkg" "lsp/kotlin"
                       "treesit/libtree-sitter-java.so")))
      (should (equal (plist-get made :modules) '(((:lang . java) (+lombok)))))
      ;; The other machine: an older server, and files of its own.
      (test-bundle--write (expand-file-name "lsp/kotlin/stale" dst))
      (test-bundle--write (expand-file-name "jvm/workspace/mine" dst))
      (test-bundle--write hellmacs-lock-file "old lock")
      (let ((hellmacs-data-dir dst))
        (hellmacs-bundle-install bundle))
      (should (equal (test-bundle--read (expand-file-name "elpaca/sources/pkg/pkg.el" dst))
                     "(provide 'pkg)"))
      (should (equal (file-symlink-p (expand-file-name "elpaca/builds/pkg/pkg.el" dst))
                     (expand-file-name "elpaca/sources/pkg/pkg.el" dst)))
      (should (file-executable-p (expand-file-name "lsp/kotlin/server/bin/kls" dst)))
      (should (file-directory-p (expand-file-name "lsp/kotlin/empty" dst)))
      (should-not (file-exists-p (expand-file-name "lsp/kotlin/stale" dst)))
      (should (file-exists-p (expand-file-name "jvm/workspace/mine" dst)))
      (should-not (file-exists-p (expand-file-name "jvm/workspace/state" dst)))
      (should (string-prefix-p "((pkg" (test-bundle--read hellmacs-lock-file)))
      (should (equal (test-bundle--read (concat hellmacs-lock-file ".before-bundle")) "old lock"))
      ;; Nothing left behind: no staging directory, no set-aside copies.
      (should-not (directory-files dst nil "\\`\\.bundle-"))
      (should-not (directory-files (expand-file-name "lsp" dst) nil "hellmacs-old")))))

(ert-deftest test-bundle/verify ()
  "A changed, missing or extra file fails the check, and is named."
  (test-bundle--with
    (test-bundle--populate src)
    (let* ((roots '("elpaca" "jvm" "lsp" "treesit")) ; all of it: nothing is extra
           (manifest (list :roots roots :entries (hellmacs-bundle--entries roots))))
      (hellmacs-bundle-verify manifest src)
      (test-bundle--write (expand-file-name "lsp/kotlin/server/bin/kls" src) "#!/bin/sh\nevil\n")
      (should (string-match-p "lsp/kotlin/server/bin/kls"
                              (cadr (should-error (hellmacs-bundle-verify manifest src)))))
      (test-bundle--write (expand-file-name "lsp/kotlin/server/bin/kls" src) "#!/bin/sh\n")
      (test-bundle--write (expand-file-name "lsp/kotlin/extra" src))
      (should (string-match-p "lsp/kotlin/extra (not in the manifest)"
                              (cadr (should-error (hellmacs-bundle-verify manifest src)))))
      (delete-file (expand-file-name "lsp/kotlin/extra" src))
      (delete-file (expand-file-name "elpaca/sources/pkg/pkg.el" src))
      (should (string-match-p "elpaca/sources/pkg/pkg.el"
                              (cadr (should-error (hellmacs-bundle-verify manifest src))))))))

(ert-deftest test-bundle/unsafe-names ()
  "A manifest can't name a file outside the directory it's unpacked in."
  (dolist (name '("/etc/passwd" "../x" "a/../../x" "a/./b" "" "a//b"))
    (should-error (hellmacs-bundle--check-name name)))
  (dolist (name '("elpaca/sources/pkg/.git/HEAD" "a..b/c" ".hidden"))
    (hellmacs-bundle--check-name name)))

(ert-deftest test-bundle/unsafe-data-link-target ()
  "A link the bundle remakes into the data directory can't lead out of it."
  (let ((root (make-temp-file "hellmacs-test-bundle" t)))
    (unwind-protect
        (progn
          (make-symbolic-link "anywhere" (expand-file-name "link" root))
          (hellmacs-bundle-verify '(:entries (("link" :data-link "elpaca/sources/pkg"))) root)
          (dolist (target '("../../.bashrc" "/etc/passwd" "a/../../x"))
            (should-error (hellmacs-bundle-verify `(:entries (("link" :data-link ,target))) root))))
      (delete-directory root t))))

(ert-deftest test-bundle/check ()
  "The format, platform, Emacs major version and module set must fit."
  (test-bundle--with
    (let ((ok (list :format hellmacs-bundle-format :platform (hellmacs-bundle--platform)
                    :emacs-version emacs-version
                    :modules '(((:lang . java) (+lombok +tree-sitter)) ((:tools . lsp) nil)))))
      (hellmacs-bundle-check ok)
      (should-error (hellmacs-bundle-check (plist-put (copy-sequence ok) :format 99)))
      (should (string-match-p "is for plan9-bell"
                              (cadr (should-error (hellmacs-bundle-check
                                                   (plist-put (copy-sequence ok) :platform "plan9-bell"))))))
      (should (string-match-p "made with Emacs 1\\.0"
                              (cadr (should-error (hellmacs-bundle-check
                                                   (plist-put (copy-sequence ok) :emacs-version "1.0"))))))
      (should (string-match-p ":lang java \\+lombok"
                              (cadr (should-error (hellmacs-bundle-check
                                                   (plist-put (copy-sequence ok) :modules
                                                              '(((:lang . java) nil))))))))
      (should (string-match-p ":lang java"
                              (cadr (should-error (hellmacs-bundle-check
                                                   (plist-put (copy-sequence ok) :modules nil)))))))))

(ert-deftest test-bundle/platform ()
  "An OS release number doesn't make another platform."
  (should (equal (hellmacs-bundle--platform "aarch64-apple-darwin23.1.0") "aarch64-apple-darwin"))
  (should (equal (hellmacs-bundle--platform "x86_64-pc-linux-gnu") "x86_64-pc-linux-gnu")))

(ert-deftest test-bundle/refuses-a-bad-bundle ()
  "Not a bundle, or a damaged one: nothing is installed."
  (test-bundle--with
    (let ((junk (expand-file-name "junk.tar" tmp)))
      (test-bundle--write (expand-file-name "stuff/file" tmp))
      (hellmacs-bundle--tar "-c" "-f" junk "-C" tmp "stuff")
      (let ((hellmacs-data-dir dst))
        (should (string-match-p "Not a Hellmacs bundle"
                                (cadr (should-error (hellmacs-bundle-install junk)))))
        (should-error (hellmacs-bundle-install (expand-file-name "nope.tar" tmp)))
        (should-not (directory-files dst nil "\\`\\.bundle-"))))))

(ert-deftest test-bundle/offline ()
  "Offline, url.el fetches, pinned downloads and git's network transports are refused."
  (let ((hellmacs-net-offline t)
        (hellmacs-mirrors nil) (hellmacs-proxy nil) (hellmacs-ca-bundle nil)
        (dest (make-temp-file "test-bundle-dl")))
    (unwind-protect
        (progn
          (should (string-match-p "Offline install"
                                  (error-message-string
                                   (should-error (url-retrieve-internal "https://example.invalid/x"
                                                                        #'ignore nil nil nil)))))
          (should (string-match-p "Lombok isn.t installed"
                                  (cadr (should-error (hellmacs-sync-download-verified
                                                       "https://example.invalid/l.jar" dest "0" "Lombok")))))
          (with-hellmacs-network
            (with-temp-buffer
              (should-not (zerop (call-process "git" nil t nil "ls-remote" "https://example.invalid/r.git")))
              (should (string-match-p "not allowed" (buffer-string))))))
      (delete-file dest)))
  ;; Online, git gets none of it.
  (let ((hellmacs-net-offline nil) (hellmacs-mirrors nil) (hellmacs-proxy nil) (hellmacs-ca-bundle nil))
    (should-not (assoc "protocol.allow" (hellmacs-net--git-config)))))

(ert-deftest test-bundle/modules-argument ()
  "--modules is read as a `hellmacs!' block's arguments."
  (should (equal (hellmacs-cli--read-modules ":lang (java +lombok) kotlin :tools lsp")
                 '(:lang (java +lombok) kotlin :tools lsp)))
  (should-error (hellmacs-cli--read-modules "java"))
  (should-error (hellmacs-cli--read-modules ":lang (java"))
  (should (equal (hellmacs-cli--option '("out.tar" "--modules" ":lang java") "--modules") ":lang java"))
  (should-not (hellmacs-cli--option '("out.tar") "--modules"))
  (should-error (hellmacs-cli--option '("--from-bundle") "--from-bundle"))
  (should-error (hellmacs-cli--option '("--from-bundle" "--env") "--from-bundle")))

(ert-deftest test-bundle/modules-override ()
  "The override replaces the user's module set (and the defaults)."
  (let ((hellmacs-modules-override '(:tools lsp))
        (hellmacs-user-dir (make-temp-file "test-bundle-user" t)))
    (unwind-protect
        (progn
          (hellmacs-modules-read-config)
          (should (equal (hellmacs-module-list) '((:tools . lsp)))))
      (let ((hellmacs-modules-override nil))
        (hellmacs-modules-read-config))
      (delete-directory hellmacs-user-dir t))))

(provide 'test-bundle)
;;; test-bundle.el ends here
