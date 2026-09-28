;;; tools/run/config.el -*- lexical-binding: t; -*-

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


;; Run configurations (Phase 12.4): a main class or a build task, with its
;; arguments, JVM options, environment, Spring profiles and working
;; directory. Read from the project's `.hellmacs/run.eld', then IntelliJ's
;; `.run/*.run.xml', then Eclipse `.launch' files, so a team's shared
;; configurations work as they are (autoload.el).
;;
;; Owns `C-c r':
;;   r run one (with completion)   d debug one   l run the last again
;; Output goes to a `*run: NAME*' buffer: ANSI colours, exceptions
;; highlighted, stack frames clickable (M-g n goes through them).

(hellmacs-leader-def
  "r"   "run"
  "r r" '("run a configuration" . hellmacs-run)
  "r d" '("debug a configuration" . hellmacs-run-debug)
  "r l" '("run the last again" . hellmacs-run-last))
