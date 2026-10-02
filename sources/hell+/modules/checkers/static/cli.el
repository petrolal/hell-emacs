;;; checkers/static/cli.el -*- lexical-binding: t; -*-

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

;; Extends bin/hell: with +sonarlint, `sync' installs the pinned
;; SonarLint, so no file waits for (or triggers) a 227 MB download.

(hell-module-load "+paths")

(defun hell-static-sync-install-sonarlint ()
  "Install the pinned SonarLint, unless it is. For `hell-sync-functions'.
Only what lsp-sonarlint runs is kept: the language server and the analyzers."
  (if (hell-static-sonarlint-installed-p)
      (hell-sync--log "SonarLint %s is installed" hell-static-sonarlint-version)
    (hell-sync--log "Downloading SonarLint %s (227 MB)..." hell-static-sonarlint-version)
    (make-directory hell-static-sonarlint-dir t)
    (hell-sync-install-zip
     "SonarLint" hell-static-sonarlint-url hell-static-sonarlint-sha256
     hell-static-sonarlint-dir hell-static-sonarlint-marker
     (lambda (stage)
       (let ((extension (expand-file-name "extension/" hell-static-sonarlint-dir)))
         (when (file-exists-p extension) (delete-directory extension t))
         (make-directory extension t)
         (dolist (part '("server" "analyzers"))
           (rename-file (expand-file-name (concat "extension/" part) stage)
                        (expand-file-name part extension))))))
    (hell-sync--log "SonarLint %s installed (SHA-256 verified)" hell-static-sonarlint-version)))

(defun hell-static-bundle-paths ()
  "The pinned SonarLint, for `hell-bundle-functions'."
  (list hell-static-sonarlint-dir))

(when (modulep! +sonarlint)
  (add-hook 'hell-sync-functions #'hell-static-sync-install-sonarlint)
  (add-hook 'hell-bundle-functions #'hell-static-bundle-paths))
