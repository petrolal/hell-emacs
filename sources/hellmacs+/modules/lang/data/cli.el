;;; lang/data/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned lemminx jar, so
;; the first XML file doesn't wait for a download.

(hellmacs-module-load "+paths")

(defun hellmacs-xml-sync-install-server ()
  "Install the pinned lemminx jar. For `hellmacs-sync-functions'."
  (if (hellmacs-xml-lemminx-installed-p)
      (hellmacs-sync--log "lemminx %s is installed" hellmacs-xml-lemminx-version)
    (hellmacs-sync--log "Downloading lemminx %s (9MB)..." hellmacs-xml-lemminx-version)
    (hellmacs-sync-download-verified hellmacs-xml-lemminx-url hellmacs-xml-lemminx-jar
                                     hellmacs-xml-lemminx-sha256 "lemminx")
    (hellmacs-sync--log "lemminx %s installed (SHA-256 verified)" hellmacs-xml-lemminx-version)))

(add-hook 'hellmacs-sync-functions #'hellmacs-xml-sync-install-server)

(defun hellmacs-xml-bundle-paths ()
  "The pinned lemminx jar. For `hellmacs-bundle-functions'."
  (list hellmacs-xml-lemminx-jar))

(add-hook 'hellmacs-bundle-functions #'hellmacs-xml-bundle-paths)
