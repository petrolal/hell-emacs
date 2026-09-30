;;; tools/http/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: with +httpyac, `sync' also installs the pinned httpyac.

(hellmacs-module-load "+paths")

(defun hellmacs-http-sync-install ()
  "Install the pinned httpyac. For `hellmacs-sync-functions'."
  (if (hellmacs-http-httpyac-installed-p)
      (hellmacs-sync--log "httpyac %s is installed" hellmacs-http-httpyac-version)
    (hellmacs-sync--log "Installing httpyac %s with npm..." hellmacs-http-httpyac-version)
    (hellmacs-sync-npm-install "httpyac" hellmacs-http-httpyac-lock-dir hellmacs-http-httpyac-dir)
    (hellmacs-sync--log "httpyac %s installed (lockfile verified)" hellmacs-http-httpyac-version)))

(defun hellmacs-http-bundle-paths ()
  "The installed httpyac. For `hellmacs-bundle-functions'."
  (list hellmacs-http-httpyac-dir))

(when (modulep! +httpyac)
  (add-hook 'hellmacs-sync-functions #'hellmacs-http-sync-install)
  (add-hook 'hellmacs-bundle-functions #'hellmacs-http-bundle-paths))
