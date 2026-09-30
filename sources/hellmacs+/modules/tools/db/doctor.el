;;; tools/db/doctor.el -*- lexical-binding: t; -*-

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


;; Checked by `bin/hellmacs doctor'.

(hellmacs-module-load "+paths")

(let* ((java (hellmacs-jdk-java-executable 11))
       (major (and (file-name-absolute-p java)
                   (hellmacs-jdk-home-major (file-name-directory (directory-file-name (file-name-directory java)))))))
  (if major
      (hellmacs-doctor-ok "JDK for sqlline: %d (%s)" major (abbreviate-file-name java))
    (hellmacs-doctor-error :topic 'jdk "sqlline and the JDBC drivers need a JDK 11+; none found")))

(dolist (name (cons 'sqlline hellmacs-db-drivers))
  (let ((spec (cdr (assq name hellmacs-db-jars))))
    (hellmacs-doctor-reachable (plist-get spec :url) (format "installing %s" name))
    (hellmacs-doctor-pinned (symbol-name name) (plist-get spec :version)
                            (hellmacs-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
                            (file-exists-p (plist-get spec :file))
                            :where (plist-get spec :file))))
