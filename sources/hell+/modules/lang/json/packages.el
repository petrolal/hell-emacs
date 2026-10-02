;;; lang/json/packages.el -*- lexical-binding: t; -*-

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


;; vscode-json-language-server runs through lsp-mode (from the npm package
;; vscode-langservers-extracted, installed by `bin/hell sync' from this
;; module's package-lock.json). JSON itself is built-in `js-json-mode'.
(depends-on! :tools lsp)

;; json-ts-mode is built into Emacs; this is the commit Emacs 31's own
;; json-ts-mode recommends (ABI 14, so Emacs 29 and 30 load it too).
(when (modulep! +tree-sitter)
  (hell-treesit!
   :grammars ((json "https://github.com/tree-sitter/tree-sitter-json" "Emacs 31's pin"
                    "4d770d31f732d50d3ec373865822fbe659e47c75" :license "MIT"))
   :remap ((js-json-mode . json-ts-mode))))
