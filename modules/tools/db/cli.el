;;; tools/db/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs sqlline and the drivers in
;; `hellmacs-db-drivers'.

(hellmacs-module-load "+paths")

(defun hellmacs-db-sync-install ()
  "Install the pinned sqlline and `hellmacs-db-drivers'. For `hellmacs-sync-functions'."
  (dolist (name (cons 'sqlline hellmacs-db-drivers))
    (let ((spec (cdr (assq name hellmacs-db-jars))))
      (if (hellmacs-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
          (hellmacs-sync--log "%s %s is installed" name (plist-get spec :version))
        (hellmacs-sync--log "Downloading %s %s..." name (plist-get spec :version))
        (hellmacs-sync-download-verified (plist-get spec :url) (plist-get spec :file)
                                         (plist-get spec :sha256) (symbol-name name))
        (hellmacs-sync--log "%s %s installed (SHA-256 verified)" name (plist-get spec :version))))))

(add-hook 'hellmacs-sync-functions #'hellmacs-db-sync-install)

(defun hellmacs-db-bundle-paths ()
  "The jars sync installs. For `hellmacs-bundle-functions'."
  (mapcar (lambda (name) (plist-get (cdr (assq name hellmacs-db-jars)) :file))
          (cons 'sqlline hellmacs-db-drivers)))

(add-hook 'hellmacs-bundle-functions #'hellmacs-db-bundle-paths)
