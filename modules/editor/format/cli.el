;;; editor/format/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs the formatter jars of the
;; enabled languages (google-java-format with :lang java, ktfmt with :lang
;; kotlin); Clojure's formatter is clojure-lsp, which :lang clojure pins.

(hellmacs-module-load "+paths")

(defvar hellmacs-format--sync-jars
  (delq nil (list (and (modulep! :lang java) 'google-java-format)
                  (and (modulep! :lang kotlin) 'ktfmt)))
  "The formatter jars the enabled languages need.")

(defun hellmacs-format-sync-install ()
  "Install the pinned formatter jars. For `hellmacs-sync-functions'."
  (dolist (name hellmacs-format--sync-jars)
    (let ((spec (hellmacs-format-jar-spec name)))
      (if (hellmacs-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
          (hellmacs-sync--log "%s %s is installed" name (plist-get spec :version))
        (hellmacs-sync--log "Downloading %s %s (%s)..." name (plist-get spec :version) (plist-get spec :size))
        (hellmacs-sync-download-verified (plist-get spec :url) (plist-get spec :file)
                                         (plist-get spec :sha256) (symbol-name name))
        (hellmacs-sync--log "%s %s installed (SHA-256 verified)" name (plist-get spec :version))))))

(add-hook 'hellmacs-sync-functions #'hellmacs-format-sync-install)

(defun hellmacs-format-bundle-paths ()
  "The pinned formatter jars. For `hellmacs-bundle-functions'."
  (mapcar (lambda (name) (plist-get (hellmacs-format-jar-spec name) :file)) hellmacs-format--sync-jars))

(add-hook 'hellmacs-bundle-functions #'hellmacs-format-bundle-paths)
