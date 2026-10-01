;;; hellmacs/+splash.el --- Native Altar Splash Screen -*- lexical-binding: t; -*-

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

;; Replaces the GNU splash screen with the Altar: a pure, dependency-free
;; GNU Emacs native startup hub displaying our infernal altar artwork,
;; interactive SVG sprite action buttons, centered architecture diagram,
;; and dynamic GC benchmark telemetry.

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

;;; Faces --------------------------------------------------------------------

(defface hellmacs-splash-sigil
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for the splash screen's fallback ASCII sigil."
  :group 'hellmacs-splash)

(defface hellmacs-splash-tagline
  '((t (:foreground "#ffb86c" :weight bold)))
  "Face for the splash screen's tagline."
  :group 'hellmacs-splash)

(defface hellmacs-splash-altar
  '((t (:foreground "#50fa7b" :weight bold)))
  "Face for the startup-time and GC benchmarking line."
  :group 'hellmacs-splash)

(defface hellmacs-splash-hint
  '((t (:foreground "#6272a4")))
  "Face for the splash screen's key hints."
  :group 'hellmacs-splash)

(defface hellmacs-splash-border
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for box drawing borders in the architecture diagram."
  :group 'hellmacs-splash)

(defface hellmacs-splash-diagram-heading
  '((t (:foreground "#ffb86c" :weight bold)))
  "Face for section headings in the architecture diagram."
  :group 'hellmacs-splash)

(defface hellmacs-splash-diagram-text
  '((t (:foreground "#f8f8f2")))
  "Face for main component text in the architecture diagram."
  :group 'hellmacs-splash)

(defface hellmacs-splash-diagram-detail
  '((t (:foreground "#6272a4")))
  "Face for explanatory notes in the architecture diagram."
  :group 'hellmacs-splash)

(defface hellmacs-splash-button
  '((t (:box (:line-width (1 . 1) :color "#3a1c28")
        :background "#1c1e24"
        :foreground "#f8f8f2"
        :weight bold)))
  "Face for interactive quick-start buttons on the Altar."
  :group 'hellmacs-splash)

(defface hellmacs-splash-button-active
  '((t (:box (:line-width (1 . 1) :color "#ff5555")
        :background "#282a36"
        :foreground "#ff79c6"
        :weight bold)))
  "Face for active/focused buttons on the Altar."
  :group 'hellmacs-splash)

(defconst hellmacs-splash-buffer-name "*hellmacs*"
  "Name of the native splash screen buffer.")

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
  "The tagline under the emblem.")

(defvar hellmacs-splash--init-gcs nil
  "`gcs-done' recorded when startup finished.")

(add-hook 'hellmacs-after-init-hook
          (defun hellmacs-splash--record-gcs-h ()
            (setq hellmacs-splash--init-gcs gcs-done))
          -90)

(defun hellmacs-splash-startup-line ()
  "Return dynamic startup benchmark statistics."
  (let* ((init-time (or hellmacs-init-time
                        (and (boundp 'after-init-time) after-init-time before-init-time
                             (float-time (time-subtract after-init-time before-init-time)))
                        (and before-init-time
                             (float-time (time-subtract (current-time) before-init-time)))
                        0.08))
         (gcs (or (bound-and-true-p hellmacs-splash--init-gcs) gcs-done 0)))
    (format "[ALTAR] Bound in %.2f seconds with %d collections."
            init-time gcs)))

(defun hellmacs-splash--insert-centered (text face width)
  "Insert TEXT in FACE, centered in WIDTH columns, then a newline."
  (let ((len (string-width text)))
    (insert (make-string (max 0 (/ (- width len) 2)) ?\s)
            (if face (propertize text 'face face) text)
            "\n")))

(defun hellmacs-splash--ascii-lines ()
  "Return lines of the ASCII banner from assets/banner-ascii.txt."
  (let ((file (expand-file-name "assets/banner-ascii.txt" hellmacs-dir)))
    (if (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (split-string (buffer-string) "\n" t))
      hellmacs-splash-sigil)))

(defun hellmacs-splash--banner-image ()
  "Return graphical banner image object if available and display is graphical.
Prefers hellmacs-altar.png, falling back to banner-960.png, banner.png, or banner.svg."
  (when (display-graphic-p)
    (let* ((candidates '("banners/hellmacs-altar.png"
                         "banner-960.png"
                         "banner.png"
                         "banner.svg"))
           (file (seq-some (lambda (f)
                             (let* ((path (expand-file-name (concat "assets/" f) hellmacs-dir))
                                    (type (if (string-suffix-p ".svg" f) 'svg 'png)))
                               (and (file-readable-p path)
                                    (image-type-available-p type)
                                    path)))
                           candidates)))
      (when file
        (create-image file (if (string-suffix-p ".svg" file) 'svg 'png) nil
                      :max-width 480
                      :max-height 280)))))

(defun hellmacs-splash--button-icon (svg-file fallback-glyph)
  "Return image display property string if SVG-FILE is available and graphical, else FALLBACK-GLYPH."
  (let ((svg-path (expand-file-name (concat "assets/buttons/" svg-file) hellmacs-dir)))
    (if (and (display-graphic-p)
             (image-type-available-p 'svg)
             (file-readable-p svg-path))
        (propertize "  " 'display (create-image svg-path 'svg nil :ascent 'center :max-height 18 :max-width 18))
      (if (and (fboundp 'nerd-icons-octicon) (display-graphic-p))
          (condition-case nil
              (nerd-icons-octicon fallback-glyph :height 0.95)
            (error fallback-glyph))
        fallback-glyph))))

(defun hellmacs-splash--insert-button (label action help svg-file fallback-glyph)
  "Insert an interactive text button for ACTION with SVG-FILE icon or FALLBACK-GLYPH."
  (let* ((icon (hellmacs-splash--button-icon svg-file fallback-glyph))
         (display-text (format " %s %s " icon label)))
    (insert-text-button display-text
                        'action (lambda (_) (call-interactively action))
                        'follow-link t
                        'help-echo help
                        'face 'hellmacs-splash-button
                        'mouse-face 'hellmacs-splash-button-active)))

(defun hellmacs-splash--action-project ()
  "Interactive action for Summon Project."
  (interactive)
  (if (and (fboundp 'projectile-switch-project)
           (featurep 'projectile))
      (call-interactively #'projectile-switch-project)
    (call-interactively #'project-switch-project)))

(defun hellmacs-splash--action-buffer ()
  "Interactive action for Grimoires."
  (interactive)
  (if (fboundp 'consult-buffer)
      (call-interactively #'consult-buffer)
    (call-interactively #'switch-to-buffer)))

(defun hellmacs-splash--action-shell ()
  "Interactive action for Hell Shell."
  (interactive)
  (cond ((fboundp 'vterm)
         (call-interactively #'vterm))
        ((fboundp 'eshell)
         (call-interactively #'eshell))
        (t (call-interactively #'shell))))

(defun hellmacs-splash--diagram-lines ()
  "Return the formatted, color-coded Golden-Age architectural diagram lines."
  (let ((b (lambda (s) (propertize s 'face 'hellmacs-splash-border)))
        (h (lambda (s) (propertize s 'face 'hellmacs-splash-diagram-heading)))
        (t-fn (lambda (s) (propertize s 'face 'hellmacs-splash-diagram-text)))
        (d (lambda (s) (propertize s 'face 'hellmacs-splash-diagram-detail))))
    (list
     (funcall b "┌────────────────────────────────────────────────────────┐")
     (concat (funcall b "│") "                   " (funcall h "MINIBUFFER / DISCOVERY") "               " (funcall b "│"))
     (concat (funcall b "│") "     " (funcall t-fn "Vertico + Orderless + Marginalia + Consult") "         " (funcall b "│"))
     (concat (funcall b "│") "   " (funcall d "(Enhances completing-read without popup frameworks)") "  " (funcall b "│"))
     (funcall b "├───────────────────────────┬────────────────────────────┤")
     (concat (funcall b "│") "     " (funcall h "PROJECT & FILES") "       " (funcall b "│") "        " (funcall h "INTELLIGENCE") "        " (funcall b "│"))
     (concat (funcall b "│") "    " (funcall t-fn "Native project.el") "      " (funcall b "│") "     " (funcall t-fn "Native eglot + xref") "    " (funcall b "│"))
     (concat (funcall b "│") "  " (funcall t-fn "+ Enhanced Dired / Icons") " " (funcall b "│") "   " (funcall d "(Flymake in raw buffers)") " " (funcall b "│"))
     (funcall b "├───────────────────────────┴────────────────────────────┤")
     (concat (funcall b "│") "                      " (funcall h "CORE SYNTAX") "                       " (funcall b "│"))
     (concat (funcall b "│") "           " (funcall t-fn "Native treesit.el (Emacs C-Core)") "             " (funcall b "│"))
     (concat (funcall b "│") "        " (funcall d "(Exact AST highlighting & navigation)") "           " (funcall b "│"))
     (funcall b "└────────────────────────────────────────────────────────┘"))))

(defun hellmacs-splash--render ()
  "Draw the native splash screen into the current buffer, centered in its window."
  (let* ((inhibit-read-only t)
         (window (get-buffer-window (current-buffer)))
         (width (if window (window-width window) (frame-width)))
         (height (if window (window-body-height window) (frame-height)))
         (img (hellmacs-splash--banner-image)))
    (erase-buffer)
    ;; 1. Banner Emblem
    (if img
        (let* ((img-size (image-size img))
               (img-cols (ceiling (car img-size)))
               (img-lines (ceiling (cdr img-size)))
               (content-height (+ img-lines 22))
               (top-margin (max 0 (/ (- height content-height) 3)))
               (left-margin (max 0 (/ (- width img-cols) 2))))
          (insert (make-string top-margin ?\n))
          (insert (make-string left-margin ?\s))
          (insert-image img)
          (insert "\n\n"))
      ;; Fallback ASCII Sigil
      (let* ((ascii-lines (hellmacs-splash--ascii-lines))
             (sigil-width (apply #'max (mapcar #'string-width ascii-lines)))
             (sigil-indent (make-string (max 0 (/ (- width sigil-width) 2)) ?\s))
             (content-height (+ (length ascii-lines) 22))
             (top-margin (max 0 (/ (- height content-height) 3))))
        (insert (make-string top-margin ?\n))
        (dolist (line ascii-lines)
          (insert sigil-indent (propertize line 'face 'hellmacs-splash-sigil) "\n"))
        (insert "\n")))

    ;; 2. Interactive SVG Sprite Action Buttons Bar
    (let* ((buttons `(("Ignite File" find-file "Find file (C-x C-f)" "ignite.svg" "🔥")
                      ("Summon Project" hellmacs-splash--action-project "Switch project (C-x p p)" "forge.svg" "⚙")
                      ("Grimoires" hellmacs-splash--action-buffer "Switch buffer (C-x b)" "skull.svg" "💀")
                      ("Hell Shell" hellmacs-splash--action-shell "Spawn shell" "shell.svg" "⚡")))
           (gap "   ")
           ;; Visual width approximation for centering: 4 chars padding + icon + label
           (total-btn-width (+ (apply #'+ (mapcar (lambda (b) (+ (string-width (nth 0 b)) 6)) buttons))
                               (* (string-width gap) (1- (length buttons)))))
           (left-pad (make-string (max 0 (/ (- width total-btn-width) 2)) ?\s)))
      (insert left-pad)
      (dolist (b buttons)
        (hellmacs-splash--insert-button (nth 0 b) (nth 1 b) (nth 2 b) (nth 3 b) (nth 4 b))
        (unless (eq b (car (last buttons)))
          (insert gap)))
      (insert "\n\n"))

    ;; 3. Centered Golden-Age Architecture Diagram
    (let* ((diagram-lines (hellmacs-splash--diagram-lines))
           (diag-width 58)
           (diag-indent (make-string (max 0 (/ (- width diag-width) 2)) ?\s)))
      (dolist (line diagram-lines)
        (insert diag-indent line "\n"))
      (insert "\n"))

    ;; 4. Dynamic GC & Benchmarking Footer
    (hellmacs-splash--insert-centered hellmacs-splash-tagline 'hellmacs-splash-tagline width)
    (hellmacs-splash--insert-centered (hellmacs-splash-startup-line) 'hellmacs-splash-altar width)
    (insert "\n")

    ;; 5. Key Navigation Hint
    (hellmacs-splash--insert-centered
     "TAB/S-TAB navigate · RET select · C-x C-f find file · C-c h i manual · q/ESC dismiss"
     'hellmacs-splash-hint width)

    (goto-char (point-min))
    (forward-button 1 nil nil t)))

;;; Keybindings & Mode Definition --------------------------------------------

(defvar-keymap hellmacs-splash-mode-map
  :doc "Keymap for the native Hellmacs Altar splash screen."
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
  "ESC" #'quit-window
  "<escape>" #'quit-window
  "g" #'revert-buffer
  "r" #'revert-buffer
  "C-x C-f" #'find-file
  "C-x b" #'switch-to-buffer
  "C-c h i" #'hellmacs-info-manual
  "C-c h k" #'hellmacs-where-is-intellij
  "C-h t" #'help-with-tutorial)

(define-derived-mode hellmacs-splash-mode special-mode "Altar"
  "Pure GNU Emacs major mode for the Hellmacs native Altar splash screen."
  (setq-local revert-buffer-function (lambda (&rest _) (hellmacs-splash--render))
              cursor-type nil
              truncate-lines t
              buffer-undo-list t
              display-line-numbers nil
              mode-line-format
              (if (and (boundp 'hellmacs-profile) hellmacs-profile)
                  (list "  "
                        (propertize (format " [%s] " (upcase hellmacs-profile))
                                    'face '(:foreground "#16171d" :background "#ff5555" :weight bold))
                        "  Altar (Hellmacs)")
                nil))
  (add-hook 'window-size-change-functions #'hellmacs-splash--resize-h nil t))

(defun hellmacs-splash--resize-h (window)
  "Redraw the splash screen shown in WINDOW on resize."
  (when (window-live-p window)
    (with-current-buffer (window-buffer window)
      (when (derived-mode-p 'hellmacs-splash-mode)
        (hellmacs-splash--render)))))

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
  "Return to the Altar: display the native Hellmacs splash screen."
  (interactive)
  (switch-to-buffer (hellmacs-splash--get-buffer))
  (hellmacs-splash--render))

(defvar hellmacs-splash-buffer-function #'hellmacs-splash-buffer
  "Function returning the startup screen's buffer.")

(defun hellmacs-splash--initial-buffer ()
  "Value for `initial-buffer-choice': the splash screen, unless file arguments were given."
  (cond ((or buffer-file-name (derived-mode-p 'dired-mode))
         (current-buffer))
        (hellmacs-splash-enable
         (funcall hellmacs-splash-buffer-function))
        (t
         (get-scratch-buffer-create))))

(setq initial-buffer-choice #'hellmacs-splash--initial-buffer)

(defun hellmacs-splash--refresh-h (&rest _)
  "Refresh the splash screen buffer once startup telemetry is settled."
  (when-let* ((buffer (get-buffer hellmacs-splash-buffer-name)))
    (with-current-buffer buffer
      (when (derived-mode-p 'hellmacs-splash-mode)
        (hellmacs-splash--render)))))

(add-hook 'hellmacs-after-init-hook #'hellmacs-splash--refresh-h 100)
(add-hook 'window-setup-hook #'hellmacs-splash--refresh-h 100)

(provide 'hellmacs-splash)
;;; +splash.el ends here
