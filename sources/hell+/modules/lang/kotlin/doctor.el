;;; lang/kotlin/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; The server is a JVM program: it runs on JAVA_HOME's java, else the PATH's.
(let* ((home (getenv "JAVA_HOME"))
       (java (if home (expand-file-name "bin/java" home) (executable-find "java"))))
  (if (not (and java (file-executable-p java)))
      (hell-doctor-error :topic 'jdk "No JDK found (set JAVA_HOME or put java on the PATH); kotlin-language-server needs 11+")
    (hell-doctor-ok "JDK for the server: %s" (abbreviate-file-name java))))

(hell-doctor-executable "unzip" "installing kotlin-language-server")
(hell-doctor-executable "kotlinc" "compiling Kotlin outside Gradle (projects build with Gradle)" nil "-version")

(hell-doctor-reachable hell-kotlin-ls-url "installing kotlin-language-server")
(hell-doctor-pinned "kotlin-language-server" hell-kotlin-ls-version
                    (hell-kotlin-ls-installed-p) (file-exists-p hell-kotlin-ls-executable)
                        :where hell-kotlin-ls-dir
                        :missing-note " (or the first Kotlin file does, unpinned)")
