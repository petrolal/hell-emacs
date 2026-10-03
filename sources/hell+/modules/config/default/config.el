;;; config/default/config.el -*- lexical-binding: t; -*-

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

;; Hell Emacs' default keybindings: `C-c h' (Hell Emacs' own map,
;; `hell-prefix-map') and the `C-c c' (code) label. Feature modules fill
;; their own groups, e.g. `:completion vertico' owns `C-c f' and `C-c s',
;; and `C-c l' is the localleader (`hell-localleader-def').
;;
;; Two layers, kept apart (13.5). Traditional: every stock key keeps its
;; meaning, and nothing is added inside Emacs' own prefixes (`C-x', `M-g',
;; `M-s', `C-x v', `C-x t'). Modern: Hell Emacs' and its packages' keys,
;; only under `C-c'. A `C-c' key never repeats a stock key's command --
;; the groups hold Hell Emacs' and its packages' commands only -- so
;; there is one way to each command, and the stock one wins. Emacs' own
;; commands keep their stock key, or `M-x' (`flymake-mode',
;; `windmove-left', `restart-emacs'...): Hell Emacs adds no key to them
;; (13.9). Installed packages keep their own
;; default keys as they ship them (13.6): nothing of theirs is rebound,
;; unset or moved.
;;
;; Stock keys get better built-in commands in place: `C-x C-b' is
;; ibuffer, `M-/' hippie-expand (dabbrev first, as before, then file
;; names, abbrevs and Lisp symbols).
;;
;; Flags:
;;   +repeat  Emacs' own `repeat-mode': after `C-x o', `C-x {', `M-g n',
;;            `C-x u' and the like, the last key alone repeats them
;;            (`C-x o o o'). Off by default: right after `C-x o', a plain
;;            `o' then switches windows instead of typing an `o'.

;; Emacs' own prefix keys that come without a name, so which-key would
;; show them as "+prefix". Names only; the keys are Emacs'. Some exist
;; only in newer Emacsen (`C-x w f' is 31's); a name for a key that
;; isn't there is never shown.
(defun hell-default--name-stock-prefixes ()
  (hell-which-key-labels
   nil
   "C-c ^"         "merge conflicts (smerge)"
   "C-c l"         "local (this mode)"
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
  (hell-default--name-stock-prefixes))

;;; Stock keys, better built-in commands -----------------------------------------

(keymap-global-set "<remap> <list-buffers>" #'ibuffer)
(keymap-global-set "<remap> <dabbrev-expand>" #'hippie-expand)

;; What stock `M-/' does comes first, so it still expands as it did;
;; the rest only when dabbrev runs out. No whole-line or list
;; expansions: those replace far more than the word at point.
(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
        try-expand-dabbrev-all-buffers
        try-expand-dabbrev-from-kill
        try-complete-file-name-partially
        try-complete-file-name
        try-expand-all-abbrevs
        try-complete-lisp-symbol-partially
        try-complete-lisp-symbol))

(when (modulep! +repeat)
  (add-hook 'hell-first-input-hook #'repeat-mode))

;;; C-c h -- the infernal meta map ---------------------------------------------
;;
;; `hell-prefix-map' is a named keymap, so you can also put it on a
;; key of your own:  (keymap-global-set "<f12>" hell-prefix-map)
;; which-key labels use Hell Emacs' own names: altar/... for the splash
;; and memory, forge/... for the config, crucible/... for the REPL. No
;; leading `+': which-key marks groups with it, and these are commands.
;; Finding a project's file is stock `C-x p f'; your config directory is
;; stock `C-x d', memory `M-x memory-report' / `M-x garbage-collect'.

(defvar-keymap hell-prefix-map
  :doc "Hell Emacs' own commands, on `C-c h'."
  "s" (cons "altar/splash" #'hell-splash)
  "r" (cons "crucible/reload" #'hell-crucible-reload)
  "R" (cons "forge/reload-config" #'hell-reload)
  "S" (cons "forge/sync" #'hell-sync-child)
  "i" (cons "forge/manual" #'hell-info-manual)
  "m" (cons "forge/describe-module" #'hell-describe-module)
  "M" (cons "forge/modules-list" #'hell-list-modules)
  "p" (cons "forge/plugins" #'hell-plugins)
  "h" (cons "forge/help" #'hell-help)
  "k" (cons "forge/where-is-intellij" #'hell-where-is-intellij))

(autoload 'hell-help "lib/help" "Open Hell Emacs JVM Help and shortcuts hub." t)
(autoload 'hell-info-manual "lib/help" "Open Hell Emacs Info manual." t)
(autoload 'hell-describe-module "lib/help" "Describe Hell Emacs module." t)
(autoload 'hell-plugins "hell-plugins" "Open Hell Emacs plugins manager." t)
(autoload 'hell-where-is-intellij "lib/intellij" "Look up IntelliJ IDEA keys in Hell Emacs." t)

(keymap-set mode-specific-map "h" hell-prefix-map)

(hell-leader-def
  "h" "hell")                    ; labels the map bound just above

;;; C-c c -- code ---------------------------------------------------------------
;;
;; What a language needs beyond the stock keys, which stay the way in:
;; `M-.' / `M-?' / `C-M-.' (definition, references, project symbols, fed
;; by the language server), `C-x p c' (build, which `:tools build' makes
;; the project's), `C-h .' (help at point). `:tools lsp' adds the server's
;; actions to this group in its buffers, and lsp-mode's whole map on
;; its own `s-l'; `C-c s e' jumps to a diagnostic.

(hell-leader-def
  "c"   "code")

;; Winner's layout undo, on its own `C-c <left>' / `C-c <right>'.
(add-hook 'hell-first-input-hook #'winner-mode)

;;; config.el ends here
