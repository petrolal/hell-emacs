;;; lang/groovy/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; The server runs on a JDK 11+; building it takes one Gradle runs on.
(let ((java (hell-jdk-java-executable 11)))
  (if (file-name-absolute-p java)
      (hell-doctor-ok "JDK for the server: %s" (abbreviate-file-name java))
    (hell-doctor-error :topic 'jdk "No JDK 11+ found (JAVA_HOME, or one `bin/hell sync' found) for groovy-language-server")))

(unless (hell-groovy-server-installed-p)
  (let ((range (hell-jdk-gradle-daemon-range hell-groovy-gradle-version)))
    (if (hell-jdk-pick (mapcar #'cdr (hell-jdk-detect)) (car range) (cdr range))
        (hell-doctor-ok "A JDK %d to %d to build the server with" (car range) (cdr range))
      (hell-doctor-error :topic 'jdk "Building groovy-language-server needs a JDK %d to %d (for Gradle %s); none found"
                             (car range) (cdr range) hell-groovy-gradle-version)))
  (hell-doctor-executable "git" "fetching groovy-language-server's source" t)
  (hell-doctor-executable "unzip" "unpacking the Gradle it's built with" t)
  (hell-doctor-reachable hell-groovy-server-url "fetching groovy-language-server's source")
  (hell-doctor-reachable hell-groovy-gradle-url "downloading the Gradle it's built with"))

(hell-doctor-pinned "groovy-language-server" (substring hell-groovy-server-commit 0 7)
                        (hell-groovy-server-installed-p) (file-exists-p hell-groovy-server-jar)
                        :where hell-groovy-server-dir)

;;; lang/groovy/doctor.el ends here
