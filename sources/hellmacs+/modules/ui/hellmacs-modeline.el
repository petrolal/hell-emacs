;;; hellmacs-modeline.el --- A minimal doom-modeline in the Hellmacs palette -*- lexical-binding: t; -*-

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

;; The `:ui modeline' module (modules/ui/modeline/ loads this file): a
;; minimal doom-modeline, coloured by the theme's `doom-modeline-*'
;; faces.
;;
;;   left:  the bar, the buffer (name, state), the position
;;   right: `mode-line-misc-info' (the Hellmacs JVM:... segment), the
;;          debugger state, the major mode, VCS, diagnostics (flymake)
;;
;; No minor modes, encoding, indentation, word count or lsp segment
;; (lsp-mode's own is already off; JVM:... says what the server is
;; doing).
;;
;; Icons come from nerd-icons when the selected frame can draw them
;; (`hellmacs-nerd-font-p'), and text otherwise; it is decided again
;; whenever another frame is selected, so an `emacsclient -t' and a GUI
;; frame each get theirs. `hellmacs-modeline-tty-icons' opts a terminal
;; with a Nerd Font in.
;;
;; doom-modeline and nerd-icons take about 50ms to load, more than the
;; startup budget has left (docs/roadmap.md, 9.3), so the modeline is
;; turned on with the first real buffer (`hellmacs-first-buffer-hook'):
;; the startup screen shows the stock mode-line, in the same colours.

;;; Code:

(defvar doom-modeline-icon)
(defvar doom-modeline-mode)
(declare-function doom-modeline-mode "doom-modeline")

(defgroup hellmacs-modeline nil
  "The Hellmacs mode-line."
  :group 'hellmacs)

(defcustom hellmacs-modeline-tty-icons nil
  "Whether the mode-line draws nerd-icons in a terminal frame.
A terminal can't tell Emacs which font it uses, so this is off: turn
it on if your terminal's font is a Nerd Font."
  :type 'boolean)

(defconst hellmacs-modeline-segments
  '((bar buffer-info buffer-position)
    (misc-info debug major-mode vcs check))
  "The left and right segments of the Hellmacs mode-line.")

(defun hellmacs-modeline-icons-p (&optional frame)
  "Non-nil if the mode-line should draw icons in FRAME (default: selected)."
  (hellmacs-icons-p hellmacs-modeline-tty-icons frame))

(defun hellmacs-modeline--update-icons (&rest _)
  "Match `doom-modeline-icon' to the selected frame.
Only set when it changes: doom-modeline watches the variable and
rebuilds its cached icons each time it is set."
  (when (bound-and-true-p doom-modeline-mode)
    (let ((icons (and (hellmacs-modeline-icons-p) t)))
      (unless (eq icons doom-modeline-icon)
        (setq doom-modeline-icon icons)))))

(use-package doom-modeline
  :defer t
  :init
  (setq doom-modeline-icon nil          ; set per frame, see above
        doom-modeline-major-mode-icon t
        ;; The icon takes the palette's colour, not nerd-icons' own.
        doom-modeline-major-mode-color-icon nil
        doom-modeline-bar-width 4
        doom-modeline-minor-modes nil
        doom-modeline-buffer-encoding nil
        doom-modeline-indent-info nil
        doom-modeline-enable-word-count nil
        doom-modeline-lsp nil
        doom-modeline-time nil
        doom-modeline-buffer-file-name-style 'truncate-upto-project)
  :config
  ;; Replace doom-modeline's main mode-line (the one every file buffer
  ;; uses) with the Hellmacs one. Its other mode-lines (dired, Magit,
  ;; the dashboard, ...) keep their own shapes and the same faces.
  (eval `(doom-modeline-def-modeline 'main
           ',(car hellmacs-modeline-segments)
           ',(cadr hellmacs-modeline-segments))
        t))

(defun hellmacs-modeline-enable ()
  "Turn the Hellmacs mode-line on."
  (interactive)
  (require 'doom-modeline)
  (doom-modeline-mode 1)
  (hellmacs-modeline--update-icons))

;; Selecting another frame (a new `emacsclient' frame, or focus moving)
;; decides the icons again.
(add-hook 'window-selection-change-functions #'hellmacs-modeline--update-icons)
(add-hook 'server-after-make-frame-hook #'hellmacs-modeline--update-icons)
(add-function :after after-focus-change-function #'hellmacs-modeline--update-icons)

(add-hook 'hellmacs-first-buffer-hook #'hellmacs-modeline-enable)

(provide 'hellmacs-modeline)
;;; hellmacs-modeline.el ends here
