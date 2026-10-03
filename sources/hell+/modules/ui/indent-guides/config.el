;;; ui/indent-guides/config.el -*- lexical-binding: t; -*-

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
;; Indentation guides for programming buffers via highlight-indent-guides.

;;; Code:

(defvar highlight-indent-guides-method)
(defvar highlight-indent-guides-responsive)
(defvar highlight-indent-guides-delay)
(declare-function highlight-indent-guides-mode "highlight-indent-guides" (&optional arg))

(use-package highlight-indent-guides
  :defer t
  :init
  (setq highlight-indent-guides-method 'character
        highlight-indent-guides-responsive 'top
        highlight-indent-guides-delay 0.1)
  (add-hook 'prog-mode-hook #'highlight-indent-guides-mode))

(provide 'ui-indent-guides-config)
;;; config.el ends here
