;;; editor/format/+paths.el -*- lexical-binding: t; -*-

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


;; The formatter jars `bin/hellmacs sync' installs, pinned by SHA-256 from
;; Maven Central (their SHA-1s match Central's own). Loaded by autoload.el,
;; cli.el and doctor.el.

(defvar hellmacs-format-jars
  (let ((dir (expand-file-name "formatters/" hellmacs-data-dir)))
    `((google-java-format
       :version "1.36.1"
       :url "https://repo1.maven.org/maven2/com/google/googlejavaformat/google-java-format/1.36.1/google-java-format-1.36.1-all-deps.jar"
       :sha256 "25b400f003089d23cc5320cdaf1a16cabee19b8aa3434d0ff021b3d9f42154b4"
       :file ,(expand-file-name "google-java-format-1.36.1-all-deps.jar" dir)
       :jdk 21                          ; compiled for Java 21
       :size "4MB")
      (ktfmt
       :version "0.64"
       :url "https://repo1.maven.org/maven2/com/facebook/ktfmt/0.64/ktfmt-0.64-with-dependencies.jar"
       :sha256 "5b3d5286fd2defcc7dc8e28c21ddf156cc6b2d8682bdcd929ce4333e7a6201f2"
       :file ,(expand-file-name "ktfmt-0.64-with-dependencies.jar" dir)
       :jdk 17
       :size "71MB")))
  "The pinned formatter jars: (NAME :version :url :sha256 :file :jdk :size).")

;; Here, not in autoload.el: cli.el needs it in `bin/hellmacs sync', which
;; loads no module's autoload.el.
(defun hellmacs-format-jar-spec (name)
  "The pinned jar of formatter NAME: a plist of :version :url :sha256 :file :jdk."
  (cdr (assq name hellmacs-format-jars)))
