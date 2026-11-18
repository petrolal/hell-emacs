;;; ui/treemacs/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; Project file explorer via treemacs, as an ordinary window rather
;; than a locked IDE sidebar: `treemacs-display-in-side-window' is off,
;; so `C-x o' cycles into it, `C-x 0'/`C-x 1' close it like any other
;; window, and it resizes with the stock window commands.

;;; Code:

(declare-function treemacs "treemacs" (&optional arg))
(declare-function treemacs-start-on-boot "treemacs" (&optional focus-treemacs))
(declare-function treemacs-load-theme "treemacs" (name))
(declare-function treemacs-node-at-point "treemacs")
(declare-function treemacs-button-get "treemacs" (button prop))
(declare-function treemacs-workspace->is-empty? "treemacs-workspaces")
(declare-function treemacs--read-first-project-path "treemacs-core-utils" ())
(declare-function treemacs-follow-mode "treemacs-follow-mode" (&optional arg))
(declare-function treemacs-project-follow-mode "treemacs-project-follow-mode" (&optional arg))

(defcustom hell-treemacs-start-on-boot t
  "Whether to open the Treemacs project tree automatically at startup."
  :type 'boolean
  :group 'hell)

(defun hell-treemacs--first-project-path-a ()
  "Seed an empty Treemacs workspace from the current project or directory.
Avoids blocking a fresh installation's first startup with a minibuffer
`read-directory-name' prompt."
  (when (treemacs-workspace->is-empty?)
    (file-truename (or (when-let* ((proj (project-current)))
                         (project-root proj))
                       default-directory))))

(defun hell-treemacs--start-on-boot-h ()
  "Open Treemacs on boot only when starting directly in a Git project buffer.
Never opens Treemacs over an empty splash screen without an active project."
  (when (and hell-treemacs-start-on-boot
             (not noninteractive)
             (project-current nil)
             (not (get-buffer-window "*GNU Emacs*" t))
             (not (string= (buffer-name) "*GNU Emacs*")))
    (treemacs-start-on-boot)))

(defun hell-treemacs-dired-here ()
  "Open Dired on the directory of the treemacs node at point.
Treemacs stays read-only navigation; batch writes (including
`wdired') go through Dired on the node's directory."
  (interactive)
  (let* ((node (treemacs-node-at-point))
         (path (and node (treemacs-button-get node :path))))
    (unless path
      (user-error "No treemacs node at point"))
    (dired (if (file-directory-p path) path (file-name-directory path)))))

(use-package treemacs
  :defer t
  :commands (treemacs treemacs-start-on-boot)
  :init
  (hell-leader-def
    "o p" '("project tree" . treemacs))
  (add-hook 'window-setup-hook #'hell-treemacs--start-on-boot-h)
  :custom
  ;; Dock Treemacs as the left column in the 3-column Hell Emacs workspace layout.
  (treemacs-display-in-side-window t)
  (treemacs-position 'left)
  (treemacs-width 32)
  (treemacs-persist-file (hell-state-file "treemacs-persist"))
  (treemacs-last-error-persist-file (hell-state-file "treemacs-persist-at-last-error"))
  :config
  (defvar treemacs-mode-map)
  (keymap-set treemacs-mode-map "C-c C-d" #'hell-treemacs-dired-here)
  (advice-add #'treemacs--read-first-project-path :override
              #'hell-treemacs--first-project-path-a)
  (treemacs-follow-mode 1)
  (treemacs-project-follow-mode 1)
  (with-eval-after-load 'treemacs-nerd-icons
    (treemacs-load-theme "nerd-icons")))

(use-package treemacs-nerd-icons
  :after treemacs
  :defer t)

;; Error/warning icons on the tree, fed from lsp-mode's diagnostics
;; table (JDTLS and the rest) regardless of flymake being the visible
;; diagnostics backend; `:tools lsp' pulls lsp-treemacs in via
;; packages.el's `depends-on!' when this module is used.
(when (modulep! :tools lsp)
  (declare-function hell-lsp-mode-used-p "tools/lsp/config")
  (declare-function lsp-treemacs-sync-mode "lsp-treemacs")
  (declare-function lsp-treemacs-errors-list "lsp-treemacs")

  (use-package lsp-treemacs
    :after (treemacs lsp-mode)
    :defer t
    :init
    (hell-leader-def
      "o e" '("project errors" . lsp-treemacs-errors-list))
    :config
    (when (hell-lsp-mode-used-p)
      (lsp-treemacs-sync-mode 1))))

(provide 'ui-treemacs-config)
;;; config.el ends here
