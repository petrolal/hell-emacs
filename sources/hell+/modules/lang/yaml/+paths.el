;;; lang/yaml/+paths.el -*- lexical-binding: t; -*-

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


;; Where yaml-language-server lives, and the release `bin/hell sync'
;; installs: package.json and package-lock.json next to this file pin it
;; and every package it needs, by integrity hash.

(defconst hell-yaml-ls-version "1.24.0"
  "yaml-language-server release this module's lockfile pins.")

(defvar hell-yaml-ls-dir (expand-file-name "yaml/" lsp-server-install-dir)
  "Where `npm ci' installs it.")

(hell-component! :name "yaml-language-server" :version hell-yaml-ls-version :license "MIT"
                 :npm t :path hell-yaml-ls-dir)

(defvar hell-yaml-ls-executable
  (expand-file-name "node_modules/.bin/yaml-language-server" hell-yaml-ls-dir)
  "The server's launcher.")

(defvar hell-yaml-ls-lock-dir (hell-module-get '(:lang . yaml) :path)
  "This module's directory, which holds the lockfile.")

(defun hell-yaml-ls-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hell-npm-installed-p hell-yaml-ls-lock-dir hell-yaml-ls-dir))
