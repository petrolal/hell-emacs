;;; editor/snippets/config.el -*- lexical-binding: t; -*-

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

;; Code snippets through tempel (Phase 10.4). Type a snippet's name and
;; complete it (`C-M-i', or pick it in the corfu popup) to expand it:
;;   Java     junit (a JUnit 5 test class), controller (a Spring REST controller)
;;   Kotlin   dataclass
;;   Clojure  deftest
;;   Scala    munit (a munit suite)
;; `M-x tempel-insert' picks any snippet for the buffer from a list. Your
;; own go in $HELLMACSDIR/templates/*.eld (tempel's format; see the
;; module's templates/ for examples), and are picked up as you save them.
;;
;; Keys: none of its own; TAB keeps indenting, in a snippet too. Inside
;; one, stock keys move between its fields: `M-}' (`forward-paragraph')
;; to the next, `M-{' to the previous, and `ESC ESC ESC' takes the whole
;; snippet back out. Moving on from the last field finishes it.

(defvar tempel-path)
(defvar tempel-map)
(declare-function tempel-expand "tempel")

(setq tempel-path
      (list (expand-file-name "templates/*.eld"
                              (hellmacs-module-get '(:editor . snippets) :path))
            (expand-file-name "templates/*.eld" hellmacs-user-dir)))

;; Only the exact name completes, ahead of everything else: tempel's list
;; of all snippets would come first in the popup and, with orderless,
;; hide the language server's candidates as you type.
(defun hellmacs-snippets--capf-h ()
  "Offer the snippet named at point to `completion-at-point'."
  (add-hook 'completion-at-point-functions #'tempel-expand -90 t))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook #'hellmacs-snippets--capf-h))

(defun hellmacs-snippets--remaps-only ()
  "Keep only `tempel-map''s remaps of stock commands; drop its own keys."
  (let (own)
    (map-keymap (lambda (event _) (unless (eq event 'remap) (push event own)))
                tempel-map)
    (dolist (event own)
      (define-key tempel-map (vector event) nil t))))

(with-eval-after-load 'tempel
  (hellmacs-snippets--remaps-only))
