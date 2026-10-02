;;; lang/data/doctor.el -*- lexical-binding: t; -*-

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

(let ((java (hell-xml-java)))
  (if (file-executable-p java)
      (hell-doctor-ok "JDK for lemminx: %s" (abbreviate-file-name java))
    (hell-doctor-error :topic 'jdk "No JDK found (set JAVA_HOME or put java on the PATH); lemminx needs 11+")))

(hell-doctor-reachable hell-xml-lemminx-url "installing lemminx")
(hell-doctor-pinned "lemminx" hell-xml-lemminx-version
                    (hell-xml-lemminx-installed-p) (file-exists-p hell-xml-lemminx-jar)
                        :where hell-xml-lemminx-jar
                        :missing-note " (or the first XML file does)")
