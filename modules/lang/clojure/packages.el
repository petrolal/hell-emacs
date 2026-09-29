;;; lang/clojure/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; clojure-lsp runs through lsp-mode.
(depends-on! :tools lsp)

(package! clojure-mode)
(package! cider)
(when (modulep! +tree-sitter)
  (package! clojure-ts-mode)
  (hellmacs-treesit!
   ;; clojure-ts-mode 0.6 wants this newer Clojure grammar (not the last
   ;; release, v0.0.13), and two more for docstrings and regex literals.
   :grammars ((clojure "https://github.com/sogaiu/tree-sitter-clojure" "unstable-20250526"
                       "69070d2e4563f8f58c7f57b0c8e093a08d7a5814" :license "CC0-1.0")
              (markdown-inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown" "v0.5.2"
                               "aca7767daa8bbe3daddafc312c34be88383c828b" "tree-sitter-markdown-inline"
                               :license "MIT")
              (regex "https://github.com/tree-sitter/tree-sitter-regex" "v0.24.3"
                     "4470c59041416e8a2a9fa343595ca28ed91f38b8" :license "MIT"))
   :remap ((clojure-mode . clojure-ts-mode)
           (clojurescript-mode . clojure-ts-clojurescript-mode)
           (clojurec-mode . clojure-ts-clojurec-mode))))
