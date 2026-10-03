;;; ui/unicode/config.el -*- lexical-binding: t; -*-

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
;; Fallback fonts for non-Latin unicode glyphs via unicode-fonts.

;;; Code:

(declare-function unicode-fonts-setup "unicode-fonts")

(use-package unicode-fonts
  :defer t
  :commands (unicode-fonts-setup)
  :init
  (when (display-graphic-p)
    (add-hook 'hell-first-file-hook #'unicode-fonts-setup)))

(provide 'ui-unicode-config)
;;; config.el ends here
