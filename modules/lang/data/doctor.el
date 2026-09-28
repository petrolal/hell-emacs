;;; lang/data/doctor.el -*- lexical-binding: t; -*-

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

(let ((java (hellmacs-xml-java)))
  (if (file-executable-p java)
      (hellmacs-doctor-ok "JDK for lemminx: %s" (abbreviate-file-name java))
    (hellmacs-doctor-error "No JDK found (set JAVA_HOME or put java on the PATH); lemminx needs 11+")))

(hellmacs-doctor-reachable hellmacs-xml-lemminx-url "installing lemminx")
(hellmacs-doctor-pinned "lemminx" hellmacs-xml-lemminx-version
                        (hellmacs-xml-lemminx-installed-p) (file-exists-p hellmacs-xml-lemminx-jar)
                        :where hellmacs-xml-lemminx-jar
                        :missing-note " (or the first XML file does)")
