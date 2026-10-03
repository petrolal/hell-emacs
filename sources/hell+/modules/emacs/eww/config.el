;;; emacs/eww/config.el -*- lexical-binding: t; -*-

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
;; Integrated web browsing via built-in EWW.

;;; Code:

(defvar eww-search-prefix)
(declare-function eww "eww" (url &optional command-args))

(use-package eww
  :defer t
  :commands (eww)
  :init
  (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
  (hell-leader-def
    "o w" '("web browser" . eww)))

(provide 'emacs-eww-config)
;;; config.el ends here
