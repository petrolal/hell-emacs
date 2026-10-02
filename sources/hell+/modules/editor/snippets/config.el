;;; editor/snippets/config.el -*- lexical-binding: t; -*-

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

;; Code snippets through tempel (Phase 10.4). Type a snippet's name and
;; complete it (`C-M-i', or pick it in the corfu popup) to expand it:
;;   Java     junit (a JUnit 5 test class), controller (a Spring REST controller)
;;   Kotlin   dataclass
;;   Clojure  deftest
;;   Scala    munit (a munit suite)
;; `M-x tempel-insert' picks any snippet for the buffer from a list. Your
;; own go in $HELLDIR/templates/*.eld (tempel's format; see the
;; module's templates/ for examples), and are picked up as you save them.
;;
;; Keys: tempel's own, as it ships them (13.6), only inside a snippet
;; (`tempel-map'): `M-}' / `M-{' next / previous field, `M-<' / `M->' the
;; first / last, `ESC ESC ESC' takes the snippet back out.

(defvar tempel-path)
(declare-function tempel-expand "tempel")

(setq tempel-path
      (list (expand-file-name "templates/*.eld"
                              (hell-module-get '(:editor . snippets) :path))
            (expand-file-name "templates/*.eld" hell-user-dir)))

;; Only the exact name completes, ahead of everything else: tempel's list
;; of all snippets would come first in the popup and, with orderless,
;; hide the language server's candidates as you type.
(defun hell-snippets--capf-h ()
  "Offer the snippet named at point to `completion-at-point'."
  (add-hook 'completion-at-point-functions #'tempel-expand -90 t))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook #'hell-snippets--capf-h))
