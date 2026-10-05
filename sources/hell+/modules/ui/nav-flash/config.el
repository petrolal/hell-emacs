;;; ui/nav-flash/config.el -*- lexical-binding: t; -*-

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
;; Flash the current line after point jumps.

;;; Code:

(declare-function nav-flash-show "nav-flash" (&optional pos end-pos face delay))

(use-package nav-flash
  :defer t
  :commands (nav-flash-show))

;; Flash line on xref jumps and large buffer switches
(defun hell-nav-flash--show-a (&rest _)
  "Flash the current line after an `xref-pop-to-location' jump."
  (when (fboundp 'nav-flash-show)
    (nav-flash-show)))

(with-eval-after-load 'xref
  (advice-add 'xref-pop-to-location :after #'hell-nav-flash--show-a))

(provide 'ui-nav-flash-config)
;;; config.el ends here
