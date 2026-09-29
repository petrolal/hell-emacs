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

(use-package which-key
  :defer 1
  :init
  (setq which-key-idle-delay 0.4
        which-key-sort-order 'which-key-key-order-alpha
        which-key-add-column-padding 1)
  :config
  (which-key-mode 1))

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
