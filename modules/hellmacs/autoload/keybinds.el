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
;; editing (see "Rules" in docs/roadmap.md). Its own
;; commands live under `C-c', the prefix Emacs reserves for users,
;; laid out like Doom's non-evil leader: `C-c h' Hellmacs, `C-c c'
;; code, `C-c f' file, `C-c b' buffer, `C-c s' search, `C-c t' toggle,
;; `C-c w' window, `C-c q' quit, and `C-c l' the localleader: the
;; commands of the current major mode (and of some minor modes), as
;; Doom's `doom-localleader-alt-key'.
;;
;; This file only provides the API every module and your own config.el
;; bind with: `hellmacs-leader-def' and `hellmacs-localleader-def'. It's
;; in core's own module (`:hellmacs', always enabled), as an autoload
;; file, as Doom keeps its keybinding API out of lisp/: it exists
;; whichever modules are enabled, and loads the first time something
;; binds a key. The default bindings themselves live in the `:config
;; default' module.
;;
;; No keybinding package is needed: Emacs 29's `keymap-set' covers
;; everything once there are no evil states to juggle.

;;; Code:

(defun hellmacs--define-keys (map prefix bindings)
  "Bind BINDINGS (KEY DEF ...) in MAP, as `hellmacs-leader-def' describes.
PREFIX is MAP's own key, for messages."
  (while bindings
    (let* ((key (pop bindings))
           (def (pop bindings))
           (old (keymap-lookup map key)))
      (keymap-set map key
                  (if (stringp def)
                      (progn
                        ;; A group label over a command would drop the command.
                        (when (and old (not (keymapp old)) (not (numberp old)))
                          (display-warning
                           'hellmacs
                           (format-message "`%s %s' was `%s'; it's now the group \"%s\""
                                           prefix key old def)))
                        ;; (LABEL . KEYMAP) is still a prefix to Emacs, and
                        ;; which-key displays LABEL for it.
                        (cons def (if (keymapp old) old (make-sparse-keymap))))
                    def)))))

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
  (hellmacs--define-keys mode-specific-map "C-c" bindings))

(defvar hellmacs-localleader-maps nil
  "Alist: mode -> its keymap on `C-c l', filled by `hellmacs-localleader-def'.")

(defun hellmacs-localleader--map (_binding)
  "The current buffer's `C-c l' map: those of its major mode and minor modes."
  (let (maps)
    (pcase-dolist (`(,mode . ,map) hellmacs-localleader-maps)
      (when (if (memq mode minor-mode-list)
                (and (boundp mode) (symbol-value mode))
              (derived-mode-p mode))
        (push map maps)))
    (if (cdr maps) (make-composed-keymap maps) (car maps))))

;;;###autoload
(defun hellmacs-localleader-def (modes &rest bindings)
  "Bind BINDINGS under `C-c l', the localleader, in buffers of MODES.

MODES is a mode or a list of them: a major mode (its derived modes
too, so list `java-mode' and `java-ts-mode' both, as neither derives
from the other) or a minor mode, where it's on. BINDINGS are as in
`hellmacs-leader-def', KEY relative to `C-c l':

  (hellmacs-localleader-def \='(java-mode java-ts-mode)
    \"b\" \='(\"build project\" . lsp-java-build-project))

`C-c l' holds the maps of every mode active in the buffer; outside
them it's unbound. The keys go into keymaps of Hellmacs' own, never
into the modes' maps."
  (unless (keymap-lookup mode-specific-map "l")
    (keymap-set mode-specific-map "l"
                '(menu-item "localleader" nil :filter hellmacs-localleader--map)))
  (dolist (mode (ensure-list modes))
    (let ((map (or (alist-get mode hellmacs-localleader-maps)
                   (setf (alist-get mode hellmacs-localleader-maps)
                         (make-sparse-keymap)))))
      (hellmacs--define-keys map "C-c l" bindings))))

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
