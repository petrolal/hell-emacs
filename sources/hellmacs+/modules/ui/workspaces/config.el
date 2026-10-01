;;; ui/workspaces/config.el -*- lexical-binding: t; -*-

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

;; Workspaces / tabs built on Emacs' native `tab-bar-mode':
;; one tab per project on stock `C-x t` keys, with project isolation,
;; modern iconography, and infernal theming.

(require 'tab-bar)

(defgroup hellmacs-workspaces nil
  "Project workspaces and tab management for Hellmacs."
  :group 'hellmacs)

(defcustom hellmacs-workspaces-show 1
  "When to show the tab bar: 1 (always), t (only when >1 tabs), or nil (never)."
  :type '(choice (const :tag "Always" 1)
                 (const :tag "When multiple tabs" t)
                 (const :tag "Never" nil))
  :group 'hellmacs-workspaces)

(defcustom hellmacs-workspaces-icons t
  "Whether to show nerd-icons glyphs on workspace tabs when available."
  :type 'boolean
  :group 'hellmacs-workspaces)

(defun hellmacs-workspaces--project-name ()
  "Return the name of the current project, or nil if not in a project."
  (cond
   ((and (fboundp 'projectile-project-name)
         (fboundp 'projectile-project-p)
         (projectile-project-p))
    (projectile-project-name))
   ((and (fboundp 'project-current)
         (project-current))
    (file-name-nondirectory (directory-file-name (project-root (project-current)))))
   (t nil)))

(defun hellmacs-workspaces-tab-name ()
  "Generate a clean, informative name for the current workspace tab."
  (let* ((proj (hellmacs-workspaces--project-name))
         (buf (buffer-name (window-buffer (minibuffer-selected-window))))
         (icon (when (and hellmacs-workspaces-icons (fboundp 'nerd-icons-octicon))
                 (if proj
                     (nerd-icons-octicon "nf-oct-repo" :face 'nerd-icons-blue :height 0.85)
                   (nerd-icons-octicon "nf-oct-file" :face 'nerd-icons-silver :height 0.85)))))
    (if proj
        (format "%s %s" (or icon "") proj)
      (format "%s %s" (or icon "") (or buf "*scratch*")))))

(defun hellmacs-workspaces-open-project-tab (dir)
  "Open or switch to a dedicated tab for the project at DIR."
  (interactive
   (list (cond
          ((fboundp 'projectile-prompt-project-dir)
           (projectile-prompt-project-dir))
          ((fboundp 'project-prompt-project-dir)
           (project-prompt-project-dir))
          (t (read-directory-name "Project directory: ")))))
  (let* ((proj-name (file-name-nondirectory (directory-file-name (expand-file-name dir))))
         (tabs (tab-bar-tabs))
         (matching-tab (seq-find (lambda (tab)
                                   (let ((name (alist-get 'name tab)))
                                     (and name (string-match-p (regexp-quote proj-name) name))))
                                 tabs)))
    (if matching-tab
        (tab-bar-select-tab-by-name (alist-get 'name matching-tab))
      (tab-bar-new-tab)
      (let ((default-directory (file-name-as-directory (expand-file-name dir))))
        (if (fboundp 'consult-projectile-find-file)
            (call-interactively #'consult-projectile-find-file)
          (if (fboundp 'project-find-file)
              (call-interactively #'project-find-file)
            (dired default-directory)))))))

;; Configure tab-bar-mode
(setq tab-bar-show hellmacs-workspaces-show
      tab-bar-close-button-show nil
      tab-bar-tab-hints t
      tab-bar-tab-name-function #'hellmacs-workspaces-tab-name
      tab-bar-select-tab-modifiers '(meta)
      tab-bar-format '(tab-bar-format-history
                       tab-bar-format-tabs
                       tab-bar-separator
                       tab-bar-format-align-right
                       tab-bar-format-global))

;; Enable tab-bar-mode
(tab-bar-mode 1)

;; Stock Emacs C-x t prefix additions & workspace bindings
(keymap-set tab-prefix-map "p" #'hellmacs-workspaces-open-project-tab)
(keymap-set tab-prefix-map "RET" #'tab-bar-select-tab-by-name)

;; Toggles
(when (boundp 'hellmacs-toggle-map)
  (keymap-set hellmacs-toggle-map "w" #'tab-bar-mode)
  (keymap-set hellmacs-toggle-map "t" #'tab-bar-mode))

;; Workspace leader group under C-c w
(defvar-keymap hellmacs-workspace-map
  :doc "Hellmacs workspace keymap."
  "w" #'tab-bar-select-tab-by-name
  "n" #'tab-bar-new-tab
  "d" #'tab-bar-close-tab
  "p" #'hellmacs-workspaces-open-project-tab
  "r" #'tab-bar-rename-tab
  "." #'tab-bar-switch-to-next-tab
  "," #'tab-bar-switch-to-prev-tab)

(keymap-set global-map "C-c w" hellmacs-workspace-map)

;;; config.el ends here
