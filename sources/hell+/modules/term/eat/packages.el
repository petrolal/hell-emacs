;;; term/eat/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

(package! eat
  ;; From its GitHub mirror, on purpose: upstream is on Codeberg, whose
  ;; 503s failed installs. Its :files as MELPA's recipe: NonGNU ELPA's
  ;; leaves out the compiled terminfo (its tarball build makes it) and
  ;; the shell integration scripts.
  :recipe (:host github :repo "emacsmirror/eat"
           :files ("*.el" ("term" "term/*.el") "*.texi" "*.ti"
                   ("terminfo/e" "terminfo/e/*") ("terminfo/65" "terminfo/65/*")
                   ("integration" "integration/*")
                   (:exclude ".dir-locals.el" "*-tests.el"))))
