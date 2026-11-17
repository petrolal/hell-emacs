;;; ui/treemacs/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Shared by treemacs, cfrs, hydra and lsp-mode: declared up front so
;; Elpaca builds each once (see lisp/packages.el).
(package! dash) (package! s) (package! ht) (package! pfuture)
(package! avy) (package! ace-window)
(package! lv) (package! hydra)
(package! posframe) (package! cfrs)
(package! nerd-icons)
(package! treemacs)
(package! treemacs-nerd-icons)

;; Error/warning icons on the tree, from lsp-mode's diagnostics table
;; (JDTLS and the rest), when `:tools lsp' is enabled.
(when (modulep! :tools lsp)
  (depends-on! :tools lsp)
  (package! lsp-treemacs))
