;;; ui/modeline/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; A minimal doom-modeline in the Hellmacs palette. The code is
;; ui/hellmacs-modeline.el, beside this module in the catalog (the file
;; name the Phase 9 spec gives it); this module puts that ui/ directory
;; on `load-path' and loads it. See that file for the segments and when it
;; turns on.
;;
;; Option, in your init.el or config.el:
;;   (setq hellmacs-modeline-tty-icons t)  ; icons in a terminal with a Nerd Font

;; At compile time too (`bin/hellmacs sync'), for the `require' below.
;; It lives in this module's directory, as a Doom module keeps its files.
(eval-and-compile
  (add-to-list 'load-path (hellmacs-module-get hellmacs--current-module :path)))
(require 'hellmacs-modeline)
