;;; ui/workspaces/config.el -*- lexical-binding: t; -*-

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

;; Workspaces / tabs built on Emacs' native `tab-bar-mode':
;; one tab per project, with project isolation, modern iconography, and
;; infernal theming. Tabs keep their stock `C-x t' keys (`C-x t 2' new,
;; `C-x t 0' close, `C-x t o' next, `C-x t RET' switch, `C-x t p p' a
;; project in a new tab); the module adds no command or key (13.7).

(require 'tab-bar)

(defgroup hell-workspaces nil
  "Project workspaces and tab management for Hell Emacs."
  :group 'hell)

(defcustom hell-workspaces-show 1
  "When to show the tab bar: 1 (always), t (only when >1 tabs), or nil (never)."
  :type '(choice (const :tag "Always" 1)
                 (const :tag "When multiple tabs" t)
                 (const :tag "Never" nil))
  :group 'hell-workspaces)

(defcustom hell-workspaces-icons t
  "Whether to show nerd-icons glyphs on workspace tabs when available."
  :type 'boolean
  :group 'hell-workspaces)

(defun hell-workspaces--project-name ()
  "Return the name of the current project, or nil if not in a project."
  (cond
   ((and (fboundp 'project-current)
         (project-current))
    (file-name-nondirectory (directory-file-name (project-root (project-current)))))
   (t nil)))

(defun hell-workspaces-tab-name ()
  "Generate a clean, informative name for the current workspace tab."
  (let* ((proj (hell-workspaces--project-name))
         (buf (buffer-name (window-buffer (minibuffer-selected-window))))
         (icon (when (and hell-workspaces-icons (fboundp 'nerd-icons-octicon))
                 (if proj
                     (nerd-icons-octicon "nf-oct-repo" :face 'nerd-icons-blue :height 0.85)
                   (nerd-icons-octicon "nf-oct-file" :face 'nerd-icons-silver :height 0.85)))))
    (if proj
        (format "%s %s" (or icon "") proj)
      (format "%s %s" (or icon "") (or buf "*scratch*")))))


(setq tab-bar-close-button-show nil
      tab-bar-tab-hints t
      tab-bar-tab-name-function #'hell-workspaces-tab-name
      tab-bar-format '(tab-bar-format-history
                       tab-bar-format-tabs
                       tab-bar-separator
                       tab-bar-format-align-right
                       tab-bar-format-global))

;; `hell-workspaces-show' and `tab-bar-mode' wait for the user's own
;; config.el (loaded after this module) to have had a chance to
;; `setq' or customize `hell-workspaces-show'; `tab-bar-show' also has
;; a `:set' function (it updates frames with tabs already showing),
;; which a plain `setq' here would skip.
(defun hell-workspaces--enable-h ()
  "Turn on `tab-bar-mode' with `hell-workspaces-show' applied."
  (customize-set-variable 'tab-bar-show hell-workspaces-show)
  (tab-bar-mode 1))

(add-hook 'emacs-startup-hook #'hell-workspaces--enable-h)

;;; config.el ends here
