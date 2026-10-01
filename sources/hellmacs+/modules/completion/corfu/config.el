;;; completion/corfu/config.el -*- lexical-binding: t; -*-

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

;; In-buffer completion: a popup that appears as you type (corfu), fed
;; by extra completion sources (cape).
;;
;; Keys: the popup keeps stock keys working. `RET' inserts the candidate
;; only once you've picked one (`M-n'/`M-p', `<down>'/`<up>', `C-n'/`C-p');
;; otherwise it's a newline, as ever. `TAB' indents; `C-M-i' completes.
;; `M-g', `M-h' and `M-t' keep their stock meanings (corfu would take
;; them for the candidate's location, its documentation and the
;; documentation popup, which shows by itself after a moment). `M-SPC'
;; is corfu's, to type a space between orderless components.
;;
;; Flags:
;;   +tab  Make TAB complete when there's nothing to indent
;;         (`tab-always-indent' = complete), and complete the candidate
;;         in the popup. Off by default, since stock Emacs TAB only
;;         indents; `C-M-i' completes either way.

(when (modulep! +tab)
  (setq tab-always-indent 'complete))

(use-package corfu
  :defer 1
  :init
  (setq corfu-auto t
        corfu-auto-delay 0.15
        corfu-auto-prefix 2
        corfu-cycle t
        corfu-preselect 'prompt
        ;; The candidate's documentation beside the popup, about as soon
        ;; as an IDE shows it; quicker still as you move on.
        corfu-popupinfo-delay '(0.5 . 0.2))
  :config
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1)
  ;; Candidates you pick come first next time, across sessions: it
  ;; saves itself with savehist, which core turns on.
  (corfu-history-mode 1)
  (when (fboundp 'corfu-terminal-mode)
    ;; Only in terminal frames: graphical ones keep corfu's own popup.
    (corfu-terminal-mode 1))
  (hellmacs-corfu--stock-keys))

(use-package nerd-icons-corfu
  :after corfu
  :init
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(defvar corfu-map)
(defvar corfu-popupinfo-map)
(defvar corfu--index)

(defun hellmacs-corfu--insert-if-selected (&optional _)
  "`corfu-insert' when a candidate is selected, else nothing (a menu-item filter).
Nothing lets the key through to its stock command: RET's newline."
  (and (>= corfu--index 0) #'corfu-insert))

(defun hellmacs-corfu--stock-keys ()
  "Give back the stock keys corfu's popup takes (see the Commentary)."
  (keymap-set corfu-map "RET" '(menu-item "" nil :filter hellmacs-corfu--insert-if-selected))
  (unless (modulep! +tab)
    (keymap-unset corfu-map "TAB" t))
  (dolist (key '("M-g" "M-h"))
    (keymap-unset corfu-map key t))
  (keymap-unset corfu-popupinfo-map "M-t" t))
;; In a terminal, Emacs before 31 can't draw corfu's popup (a child
;; frame): `corfu-terminal' draws it there, and only there.

;; cape adds completion sources that work anywhere: file names
;; everywhere, and words from open buffers in prose. Modes with their
;; own completion (elisp, or a language server via `:tools lsp') still
;; come first; these are the fallbacks.
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'text-mode-hook
            (defun hellmacs-corfu--text-capfs-h ()
              (add-hook 'completion-at-point-functions #'cape-dabbrev 90 t))))
