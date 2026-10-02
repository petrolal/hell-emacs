;;; lang/kotlin/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned
;; kotlin-language-server, so the first Kotlin file doesn't wait for a
;; download, and with +tree-sitter builds the Kotlin grammar.

(hell-module-load "+paths")


(defvar hell-kotlin-install-server-on-sync t
  "Whether `bin/hell sync' installs kotlin-language-server when it's missing.")

(defun hell-kotlin-sync-install-server ()
  "Install the pinned kotlin-language-server. For `hell-sync-functions'.
Safe to run every sync: it only downloads when the unpacked server isn't
the pinned release (also after lsp-mode installed a different one)."
  (when hell-kotlin-install-server-on-sync
    (if (hell-kotlin-ls-installed-p)
        (hell-sync--log "kotlin-language-server %s is installed" hell-kotlin-ls-version)
      (hell-sync--log "Downloading kotlin-language-server %s (87MB)..." hell-kotlin-ls-version)
      (hell-sync-install-zip
       "kotlin-language-server" hell-kotlin-ls-url hell-kotlin-ls-sha256
       hell-kotlin-ls-dir hell-kotlin-ls-marker
       (lambda (stage)
         ;; Replace the old server only once the new one is unpacked.
         (let ((server (expand-file-name "server" hell-kotlin-ls-dir)))
           (when (file-directory-p server) (delete-directory server t))
           (rename-file (expand-file-name "server" stage) server))))
      (unless (hell-kotlin-ls-installed-p)
        (error "kotlin-language-server was unpacked but %s isn't executable"
               (abbreviate-file-name hell-kotlin-ls-executable)))
      (hell-sync--log "kotlin-language-server %s installed (SHA-256 verified)"
                          hell-kotlin-ls-version))))

(add-hook 'hell-sync-functions #'hell-kotlin-sync-install-server)

(defun hell-kotlin-bundle-paths ()
  "The pinned kotlin-language-server. For `hell-bundle-functions'."
  (list hell-kotlin-ls-dir))

(add-hook 'hell-bundle-functions #'hell-kotlin-bundle-paths)
