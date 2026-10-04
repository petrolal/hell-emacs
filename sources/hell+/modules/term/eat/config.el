;;; term/eat/config.el -*- lexical-binding: t; -*-

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
;; Fast terminal emulation in pure Elisp via Eat.

;;; Code:

(declare-function eat "eat" (&optional arg))
(declare-function eat-project "eat" ())

(use-package eat
  :defer t
  :commands (eat eat-project)
  :init
  (hell-leader-def
    "o T" '("terminal (eat)" . eat)
    "o P" '("project terminal (eat)" . eat-project)))

(provide 'term-eat-config)
;;; config.el ends here
