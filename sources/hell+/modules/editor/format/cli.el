;;; editor/format/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs the formatter jars of the
;; enabled languages (google-java-format with :lang java, ktfmt with :lang
;; kotlin); Clojure's formatter is clojure-lsp, which :lang clojure pins.

(hell-module-load "+paths")

(defvar hell-format--sync-jars
  (delq nil (list (and (modulep! :lang java) 'google-java-format)
                  (and (modulep! :lang kotlin) 'ktfmt)))
  "The formatter jars the enabled languages need.")

(defun hell-format-sync-install ()
  "Install the pinned formatter jars. For `hell-sync-functions'."
  (dolist (name hell-format--sync-jars)
    (let ((spec (hell-format-jar-spec name)))
      (if (hell-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
          (hell-sync--log "%s %s is installed" name (plist-get spec :version))
        (hell-sync--log "Downloading %s %s (%s)..." name (plist-get spec :version) (plist-get spec :size))
        (hell-sync-download-verified (plist-get spec :url) (plist-get spec :file)
                                         (plist-get spec :sha256) (symbol-name name))
        (hell-sync--log "%s %s installed (SHA-256 verified)" name (plist-get spec :version))))))

(add-hook 'hell-sync-functions #'hell-format-sync-install)

(defun hell-format-bundle-paths ()
  "The pinned formatter jars. For `hell-bundle-functions'."
  (mapcar (lambda (name) (plist-get (hell-format-jar-spec name) :file)) hell-format--sync-jars))

(add-hook 'hell-bundle-functions #'hell-format-bundle-paths)
