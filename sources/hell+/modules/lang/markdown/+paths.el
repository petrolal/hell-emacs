;;; lang/markdown/+paths.el -*- lexical-binding: t; -*-

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


;; Where marksman lives, and the release `bin/hell sync' installs.
;; Loaded by config.el at startup, by cli.el in bin/hell and by
;; doctor.el, before lsp-marksman loads.

;; One self-contained binary per platform. The sums are the ones GitHub
;; lists for the release's assets; macOS has one universal binary.
(defconst hell-markdown-marksman-version "2026-02-08"
  "marksman release `bin/hell sync' installs.")

(defconst hell-markdown-marksman-pins
  '(("linux-x86_64"   "marksman-linux-x64"   "be5098e8213219269c47fc0d916a66fa31ce0602ec967475c722260aabf26087")
    ("linux-aarch64"  "marksman-linux-arm64" "db8e124527f7f8048e3e6c91821b9c52ef173d92c01e47d221bf1337afd962fb")
    ("darwin-x86_64"  "marksman-macos"       "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b")
    ("darwin-aarch64" "marksman-macos"       "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b")
    ("windows-x86_64" "marksman.exe"         "a6d05beb08ebe41b0a9f09c98a438540421436fa5531424c22e0bb1d22529705"))
  "(PLATFORM ASSET SHA-256) for each platform the release has a binary for.")

(defun hell-markdown-marksman-pin ()
  "The pinned SHA-256 for this platform, or nil if there is none."
  (nth 2 (assoc (hell-platform) hell-markdown-marksman-pins)))

(defun hell-markdown-marksman-url ()
  "Where this platform's pinned binary is downloaded from."
  (format "https://github.com/artempyanykh/marksman/releases/download/%s/%s"
          hell-markdown-marksman-version
          (nth 1 (assoc (hell-platform) hell-markdown-marksman-pins))))

(defvar hell-markdown-marksman-executable
  (expand-file-name (if (eq system-type 'windows-nt) "marksman/marksman.exe" "marksman/marksman")
                    lsp-server-install-dir)
  "The pinned marksman binary.")

(hell-component! :name "marksman" :version hell-markdown-marksman-version :license "MIT"
                 :url (hell-markdown-marksman-url) :sha256 (hell-markdown-marksman-pin)
                     :sha256s (mapcar (lambda (pin) (nth 2 pin)) hell-markdown-marksman-pins)
                     :path hell-markdown-marksman-executable)

(defun hell-markdown-marksman--marker ()
  (expand-file-name ".hell-sha256" (file-name-directory hell-markdown-marksman-executable)))

(defun hell-markdown-marksman-installed-p ()
  "Non-nil if the pinned binary for this platform is installed and executable."
  (when-let* ((pin (hell-markdown-marksman-pin)))
    (and (file-executable-p hell-markdown-marksman-executable)
         (hell-marker-current-p (hell-markdown-marksman--marker) pin))))
