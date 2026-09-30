;;; lang/groovy/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; The server runs on a JDK 11+; building it takes one Gradle runs on.
(let ((java (hellmacs-jdk-java-executable 11)))
  (if (file-name-absolute-p java)
      (hellmacs-doctor-ok "JDK for the server: %s" (abbreviate-file-name java))
    (hellmacs-doctor-error :topic 'jdk "No JDK 11+ found (JAVA_HOME, or one `bin/hellmacs sync' found) for groovy-language-server")))

(unless (hellmacs-groovy-server-installed-p)
  (let ((range (hellmacs-jdk-gradle-daemon-range hellmacs-groovy-gradle-version)))
    (if (hellmacs-jdk-pick (mapcar #'cdr (hellmacs-jdk-detect)) (car range) (cdr range))
        (hellmacs-doctor-ok "A JDK %d to %d to build the server with" (car range) (cdr range))
      (hellmacs-doctor-error :topic 'jdk "Building groovy-language-server needs a JDK %d to %d (for Gradle %s); none found"
                             (car range) (cdr range) hellmacs-groovy-gradle-version)))
  (hellmacs-doctor-executable "git" "fetching groovy-language-server's source" t)
  (hellmacs-doctor-executable "unzip" "unpacking the Gradle it's built with" t)
  (hellmacs-doctor-reachable hellmacs-groovy-server-url "fetching groovy-language-server's source")
  (hellmacs-doctor-reachable hellmacs-groovy-gradle-url "downloading the Gradle it's built with"))

(hellmacs-doctor-pinned "groovy-language-server" (substring hellmacs-groovy-server-commit 0 7)
                        (hellmacs-groovy-server-installed-p) (file-exists-p hellmacs-groovy-server-jar)
                        :where hellmacs-groovy-server-dir)

;;; lang/groovy/doctor.el ends here
