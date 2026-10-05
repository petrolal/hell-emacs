;;; lang/ocaml/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; OCaml development with Tuareg mode and OCaml-LSP.

;;; Code:

(use-package tuareg
  :mode ("\\.ml[ip]?\\'" . tuareg-mode)
  :config
  (add-hook 'tuareg-mode-hook #'lsp-deferred))

(defun hell-ocaml-build ()
  "Build the current dune project."
  (interactive)
  (compile "dune build"))

(defun hell-ocaml-runtest ()
  "Run the current dune project's tests."
  (interactive)
  (compile "dune runtest"))

(defun hell-ocaml-exec ()
  "Execute the current dune project."
  (interactive)
  (compile "dune exec"))

(defun hell-ocaml-repl ()
  "Start an OCaml REPL (utop)."
  (interactive)
  (if (fboundp 'tuareg-run-ocaml) (tuareg-run-ocaml) (compile "dune utop")))

(hell-localleader-def 'tuareg-mode
  "b" '("dune build" . hell-ocaml-build)
  "t" '("dune runtest" . hell-ocaml-runtest)
  "r" '("dune exec" . hell-ocaml-exec)
  "s" '("utop/repl" . hell-ocaml-repl))

(provide 'lang-ocaml-config)
;;; config.el ends here
