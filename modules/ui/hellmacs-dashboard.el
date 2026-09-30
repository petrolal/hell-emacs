;;; hellmacs-dashboard.el --- The infernal startup dashboard -*- lexical-binding: t; -*-

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

;; The `:ui dashboard' module (modules/ui/dashboard/ loads this file):
;; `dashboard' as the startup screen, in place of the Altar.
;;
;;   - The sigil banner: a picture in a graphical frame, the ASCII one
;;     in a terminal, dashboard's own text logo if a file is missing
;;     (`hellmacs-dashboard-banner').
;;   - The title, the "[ALTAR] Bound in ..." line, recent files (5),
;;     projects (5, from project.el) and bookmarks (3), and a footer
;;     that changes each time the dashboard is drawn.
;;   - Icons from nerd-icons in a graphical frame that has a font with
;;     them; plain text in a terminal unless `hellmacs-dashboard-tty-icons'.
;;
;; Keys are the stock ones: TAB and S-TAB move between items, RET opens
;; one, `g' redraws, `q' buries the buffer, and C-n/C-p/C-f/C-b move as
;; anywhere else. dashboard's own single-letter jumps (j, k, r, m, p,
;; 1-9, { }) and its "remove item" on DEL are taken out. `C-c h s' goes
;; back to it.
;;
;; Every state file it reads (recentf, bookmarks, the project list) is
;; already in the state directory (lisp/hellmacs.el).

;;; Code:

(require 'hellmacs-splash)

(defvar dashboard-mode-map)
(defvar dashboard-buffer-name)
(defvar dashboard-startup-banner)
(defvar dashboard-footer-messages)
(defvar dashboard-footer-icon)
(declare-function dashboard-insert-startupify-lists "dashboard")
(declare-function nerd-icons-sucicon "nerd-icons")

(defgroup hellmacs-dashboard nil
  "The Hellmacs startup dashboard."
  :group 'hellmacs)

(defcustom hellmacs-dashboard-tty-icons nil
  "Whether to draw nerd-icons in a terminal frame.
A terminal can't tell Emacs which font it uses, so this is off: turn
it on if your terminal's font is a Nerd Font."
  :type 'boolean)

(defconst hellmacs-dashboard-title "HELLMACS: THE INFERNAL JVM HACKING ENVIRONMENT"
  "The line under the banner.")

(defconst hellmacs-dashboard-footers
  '("BYTECODE SUBJUGATED // REPL FIRED"
    "MAMMON FORGE: HEAP CONSUMED, CODES SMELTED"
    "THE JVM ALTAR STANDS READY")
  "The footer lines, shown in turn: a different one each time it is drawn.")

(defvar hellmacs-dashboard--footer-index -1
  "Index in `hellmacs-dashboard-footers' of the footer last drawn.")

(defconst hellmacs-dashboard-assets-dir (expand-file-name "assets/" hellmacs-dir)
  "Where the banner files are.")

(defconst hellmacs-dashboard-images '("banner-960.png" "banner.png" "banner.svg")
  "Graphical banners, in order of preference.
banner-960.png is banner.png scaled down: decoding the full 2816x1536
file takes 75-100ms, the copy 7ms (docs/roadmap.md, 9.2).")

(defconst hellmacs-dashboard-text-banner "banner-ascii.txt"
  "The banner drawn in a terminal.")

;;; Choosing the banner -----------------------------------------------------

(defun hellmacs-dashboard--asset (name)
  "The absolute path of asset NAME, or nil if it doesn't exist."
  (let ((file (expand-file-name name hellmacs-dashboard-assets-dir)))
    (and (file-readable-p file) file)))

(defun hellmacs-dashboard--image ()
  "The first graphical banner that exists and this Emacs can draw, or nil."
  (seq-some (lambda (name)
              (when-let* ((file (hellmacs-dashboard--asset name)))
                (and (image-type-available-p
                      (if (string-suffix-p ".svg" name) 'svg 'png))
                     file)))
            hellmacs-dashboard-images))

(defun hellmacs-dashboard-banner (&optional frame)
  "The `dashboard-startup-banner' value for FRAME (default: the selected one).
A graphical frame gets the picture (and the text banner as a
fallback), a terminal the text banner; with neither file, dashboard's
own ASCII logo. It never signals an error, even with no assets."
  (condition-case nil
      (let ((image (and (display-graphic-p frame) (hellmacs-dashboard--image)))
            (text (hellmacs-dashboard--asset hellmacs-dashboard-text-banner)))
        (if (and image text) (cons image text) (or image text 'ascii)))
    (error 'ascii)))

;;; What is drawn --------------------------------------------------------------

(defun hellmacs-dashboard--next-footer ()
  "Advance to the next footer and return it."
  (setq hellmacs-dashboard--footer-index
        (% (1+ hellmacs-dashboard--footer-index) (length hellmacs-dashboard-footers)))
  (nth hellmacs-dashboard--footer-index hellmacs-dashboard-footers))

(defun hellmacs-dashboard-icons-p (&optional frame)
  "Non-nil if FRAME (default: the selected one) should show icons.
See `hellmacs-icons-p' and `hellmacs-dashboard-tty-icons'."
  (hellmacs-icons-p hellmacs-dashboard-tty-icons frame))

(defun hellmacs-dashboard--prepare-h ()
  "Set what depends on the frame and on the moment, before each drawing."
  (let ((icons (and (hellmacs-dashboard-icons-p) (require 'nerd-icons nil t))))
    ;; Decided once per drawing: dashboard asks for every heading and item.
    (setq dashboard-display-icons-p (and icons t)
          dashboard-startup-banner (hellmacs-dashboard-banner)
          dashboard-footer-messages (list (hellmacs-dashboard--next-footer))
          ;; nerd-icons is loaded only for a frame that draws icons: a
          ;; plain `setq', since the option's setter would load it.
          dashboard-icon-type (and icons 'nerd-icons)
          dashboard-footer-icon
          (if icons
              (nerd-icons-sucicon "nf-custom-emacs" :face 'dashboard-footer-icon-face)
            (propertize ">" 'face 'dashboard-footer-icon-face)))))

;;; Keys ---------------------------------------------------------------------

(defconst hellmacs-dashboard-removed-keys
  '("j" "k" "{" "}" "1" "2" "3" "4" "5" "6" "7" "8" "9"
    "C-n" "C-p" "<up>" "<down>" "DEL" "<backspace>" "<delete>")
  "Keys dashboard binds that Hellmacs takes out of `dashboard-mode-map'.
Single-letter jumps aren't stock Emacs keys, C-n/C-p and the arrows
go back to their global commands, and DEL removed the item at point.")

(defun hellmacs-dashboard--vanilla-keys ()
  "Take the non-stock keys out of `dashboard-mode-map'."
  (dolist (key hellmacs-dashboard-removed-keys)
    (keymap-unset dashboard-mode-map key t)))

;;; Showing it -----------------------------------------------------------------

(use-package dashboard
  :defer t
  :init
  ;; Set before dashboard loads: several of its defaults are computed
  ;; when it does. `dashboard-icon-type' stays nil until a frame draws
  ;; icons (see `hellmacs-dashboard--prepare-h'): its setter loads
  ;; nerd-icons (18ms), which a terminal never uses.
  (setq dashboard-icon-type nil
        dashboard-heading-icons '((recents . "nf-oct-history")
                                  (bookmarks . "nf-oct-bookmark")
                                  (projects . "nf-oct-rocket"))
        dashboard-display-icons-p nil   ; set per drawing, see above
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-footer-icon ">"
        dashboard-banner-logo-title hellmacs-dashboard-title
        dashboard-init-info #'hellmacs-splash-startup-line
        dashboard-image-banner-max-width 480
        dashboard-image-banner-max-height 320
        dashboard-center-content t
        dashboard-vertically-center-content t
        dashboard-items '((recents . 5) (projects . 5) (bookmarks . 3))
        dashboard-projects-backend 'project-el
        dashboard-item-shortcuts nil    ; no r/p/m jump keys
        dashboard-show-shortcuts nil)
  :config
  (hellmacs-dashboard--vanilla-keys)
  (add-hook 'dashboard-before-initialize-hook #'hellmacs-dashboard--prepare-h))

(defvar hellmacs-dashboard--window-setup-done nil
  "Non-nil once startup's `window-setup-hook' has run.")

(defun hellmacs-dashboard-buffer ()
  "Return the dashboard buffer, drawn for the selected frame.
During startup it is only drawn once it is in a window (from
`window-setup-hook'), where it can center itself: one drawing, not two."
  (require 'dashboard)
  (let ((buffer (get-buffer-create dashboard-buffer-name)))
    (with-current-buffer buffer
      (if (or hellmacs-dashboard--window-setup-done noninteractive)
          (dashboard-insert-startupify-lists t)
        (unless (derived-mode-p 'dashboard-mode)
          (dashboard-mode))))
    buffer))

;;;###autoload
(defun hellmacs-dashboard ()
  "Show the Hellmacs dashboard."
  (interactive)
  (require 'dashboard)
  (switch-to-buffer (get-buffer-create dashboard-buffer-name))
  ;; Drawn once it's in a window, so it centers itself in it.
  (dashboard-insert-startupify-lists t))

(defun hellmacs-dashboard--startup-buffer ()
  "The startup screen: the dashboard, or the Altar if it fails.
Also used for each new `emacsclient -c' frame, so the banner and icons
suit that frame; `hellmacs-splash--initial-buffer' decides when."
  (condition-case err
      (hellmacs-dashboard-buffer)
    (error
     (display-warning 'hellmacs (format "The dashboard failed, showing the Altar: %s"
                                        (error-message-string err)))
     (hellmacs-splash-buffer))))

(setq hellmacs-splash-buffer-function #'hellmacs-dashboard--startup-buffer)

;; `C-c h s' (`hellmacs-splash', in :config default) goes to the dashboard.
(keymap-set global-map "<remap> <hellmacs-splash>" #'hellmacs-dashboard)

(defun hellmacs-dashboard--redraw-h (&rest _)
  "Redraw the dashboard where it is shown, e.g. now that startup time is known."
  (when-let* ((name (bound-and-true-p dashboard-buffer-name))
              (buffer (get-buffer name))
              (window (get-buffer-window buffer t)))
    (with-selected-window window
      (dashboard-insert-startupify-lists t))))

;; Startup time is known once every package is activated, which can be
;; after the dashboard is first drawn; the first window it lands in is
;; only known after startup too.
(add-hook 'hellmacs-after-init-hook #'hellmacs-dashboard--redraw-h)
(add-hook 'window-setup-hook
          (defun hellmacs-dashboard--window-setup-h ()
            (setq hellmacs-dashboard--window-setup-done t)
            (hellmacs-dashboard--redraw-h)))

(provide 'hellmacs-dashboard)
;;; hellmacs-dashboard.el ends here
