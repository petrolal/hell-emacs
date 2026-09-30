;;; lang/docker/+paths.el -*- lexical-binding: t; -*-

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


;; Where docker-language-server lives, and the release `bin/hellmacs sync'
;; installs. Loaded by config.el at startup, by cli.el in bin/hellmacs and
;; by doctor.el.

;; One self-contained binary per platform (it's written in Go). The sums
;; are the ones GitHub lists for the release's assets.
(defconst hellmacs-docker-ls-version "0.20.1"
  "docker-language-server release `bin/hellmacs sync' installs.")

(defconst hellmacs-docker-ls-pins
  '(("linux-x86_64"    "linux-amd64"         "01907aa5b0eae11e44cffea0a993d08aa155542a9af570295dd1dff39e67692a")
    ("linux-aarch64"   "linux-arm64"         "bd56c7815e0a22cfb708669f3d5e817de91d9b54039ff7e52867142a132ad8d7")
    ("darwin-x86_64"   "darwin-amd64"        "2dbaec15645e940d1e02092f5b5e10148531a6206225e71faab7bfe71130b457")
    ("darwin-aarch64"  "darwin-arm64"        "5a9d48fd2b1334d7d20a62faf542e611cca32dc79a478553ad65c27437467fac")
    ("windows-x86_64"  "windows-amd64"       "3c1e5019cbd9779341d39c94589d058434ef295b3a1a0c0e89bdfb7ae4d59e2e")
    ("windows-aarch64" "windows-arm64"       "ac1c1190deb7b605829a11702222eb5fe8a68968c287c8af34615f4f92c0712d"))
  "(PLATFORM ASSET SHA-256) for each platform; ASSET is the release's name for it.")

(defun hellmacs-docker-ls-pin ()
  "The pinned SHA-256 for this platform, or nil if there is none."
  (nth 2 (assoc (hellmacs-platform) hellmacs-docker-ls-pins)))

(defun hellmacs-docker-ls-url ()
  "Where this platform's pinned binary is downloaded from."
  (format "https://github.com/docker/docker-language-server/releases/download/v%s/docker-language-server-%s-v%s%s"
          hellmacs-docker-ls-version
          (nth 1 (assoc (hellmacs-platform) hellmacs-docker-ls-pins))
          hellmacs-docker-ls-version
          (if (eq system-type 'windows-nt) ".exe" "")))

(defvar hellmacs-docker-ls-executable
  (expand-file-name (if (eq system-type 'windows-nt)
                        "docker/docker-language-server.exe"
                      "docker/docker-language-server")
                    lsp-server-install-dir)
  "The pinned binary.")

(hellmacs-component! :name "docker-language-server" :version hellmacs-docker-ls-version
                     :license "Apache-2.0"
                     :url (hellmacs-docker-ls-url) :sha256 (hellmacs-docker-ls-pin)
                     :sha256s (mapcar (lambda (pin) (nth 2 pin)) hellmacs-docker-ls-pins)
                     :path hellmacs-docker-ls-executable)

(defun hellmacs-docker-ls--marker ()
  (expand-file-name ".hellmacs-sha256" (file-name-directory hellmacs-docker-ls-executable)))

(defun hellmacs-docker-ls-installed-p ()
  "Non-nil if the pinned binary for this platform is installed and executable."
  (when-let* ((pin (hellmacs-docker-ls-pin)))
    (and (file-executable-p hellmacs-docker-ls-executable)
         (hellmacs-marker-current-p (hellmacs-docker-ls--marker) pin))))
