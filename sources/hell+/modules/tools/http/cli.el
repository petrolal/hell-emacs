;;; tools/http/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: with +httpyac, `sync' also installs the pinned httpyac.

(hell-module-load "+paths")

(defun hell-http-sync-install ()
  "Install the pinned httpyac. For `hell-sync-functions'."
  (if (hell-http-httpyac-installed-p)
      (hell-sync--log "httpyac %s is installed" hell-http-httpyac-version)
    (hell-sync--log "Installing httpyac %s with npm..." hell-http-httpyac-version)
    (hell-sync-npm-install "httpyac" hell-http-httpyac-lock-dir hell-http-httpyac-dir)
    (hell-sync--log "httpyac %s installed (lockfile verified)" hell-http-httpyac-version)))

(defun hell-http-bundle-paths ()
  "The installed httpyac. For `hell-bundle-functions'."
  (list hell-http-httpyac-dir))

(when (modulep! +httpyac)
  (add-hook 'hell-sync-functions #'hell-http-sync-install)
  (add-hook 'hell-bundle-functions #'hell-http-bundle-paths))
