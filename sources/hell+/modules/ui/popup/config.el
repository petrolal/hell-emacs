;;; ui/popup/config.el -*- lexical-binding: t; -*-

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

;; Temporary buffers open in one window at the bottom of the frame instead
;; of taking over your layout (Phase 10.3): compilation and runs, test
;; results and coverage, REPLs, help, xref and diagnostics. Each new one
;; replaces the last one there. Built-in `display-buffer-alist'
;; and side windows only; nothing is installed.
;;
;; Keys: none of its own. A popup closes with its own `q' (`quit-window')
;; or stock `C-x 0', and `C-x 1' in your code closes it too. `C-c w t'
;; (`window-toggle-side-windows') hides the popup and brings it back.
;; `C-x b' still shows any of these buffers in the selected window.
;;
;; Add your own with `hell-popup-rules' (in config.el); an entry of
;; yours in `display-buffer-alist' wins over the module's.

(defvar hell-popup-rules
  '("\\`\\*compilation\\*" (derived-mode . compilation-mode) ; also grep
    "\\`\\*run: "                                            ; :tools run
    "\\`\\*hell-\\(?:tests\\|coverage\\|static\\)\\*"    ; :tools test, :checkers static
    (derived-mode . hell-test-results-mode) (derived-mode . hell-coverage-summary-mode)
    "\\`\\*cider-\\(?:repl\\|error\\|test-report\\|doc\\)" (derived-mode . cider-repl-mode)
    "\\`\\*Help\\*" (derived-mode . help-mode) "\\`\\*lsp-help\\*"
    "\\`\\*xref\\*" (derived-mode . xref--xref-buffer-mode)
    "\\`\\*Flymake diagnostics for " (derived-mode . flymake-diagnostics-buffer-mode))
  "Buffers shown at the bottom of the frame: `buffer-match-p' conditions.
A buffer matching any of them is a popup.")

(defun hell-popup-display (buffer alist)
  "Show BUFFER in a fresh bottom side window, closing the popup there.
A `display-buffer' action function. Reusing that window would make `q'
bring back the popup before it instead of closing it."
  (dolist (window (window-list nil 'nomini))
    (when (and (eq (window-parameter window 'window-side) 'bottom)
               (not (eq (window-buffer window) buffer))
               ;; A popup's; a side window someone else opened stays.
               (hell-popup-buffer-p (window-buffer window)))
      (delete-window window)))
  (display-buffer-in-side-window buffer alist))

(defvar hell-popup-action
  '((display-buffer-reuse-window hell-popup-display)
    (side . bottom)
    (slot . 0)
    (window-height . 0.3)
    (preserve-size . (nil . t)))
  "How popups are displayed: a `display-buffer' action.")

(defun hell-popup-buffer-p (buffer-or-name &rest _)
  "Non-nil if BUFFER-OR-NAME matches `hell-popup-rules'."
  (buffer-match-p (cons 'or hell-popup-rules) buffer-or-name))

;; One entry, updated in place on a reload, so it stays where it was:
;; behind any entry of yours added after it.
(if-let* ((entry (assq 'hell-popup-buffer-p display-buffer-alist)))
    (setcdr entry hell-popup-action)
  (push (cons 'hell-popup-buffer-p hell-popup-action) display-buffer-alist))

(hell-leader-def
  "w t" '("toggle popups" . window-toggle-side-windows))
