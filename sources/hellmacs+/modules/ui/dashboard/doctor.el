;;; ui/dashboard/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Checked by `bin/hellmacs doctor'.

(dolist (item '(("banners/banner-960.png" "banner-960.png")
                ("banners/banner.png" "banner.png")
                ("banners/banner.svg" "banner.svg")
                ("ascii/banner-ascii.txt" "banner-ascii.txt")))
  (let* ((primary (car item))
         (fallback (cadr item))
         (found (or (and (file-readable-p (expand-file-name (concat "assets/" primary) hellmacs-dir)) primary)
                    (and (file-readable-p (expand-file-name (concat "assets/" fallback) hellmacs-dir)) fallback))))
    (if found
        (hellmacs-doctor-ok "Banner assets/%s" found)
      (hellmacs-doctor-warn :topic 'checkout "assets/%s is missing; the dashboard falls back to the next banner" primary))))

(hellmacs-doctor-nerd-font "the dashboard shows no icons")
