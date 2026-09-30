;;; tools/magit/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-
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

(defconst hellmacs-magit--minimal-git "2.25.0"
  "The oldest Git Magit supports (its own `magit--minimal-git').")

(let ((line (hellmacs-cli--version "git" "--version")))
  (if (and line (string-match "\\([0-9]+\\(?:\\.[0-9]+\\)+\\)" line))
      (let ((number (match-string 1 line)))
        (if (version< number hellmacs-magit--minimal-git)
            (hellmacs-doctor-error "Git %s is too old for Magit (needs %s+)"
                                   number hellmacs-magit--minimal-git)
          (hellmacs-doctor-ok "Git %s (Magit needs %s+)" number hellmacs-magit--minimal-git)))
    (hellmacs-doctor-error "git not found; Magit runs every command through it")))
