;;; hellmacs/+splash.el --- The Altar: Hellmacs' startup screen -*- lexical-binding: t; -*-

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

;; Replaces the GNU splash screen with the Altar: a modern, visual
;; startup hub showing the Hellmacs sigil/banner, JVM tagline,
;; startup telemetry, and clickable quick-start buttons.

(require 'button)
(require 'image)
(require 'subr-x)

(defvar hellmacs-dir)
(defvar hellmacs-profile)
(defvar hellmacs-init-time)

(defgroup hellmacs-splash nil
  "The Hellmacs startup screen."
  :group 'hellmacs)

(defcustom hellmacs-splash-enable t
  "Whether Emacs starts on the Altar (`*hellmacs*') instead of *scratch*."
  :type 'boolean
  :group 'hellmacs-splash)

;; Faces
(defface hellmacs-splash-sigil '((t (:inherit error :weight bold)))
  "Face for the splash screen's ASCII sigil.")

(defface hellmacs-splash-tagline '((t (:inherit warning :weight bold)))
  "Face for the splash screen's tagline.")

(defface hellmacs-splash-altar '((t (:inherit success :weight bold)))
  "Face for the splash screen's startup-time line.")

(defface hellmacs-splash-hint '((t (:inherit shadow)))
  "Face for the splash screen's key hints.")

(defface hellmacs-splash-button
  '((t (:inherit custom-button
        :box (:line-width (1 . 1) :color "#3f444a")
        :background "#1c1e24"
        :foreground "#bbc2cf")))
  "Face for interactive quick-start buttons on the Altar.")

(defface hellmacs-splash-button-active
  '((t (:inherit custom-button-mouse
        :box (:line-width (1 . 1) :color "#da8548")
        :background "#282c34"
        :foreground "#ecbe7b"
        :weight bold)))
  "Face for active/focused buttons on the Altar.")

(defconst hellmacs-splash-buffer-name "*hellmacs*"
  "Name of the splash screen buffer.")

(defconst hellmacs-splash-sigil
  '("|`-._                                   _.-'|"
    " \\    `-._      /\\            /\\    _.-'    /"
    "  `-.     `-.  /  \\__________/  \\  .-'     .-'"
    "     `-.     `|  /\\          /\\  |'     .-'"
    "        `-.   | /  \\        /  \\ |   .-'"
    "           `-.|                  |.-'"
    "              |   <@>      <@>   |"
    "              |        /\\        |"
    "               \\    \\__/\\__/    /"
    "                `-._[||||||]_.-'"
    "                    `-.__.-'")
  "The horned cyber-cat ASCII sigil.")

(defconst hellmacs-splash-tagline
  (if (and (boundp 'hellmacs-profile) hellmacs-profile)
      (format "HELLMACS [%s] // [ JVM FORGE IGNITED ] // Heavy metal syntax. Bytecode subjugated."
              (upcase hellmacs-profile))
    "HELLMACS // [ JVM FORGE IGNITED ] // Heavy metal syntax. Bytecode subjugated.")
  "The line under the sigil.")

(defvar hellmacs-splash--init-gcs nil
  "`gcs-done' when startup finished.")

(add-hook 'hellmacs-after-init-hook
          (defun hellmacs-splash--record-gcs-h ()
            (setq hellmacs-splash--init-gcs gcs-done))
          -90)

(defun hellmacs-splash-startup-line ()
  "Return the line saying how long startup took, or a placeholder before."
  (if hellmacs-init-time
      (let ((gcs (or hellmacs-splash--init-gcs gcs-done)))
        (format "[ALTAR] Bound in %.2f seconds with %d garbage collection%s."
                hellmacs-init-time gcs (if (= gcs 1) "" "s")))
    "[ALTAR] Binding..."))

(defun hellmacs-splash--insert-centered (text face width)
  "Insert TEXT in FACE, centered in WIDTH columns, then a newline."
  (insert (make-string (max 0 (/ (- width (string-width text)) 2)) ?\s)
          (propertize text 'face face)
          "\n"))

(defun hellmacs-splash--banner-image ()
  "Return graphical banner image object if available and display is graphical."
  (when (and (display-graphic-p) (image-type-available-p 'png))
    (let* ((assets-dir (expand-file-name "assets/" hellmacs-dir))
           (candidates '("banner-960.png" "banner.png" "banner.svg"))
           (file (seq-some (lambda (f)
                             (let ((path (expand-file-name f assets-dir)))
                               (and (file-readable-p path) path)))
                           candidates)))
      (when file
        (create-image file (if (string-suffix-p ".svg" file) 'svg 'png) nil
                      :max-width 540
                      :max-height 280)))))

(defun hellmacs-splash--button (label action help &optional icon)
  "Insert an interactive button showing LABEL and ICON that calls ACTION."
  (let ((display-text (if icon (format " %s %s " icon label) (format " %s " label))))
    (insert-text-button display-text
                        'action (lambda (_) (call-interactively action))
                        'follow-link t
                        'help-echo help
                        'face 'hellmacs-splash-button
                        'mouse-face 'hellmacs-splash-button-active)))

(defun hellmacs-splash--icon (name fallback)
  "Get nerd-icons icon NAME or return FALLBACK."
  (if (and (fboundp 'nerd-icons-octicon) (display-graphic-p))
      (condition-case nil
          (nerd-icons-octicon name :height 0.95)
        (error fallback))
    fallback))

(defun hellmacs-splash--render ()
  "Draw the splash screen into the current buffer, centered in its window."
  (let* ((inhibit-read-only t)
         (window (get-buffer-window (current-buffer)))
         (width (if window (window-width window) (frame-width)))
         (height (if window (window-body-height window) (frame-height)))
         (img (hellmacs-splash--banner-image)))
    (erase-buffer)
    (if img
        (let* ((img-size (image-size img))
               (img-cols (ceiling (car img-size)))
               (img-lines (ceiling (cdr img-size)))
               (content-height (+ img-lines 9))
               (top-margin (max 0 (/ (- height content-height) 3)))
               (left-margin (max 0 (/ (- width img-cols) 2))))
          (insert (make-string top-margin ?\n))
          (insert (make-string left-margin ?\s))
          (insert-image img)
          (insert "\n\n"))
      ;; Fallback ASCII Sigil
      (let* ((sigil-width (apply #'max (mapcar #'string-width hellmacs-splash-sigil)))
             (sigil-indent (make-string (max 0 (/ (- width sigil-width) 2)) ?\s))
             (content-height (+ (length hellmacs-splash-sigil) 8))
             (top-margin (max 0 (/ (- height content-height) 3))))
        (insert (make-string top-margin ?\n))
        (dolist (line hellmacs-splash-sigil)
          (insert sigil-indent (propertize line 'face 'hellmacs-splash-sigil) "\n"))
        (insert "\n")))

    (hellmacs-splash--insert-centered hellmacs-splash-tagline 'hellmacs-splash-tagline width)
    (hellmacs-splash--insert-centered (hellmacs-splash-startup-line) 'hellmacs-splash-altar width)
    (insert "\n")

    ;; Interactive Button Hub (Two clean rows with icons)
    (let* ((row1 `(("scratch" scratch-buffer "Open *scratch* buffer"
                    ,(hellmacs-splash--icon "nf-oct-file_code" "📄"))
                   ("find file" find-file "Find file (C-x C-f)"
                    ,(hellmacs-splash--icon "nf-oct-search" "🔍"))
                   ("recent files" hellmacs-splash-recent-files "Recent files"
                    ,(hellmacs-splash--icon "nf-oct-history" "🕒"))
                   ("project" project-switch-project "Switch project (C-x p p)"
                    ,(hellmacs-splash--icon "nf-oct-rocket" "🚀"))
                   ("dired" dired-jump "File manager (C-x d / C-x C-j)"
                    ,(hellmacs-splash--icon "nf-oct-file_directory" "📁"))))
           (row2 `(("tutorial" help-with-tutorial "Official Emacs tutorial (C-h t)"
                    ,(hellmacs-splash--icon "nf-oct-mortar_board" "🎓"))
                   ("manual" hellmacs-info-manual "Hellmacs Info manual (C-c h i)"
                    ,(hellmacs-splash--icon "nf-oct-book" "📖"))
                   ("guided tour" hellmacs-splash-guided-tour "Guided tour of GNU Emacs"
                    ,(hellmacs-splash--icon "nf-oct-globe" "🌐"))
                   ("customize" customize "Customize Emacs settings"
                    ,(hellmacs-splash--icon "nf-oct-gear" "⚙"))
                   ("intellij keys" hellmacs-where-is-intellij "IntelliJ key finder (C-c h k)"
                    ,(hellmacs-splash--icon "nf-oct-light_bulb" "💡"))))
           (gap "   "))
      (dolist (buttons (list row1 row2))
        (let ((row-width (+ (apply #'+ (mapcar (lambda (b) (+ (string-width (nth 0 b)) 4 (string-width (nth 3 b)))) buttons))
                            (* (string-width gap) (1- (length buttons))))))
          (insert (make-string (max 0 (/ (- width row-width) 2)) ?\s))
          (dolist (b buttons)
            (hellmacs-splash--button (nth 0 b) (nth 1 b) (nth 2 b) (nth 3 b))
            (unless (eq b (car (last buttons)))
              (insert gap)))
          (insert "\n\n"))))

    (hellmacs-splash--insert-centered
     "TAB/Shift-TAB navigate buttons · RET activate · C-x C-f find file · C-c h i manual · q close"
     'hellmacs-splash-hint width)
    (goto-char (point-min))
    (forward-button 1 nil nil t)))

(defun hellmacs-splash-guided-tour ()
  "Open the official GNU Emacs Guided Tour."
  (interactive)
  (browse-url "https://www.gnu.org/software/emacs/tour/"))

(autoload 'hellmacs-info-manual "lib/help" nil t)
(autoload 'hellmacs-where-is-intellij "lib/intellij" nil t)

(defun hellmacs-splash-recent-files ()
  "Open a recently visited file, starting `recentf-mode' if needed."
  (interactive)
  (recentf-mode 1)
  (call-interactively #'recentf-open))

;; Explicit keymap ensuring complete keyboard navigation
(defvar-keymap hellmacs-splash-mode-map
  :doc "Keymap for Hellmacs Altar splash screen."
  :parent special-mode-map
  "TAB" #'forward-button
  "<tab>" #'forward-button
  "C-i" #'forward-button
  "n" #'forward-button
  "f" #'forward-button
  "<right>" #'forward-button
  "<down>" #'forward-button
  "<backtab>" #'backward-button
  "S-TAB" #'backward-button
  "<iso-lefttab>" #'backward-button
  "p" #'backward-button
  "b" #'backward-button
  "<left>" #'backward-button
  "<up>" #'backward-button
  "RET" #'push-button
  "<return>" #'push-button
  "q" #'quit-window
  "g" #'revert-buffer
  "C-x C-f" #'find-file
  "C-x b" #'switch-to-buffer
  "C-c h i" #'hellmacs-info-manual
  "C-c h k" #'hellmacs-where-is-intellij
  "C-h t" #'help-with-tutorial)

(define-derived-mode hellmacs-splash-mode special-mode "Altar"
  "Major mode for the Hellmacs splash screen."
  (setq-local revert-buffer-function (lambda (&rest _) (hellmacs-splash--render))
              cursor-type nil
              truncate-lines t
              mode-line-format
              (if (and (boundp 'hellmacs-profile) hellmacs-profile)
                  (list "  "
                        (propertize (format " [%s] " (upcase hellmacs-profile))
                                    'face '(:foreground "#16171d" :background "#da8548" :weight bold))
                        "  Altar (Hellmacs)")
                nil)
              buffer-undo-list t
              display-line-numbers nil)
  (add-hook 'window-size-change-functions #'hellmacs-splash--resize-h nil t))

(defun hellmacs-splash--resize-h (window)
  "Redraw the splash screen shown in WINDOW, which changed size."
  (with-current-buffer (window-buffer window)
    (hellmacs-splash--render)))

(defun hellmacs-splash--get-buffer ()
  "Return the splash buffer, in its mode, without drawing it."
  (let ((buffer (get-buffer-create hellmacs-splash-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hellmacs-splash-mode)
        (hellmacs-splash-mode)))
    buffer))

(defun hellmacs-splash-buffer ()
  "Return the splash buffer, (re)drawn."
  (with-current-buffer (hellmacs-splash--get-buffer)
    (hellmacs-splash--render)
    (current-buffer)))

;;;###autoload
(defun hellmacs-splash ()
  "Return to the Altar: show the Hellmacs splash screen."
  (interactive)
  (switch-to-buffer (hellmacs-splash--get-buffer))
  (hellmacs-splash--render))

(defvar hellmacs-splash-buffer-function #'hellmacs-splash-buffer
  "Function returning the startup screen's buffer.")

(defun hellmacs-splash--initial-buffer ()
  "Value for `initial-buffer-choice': the splash screen, unless disabled."
  (cond ((or buffer-file-name (derived-mode-p 'dired-mode))
         (current-buffer))
        (hellmacs-splash-enable
         (funcall hellmacs-splash-buffer-function))
        (t
         (get-scratch-buffer-create))))

(setq initial-buffer-choice #'hellmacs-splash--initial-buffer)

(add-hook 'hellmacs-after-init-hook
          (defun hellmacs-splash--refresh-h ()
            (when-let* ((buffer (get-buffer hellmacs-splash-buffer-name)))
              (with-current-buffer buffer
                (hellmacs-splash--render)))))

(provide 'hellmacs-splash)
;;; +splash.el ends here
