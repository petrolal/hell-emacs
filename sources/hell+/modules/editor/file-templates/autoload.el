;;; editor/file-templates/autoload.el -*- lexical-binding: t; -*-

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

;; What the Clojure file templates fill in from the file they're in: its
;; namespace, and the one a test namespace tests. The package and class
;; of Java and Kotlin files come from :editor snippets'
;; `hell-snippets-package-line' and `hell-snippets-class'.

(defconst hell-file-templates--clojure-roots
  "\\(?:src/[^/]+/clojure\\|src\\|test\\|dev\\)/"
  "Clojure's source directories, relative to a project's root.")

(defconst hell-file-templates--clojure-projects
  '("deps.edn" "project.clj" "bb.edn" "shadow-cljs.edn" "build.boot")
  "Files that mark a Clojure project's root.")

;;;###autoload
(defun hell-file-templates-clojure-ns (&optional file)
  "The Clojure namespace of FILE (the buffer's by default), from its path.
Read from under the nearest project's src/, test/, dev/ or
src/<set>/clojure/ (the innermost of those with no project file):
src/my_app/core.clj is my-app.core. Nil outside them (project.clj, say)."
  (when-let* ((file (or file buffer-file-name))
              (file (expand-file-name file))
              (path (if-let* ((root (hell-file-templates--clojure-root file)))
                        (hell-file-templates--under-root
                         (concat "\\`" hell-file-templates--clojure-roots)
                         (file-relative-name file root))
                      (hell-file-templates--under-root
                       (concat ".*/" hell-file-templates--clojure-roots) file))))
    (string-replace "_" "-" (string-replace "/" "." (file-name-sans-extension path)))))

(defun hell-file-templates--clojure-root (file)
  "The root of the Clojure project FILE is in, or nil."
  (locate-dominating-file
   (file-name-directory file)
   (lambda (dir)
     (seq-some (lambda (name) (file-exists-p (expand-file-name name dir)))
               hell-file-templates--clojure-projects))))

(defun hell-file-templates--under-root (prefix path)
  "What follows PREFIX (a regexp) in PATH, or nil."
  (and (string-match (concat prefix "\\(.+\\)\\'") path)
       (match-string 1 path)))

;;;###autoload
(defun hell-file-templates-clojure-tested-ns ()
  "The namespace the buffer's test namespace tests: shop.cart for shop.cart-test."
  (replace-regexp-in-string "-test\\'" "" (or (hell-file-templates-clojure-ns) "")))
