;;; lang/markdown/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned marksman.

(hellmacs-module-load "+paths")

(defun hellmacs-markdown-sync-install-server ()
  "Install the pinned marksman. For `hellmacs-sync-functions'."
  (cond ((not (hellmacs-markdown-marksman-pin))
         (hellmacs-sync--log "No pinned marksman for %s; put marksman on the PATH"
                             (or (hellmacs-platform) system-type)))
        ((hellmacs-markdown-marksman-installed-p)
         (hellmacs-sync--log "marksman %s is installed" hellmacs-markdown-marksman-version))
        (t
         (hellmacs-sync--log "Downloading marksman %s (22MB)..." hellmacs-markdown-marksman-version)
         (hellmacs-sync-install-binary "marksman" (hellmacs-markdown-marksman-url)
                                       (hellmacs-markdown-marksman-pin)
                                       hellmacs-markdown-marksman-executable
                                       (hellmacs-markdown-marksman--marker))
         (hellmacs-sync--log "marksman %s installed (SHA-256 verified)" hellmacs-markdown-marksman-version))))

(add-hook 'hellmacs-sync-functions #'hellmacs-markdown-sync-install-server)

(defun hellmacs-markdown-bundle-paths ()
  "The pinned marksman. For `hellmacs-bundle-functions'."
  (list (file-name-directory hellmacs-markdown-marksman-executable)))

(add-hook 'hellmacs-bundle-functions #'hellmacs-markdown-bundle-paths)
