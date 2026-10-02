;;; lang/clojure/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned clojure-lsp, so the
;; first Clojure file doesn't wait for a download, and with +tree-sitter
;; builds the Clojure grammar.

(hell-module-load "+paths")


(defvar hell-clojure-install-server-on-sync t
  "Whether `bin/hell sync' installs clojure-lsp when it's missing.")

(defun hell-clojure-sync-install-server ()
  "Install the pinned clojure-lsp. For `hell-sync-functions'.
Safe to run every sync: it only downloads when the installed binary isn't
the pinned release. A clojure-lsp on your PATH is used in preference, so
nothing is installed if there is one."
  (cond
   ((not hell-clojure-install-server-on-sync))
   ((executable-find "clojure-lsp")
    (hell-sync--log "clojure-lsp: using %s from the PATH"
                        (abbreviate-file-name (executable-find "clojure-lsp"))))
   ((not (hell-clojure-lsp-pin))
    (hell-sync--log "No pinned clojure-lsp for %s; put clojure-lsp on the PATH"
                        (or (hell-clojure-lsp-platform) system-type)))
   ((hell-clojure-lsp-installed-p)
    (hell-sync--log "clojure-lsp %s is installed" hell-clojure-lsp-version))
   (t
    (hell-sync--log "Downloading clojure-lsp %s (%s)..." hell-clojure-lsp-version
                        (hell-clojure-lsp-platform))
    (hell-sync-install-zip
     "clojure-lsp" (hell-clojure-lsp-url) (hell-clojure-lsp-pin)
     hell-clojure-lsp-dir hell-clojure-lsp-marker
     (lambda (stage)
       (let ((binary (expand-file-name "clojure-lsp" stage)))
         (set-file-modes binary #o755)
         (rename-file binary hell-clojure-lsp-executable t))))
    (unless (hell-clojure-lsp-installed-p)
      (error "clojure-lsp was unpacked but %s isn't executable"
             (abbreviate-file-name hell-clojure-lsp-executable)))
    (hell-sync--log "clojure-lsp %s installed (SHA-256 verified)" hell-clojure-lsp-version))))

(add-hook 'hell-sync-functions #'hell-clojure-sync-install-server)

(defun hell-clojure-bundle-paths ()
  "The pinned clojure-lsp, when sync installed it (not with one on the PATH).
For `hell-bundle-functions'."
  (list hell-clojure-lsp-dir))

(add-hook 'hell-bundle-functions #'hell-clojure-bundle-paths)
