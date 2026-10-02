;;; lang/json/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the pinned JSON server.

(hell-module-load "+paths")

(defun hell-json-sync-install-server ()
  "Install the pinned vscode-json-language-server. For `hell-sync-functions'."
  (if (hell-json-ls-installed-p)
      (hell-sync--log "vscode-json-language-server %s is installed" hell-json-ls-version)
    (hell-sync--log "Installing vscode-json-language-server %s with npm..." hell-json-ls-version)
    (hell-sync-npm-install "vscode-json-language-server" hell-json-ls-lock-dir hell-json-ls-dir)
    (hell-sync--log "vscode-json-language-server %s installed (lockfile verified)" hell-json-ls-version)))

(add-hook 'hell-sync-functions #'hell-json-sync-install-server)

(defun hell-json-bundle-paths ()
  "The installed server. For `hell-bundle-functions'."
  (list hell-json-ls-dir))

(add-hook 'hell-bundle-functions #'hell-json-bundle-paths)
