;;; ui/treemacs/config.el -*- lexical-binding: t; -*-

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
;; Project file explorer sidebar via treemacs.

;;; Code:

(declare-function treemacs "treemacs" (&optional arg))
(declare-function treemacs-load-theme "treemacs" (name))

(use-package treemacs
  :defer t
  :commands (treemacs)
  :init
  (hell-leader-def
    "o p" '("project tree" . treemacs))
  :config
  (with-eval-after-load 'treemacs-nerd-icons
    (treemacs-load-theme "nerd-icons")))

(use-package treemacs-nerd-icons
  :after treemacs
  :defer t)

(provide 'ui-treemacs-config)
;;; config.el ends here
