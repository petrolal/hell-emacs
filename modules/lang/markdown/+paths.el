;;; lang/markdown/+paths.el -*- lexical-binding: t; -*-

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


;; Where marksman lives, and the release `bin/hellmacs sync' installs.
;; Loaded by config.el at startup, by cli.el in bin/hellmacs and by
;; doctor.el, before lsp-marksman loads.

;; One self-contained binary per platform. The sums are the ones GitHub
;; lists for the release's assets; macOS has one universal binary.
(defconst hellmacs-markdown-marksman-version "2026-02-08"
  "marksman release `bin/hellmacs sync' installs.")

(defconst hellmacs-markdown-marksman-pins
  '(("linux-x86_64"   "marksman-linux-x64"   "be5098e8213219269c47fc0d916a66fa31ce0602ec967475c722260aabf26087")
    ("linux-aarch64"  "marksman-linux-arm64" "db8e124527f7f8048e3e6c91821b9c52ef173d92c01e47d221bf1337afd962fb")
    ("darwin-x86_64"  "marksman-macos"       "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b")
    ("darwin-aarch64" "marksman-macos"       "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b")
    ("windows-x86_64" "marksman.exe"         "a6d05beb08ebe41b0a9f09c98a438540421436fa5531424c22e0bb1d22529705"))
  "(PLATFORM ASSET SHA-256) for each platform the release has a binary for.")

(defun hellmacs-markdown-marksman-pin ()
  "The pinned SHA-256 for this platform, or nil if there is none."
  (nth 2 (assoc (hellmacs-platform) hellmacs-markdown-marksman-pins)))

(defun hellmacs-markdown-marksman-url ()
  "Where this platform's pinned binary is downloaded from."
  (format "https://github.com/artempyanykh/marksman/releases/download/%s/%s"
          hellmacs-markdown-marksman-version
          (nth 1 (assoc (hellmacs-platform) hellmacs-markdown-marksman-pins))))

(defvar hellmacs-markdown-marksman-executable
  (expand-file-name (if (eq system-type 'windows-nt) "marksman/marksman.exe" "marksman/marksman")
                    lsp-server-install-dir)
  "The pinned marksman binary.")

(defun hellmacs-markdown-marksman--marker ()
  (expand-file-name ".hellmacs-sha256" (file-name-directory hellmacs-markdown-marksman-executable)))

(defun hellmacs-markdown-marksman-installed-p ()
  "Non-nil if the pinned binary for this platform is installed and executable."
  (when-let* ((pin (hellmacs-markdown-marksman-pin)))
    (and (file-executable-p hellmacs-markdown-marksman-executable)
         (hellmacs-marker-current-p (hellmacs-markdown-marksman--marker) pin))))
