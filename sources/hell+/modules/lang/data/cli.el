;;; lang/data/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned lemminx jar, so
;; the first XML file doesn't wait for a download.

(hell-module-load "+paths")

(defun hell-xml-sync-install-server ()
  "Install the pinned lemminx jar. For `hell-sync-functions'."
  (if (hell-xml-lemminx-installed-p)
      (hell-sync--log "lemminx %s is installed" hell-xml-lemminx-version)
    (hell-sync--log "Downloading lemminx %s (9MB)..." hell-xml-lemminx-version)
    (hell-sync-download-verified hell-xml-lemminx-url hell-xml-lemminx-jar
                                     hell-xml-lemminx-sha256 "lemminx")
    (hell-sync--log "lemminx %s installed (SHA-256 verified)" hell-xml-lemminx-version)))

(add-hook 'hell-sync-functions #'hell-xml-sync-install-server)

(defun hell-xml-bundle-paths ()
  "The pinned lemminx jar. For `hell-bundle-functions'."
  (list hell-xml-lemminx-jar))

(add-hook 'hell-bundle-functions #'hell-xml-bundle-paths)
