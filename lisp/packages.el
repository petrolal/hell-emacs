;;; lisp/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Packages Hellmacs' core declares for every configuration, read before
;; any module's packages.el (as Doom's lisp/packages.el is).
;;
;; `compat' is a dependency of most modern packages (vertico, consult,
;; corfu, marginalia, orderless, ...). Declaring it here, up front,
;; makes Elpaca build it once as a top-level package. Left to be
;; discovered as a dependency, several packages queue it at the same
;; moment on a fresh install, Elpaca starts building it twice, the
;; second build fails, and the packages waiting on it never finish.
(package! compat)

;; Collects garbage while idle instead of mid-keystroke; see "GC
;; lifecycle" in hellmacs.el. Not needed with Emacs' incremental GC.
(unless (fboundp 'igc-info)
  (package! gcmh))
