;;; checkers/static/cli.el -*- lexical-binding: t; -*-

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

;; Extends bin/hellmacs: with +sonarlint, `sync' installs the pinned
;; SonarLint, so no file waits for (or triggers) a 227 MB download.

(hellmacs-module-load "+paths")

(defun hellmacs-static-sync-install-sonarlint ()
  "Install the pinned SonarLint, unless it is. For `hellmacs-sync-functions'.
Only what lsp-sonarlint runs is kept: the language server and the analyzers."
  (if (hellmacs-static-sonarlint-installed-p)
      (hellmacs-sync--log "SonarLint %s is installed" hellmacs-static-sonarlint-version)
    (hellmacs-sync--log "Downloading SonarLint %s (227 MB)..." hellmacs-static-sonarlint-version)
    (make-directory hellmacs-static-sonarlint-dir t)
    (hellmacs-sync-install-zip
     "SonarLint" hellmacs-static-sonarlint-url hellmacs-static-sonarlint-sha256
     hellmacs-static-sonarlint-dir hellmacs-static-sonarlint-marker
     (lambda (stage)
       (let ((extension (expand-file-name "extension/" hellmacs-static-sonarlint-dir)))
         (when (file-exists-p extension) (delete-directory extension t))
         (make-directory extension t)
         (dolist (part '("server" "analyzers"))
           (rename-file (expand-file-name (concat "extension/" part) stage)
                        (expand-file-name part extension))))))
    (hellmacs-sync--log "SonarLint %s installed (SHA-256 verified)" hellmacs-static-sonarlint-version)))

(defun hellmacs-static-bundle-paths ()
  "The pinned SonarLint, for `hellmacs-bundle-functions'."
  (list hellmacs-static-sonarlint-dir))

(when (modulep! +sonarlint)
  (add-hook 'hellmacs-sync-functions #'hellmacs-static-sync-install-sonarlint)
  (add-hook 'hellmacs-bundle-functions #'hellmacs-static-bundle-paths))
