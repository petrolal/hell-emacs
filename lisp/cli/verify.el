;;; lisp/cli/verify.el --- Check what sync installed is still as it left it -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `bin/hell verify' (12.9, supply chain). Every download is checked
;; against its pinned SHA-256 when it's installed, and every package is
;; installed at a commit; this checks, any time later, that nothing has
;; changed since: sync records the SHA-256 of every file it installed
;; (servers, jars, grammars, the packages' compiled files) and each
;; package's commit, in the profile's installed.eld; verify compares
;; what's on disk with that record, and with your lock file.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'hell-lib)

(defvar hell-data-dir)              ; early-init.el

(defconst hell-verify-format 1
  "Version of installed.eld's layout.")

;;; The walk -------------------------------------------------------------------

(defun hell-verify--walk (roots)
  "Everything under ROOTS (relative to `hell-data-dir'), not following links.
A list of (NAME :file) and (NAME :link TARGET), NAME relative to
`hell-data-dir'."
  (let (entries)
    (cl-labels ((walk (file name)
                  (cond ((file-symlink-p file)
                         (push (list name :link (file-symlink-p file)) entries))
                        ((file-directory-p file)
                         (dolist (child (directory-files file nil directory-files-no-dot-files-regexp t))
                           (walk (expand-file-name child file) (concat name "/" child))))
                        ((file-regular-p file)
                         (push (list name :file) entries)))))
      (dolist (root roots)
        (let ((file (expand-file-name root hell-data-dir)))
          (when (or (file-exists-p file) (file-symlink-p file))
            (walk file root)))))
    (nreverse entries)))

(defun hell-verify--hash (entries)
  "ENTRIES from `hell-verify--walk', each file's with its size and SHA-256:
\(NAME :file SIZE SHA256)."
  (let ((hashes (hell-files-sha256
                 (cl-loop for (name kind) in entries
                          when (eq kind :file) collect (expand-file-name name hell-data-dir)))))
    (mapcar (lambda (entry)
              (if (eq (cadr entry) :file)
                  (let ((file (expand-file-name (car entry) hell-data-dir)))
                    (list (car entry) :file (file-attribute-size (file-attributes file))
                          (gethash file hashes)))
                entry))
            entries)))

;;; Recording --------------------------------------------------------------------

(defun hell-verify-record (file roots packages)
  "Record in FILE what's installed: every file under ROOTS, and PACKAGES.
ROOTS are relative to `hell-data-dir'; PACKAGES is a list of
\(ID SOURCE-DIR COMMIT)."
  (let ((data (list :format hell-verify-format
                    :recorded (format-time-string "%FT%T%z")
                    :roots roots
                    :entries (hell-verify--hash (hell-verify--walk roots))
                    :packages packages)))
    (make-directory (file-name-directory file) t)
    (with-temp-file file
      (let ((print-length nil) (print-level nil) (print-escape-newlines t))
        (insert ";; -*- mode: lisp-data -*-\n"
                ";; What `bin/hell sync' installed, for `bin/hell verify'; don't edit.\n")
        (prin1 data (current-buffer))
        (insert "\n")))
    data))

;;; What sync installed ----------------------------------------------------------

(defun hell-verify-installed-roots (roots)
  "ROOTS (what a bundle carries) less Elpaca's git checkouts and its cache.
Git checks those, through the packages' commits."
  (seq-remove (lambda (root)
                (or (string-prefix-p "elpaca/sources/" root)
                    (member root '("elpaca/sources" "elpaca/cache"))
                    (string-prefix-p "elpaca/cache/" root)))
              roots))

(defvar hell-profile-dir)
(declare-function hell-bundle--roots "hell-bundle")
(declare-function elpaca--queued "elpaca")
(declare-function elpaca<-source-dir "elpaca")

(defun hell-verify-record-installed ()
  "Record what the sync that just ran installed, for `bin/hell verify'.
Run at the end of `hell-sync' and `bin/hell upgrade', with
Elpaca loaded."
  (hell-require 'hell-cli 'bundle)
  (let ((packages (cl-loop for (id . e) in (elpaca--queued)
                           for dir = (elpaca<-source-dir e)
                           for head = (hell-verify--git dir "rev-parse" "HEAD")
                           when (zerop (car head))
                           collect (list id dir (cdr head)))))
    (hell-verify-record (expand-file-name "installed.eld" hell-profile-dir)
                        (hell-verify-installed-roots (hell-bundle--roots))
                            packages)))

;;; Checking ---------------------------------------------------------------------

(defun hell-verify--read (file)
  "FILE's data, if it's readable and in `hell-verify-format'; else nil."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (let ((data (ignore-errors (read (current-buffer)))))
        (and (plistp data) (eql (plist-get data :format) hell-verify-format) data)))))

(defun hell-verify--lock-refs (lock)
  "Package id -> the commit LOCK, an Elpaca lock file, pins it at."
  (when (and lock (file-readable-p lock))
    (with-temp-buffer
      (insert-file-contents lock)
      (let ((entries (ignore-errors (read (current-buffer)))))
        (cl-loop for entry in (and (listp entries) entries)
                 for recipe = (plist-get (cdr-safe entry) :recipe)
                 when (plist-get recipe :ref)
                 collect (cons (car entry) (plist-get recipe :ref)))))))

(defun hell-verify--git (dir &rest args)
  "(EXIT . OUTPUT) of git ARGS in DIR (`hell-process-output')."
  (apply #'hell-process-output "git" "-C" (expand-file-name dir) args))

(defun hell-verify--file-problems (recorded)
  "What differs between the RECORDED entries and what's on disk now."
  (let* ((roots (plist-get recorded :roots))
         (was (make-hash-table :test #'equal))
         (now (hell-verify--walk roots))
         (now-names (make-hash-table :test #'equal))
         (hashes (hell-files-sha256
                  (cl-loop for (name kind) in now
                           when (eq kind :file) collect (expand-file-name name hell-data-dir))))
         problems)
    (dolist (entry (plist-get recorded :entries))
      (puthash (car entry) entry was))
    (dolist (entry now)
      (puthash (car entry) entry now-names)
      (let ((name (car entry))
            (before (gethash (car entry) was)))
        (cond
         ((null before)
          (push (format "%s: not installed by sync" name) problems))
         ((eq (cadr entry) :link)
          (unless (and (eq (cadr before) :link) (equal (nth 2 before) (nth 2 entry)))
            (push (format "%s: points to %s, not %s" name (nth 2 entry)
                          (if (eq (cadr before) :link) (nth 2 before) "a file"))
                  problems)))
         ((not (eq (cadr before) :file))
          (push (format "%s: a file, where sync left a link to %s" name (nth 2 before)) problems))
         ((not (equal (gethash (expand-file-name name hell-data-dir) hashes) (nth 3 before)))
          (push (format "%s: changed since sync (SHA-256 differs)" name) problems)))))
    (maphash (lambda (name _)
               (unless (gethash name now-names)
                 (push (format "%s: missing" name) problems)))
             was)
    (sort problems #'string<)))

(defun hell-verify--package-problems (packages lock)
  "Return what differs between PACKAGES, the checkouts, and LOCK.
PACKAGES are (ID DIR COMMIT), as sync recorded them."
  (let ((locked (hell-verify--lock-refs lock))
        problems)
    (pcase-dolist (`(,id ,dir ,commit) packages)
      (if (not (file-directory-p dir))
          (push (format "%s: missing (%s)" id (abbreviate-file-name dir)) problems)
        (let ((head (hell-verify--git dir "rev-parse" "HEAD")))
          (cond ((not (zerop (car head)))
                 (push (format "%s: not a git checkout any more (%s)" id (abbreviate-file-name dir)) problems))
                ((not (equal (cdr head) commit))
                 (push (format "%s: at %s, not %s as sync installed it" id
                               (substring (cdr head) 0 (min 7 (length (cdr head))))
                               (substring commit 0 (min 7 (length commit))))
                       problems)))
          (let ((status (hell-verify--git dir "status" "--porcelain" "--untracked-files=no")))
            (when (and (zerop (car status)) (not (string-empty-p (cdr status))))
              (push (format "%s: has local changes (%s)" id (abbreviate-file-name dir)) problems)))
          (when-let* ((ref (alist-get id locked)))
            (unless (equal ref commit)
              (push (format "%s: installed at %s, but your lock file has %s" id
                            (substring commit 0 (min 7 (length commit))) (substring ref 0 (min 7 (length ref))))
                    problems))))))
    (nreverse problems)))

(defun hell-verify-problems (manifest &optional lock)
  "Return everything installed that isn't as recorded or pinned.
That's as MANIFEST (installed.eld) recorded it, or as LOCK (a lock file)
pins it: a list of one-line descriptions, nil when all is well."
  (if-let* ((recorded (hell-verify--read manifest)))
      (append (hell-verify--file-problems recorded)
              (hell-verify--package-problems (plist-get recorded :packages) lock))
    (list (format "No record of what sync installed (%s); run `bin/hell sync'"
                  (abbreviate-file-name manifest)))))

(defun hell-verify-summary (manifest)
  "(FILES . PACKAGES): how many MANIFEST records."
  (let ((recorded (hell-verify--read manifest)))
    (cons (cl-count :file (plist-get recorded :entries) :key #'cadr)
          (length (plist-get recorded :packages)))))

(hell-provide 'hell-cli 'verify)
;;; verify.el ends here
