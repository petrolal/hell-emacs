;;; lang/sh/+paths.el -*- lexical-binding: t; -*-

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


;; Where bash-language-server lives, and the release `bin/hell sync'
;; installs: package.json and package-lock.json next to this file pin it
;; and every package it needs, by integrity hash.

(defconst hell-sh-ls-version "5.8.1"
  "bash-language-server release this module's lockfile pins.")

(defvar hell-sh-ls-dir (expand-file-name "bash/" lsp-server-install-dir)
  "Where `npm ci' installs it.")

(hell-component! :name "bash-language-server" :version hell-sh-ls-version :license "MIT"
                 :npm t :path hell-sh-ls-dir)

(defvar hell-sh-ls-executable
  (expand-file-name "node_modules/.bin/bash-language-server" hell-sh-ls-dir)
  "The server's launcher.")

(defvar hell-sh-ls-lock-dir (hell-module-get '(:lang . sh) :path)
  "This module's directory, which holds the lockfile.")

(defun hell-sh-ls-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hell-npm-installed-p hell-sh-ls-lock-dir hell-sh-ls-dir))
