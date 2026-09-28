;;; lang/json/+paths.el -*- lexical-binding: t; -*-

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


;; Where the JSON server lives, and the release `bin/hellmacs sync'
;; installs: package.json and package-lock.json next to this file pin it
;; and every package it needs, by integrity hash.

(defconst hellmacs-json-ls-version "4.10.0"
  "vscode-langservers-extracted release this module's lockfile pins.")

(defvar hellmacs-json-ls-dir (expand-file-name "json/" lsp-server-install-dir)
  "Where `npm ci' installs it.")

(defvar hellmacs-json-ls-executable
  (expand-file-name "node_modules/.bin/vscode-json-language-server" hellmacs-json-ls-dir)
  "The server's launcher.")

(defvar hellmacs-json-ls-lock-dir (hellmacs-module-get '(:lang . json) :path)
  "This module's directory, which holds the lockfile.")

(defun hellmacs-json-ls-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hellmacs-npm-installed-p hellmacs-json-ls-lock-dir hellmacs-json-ls-dir))
