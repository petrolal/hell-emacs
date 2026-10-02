;;; tools/db/doctor.el -*- lexical-binding: t; -*-

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


;; Checked by `bin/hell doctor'.

(hell-module-load "+paths")

(let* ((java (hell-jdk-java-executable 11))
       (major (and (file-name-absolute-p java)
                   (hell-jdk-home-major (file-name-directory (directory-file-name (file-name-directory java)))))))
  (if major
      (hell-doctor-ok "JDK for sqlline: %d (%s)" major (abbreviate-file-name java))
    (hell-doctor-error :topic 'jdk "sqlline and the JDBC drivers need a JDK 11+; none found")))

(dolist (name (cons 'sqlline hell-db-drivers))
  (let ((spec (cdr (assq name hell-db-jars))))
    (hell-doctor-reachable (plist-get spec :url) (format "installing %s" name))
    (hell-doctor-pinned (symbol-name name) (plist-get spec :version)
                            (hell-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
                            (file-exists-p (plist-get spec :file))
                            :where (plist-get spec :file))))
