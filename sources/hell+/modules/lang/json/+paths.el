;;; lang/json/+paths.el -*- lexical-binding: t; -*-

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


;; Where the JSON server lives, and the release `bin/hell sync'
;; installs: package.json and package-lock.json next to this file pin it
;; and every package it needs, by integrity hash.

(defconst hell-json-ls-version "4.10.0"
  "vscode-langservers-extracted release this module's lockfile pins.")

(defvar hell-json-ls-dir (expand-file-name "json/" lsp-server-install-dir)
  "Where `npm ci' installs it.")

(hell-component! :name "vscode-langservers-extracted" :version hell-json-ls-version :license "MIT"
                 :npm t :path hell-json-ls-dir)

(defvar hell-json-ls-executable
  (expand-file-name "node_modules/.bin/vscode-json-language-server" hell-json-ls-dir)
  "The server's launcher.")

(defvar hell-json-ls-lock-dir (hell-module-get '(:lang . json) :path)
  "This module's directory, which holds the lockfile.")

(defun hell-json-ls-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hell-npm-installed-p hell-json-ls-lock-dir hell-json-ls-dir))
