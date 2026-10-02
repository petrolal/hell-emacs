;;; tools/magit/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-
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

(defconst hell-magit--minimal-git "2.25.0"
  "The oldest Git Magit supports (its own `magit--minimal-git').")

(let ((line (hell-cli--version "git" "--version")))
  (if (and line (string-match "\\([0-9]+\\(?:\\.[0-9]+\\)+\\)" line))
      (let ((number (match-string 1 line)))
        (if (version< number hell-magit--minimal-git)
            (hell-doctor-error :topic 'tools "Git %s is too old for Magit (needs %s+)"
                               number hell-magit--minimal-git)
          (hell-doctor-ok "Git %s (Magit needs %s+)" number hell-magit--minimal-git)))
    (hell-doctor-error :topic 'tools "git not found; Magit runs every command through it")))
