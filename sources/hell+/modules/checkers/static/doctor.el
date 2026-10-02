;;; checkers/static/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

(when (modulep! +sonarlint)
  (hell-module-load "+paths")
  (hell-doctor-pinned "SonarLint" hell-static-sonarlint-version
                          (hell-static-sonarlint-installed-p)
                          (file-exists-p hell-static-sonarlint-dir)
                          :where hell-static-sonarlint-dir)
  (hell-require 'hell-lib 'jdk)
  (let ((java (hell-jdk-java-executable 17)))
    (if (and (equal java "java") (not (executable-find "java")))
        (hell-doctor-error :topic 'jdk "SonarLint needs a JDK 17 or later, and there's no java")
      (hell-doctor-ok "SonarLint runs on %s" (abbreviate-file-name java)))))
