;;; modules/hellmacs/autoload/keybinds.el --- The C-c leader -*- lexical-binding: t; -*-

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

;; Hellmacs uses Emacs' default keybindings -- no evil, no modal
;; editing (see "Keybinding policy" in docs/roadmap.md). Its own
;; commands live under `C-c', the prefix Emacs reserves for users,
;; laid out like Doom's non-evil leader: `C-c h' Hellmacs, `C-c f'
;; file, `C-c b' buffer, `C-c s' search, `C-c w' window, `C-c q' quit.
;;
;; This file only provides `hellmacs-leader-def', which every module and
;; your own config.el use to bind into that layout. It's in core's own
;; module (`:hellmacs', always enabled), as an autoload file, as Doom
;; keeps its keybinding API out of lisp/: it exists whichever modules
;; are enabled, and loads the first time something binds a key. The
;; default bindings themselves live in the `:config default' module.
;;
;; No keybinding package is needed: Emacs 29's `keymap-set' covers
;; everything once there are no evil states to juggle.

;;; Code:

;;;###autoload
(defun hellmacs-leader-def (&rest bindings)
  "Bind BINDINGS, alternating KEY DEF pairs, under the `C-c' leader.

KEY is relative to `C-c', in `keymap-set' syntax (\"f f\" means
`C-c f f'). DEF is one of:
  - a command
  - (DESCRIPTION . COMMAND), to also give which-key a label
  - a string, to label KEY as a prefix group (\"file\" for `C-c f')

  (hellmacs-leader-def
    \"f\"   \"file\"
    \"f r\" \='(\"recent file\" . consult-recent-file))

Bindings go into `mode-specific-map', the keymap Emacs itself puts on
`C-c', so bindings made there by the user or by other packages keep
working alongside Hellmacs'."
  (while bindings
    (let ((key (pop bindings))
          (def (pop bindings)))
      (keymap-set mode-specific-map key
                  (if (stringp def)
                      ;; (LABEL . KEYMAP) is still a prefix to Emacs, and
                      ;; which-key displays LABEL for it.
                      (let ((map (keymap-lookup mode-specific-map key)))
                        (cons def (if (keymapp map) map (make-sparse-keymap))))
                    def)))))

(declare-function which-key-add-key-based-replacements "which-key")
(declare-function which-key-add-major-mode-key-based-replacements "which-key")

;;;###autoload
(defun hellmacs-which-key-labels (mode &rest bindings)
  "Name prefix keys for which-key, so none shows as \"+prefix\".
BINDINGS alternate KEY LABEL, KEY in `kbd' syntax (\"C-x r\"). With MODE
nil the names apply everywhere; else only in that major mode. Loads
which-key if it isn't yet, so call it from a hook or `after!', never at
startup. Only names: nothing is bound."
  (when (require 'which-key nil t)
    (if mode
        (apply #'which-key-add-major-mode-key-based-replacements mode bindings)
      (apply #'which-key-add-key-based-replacements bindings))))

(provide 'hellmacs-keybinds)
;;; keybinds.el ends here
