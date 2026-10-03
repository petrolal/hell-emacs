;;; lang/fortran/config.el -*- lexical-binding: t; -*-

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
;; Fortran scientific computing support with built-in f90-mode and fortls.

;;; Code:

(use-package f90
  :ensure nil
  :mode ("\\.[fF]9[05]\\'" . f90-mode)
  :mode ("\\.[fF]0[38]\\'" . f90-mode)
  :config
  (add-hook 'f90-mode-hook #'lsp-deferred))

(use-package fortran
  :ensure nil
  :mode ("\\.[fF]\\'" . fortran-mode)
  :config
  (add-hook 'fortran-mode-hook #'lsp-deferred))

(hell-localleader-def '(f90-mode fortran-mode)
  "b" '("compile fortran" . (lambda () (interactive) (compile (format "gfortran -Wall -c %s" (buffer-file-name)))))
  "r" '("run fortran" . (lambda () (interactive) (compile (format "gfortran -Wall %s -o a.out && ./a.out" (buffer-file-name))))))

(provide 'lang-fortran-config)
;;; config.el ends here
