;;; lang/docker/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned docker-language-server.

(hellmacs-module-load "+paths")

(defun hellmacs-docker-sync-install-server ()
  "Install the pinned docker-language-server. For `hellmacs-sync-functions'."
  (cond ((not (hellmacs-docker-ls-pin))
         (hellmacs-sync--log "No pinned docker-language-server for %s"
                             (or (hellmacs-platform) system-type)))
        ((hellmacs-docker-ls-installed-p)
         (hellmacs-sync--log "docker-language-server %s is installed" hellmacs-docker-ls-version))
        (t
         (hellmacs-sync--log "Downloading docker-language-server %s (40MB)..." hellmacs-docker-ls-version)
         (hellmacs-sync-install-binary "docker-language-server" (hellmacs-docker-ls-url)
                                       (hellmacs-docker-ls-pin) hellmacs-docker-ls-executable
                                       (hellmacs-docker-ls--marker))
         (hellmacs-sync--log "docker-language-server %s installed (SHA-256 verified)"
                             hellmacs-docker-ls-version))))

(add-hook 'hellmacs-sync-functions #'hellmacs-docker-sync-install-server)

(defun hellmacs-docker-bundle-paths ()
  "The pinned server. For `hellmacs-bundle-functions'."
  (list (file-name-directory hellmacs-docker-ls-executable)))

(add-hook 'hellmacs-bundle-functions #'hellmacs-docker-bundle-paths)
