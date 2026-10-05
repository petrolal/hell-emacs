;;; lang/sml/config.el -*- lexical-binding: t; -*-

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
;; Standard ML programming language support and Millet LSP.

;;; Code:

(use-package sml-mode
  :mode ("\\.\(?:sml\\|sig\)\\'" . sml-mode)
  :config
  (add-hook 'sml-mode-hook #'lsp-deferred))

(defun hell-sml-start-repl ()
  "Start an SML REPL."
  (interactive)
  (if (fboundp 'sml-prog-proc) (sml-prog-proc) (compile "sml")))

(defun hell-sml-load-file ()
  "Load the current SML file into the REPL."
  (interactive)
  (if (fboundp 'sml-load-file)
      (sml-load-file (buffer-file-name))
    (compile "sml")))

(defun hell-sml-compile ()
  "Compile the current SML file with mlton."
  (interactive)
  (compile (format "mlton %s" (shell-quote-argument (buffer-file-name)))))

(hell-localleader-def 'sml-mode
  "s" '("run SML REPL" . hell-sml-start-repl)
  "b" '("load file" . hell-sml-load-file)
  "c" '("compile with mlton" . hell-sml-compile))

(provide 'lang-sml-config)
;;; config.el ends here
