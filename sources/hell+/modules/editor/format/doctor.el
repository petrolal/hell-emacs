;;; editor/format/doctor.el -*- lexical-binding: t; -*-

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


;; Checked by `bin/hell doctor'.

(hell-module-load "+paths")
(hell-module-load "autoload")

(dolist (name (delq nil (list (and (modulep! :lang java) 'google-java-format)
                              (and (modulep! :lang kotlin) 'ktfmt))))
  (let* ((spec (hell-format-jar-spec name))
         (java (hell-jdk-java-executable (plist-get spec :jdk)))
         (major (and (file-executable-p java)
                     (hell-jdk-home-major (file-name-directory (directory-file-name (file-name-directory java)))))))
    (hell-doctor-reachable (plist-get spec :url) (format "installing %s" name))
    (hell-doctor-pinned (symbol-name name) (plist-get spec :version)
                            (hell-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))
                            (file-exists-p (plist-get spec :file))
                            :where (plist-get spec :file))
    (if (and major (>= major (plist-get spec :jdk)))
        (hell-doctor-ok "%s runs on JDK %d (%s)" name major (abbreviate-file-name java))
      (hell-doctor-error :topic 'jdk "%s needs a JDK %d+; none found (JAVA_HOME, the JDKs sync found, the PATH)"
                             name (plist-get spec :jdk)))))

(when (modulep! :lang clojure)
  (let ((clojure-lsp (hell-format--clojure-lsp)))
    (if (executable-find clojure-lsp)
        (hell-doctor-ok "cljfmt through clojure-lsp: %s" (abbreviate-file-name (executable-find clojure-lsp)))
      (hell-doctor-warn :topic 'installs "No clojure-lsp yet to format Clojure with; `bin/hell sync' installs it"))))
