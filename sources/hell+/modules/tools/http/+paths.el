;;; tools/http/+paths.el -*- lexical-binding: t; -*-

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


;; Where httpyac lives (+httpyac), and the release `bin/hell sync'
;; installs: package.json and package-lock.json next to this file pin it
;; and every package it needs, by integrity hash.

(defconst hell-http-httpyac-version "6.16.7"
  "httpyac release this module's lockfile pins.")

(defvar hell-http-httpyac-dir (expand-file-name "httpyac/" hell-data-dir)
  "Where `npm ci' installs it.")

(hell-component! :name "httpyac" :version hell-http-httpyac-version :license "MIT"
                 :npm t :path hell-http-httpyac-dir)

(defvar hell-http-httpyac-executable
  (expand-file-name "node_modules/.bin/httpyac" hell-http-httpyac-dir)
  "httpyac's launcher.")

(defvar hell-http-httpyac-lock-dir (hell-module-get '(:tools . http) :path)
  "This module's directory, which holds the lockfile.")

(defun hell-http-httpyac-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hell-npm-installed-p hell-http-httpyac-lock-dir hell-http-httpyac-dir))
