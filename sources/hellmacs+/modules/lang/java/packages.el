;;; lang/java/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; JDTLS runs through lsp-java, on lsp-mode.
(depends-on! :tools lsp)

;; Shared by several of lsp-java's own dependencies: declared up front so
;; Elpaca builds each exactly once (roadmap 6.0's dependency audit).
(package! posframe)
(package! treemacs)
(package! dap-mode)
(package! lsp-java)                     ; also provides dap-java

;; +spring: application.yml is edited in yaml-mode, which the Spring Boot
;; server attaches to (lsp-java-boot).
(when (modulep! +spring)
  (package! yaml-mode))

;; java-ts-mode is built into Emacs; `bin/hellmacs sync' builds its grammar.
(when (modulep! +tree-sitter)
  (hellmacs-treesit!
   :grammars ((java "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5"
                    "94703d5a6bed02b98e438d7cad1136c01a60ba2c" :license "MIT"))
   :remap ((java-mode . java-ts-mode))))
