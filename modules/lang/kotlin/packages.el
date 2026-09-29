;;; lang/kotlin/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; kotlin-language-server runs through lsp-mode.
(depends-on! :tools lsp)

(package! kotlin-mode)
(when (modulep! +tree-sitter)
  (package! kotlin-ts-mode)
  (hellmacs-treesit!
   ;; Not the last tag (0.3.8, 2024): kotlin-ts-mode's font-lock rules follow
   ;; the grammar's main branch, and 0.3.8 makes it drop string and constant
   ;; highlighting. This is main on 2026-08-02.
   :grammars ((kotlin "https://github.com/fwcd/tree-sitter-kotlin" "main 2026-08-02"
                      "1852ea17b7f60fb3f9d84e0b1555d56b46b39fb1" :license "MIT"))
   :remap ((kotlin-mode . kotlin-ts-mode))))
