;;; editor/format/config.el -*- lexical-binding: t; -*-

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


;; Each language's own formatter (autoload.el), on the keys you already
;; have: `C-c c f' and lsp-mode's `C-c c l = =' (and eglot's command) are
;; remapped, in Java, Kotlin and Clojure buffers, to the pinned
;; formatter; XML, YAML and JSON keep their language server's. No new keys. Flags:
;;   +onsave  format on save (off by default, so a first save doesn't
;;            reformat a whole legacy file)
;;
;; Groovy has no maintained formatter and is left alone.

(defvar apheleia-formatters)

(after! apheleia
  (dolist (formatter (hellmacs-format-apheleia-formatters))
    (setf (alist-get (car formatter) apheleia-formatters) (cdr formatter))))

(add-hook! (java-mode java-ts-mode kotlin-mode kotlin-ts-mode clojure-mode clojure-ts-mode)
           #'hellmacs-format-mode)

;; Before lsp-deferred's hook, so JDTLS starts with the project's profile.
(add-hook! (java-mode java-ts-mode) :depth -10 #'hellmacs-format--java-profile-h)

(when (modulep! +onsave)
  (add-hook! (java-mode java-ts-mode kotlin-mode kotlin-ts-mode clojure-mode clojure-ts-mode
              nxml-mode yaml-mode yaml-ts-mode js-json-mode json-ts-mode)
             #'hellmacs-format--onsave-h))
