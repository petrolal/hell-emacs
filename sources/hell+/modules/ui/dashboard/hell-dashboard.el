;;; hell-dashboard.el --- The infernal startup dashboard -*- lexical-binding: t; -*-

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

;; Custom Infernal Startup Dashboard powered by emacs-dashboard and nerd-icons:
;; - Crimson & Dark Slate palette (#15161b, #ff5555, #ffb86c, #bd93f9)
;; - Graphical banner framing and centering
;; - Quick-action navigator buttons (Ignite File, Summon Project, Recent Grimoires, Hell Shell)
;; - Recent files, projects, and bookmarks with nerd-icons
;; - Dynamic telemetry footer with garbage collection statistics

(require 'hell-splash (expand-file-name "hell/+splash" hell-modules-dir))
(require 'subr-x)

(defvar dashboard-mode-map)
(defvar dashboard-buffer-name)
(defvar dashboard-startup-banner)
(defvar dashboard-footer-messages)
(defvar dashboard-footer-icon)
(defvar dashboard-navigator-buttons)
(declare-function dashboard-insert-startupify-lists "dashboard")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function nerd-icons-faicon "nerd-icons")
(declare-function nerd-icons-octicon "nerd-icons")
(declare-function nerd-icons-codicon "nerd-icons")

(defgroup hell-dashboard nil
  "The Hell Emacs startup dashboard."
  :group 'hell)

(defcustom hell-dashboard-tty-icons nil
  "Whether to draw nerd-icons in a terminal frame."
  :type 'boolean
  :group 'hell-dashboard)

(defconst hell-dashboard-assets-dir (expand-file-name "assets/" hell-dir)
  "Where the banner files are.")

(defconst hell-dashboard-images
  '("banners/banner-960.png" "banners/banner.png" "banners/banner.svg" "banner-960.png" "banner.png" "banner.svg")
  "Graphical banners, in order of preference.")

;;; Banner resolution --------------------------------------------------------

(defun hell-dashboard--asset (name)
  "The absolute path of asset NAME, or nil if it doesn't exist."
  (let ((file (expand-file-name name hell-dashboard-assets-dir)))
    (and (file-readable-p file) file)))

(defun hell-dashboard--image ()
  "The first graphical banner that exists and this Emacs can draw, or nil."
  (seq-some (lambda (name)
              (when-let* ((file (hell-dashboard--asset name)))
                (and (image-type-available-p
                      (if (string-suffix-p ".svg" name) 'svg 'png))
                     file)))
            hell-dashboard-images))

(defun hell-dashboard-banner (&optional frame)
  "The `dashboard-startup-banner' value for FRAME (default: the selected one)."
  (condition-case nil
      (or (and (display-graphic-p frame) (hell-dashboard--image))
          'ascii)
    (error 'ascii)))

;;; Dynamic Footer & Navigator -----------------------------------------------

(defun hell-dashboard-footer-message ()
  "Construct dynamic infernal footer referencing benchmark telemetry."
  (let ((init-sec (or hell-init-time
                      (and (boundp 'after-init-time) (boundp 'before-init-time)
                           after-init-time before-init-time
                           (float-time (time-subtract after-init-time before-init-time)))
                      0.10))
        (gcs (or (bound-and-true-p hell-splash--init-gcs) gcs-done)))
    (format "HELL EMACS // [ JVM FORGE IGNITED ] // Bytecode subjugated.\n[ALTAR] Bound in %.2f seconds with %d garbage collection%s."
            init-sec gcs (if (= gcs 1) "" "s"))))

(defun hell-dashboard--navigator ()
  "Construct the infernal navigator quick-access buttons."
  (let ((has-icons (and (display-graphic-p) (require 'nerd-icons nil t))))
    `(((,(if has-icons
             (nerd-icons-faicon "nf-fa-fire" :face '(:foreground "#ff5555"))
           "🔥")
        "Ignite File"
        "Find file in altar"
        (lambda (&rest _) (call-interactively #'find-file))
        'nerd-icons-red)
       (,(if has-icons
             (nerd-icons-octicon "nf-oct-repo" :face '(:foreground "#ffb86c"))
           "📁")
        "Summon Project"
        "Open registered project"
        (lambda (&rest _)
          (if (fboundp 'consult-projectile)
              (call-interactively #'consult-projectile)
            (if (fboundp 'projectile-switch-project)
                (call-interactively #'projectile-switch-project)
              (call-interactively #'project-switch-project))))
        'nerd-icons-orange)
       (,(if has-icons
             (nerd-icons-faicon "nf-fa-skull" :face '(:foreground "#bd93f9"))
           "💀")
        "Recent Grimoires"
        "Switch to recent buffer or grimoire"
        (lambda (&rest _)
          (if (fboundp 'consult-buffer)
              (call-interactively #'consult-buffer)
            (call-interactively #'switch-to-buffer)))
        'nerd-icons-purple)
       (,(if has-icons
             (nerd-icons-codicon "nf-cod-terminal_bash" :face '(:foreground "#50fa7b"))
           "⚡")
        "Hell Shell"
        "Open vterm / eshell terminal"
        (lambda (&rest _)
          (cond ((fboundp 'vterm) (vterm))
                (t (eshell))))
        'nerd-icons-green)))))

(defun hell-dashboard-icons-p (&optional frame)
  "Non-nil if FRAME (default: the selected one) should show icons."
  (hell-icons-p hell-dashboard-tty-icons frame))

(defun hell-dashboard--prepare-h ()
  "Configure dynamic values before drawing dashboard."
  (let ((icons (and (hell-dashboard-icons-p) (require 'nerd-icons nil t))))
    (setq dashboard-display-icons-p (and icons t)
          dashboard-startup-banner (hell-dashboard-banner)
          dashboard-footer-messages (list (hell-dashboard-footer-message))
          dashboard-icon-type (and icons 'nerd-icons)
          dashboard-navigator-buttons (hell-dashboard--navigator))))

;;; Dashboard Configuration --------------------------------------------------

(use-package dashboard
  :defer t
  :init
  (setq dashboard-banner-logo-title nil
        dashboard-startup-banner (hell-dashboard-banner)
        dashboard-image-banner-max-height 280
        dashboard-image-banner-max-width 480
        dashboard-center-content t
        dashboard-vertically-center-content nil
        dashboard-show-shortcuts t
        dashboard-display-icons-p t
        dashboard-icon-type 'nerd-icons
        dashboard-set-file-icons t
        dashboard-set-heading-icons t
        dashboard-heading-icons '((recents   . "nf-oct-history")
                                  (bookmarks . "nf-oct-bookmark")
                                  (projects  . "nf-oct-rocket")
                                  (agenda    . "nf-oct-calendar"))
        dashboard-items '((recents   . 5)
                          (projects  . 4)
                          (bookmarks . 3))
        dashboard-projects-backend (if (modulep! :tools projectile) 'projectile 'project-el)
        dashboard-footer-icon ""
        dashboard-footer-messages (list (hell-dashboard-footer-message))
        dashboard-navigator-buttons (hell-dashboard--navigator))
  :config
  (add-hook 'dashboard-before-initialize-hook #'hell-dashboard--prepare-h)
  ;; Custom infernal face styling
  (custom-set-faces
   '(dashboard-heading ((t (:foreground "#ff5555" :weight bold :height 1.1))))
   '(dashboard-items-face ((t (:foreground "#f8f8f2"))))
   '(dashboard-footer ((t (:foreground "#ffb86c" :height 0.9))))
   '(dashboard-no-items-face ((t (:foreground "#6272a4"))))))

(defvar hell-dashboard--window-setup-done nil
  "Non-nil once startup's `window-setup-hook' has run.")

(defun hell-dashboard-buffer ()
  "Return the dashboard buffer, drawn for the selected frame."
  (require 'dashboard)
  (let ((buffer (get-buffer-create dashboard-buffer-name)))
    (with-current-buffer buffer
      (if (or hell-dashboard--window-setup-done noninteractive)
          (dashboard-insert-startupify-lists t)
        (unless (derived-mode-p 'dashboard-mode)
          (dashboard-mode))))
    buffer))

;;;###autoload
(defun hell-dashboard ()
  "Show the Hell Emacs dashboard."
  (interactive)
  (require 'dashboard)
  (switch-to-buffer (get-buffer-create dashboard-buffer-name))
  (dashboard-insert-startupify-lists t))

(defun hell-dashboard--startup-buffer ()
  "The startup screen: the dashboard, or the Altar if it fails."
  (condition-case err
      (hell-dashboard-buffer)
    (error
     (display-warning 'hell (format "The dashboard failed, showing the Altar: %s"
                                    (error-message-string err)))
     (hell-splash-buffer))))

(setq hell-splash-buffer-function #'hell-dashboard--startup-buffer)

;; `C-c h s' goes to the dashboard
(keymap-set global-map "<remap> <hell-splash>" #'hell-dashboard)

(defun hell-dashboard--redraw-h (&rest _)
  "Redraw the dashboard where it is shown."
  (when-let* ((name (bound-and-true-p dashboard-buffer-name))
              (buffer (get-buffer name))
              (window (get-buffer-window buffer t)))
    (with-selected-window window
      (dashboard-insert-startupify-lists t))))

(add-hook 'hell-after-init-hook #'hell-dashboard--redraw-h)
(add-hook 'window-setup-hook
          (defun hell-dashboard--window-setup-h ()
            (setq hell-dashboard--window-setup-done t)
            (hell-dashboard--redraw-h)))

(provide 'hell-dashboard)
;;; hell-dashboard.el ends here
