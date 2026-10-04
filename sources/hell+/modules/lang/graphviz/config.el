;;; lang/graphviz/config.el -*- lexical-binding: t; -*-

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
;; Graphviz DOT graph specification language support.

;;; Code:

(use-package graphviz-dot-mode
  :mode ("\\.\(?:dot\\|gv\)\\'" . graphviz-dot-mode))

(hell-localleader-def 'graphviz-dot-mode
  "p" '("preview graph" . (lambda () (interactive) (if (fboundp 'compile-dot) (compile-dot) (compile "dot -Tpng -O"))))
  "c" '("compile graph" . (lambda () (interactive) (compile (format "dot -Tsvg %s -o %s" (shell-quote-argument (buffer-file-name)) (shell-quote-argument (concat (file-name-sans-extension (buffer-file-name)) ".svg")))))))

(provide 'lang-graphviz-config)
;;; config.el ends here
