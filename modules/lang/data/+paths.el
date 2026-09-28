;;; lang/data/+paths.el -*- lexical-binding: t; -*-

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


;; Where lemminx lives, and the release `bin/hellmacs sync' installs.
;; Loaded by config.el at startup, by cli.el in bin/hellmacs and by
;; doctor.el, before lsp-xml loads.

;; The uber jar: one file for every platform, run on a JDK (11+), which a
;; JVM developer always has. The same bytes are on the Eclipse Maven
;; repository (org.eclipse.lemminx:org.eclipse.lemminx:0.31.2:uber).
(defconst hellmacs-xml-lemminx-version "0.31.2"
  "lemminx release `bin/hellmacs sync' installs.")

(defconst hellmacs-xml-lemminx-url
  (format "https://download.eclipse.org/lemminx/releases/%s/org.eclipse.lemminx-uber.jar"
          hellmacs-xml-lemminx-version)
  "Where that release's uber jar is downloaded from.")

(defconst hellmacs-xml-lemminx-sha256
  "f4fde164e785c635e5f86361dbf4b993bfe2c5f83fdb52891d058b7dfc9bcfc8"
  "SHA-256 of the uber jar for `hellmacs-xml-lemminx-version'.")

(defvar hellmacs-xml-lemminx-jar
  (expand-file-name (format "xmlls/org.eclipse.lemminx-%s-uber.jar" hellmacs-xml-lemminx-version)
                    lsp-server-install-dir)
  "The pinned jar, named by its version.")

(defun hellmacs-xml-lemminx-installed-p ()
  "Non-nil if the pinned jar is installed (its bytes are checked)."
  (hellmacs-file-pinned-p hellmacs-xml-lemminx-jar hellmacs-xml-lemminx-sha256))

(defun hellmacs-xml-java ()
  "The java lemminx runs on: JAVA_HOME's, else the PATH's."
  (let ((home (getenv "JAVA_HOME")))
    (or (and home (let ((java (expand-file-name "bin/java" home)))
                    (and (file-executable-p java) java)))
        (executable-find "java")
        "java")))
