;;; lang/kotlin/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned
;; kotlin-language-server, so the first Kotlin file doesn't wait for a
;; download, and with +tree-sitter builds the Kotlin grammar.

(hellmacs-module-load "+paths")


(defvar hellmacs-kotlin-install-server-on-sync t
  "Whether `bin/hellmacs sync' installs kotlin-language-server when it's missing.")

(defun hellmacs-kotlin-sync-install-server ()
  "Install the pinned kotlin-language-server. For `hellmacs-sync-functions'.
Safe to run every sync: it only downloads when the unpacked server isn't
the pinned release (also after lsp-mode installed a different one)."
  (when hellmacs-kotlin-install-server-on-sync
    (if (hellmacs-kotlin-ls-installed-p)
        (hellmacs-sync--log "kotlin-language-server %s is installed" hellmacs-kotlin-ls-version)
      (hellmacs-sync--log "Downloading kotlin-language-server %s (87MB)..." hellmacs-kotlin-ls-version)
      (hellmacs-sync-install-zip
       "kotlin-language-server" hellmacs-kotlin-ls-url hellmacs-kotlin-ls-sha256
       hellmacs-kotlin-ls-dir hellmacs-kotlin-ls-marker
       (lambda (stage)
         ;; Replace the old server only once the new one is unpacked.
         (let ((server (expand-file-name "server" hellmacs-kotlin-ls-dir)))
           (when (file-directory-p server) (delete-directory server t))
           (rename-file (expand-file-name "server" stage) server))))
      (unless (hellmacs-kotlin-ls-installed-p)
        (error "kotlin-language-server was unpacked but %s isn't executable"
               (abbreviate-file-name hellmacs-kotlin-ls-executable)))
      (hellmacs-sync--log "kotlin-language-server %s installed (SHA-256 verified)"
                          hellmacs-kotlin-ls-version))))

(add-hook 'hellmacs-sync-functions #'hellmacs-kotlin-sync-install-server)

(defun hellmacs-kotlin-bundle-paths ()
  "The pinned kotlin-language-server. For `hellmacs-bundle-functions'."
  (list hellmacs-kotlin-ls-dir))

(add-hook 'hellmacs-bundle-functions #'hellmacs-kotlin-bundle-paths)
