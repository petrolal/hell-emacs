;;; checkers/syntax/config.el -*- lexical-binding: t; -*-

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
;; On-the-fly syntax checking via Flycheck.

;;; Code:

(declare-function flycheck-mode "flycheck" (&optional arg))
(declare-function flycheck-next-error "flycheck" (&optional n reset))
(declare-function flycheck-previous-error "flycheck" (&optional n reset))
(declare-function flycheck-list-errors "flycheck" ())

(use-package flycheck
  :defer t
  :commands (flycheck-mode flycheck-list-errors)
  :init
  (add-hook 'prog-mode-hook #'flycheck-mode)
  (define-key global-map (kbd "C-c ! n") #'flycheck-next-error)
  (define-key global-map (kbd "C-c ! p") #'flycheck-previous-error)
  (define-key global-map (kbd "C-c ! l") #'flycheck-list-errors))

(provide 'checkers-syntax-config)
;;; config.el ends here
