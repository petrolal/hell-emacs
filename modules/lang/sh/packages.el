;;; lang/sh/packages.el -*- lexical-binding: t; -*-

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


;; bash-language-server runs through lsp-mode (an npm package, installed
;; by `bin/hellmacs sync' from this module's package-lock.json). Shell
;; scripts are built-in `sh-mode'.
(depends-on! :tools lsp)

;; bash-ts-mode is built into Emacs; v0.23.3 is the commit Emacs 31's own
;; bash-ts-mode recommends (ABI 14; the newer v0.25 is ABI 15, which Emacs
;; 29 and 30 can't load).
(when (modulep! +tree-sitter)
  (hellmacs-treesit!
   :grammars ((bash "https://github.com/tree-sitter/tree-sitter-bash" "v0.23.3"
                    "487734f87fd87118028a65a4599352fa99c9cde8" :license "MIT"))
   :remap ((sh-mode . bash-ts-mode))))
