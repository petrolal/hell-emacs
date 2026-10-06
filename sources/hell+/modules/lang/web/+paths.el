;;; lang/web/+paths.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

;; Where the CSS server lives, and the release `bin/hell sync' installs:
;; package.json and package-lock.json next to this file pin it and every
;; package it needs, by integrity hash.

(defconst hell-web-css-ls-version "4.10.0"
  "vscode-langservers-extracted release this module's lockfile pins.")

(defvar hell-web-css-ls-dir (expand-file-name "web-css/" lsp-server-install-dir)
  "Where `npm ci' installs it.")

(hell-component! :name "vscode-langservers-extracted" :version hell-web-css-ls-version :license "MIT"
                 :npm t :path hell-web-css-ls-dir)

(defvar hell-web-css-ls-executable
  (expand-file-name "node_modules/.bin/vscode-css-language-server" hell-web-css-ls-dir)
  "The server's launcher.")

(defvar hell-web-css-ls-lock-dir (hell-module-get '(:lang . web) :path)
  "This module's directory, which holds the lockfile.")

(defun hell-web-css-ls-installed-p ()
  "Non-nil if the lockfile's packages are installed."
  (hell-npm-installed-p hell-web-css-ls-lock-dir hell-web-css-ls-dir))
