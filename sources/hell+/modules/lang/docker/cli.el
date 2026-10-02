;;; lang/docker/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned docker-language-server.

(hell-module-load "+paths")

(defun hell-docker-sync-install-server ()
  "Install the pinned docker-language-server. For `hell-sync-functions'."
  (cond ((not (hell-docker-ls-pin))
         (hell-sync--log "No pinned docker-language-server for %s"
                             (or (hell-platform) system-type)))
        ((hell-docker-ls-installed-p)
         (hell-sync--log "docker-language-server %s is installed" hell-docker-ls-version))
        (t
         (hell-sync--log "Downloading docker-language-server %s (40MB)..." hell-docker-ls-version)
         (hell-sync-install-binary "docker-language-server" (hell-docker-ls-url)
                                       (hell-docker-ls-pin) hell-docker-ls-executable
                                       (hell-docker-ls--marker))
         (hell-sync--log "docker-language-server %s installed (SHA-256 verified)"
                             hell-docker-ls-version))))

(add-hook 'hell-sync-functions #'hell-docker-sync-install-server)

(defun hell-docker-bundle-paths ()
  "The pinned server. For `hell-bundle-functions'."
  (list (file-name-directory hell-docker-ls-executable)))

(add-hook 'hell-bundle-functions #'hell-docker-bundle-paths)
