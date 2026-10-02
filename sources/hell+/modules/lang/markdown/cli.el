;;; lang/markdown/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned marksman.

(hell-module-load "+paths")

(defun hell-markdown-sync-install-server ()
  "Install the pinned marksman. For `hell-sync-functions'."
  (cond ((not (hell-markdown-marksman-pin))
         (hell-sync--log "No pinned marksman for %s; put marksman on the PATH"
                             (or (hell-platform) system-type)))
        ((hell-markdown-marksman-installed-p)
         (hell-sync--log "marksman %s is installed" hell-markdown-marksman-version))
        (t
         (hell-sync--log "Downloading marksman %s (22MB)..." hell-markdown-marksman-version)
         (hell-sync-install-binary "marksman" (hell-markdown-marksman-url)
                                       (hell-markdown-marksman-pin)
                                       hell-markdown-marksman-executable
                                       (hell-markdown-marksman--marker))
         (hell-sync--log "marksman %s installed (SHA-256 verified)" hell-markdown-marksman-version))))

(add-hook 'hell-sync-functions #'hell-markdown-sync-install-server)

(defun hell-markdown-bundle-paths ()
  "The pinned marksman. For `hell-bundle-functions'."
  (list (file-name-directory hell-markdown-marksman-executable)))

(add-hook 'hell-bundle-functions #'hell-markdown-bundle-paths)
