;;; lang/kotlin/+paths.el -*- lexical-binding: t; -*-

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


;; Where kotlin-language-server lives, and the release `bin/hell sync'
;; installs. Loaded by config.el at startup, by cli.el in bin/hell and
;; by doctor.el, before lsp-kotlin loads.

;; The cache of decompiled library sources M-. opens.
(setq lsp-kotlin-workspace-dir (expand-file-name "jvm/kotlin-workspace/" hell-data-dir)
      lsp-kotlin-workspace-cache-dir (expand-file-name ".cache/" lsp-kotlin-workspace-dir))

;; The last release of fwcd/kotlin-language-server (January 2025). Pinned
;; by SHA-256, unlike lsp-mode's own "latest" download.
(defconst hell-kotlin-ls-version "1.3.13"
  "kotlin-language-server release `bin/hell sync' installs.")

(defconst hell-kotlin-ls-url
  (format "https://github.com/fwcd/kotlin-language-server/releases/download/%s/server.zip"
          hell-kotlin-ls-version)
  "Where that release's server.zip is downloaded from.")

(defconst hell-kotlin-ls-sha256
  "4fe7d71d087b307c7869036171bd9d8c6a4284cd7c25b89098b0a24eb2d9b6d2"
  "SHA-256 of server.zip for `hell-kotlin-ls-version'.")

(defvar hell-kotlin-ls-dir (expand-file-name "kotlin/" lsp-server-install-dir)
  "Where the server is unpacked; lsp-mode looks in its server/bin/ first.")

(hell-component! :name "kotlin-language-server" :version hell-kotlin-ls-version :license "MIT"
                 :url hell-kotlin-ls-url :sha256 hell-kotlin-ls-sha256
                     :path hell-kotlin-ls-dir)

(defvar hell-kotlin-ls-executable
  (expand-file-name "server/bin/kotlin-language-server" hell-kotlin-ls-dir)
  "The server's launcher script.")

(defvar hell-kotlin-ls-marker
  (expand-file-name ".hell-sha256" hell-kotlin-ls-dir)
  "Records the SHA-256 of the server.zip that was unpacked.")

(defun hell-kotlin-ls-installed-p ()
  "Non-nil if the pinned server is unpacked and its launcher is executable."
  (and (file-executable-p hell-kotlin-ls-executable)
       (hell-marker-current-p hell-kotlin-ls-marker hell-kotlin-ls-sha256)))
