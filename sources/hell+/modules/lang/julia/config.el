;;; lang/julia/config.el -*- lexical-binding: t; -*-

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
;; Julia high-performance technical computing language support.

;;; Code:

(use-package julia-mode
  :mode ("\\.jl\\'" . julia-mode)
  :config
  (add-hook 'julia-mode-hook #'lsp-deferred))

(defun hell-julia-run ()
  "Run the current Julia file."
  (interactive)
  (compile (format "julia %s" (shell-quote-argument (buffer-file-name)))))

(defun hell-julia-test ()
  "Run the current Julia project's tests."
  (interactive)
  (compile "julia --project -e 'using Pkg; Pkg.test()'"))

(hell-localleader-def 'julia-mode
  "r" '("run julia file" . hell-julia-run)
  "t" '("run tests" . hell-julia-test))

(provide 'lang-julia-config)
;;; config.el ends here
