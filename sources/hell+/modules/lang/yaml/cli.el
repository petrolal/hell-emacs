;;; lang/yaml/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned yaml-language-server.

(hell-module-load "+paths")

(defun hell-yaml-sync-install-server ()
  "Install the pinned yaml-language-server. For `hell-sync-functions'."
  (if (hell-yaml-ls-installed-p)
      (hell-sync--log "yaml-language-server %s is installed" hell-yaml-ls-version)
    (hell-sync--log "Installing yaml-language-server %s with npm..." hell-yaml-ls-version)
    (hell-sync-npm-install "yaml-language-server" hell-yaml-ls-lock-dir hell-yaml-ls-dir)
    (hell-sync--log "yaml-language-server %s installed (lockfile verified)" hell-yaml-ls-version)))

(add-hook 'hell-sync-functions #'hell-yaml-sync-install-server)

(defun hell-yaml-bundle-paths ()
  "The installed server. For `hell-bundle-functions'."
  (list hell-yaml-ls-dir))

(add-hook 'hell-bundle-functions #'hell-yaml-bundle-paths)
