;;; default-lock.el --- Write static/packages.lock.eld -*- lexical-binding: t; -*-

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

;; For maintainers, through `make lock': install every module's packages,
;; with every flag its files test, at their newest commits (or their
;; `:pin'), then record those commits in `hell-default-lock-file'. Sync
;; installs from it when a user has no lock file of their own.
;;
;; Run it in the Makefile's throwaway HELLDIR: it writes an init.el
;; there enabling everything. Only packages are installed; the modules'
;; sync steps (JDKs, language servers, grammars) are skipped.
;; Re-run it after changing a `package!' or its `:pin', and test before
;; committing the new lock.

;;; Code:

(require 'cl-lib)
(require 'hell-modules)
(hell-require 'hell-cli 'sync)

(declare-function elpaca-write-lock-file "elpaca" (file))
(declare-function elpaca-get "elpaca" (id))
(declare-function elpaca<-status "elpaca" (e))

(defun hell-default-lock--flags (dir)
  "Every +flag the files in module DIR test with `modulep!'."
  (let (flags)
    (dolist (file (directory-files-recursively dir "\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents file)
        (while (re-search-forward "(modulep!\\(\\(?: +[+-][a-z0-9-]+\\)+\\))" nil t)
          (dolist (flag (split-string (match-string 1)))
            (setq flag (concat "+" (substring flag 1)))
            (cl-pushnew (intern flag) flags)))))
    (sort flags #'string<)))

(defun hell-default-lock--modules ()
  "The `hell!' arguments enabling every catalog module with all its flags."
  (let ((root (expand-file-name "hell+/modules/" hell-sources-dir))
        args)
    (dolist (group (directory-files root nil "\\`[a-z]"))
      (push (intern (concat ":" group)) args)
      (dolist (name (directory-files (expand-file-name group root) nil "\\`[a-z]"))
        (let ((flags (hell-default-lock--flags (expand-file-name name (expand-file-name group root)))))
          (push (if flags (cons (intern name) flags) (intern name)) args))))
    (nreverse args)))

(let ((init (expand-file-name "init.el" hell-user-dir)))
  (make-directory hell-user-dir t)
  (with-temp-file init
    (prin1 `(hell! ,@(hell-default-lock--modules)) (current-buffer)))
  (hell-modules-read-config)
  (hell-modules-install-packages 'ignore-lock)
  (defvar elpaca-lock-file-functions)
  ;; Every installed package, as `bin/hell lock'; a failed one has no
  ;; commit to record.
  (let ((elpaca-lock-file-functions
         (list (lambda (e) (eq (elpaca<-status e) 'finished)))))
    (elpaca-write-lock-file hell-default-lock-file))
  (let ((failed (cl-loop for (name . plist) in hell-packages
                         for e = (and (hell-package--order name plist) (elpaca-get name))
                         when (and e (not (eq (elpaca<-status e) 'finished)))
                         collect name)))
    (message "Wrote %s%s" (abbreviate-file-name hell-default-lock-file)
             (if failed
                 (format "\nThese failed to build (not locked): %s"
                         (mapconcat #'symbol-name failed ", "))
               ""))))

;;; default-lock.el ends here
