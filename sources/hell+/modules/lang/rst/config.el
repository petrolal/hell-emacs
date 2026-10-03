;;; lang/rst/config.el -*- lexical-binding: t; -*-

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
;; reStructuredText documentation support and Esbonio LSP.

;;; Code:

(use-package rst
  :ensure nil
  :mode ("\\.rst\\'" . rst-mode)
  :config
  (add-hook 'rst-mode-hook #'lsp-deferred))

(hell-localleader-def 'rst-mode
  "c" '("sphinx compile" . (lambda () (interactive) (compile "sphinx-build -b html . _build")))
  "p" '("preview rst" . (lambda () (interactive) (if (fboundp 'rst-compile) (rst-compile) (compile "rst2html.py")))))

(provide 'lang-rst-config)
;;; config.el ends here
