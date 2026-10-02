;;; lang/yaml/packages.el -*- lexical-binding: t; -*-

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


;; yaml-language-server runs through lsp-mode (an npm package, installed
;; by `bin/hell sync' from this module's package-lock.json).
(depends-on! :tools lsp)

(package! yaml-mode)
;; yaml-ts-mode is built into Emacs; this is the commit Emacs 31's own
;; yaml-ts-mode recommends (ABI 14, so Emacs 29 and 30 load it too).
(when (modulep! +tree-sitter)
  (hell-treesit!
   :grammars ((yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml" "v0.7.0"
                    "b733d3f5f5005890f324333dd57e1f0badec5c87" :license "MIT"))
   :remap ((yaml-mode . yaml-ts-mode))))
