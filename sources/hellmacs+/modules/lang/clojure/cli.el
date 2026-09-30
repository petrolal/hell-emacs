;;; lang/clojure/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned clojure-lsp, so the
;; first Clojure file doesn't wait for a download, and with +tree-sitter
;; builds the Clojure grammar.

(hellmacs-module-load "+paths")


(defvar hellmacs-clojure-install-server-on-sync t
  "Whether `bin/hellmacs sync' installs clojure-lsp when it's missing.")

(defun hellmacs-clojure-sync-install-server ()
  "Install the pinned clojure-lsp. For `hellmacs-sync-functions'.
Safe to run every sync: it only downloads when the installed binary isn't
the pinned release. A clojure-lsp on your PATH is used in preference, so
nothing is installed if there is one."
  (cond
   ((not hellmacs-clojure-install-server-on-sync))
   ((executable-find "clojure-lsp")
    (hellmacs-sync--log "clojure-lsp: using %s from the PATH"
                        (abbreviate-file-name (executable-find "clojure-lsp"))))
   ((not (hellmacs-clojure-lsp-pin))
    (hellmacs-sync--log "No pinned clojure-lsp for %s; put clojure-lsp on the PATH"
                        (or (hellmacs-clojure-lsp-platform) system-type)))
   ((hellmacs-clojure-lsp-installed-p)
    (hellmacs-sync--log "clojure-lsp %s is installed" hellmacs-clojure-lsp-version))
   (t
    (hellmacs-sync--log "Downloading clojure-lsp %s (%s)..." hellmacs-clojure-lsp-version
                        (hellmacs-clojure-lsp-platform))
    (hellmacs-sync-install-zip
     "clojure-lsp" (hellmacs-clojure-lsp-url) (hellmacs-clojure-lsp-pin)
     hellmacs-clojure-lsp-dir hellmacs-clojure-lsp-marker
     (lambda (stage)
       (let ((binary (expand-file-name "clojure-lsp" stage)))
         (set-file-modes binary #o755)
         (rename-file binary hellmacs-clojure-lsp-executable t))))
    (unless (hellmacs-clojure-lsp-installed-p)
      (error "clojure-lsp was unpacked but %s isn't executable"
             (abbreviate-file-name hellmacs-clojure-lsp-executable)))
    (hellmacs-sync--log "clojure-lsp %s installed (SHA-256 verified)" hellmacs-clojure-lsp-version))))

(add-hook 'hellmacs-sync-functions #'hellmacs-clojure-sync-install-server)

(defun hellmacs-clojure-bundle-paths ()
  "The pinned clojure-lsp, when sync installed it (not with one on the PATH).
For `hellmacs-bundle-functions'."
  (list hellmacs-clojure-lsp-dir))

(add-hook 'hellmacs-bundle-functions #'hellmacs-clojure-bundle-paths)
