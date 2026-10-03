;;; lang/java/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; JDTLS runs through lsp-java, on lsp-mode.
(depends-on! :tools lsp)

;; Shared by several of lsp-java's own dependencies: declared up front so
;; Elpaca builds each exactly once (roadmap 6.0's dependency audit).
(package! posframe)
(package! treemacs)
(package! dap-mode)
(package! lsp-java)                     ; also provides dap-java

;; Grammars `bin/hell sync' builds, in one declaration (a module has one):
;;   +tree-sitter  java-ts-mode, built into Emacs, for Java files.
;;   +spring       yaml-ts-mode, built into Emacs, for application.yml,
;;                 which the Spring Boot server attaches to (lsp-java-boot);
;;                 the same pin as :lang yaml's.
(when (or (modulep! +tree-sitter) (modulep! +spring))
  (hell-treesit-declare
   (append (when (modulep! +tree-sitter)
             '((java "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5"
                     "94703d5a6bed02b98e438d7cad1136c01a60ba2c" :license "MIT")))
           (when (modulep! +spring)
             '((yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml" "v0.7.0"
                     "b733d3f5f5005890f324333dd57e1f0badec5c87" :license "MIT"))))
   (when (modulep! +tree-sitter)
     '((java-mode . java-ts-mode)))))
