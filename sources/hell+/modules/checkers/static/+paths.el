;;; checkers/static/+paths.el -*- lexical-binding: t; -*-

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

;; +sonarlint: the pinned SonarLint, shared by config.el, cli.el and doctor.el.
;;
;; SonarLint for VS Code 4.6.0: the release lsp-sonarlint is written and
;; tested against (newer ones changed the protocol). The build without a
;; bundled JRE (Hell Emacs picks a JDK 17+): the language server and its
;; analyzers, 227 MB. Checked 2026-09-29.

(defvar lsp-server-install-dir)

(defconst hell-static-sonarlint-version "4.6.0"
  "The SonarLint for VS Code release installed.")

(defconst hell-static-sonarlint-url
  "https://github.com/SonarSource/sonarlint-vscode/releases/download/4.6.0%2B76435/sonarlint-vscode-4.6.0.vsix"
  "Where the pinned SonarLint comes from.")

(defconst hell-static-sonarlint-sha256
  "7c7a2cd4719d525511572827ee279cc27def1a1815cd4505d1c4c8444c76ccc7"
  "SHA-256 of `hell-static-sonarlint-url'.")

(defvar hell-static-sonarlint-dir (expand-file-name "sonarlint/" lsp-server-install-dir)
  "Where sync installs SonarLint (lsp-sonarlint's `lsp-sonarlint-download-dir').")

(hell-component! :name "sonarlint-vscode" :version hell-static-sonarlint-version
                 :license "LGPL-3.0-only"
                     :url hell-static-sonarlint-url :sha256 hell-static-sonarlint-sha256
                     :path hell-static-sonarlint-dir)

(defvar hell-static-sonarlint-marker (expand-file-name ".hell-pin" hell-static-sonarlint-dir)
  "Records the SHA-256 SonarLint was installed from.")

(defun hell-static-sonarlint-installed-p ()
  "Non-nil if the pinned SonarLint is installed."
  (and (file-exists-p (expand-file-name "extension/server/sonarlint-ls.jar" hell-static-sonarlint-dir))
       (hell-marker-current-p hell-static-sonarlint-marker hell-static-sonarlint-sha256)))
