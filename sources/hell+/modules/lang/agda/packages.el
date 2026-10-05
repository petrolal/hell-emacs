;;; lang/agda/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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
;; Package definitions for Agda support.

;;; Code:

;; Not on any archive: Agda ships it in its own repository. Pinned to
;; a release (v2.8.0.2): the mode refuses to start with any Agda but
;; its own version, and master's is never a released one.
(package! agda2-mode
  :recipe (:host github :repo "agda/agda"
           :files ("src/data/emacs-mode/*.el"))
  :pin "cccf42fa88eae25ccbe2623f489021d2075f6f73")

(provide 'hell-lang-agda-packages)
;;; packages.el ends here
