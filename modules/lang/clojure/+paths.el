;;; lang/clojure/+paths.el -*- lexical-binding: t; -*-

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


;; Where clojure-lsp lives, and the release `bin/hellmacs sync' installs.
;; Loaded by config.el at startup, by cli.el in bin/hellmacs and by
;; doctor.el, before lsp-clojure loads.

;; clojure-lsp's caches (decompiled and extracted library sources).
(setq lsp-clojure-workspace-dir (expand-file-name "jvm/clojure-workspace/" hellmacs-data-dir)
      lsp-clojure-workspace-cache-dir (expand-file-name ".cache/" lsp-clojure-workspace-dir)
      lsp-clojure-library-dirs (list lsp-clojure-workspace-cache-dir
                                     (expand-file-name "~/.gitlibs/libs")))

;; A native binary, one download per platform, pinned by SHA-256. The
;; Linux x86-64, Linux arm64 and macOS x86-64 sums are the ones the release
;; publishes (Linux x86-64 was also checked against a real download and the
;; binary run); the release publishes none for macOS arm64, whose sum comes
;; from one download. Only Linux x86-64 has been run on this project.
(defconst hellmacs-clojure-lsp-version "2026.07.06-14.34.19"
  "clojure-lsp release `bin/hellmacs sync' installs.")

(defconst hellmacs-clojure-lsp-sha256
  '(("linux-amd64"   . "520f724ee02f4b3ecb225395a7a5a4ccad3878d6d1418240cd9636afcf9b858e")
    ("linux-aarch64" . "0595e65a5934d3208246f529b5cf0497d7167d7e9b8317e9b391e05b5c0906d7")
    ("macos-amd64"   . "0449f7f8fc975157cb4e5cdcf365bcd43bcf1fa47b99256427e7a86e4c17fc3f")
    ("macos-aarch64" . "dd9a8e36add53b8d8166bb3d7580c6e5563401aea87b62600786af2e7d37ccde"))
  "SHA-256 of clojure-lsp-native-PLATFORM.zip, by platform, for that release.")

(defun hellmacs-clojure-lsp-platform ()
  "This machine's clojure-lsp release platform (\"linux-amd64\"...), or nil."
  (when-let* ((os (pcase system-type ('gnu/linux "linux-") ('darwin "macos-"))))
    (let ((arch (car (split-string system-configuration "-"))))
      (concat os (if (string= arch "x86_64") "amd64" arch)))))

(defun hellmacs-clojure-lsp-pin ()
  "The pinned SHA-256 for this platform, or nil if there is none."
  (cdr (assoc (hellmacs-clojure-lsp-platform) hellmacs-clojure-lsp-sha256)))

(defun hellmacs-clojure-lsp-url ()
  "Where this platform's pinned zip is downloaded from."
  (format "https://github.com/clojure-lsp/clojure-lsp/releases/download/%s/clojure-lsp-native-%s.zip"
          hellmacs-clojure-lsp-version (hellmacs-clojure-lsp-platform)))

(defvar hellmacs-clojure-lsp-dir (expand-file-name "clojure/" lsp-server-install-dir)
  "Where the binary lives (lsp-mode's own store path is here).")

(defvar hellmacs-clojure-lsp-executable (expand-file-name "clojure-lsp" hellmacs-clojure-lsp-dir)
  "The pinned clojure-lsp binary.")

(hellmacs-component! :name "clojure-lsp" :version hellmacs-clojure-lsp-version :license "MIT"
                     :url (hellmacs-clojure-lsp-url) :sha256 (hellmacs-clojure-lsp-pin)
                     :sha256s (mapcar #'cdr hellmacs-clojure-lsp-sha256)
                     :path hellmacs-clojure-lsp-executable)

(defvar hellmacs-clojure-lsp-marker (expand-file-name ".hellmacs-sha256" hellmacs-clojure-lsp-dir)
  "Records the SHA-256 of the zip whose binary is installed.")

(defun hellmacs-clojure-lsp-installed-p ()
  "Non-nil if the pinned binary for this platform is installed and executable."
  (when-let* ((pin (hellmacs-clojure-lsp-pin)))
    (and (file-executable-p hellmacs-clojure-lsp-executable)
         (hellmacs-marker-current-p hellmacs-clojure-lsp-marker pin))))
