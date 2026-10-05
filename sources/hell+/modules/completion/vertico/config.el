;;; completion/vertico/config.el -*- lexical-binding: t; -*-

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

;; Minibuffer completion: vertico (UI), orderless (matching),
;; marginalia (annotations), consult (commands).
;;
;; Owns the `C-c f' (file) and `C-c s' (search) leader groups, with only
;; what stock Emacs has no key for (13.5): finding, saving, switching and
;; killing buffers, `occur', imenu and bookmarks keep their stock keys
;; (`C-x C-f', `C-x C-s', `C-x b', `C-x k', `M-s o', `M-g i', `C-x r b').
;; `consult' remaps those stock commands -- `C-x b', `M-y', `M-g g' and
;; the rest keep their keys -- to its richer versions with previews.
;; Nothing is added inside Emacs' own `M-g' and `M-s' prefixes.

(hell-leader-def
  "f"   "file"
  "s"   "search")

;; Neither is needed before the first command: vertico turns on with it
;; (before any minibuffer opens), and orderless loads with the first
;; completion (its autoloads register the `orderless' style).
(use-package vertico
  :hook (hell-first-input . vertico-mode)
  :init
  (setq vertico-count 12
        vertico-cycle t))

(use-package orderless
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :hook (hell-first-input . marginalia-mode))

(use-package nerd-icons-completion
  :after marginalia
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
  :config
  (nerd-icons-completion-mode 1))

(use-package consult
  ;; consult is big; load it while idle so the first C-x b is instant.
  :defer-incrementally t
  :bind
  (;; Replace default commands everywhere they're bound -- `C-x b',
   ;; `C-x 4 b', `C-x 5 b', `C-x t b', `M-y', `M-g g', `M-g i', ...
   ;; -- rather than inventing new keys.
   ([remap switch-to-buffer]              . consult-buffer)
   ([remap switch-to-buffer-other-window] . consult-buffer-other-window)
   ([remap switch-to-buffer-other-frame]  . consult-buffer-other-frame)
   ([remap switch-to-buffer-other-tab]    . consult-buffer-other-tab)
   ([remap project-switch-to-buffer]      . consult-project-buffer)
   ([remap yank-pop]                      . consult-yank-pop)
   ([remap goto-line]                     . consult-goto-line)
   ([remap imenu]                         . consult-imenu)
   ([remap bookmark-jump]                 . consult-bookmark))
  :init
  (setq consult-narrow-key "<"
        consult-preview-key 'any)
  ;; `C-c s' has Doom's letters: s this buffer, p the project, f a file.
  (hell-leader-def
    "f r" '("recent file" . consult-recent-file)
    "s s" '("search buffer" . consult-line)
    "s p" '("search project" . consult-ripgrep)
    "s f" '("locate file" . consult-find)
    "s o" '("jump to heading" . consult-outline)
    "s e" '("jump to diagnostic" . consult-flymake)))
