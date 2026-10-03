;;; lang/ess/config.el -*- lexical-binding: t; -*-

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
;; Emacs Speaks Statistics (ESS) for R and data analysis.

;;; Code:

(use-package ess
  :mode (("\\.[rR]\\'" . R-mode)
         ("\\.[rR]profile\\'" . R-mode))
  :config
  (add-hook 'R-mode-hook #'lsp-deferred)
  (add-hook 'ess-r-mode-hook #'lsp-deferred))

(hell-localleader-def '(ess-r-mode R-mode)
  "r" '("start R session" . (lambda () (interactive) (if (fboundp 'R) (call-interactively 'R) (compile "R"))))
  "b" '("eval buffer" . (lambda () (interactive) (when (fboundp 'ess-eval-buffer) (ess-eval-buffer nil))))
  "l" '("eval line/region" . (lambda () (interactive) (when (fboundp 'ess-eval-region-or-line-and-step) (ess-eval-region-or-line-and-step)))))

(provide 'lang-ess-config)
;;; config.el ends here
