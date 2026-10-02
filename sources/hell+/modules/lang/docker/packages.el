;;; lang/docker/packages.el -*- lexical-binding: t; -*-

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


;; Docker's docker-language-server runs through lsp-mode (a native binary,
;; pinned by SHA-256 and installed by `bin/hell sync'). lsp-mode has
;; no client for it, so config.el registers one.
(depends-on! :tools lsp)

(package! dockerfile-mode)
;; dockerfile-ts-mode is built into Emacs; this is the commit Emacs 31's
;; own dockerfile-ts-mode recommends (ABI 14, so Emacs 29 and 30 load it).
(when (modulep! +tree-sitter)
  (hell-treesit!
   :grammars ((dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile" "Emacs 31's pin"
                          "087daa20438a6cc01fa5e6fe6906d77c869d19fe" :license "MIT"))
   :remap ((dockerfile-mode . dockerfile-ts-mode))))
