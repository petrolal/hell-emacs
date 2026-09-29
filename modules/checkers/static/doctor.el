;;; checkers/static/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

(when (modulep! +sonarlint)
  (hellmacs-module-load "+paths")
  (hellmacs-doctor-pinned "SonarLint" hellmacs-static-sonarlint-version
                          (hellmacs-static-sonarlint-installed-p)
                          (file-exists-p hellmacs-static-sonarlint-dir)
                          :where hellmacs-static-sonarlint-dir)
  (require 'hellmacs-jdk)
  (let ((java (hellmacs-jdk-java-executable 17)))
    (if (and (equal java "java") (not (executable-find "java")))
        (hellmacs-doctor-error "SonarLint needs a JDK 17 or later, and there's no java")
      (hellmacs-doctor-ok "SonarLint runs on %s" (abbreviate-file-name java)))))
