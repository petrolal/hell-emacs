;;; ui/dashboard/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Checked by `bin/hell doctor'.

(dolist (item '(("banners/banner-960.png" "banner-960.png")
                ("banners/banner.png" "banner.png")
                ("banners/banner.svg" "banner.svg")
                ("ascii/banner-ascii.txt" "banner-ascii.txt")))
  (let* ((primary (car item))
         (fallback (cadr item))
         (found (or (and (file-readable-p (expand-file-name (concat "assets/" primary) hell-dir)) primary)
                    (and (file-readable-p (expand-file-name (concat "assets/" fallback) hell-dir)) fallback))))
    (if found
        (hell-doctor-ok "Banner assets/%s" found)
      (hell-doctor-warn :topic 'checkout "assets/%s is missing; the dashboard falls back to the next banner" primary))))

(hell-doctor-nerd-font "the dashboard shows no icons")
