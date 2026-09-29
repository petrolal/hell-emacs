;;; checkers/static/+paths.el -*- lexical-binding: t; -*-

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

;; +sonarlint: the pinned SonarLint, shared by config.el, cli.el and doctor.el.
;;
;; SonarLint for VS Code 4.6.0: the release lsp-sonarlint is written and
;; tested against (newer ones changed the protocol). The build without a
;; bundled JRE (Hellmacs picks a JDK 17+): the language server and its
;; analyzers, 227 MB. Checked 2026-09-29.

(defvar lsp-server-install-dir)

(defconst hellmacs-static-sonarlint-version "4.6.0"
  "The SonarLint for VS Code release installed.")

(defconst hellmacs-static-sonarlint-url
  "https://github.com/SonarSource/sonarlint-vscode/releases/download/4.6.0%2B76435/sonarlint-vscode-4.6.0.vsix"
  "Where the pinned SonarLint comes from.")

(defconst hellmacs-static-sonarlint-sha256
  "7c7a2cd4719d525511572827ee279cc27def1a1815cd4505d1c4c8444c76ccc7"
  "SHA-256 of `hellmacs-static-sonarlint-url'.")

(defvar hellmacs-static-sonarlint-dir (expand-file-name "sonarlint/" lsp-server-install-dir)
  "Where sync installs SonarLint (lsp-sonarlint's `lsp-sonarlint-download-dir').")

(hellmacs-component! :name "sonarlint-vscode" :version hellmacs-static-sonarlint-version
                     :license "LGPL-3.0-only"
                     :url hellmacs-static-sonarlint-url :sha256 hellmacs-static-sonarlint-sha256
                     :path hellmacs-static-sonarlint-dir)

(defvar hellmacs-static-sonarlint-marker (expand-file-name ".hellmacs-pin" hellmacs-static-sonarlint-dir)
  "Records the SHA-256 SonarLint was installed from.")

(defun hellmacs-static-sonarlint-installed-p ()
  "Non-nil if the pinned SonarLint is installed."
  (and (file-exists-p (expand-file-name "extension/server/sonarlint-ls.jar" hellmacs-static-sonarlint-dir))
       (hellmacs-marker-current-p hellmacs-static-sonarlint-marker hellmacs-static-sonarlint-sha256)))
