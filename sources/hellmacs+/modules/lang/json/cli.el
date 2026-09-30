;;; lang/json/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the pinned JSON server.

(hellmacs-module-load "+paths")

(defun hellmacs-json-sync-install-server ()
  "Install the pinned vscode-json-language-server. For `hellmacs-sync-functions'."
  (if (hellmacs-json-ls-installed-p)
      (hellmacs-sync--log "vscode-json-language-server %s is installed" hellmacs-json-ls-version)
    (hellmacs-sync--log "Installing vscode-json-language-server %s with npm..." hellmacs-json-ls-version)
    (hellmacs-sync-npm-install "vscode-json-language-server" hellmacs-json-ls-lock-dir hellmacs-json-ls-dir)
    (hellmacs-sync--log "vscode-json-language-server %s installed (lockfile verified)" hellmacs-json-ls-version)))

(add-hook 'hellmacs-sync-functions #'hellmacs-json-sync-install-server)

(defun hellmacs-json-bundle-paths ()
  "The installed server. For `hellmacs-bundle-functions'."
  (list hellmacs-json-ls-dir))

(add-hook 'hellmacs-bundle-functions #'hellmacs-json-bundle-paths)
