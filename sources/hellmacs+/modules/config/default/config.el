;;; config/default/config.el -*- lexical-binding: t; -*-

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

;; Hellmacs' default keybindings and the groups with no natural owning
;; feature module: `C-c h' (Hellmacs' own map, `hellmacs-prefix-map'),
;; `C-c q' (quit) and `C-c w' (built-in window commands). Feature modules fill their own groups,
;; e.g. `:completion vertico' owns `C-c f', `C-c b' and `C-c s'.

;; Emacs' own prefix keys that come without a name, so which-key would
;; show them as "+prefix". Names only; the keys are Emacs'. Some exist
;; only in newer Emacsen (`C-x w f' is 31's); a name for a key that
;; isn't there is never shown.
(defun hellmacs-default--name-stock-prefixes ()
  (hellmacs-which-key-labels
   nil
   "C-c ^"         "merge conflicts (smerge)"
   "C-x a"         "abbrevs"
   "C-x a i"       "inverse add abbrev"
   "C-x C-a"       "debugger (gud)"
   "C-x C-k C-q"   "quit macro if counter"
   "C-x C-k C-r"   "counter registers"
   "C-x C-k C-r a" "add counter to register if"
   "C-x n"         "narrow"
   "C-x p"         "project"
   "C-x p C-x"     "project buffers"
   "C-x r"         "registers, rectangles, bookmarks"
   "C-x RET"       "coding systems, input methods"
   "C-x t"         "tabs"
   "C-x t ^"       "detach"
   "C-x v"         "version control"
   "C-x v b"       "branches"
   "C-x v E"       "outgoing and edited"
   "C-x v M"       "since the merge base"
   "C-x v T"       "unintegrated"
   "C-x v T R"     "unintegrated with remote"
   "C-x v w"       "working trees"
   "C-x w"         "window layout"
   "C-x w ^"       "detach"
   "C-x w f"       "flip layout"
   "C-x w o"       "rotate windows"
   "C-x w r"       "rotate layout"
   "C-x x"         "buffer"
   "M-s h"         "highlight"
   ;; `C-x 8': insert a character, grouped by accent.
   "C-x 8"         "insert character"
   "C-x 8 \""      "¨ diaeresis"
   "C-x 8 '"       "´ acute"
   "C-x 8 )"       "˘ breve"
   "C-x 8 *"       "• symbols"
   "C-x 8 ,"       "¸ cedilla, ogonek"
   "C-x 8 ."       "˙ dot"
   "C-x 8 /"       "/ stroke, ligatures"
   "C-x 8 ="       "¯ macron"
   "C-x 8 = /"     "ǣ macron ligatures"
   "C-x 8 ^"       "ˆ circumflex"
   "C-x 8 ^ ^"     "ˇ caron"
   "C-x 8 _"       "– dashes, ≤ ≥"
   "C-x 8 `"       "` grave"
   "C-x 8 ~"       "˜ tilde"
   "C-x 8 1"       "† ½ ¼"
   "C-x 8 1 /"     "fractions"
   "C-x 8 2"       "‡"
   "C-x 8 3"       "¾"
   "C-x 8 3 /"     "fractions"
   "C-x 8 a"       "→ arrows, æ"
   "C-x 8 A"       "Æ"
   "C-x 8 e"       "emoji"
   "C-x 8 N"       "№"
   "C-x 8 O"       "Œ"))

(use-package which-key
  :defer 1
  :init
  (setq which-key-idle-delay 0.4
        which-key-sort-order 'which-key-key-order-alpha
        which-key-add-column-padding 1)
  :config
  (which-key-mode 1)
  (hellmacs-default--name-stock-prefixes))

;;; C-c h -- the infernal meta map ---------------------------------------------
;;
;; `hellmacs-prefix-map' is a named keymap, so you can also put it on a
;; key of your own:  (keymap-global-set "<f12>" hellmacs-prefix-map)
;; which-key labels use Hellmacs' own names: +altar/... for the splash
;; and memory, +forge/... for projects and the config, +crucible/... for
;; the REPL.

(defvar-keymap hellmacs-prefix-map
  :doc "Hellmacs' own commands, on `C-c h'."
  ;; `:ui dashboard' remaps `hellmacs-splash' to itself.
  "s" (cons (if (modulep! :ui dashboard) "+altar/dashboard" "+altar/return") #'hellmacs-splash)
  "c" (cons "+altar/reap" #'hellmacs-reap)
  "f" (cons "+forge/find-file" #'hellmacs-forge-find-file)
  "r" (cons "+crucible/reload" #'hellmacs-crucible-reload)
  "R" (cons "+forge/reload-config" #'hellmacs-reload)
  "S" (cons "+forge/sync" #'hellmacs-sync)
  "u" (cons "+forge/user-config" #'hellmacs-visit-user-dir)
  "v" (cons "+forge/hellmacs-dir" #'hellmacs-visit-dir)
  "m" (cons "+forge/modules" #'hellmacs-list-modules))

(keymap-set mode-specific-map "h" hellmacs-prefix-map)

;;; C-c q -----------------------------------------------------------------------

(hellmacs-leader-def
  "h"   "+hellmacs/forge"            ; labels the map bound just above
  "q"   "quit"
  "q q" '("quit emacs" . save-buffers-kill-terminal)
  "q r" '("restart emacs" . restart-emacs))

;;; C-c w -- windows -----------------------------------------------------------
;;
;; Built-in commands only. The defaults (`C-x 2', `C-x 3', `C-x 0',
;; `C-x 1', `C-x o') still work; this group gathers them in one place
;; and adds directional movement and window-layout undo.

(add-hook 'hellmacs-first-input-hook #'winner-mode)

(hellmacs-leader-def
  "w"   "window"
  "w s" '("split below" . split-window-below)
  "w v" '("split right" . split-window-right)
  "w d" '("delete window" . delete-window)
  "w m" '("maximize (delete others)" . delete-other-windows)
  "w o" '("other window" . other-window)
  "w =" '("balance windows" . balance-windows)
  "w b" '("window left" . windmove-left)
  "w f" '("window right" . windmove-right)
  "w p" '("window up" . windmove-up)
  "w n" '("window down" . windmove-down)
  "w u" '("undo layout" . winner-undo)
  "w r" '("redo layout" . winner-redo))
