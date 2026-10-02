;;; lang/sh/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned bash-language-server.

(hell-module-load "+paths")

(defun hell-sh-sync-install-server ()
  "Install the pinned bash-language-server. For `hell-sync-functions'."
  (if (hell-sh-ls-installed-p)
      (hell-sync--log "bash-language-server %s is installed" hell-sh-ls-version)
    (hell-sync--log "Installing bash-language-server %s with npm..." hell-sh-ls-version)
    (hell-sync-npm-install "bash-language-server" hell-sh-ls-lock-dir hell-sh-ls-dir)
    (hell-sync--log "bash-language-server %s installed (lockfile verified)" hell-sh-ls-version)))

(add-hook 'hell-sync-functions #'hell-sh-sync-install-server)

(defun hell-sh-bundle-paths ()
  "The installed server. For `hell-bundle-functions'."
  (list hell-sh-ls-dir))

(add-hook 'hell-bundle-functions #'hell-sh-bundle-paths)
