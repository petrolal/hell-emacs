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
;; interactive SVG sprite action buttons, dynamic two-column sacrifices
;; & forges dashboard, and dynamic GC benchmark telemetry.

(require 'button)
(require 'image)
(require 'project)
(require 'recentf)
(require 'subr-x)

(defvar hellmacs-dir)
(defvar hellmacs-profile)
(defvar hellmacs-init-time)

(autoload 'hellmacs-info-manual "lib/help" nil t)
(autoload 'hellmacs-plugins "hellmacs-plugins" nil t)
(autoload 'hellmacs-where-is-intellij "lib/intellij" nil t)

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
  "Face for the splash screen's key hints and secondary paths."
  :group 'hellmacs-splash)

(defface hellmacs-splash-border
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for separator lines in the dashboard."
  :group 'hellmacs-splash)

(defface hellmacs-splash-section-heading
  '((t (:foreground "#ffb86c" :weight bold)))
  "Face for section headings in the two-column dashboard."
  :group 'hellmacs-splash)

(defface hellmacs-splash-button
  '((t (:box (:line-width (1 . 1) :color "#3a1c28")
        :background "#1c1e24"
        :foreground "#f8f8f2"
        :weight bold)))
  "Face for interactive quick-start sprite buttons on the Altar."
  :group 'hellmacs-splash)

(defface hellmacs-splash-button-active
  '((t (:box (:line-width (1 . 1) :color "#ff5555")
        :background "#282a36"
        :foreground "#ff79c6"
        :weight bold)))
  "Face for active/focused sprite buttons on the Altar."
  :group 'hellmacs-splash)

(defface hellmacs-splash-item
  '((t (:foreground "#f8f8f2")))
  "Face for file and project items in the two-column dashboard."
  :group 'hellmacs-splash)

(defface hellmacs-splash-item-active
  '((t (:foreground "#ff79c6" :underline t :weight bold)))
  "Face for hovered/focused file and project items in the two-column dashboard."
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
  "Return lines of the ASCII banner from assets/ascii/banner-ascii.txt."
  (let ((file (or (let ((f (expand-file-name "assets/ascii/banner-ascii.txt" hellmacs-dir)))
                    (and (file-readable-p f) f))
                  (expand-file-name "assets/banner-ascii.txt" hellmacs-dir))))
    (if (and file (file-readable-p file))
        (with-temp-buffer
          (insert-file-contents file)
          (split-string (buffer-string) "\n" t))
      hellmacs-splash-sigil)))

(defun hellmacs-splash--banner-image ()
  "Return graphical banner image object if available and display is graphical.
Prefers banner-960.png, falling back to banner.png or banner.svg in assets/banners/."
  (when (display-graphic-p)
    (let* ((candidates '("banners/banner-960.png"
                         "banners/banner.png"
                         "banners/banner.svg"
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

(defun hellmacs-splash--insert-button (label action help svg-file fallback-glyph &optional fixed-width)
  "Insert an interactive text button for ACTION with SVG-FILE icon or FALLBACK-GLYPH.
If FIXED-WIDTH is non-nil, pad the inside of the button so its visual width is FIXED-WIDTH."
  (let* ((icon (hellmacs-splash--button-icon svg-file fallback-glyph))
         (icon-width (if (display-graphic-p) 2 (string-width fallback-glyph)))
         (label-width (string-width label))
         (inner-width (+ 1 icon-width 1 label-width 1))
         (pad-len (if fixed-width (max 0 (- fixed-width inner-width)) 0))
         (pad (make-string pad-len ?\s))
         (display-text (format " %s %s%s " icon label pad)))
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

(defun hellmacs-splash--action-plugins ()
  "Interactive action for Relic Chamber."
  (interactive)
  (if (fboundp 'hellmacs-plugins)
      (call-interactively #'hellmacs-plugins)
    (call-interactively #'list-packages)))

(defun hellmacs-splash--action-github ()
  "Open the official Hellmacs repository on GitHub."
  (interactive)
  (browse-url "https://github.com/petrolal/hellmacs"))

(defun hellmacs-splash--action-beacon ()
  "Display the official Dark Beacon portal status."
  (interactive)
  (message "[ALTAR] Beacon portal under construction..."))

;;; Dynamic Sacrifices & Forges Data -----------------------------------------

(defun hellmacs-splash--get-recents (&optional limit)
  "Return up to LIMIT recent file paths."
  (unless recentf-mode
    (recentf-mode 1))
  (let ((lim (or limit 5)))
    (seq-take (seq-filter (lambda (f) (and (stringp f) (file-exists-p f)))
                          (bound-and-true-p recentf-list))
              lim)))

(defun hellmacs-splash--get-projects (&optional limit)
  "Return up to LIMIT known project paths."
  (let ((lim (or limit 5))
        (projects (cond ((and (bound-and-true-p projectile-known-projects)
                              (featurep 'projectile))
                         projectile-known-projects)
                        ((fboundp 'project-known-project-roots)
                         (project-known-project-roots))
                        (t nil))))
    (seq-take (seq-filter (lambda (p) (and (stringp p) (file-exists-p p)))
                          projects)
              lim)))

(defun hellmacs-splash--file-icon (file)
  "Return nerd-icons or unicode icon for FILE."
  (if (and (display-graphic-p) (fboundp 'nerd-icons-icon-for-file))
      (condition-case nil
          (nerd-icons-icon-for-file file :height 0.9)
        (error "📄"))
    "📄"))

(defun hellmacs-splash--project-icon (dir)
  "Return nerd-icons or unicode icon for project DIR."
  (if (and (display-graphic-p) (fboundp 'nerd-icons-octicon))
      (condition-case nil
          (nerd-icons-octicon "nf-oct-rocket" :height 0.9)
        (error "🚀"))
    "🚀"))

(defun hellmacs-splash--truncate-str (str max-len)
  "Truncate STR to MAX-LEN columns with ellipsis if needed."
  (if (> (string-width str) max-len)
      (concat (substring str 0 (max 0 (- max-len 1))) "…")
    str))

(defun hellmacs-splash--format-file-entry (path max-width)
  "Format PATH with icon, filename, and directory within MAX-WIDTH."
  (let* ((icon (hellmacs-splash--file-icon path))
         (abbrev (abbreviate-file-name path))
         (fname (file-name-nondirectory abbrev))
         (dir (file-name-directory abbrev))
         (dir-str (if dir (hellmacs-splash--truncate-str dir (max 8 (- max-width (string-width fname) 6))) ""))
         (base (format "%s %s" icon fname)))
    (if (and dir-str (not (string-empty-p dir-str)))
        (let* ((total-str (format "%s  %s" base (propertize dir-str 'face 'hellmacs-splash-hint))))
          (if (<= (string-width total-str) max-width)
              total-str
            (hellmacs-splash--truncate-str total-str max-width)))
      (hellmacs-splash--truncate-str base max-width))))

(defun hellmacs-splash--format-project-entry (path max-width)
  "Format project root PATH with icon, name, and directory within MAX-WIDTH."
  (let* ((icon (hellmacs-splash--project-icon path))
         (clean-path (directory-file-name path))
         (abbrev (abbreviate-file-name clean-path))
         (pname (file-name-nondirectory abbrev))
         (dir (file-name-directory abbrev))
         (dir-str (if dir (hellmacs-splash--truncate-str dir (max 8 (- max-width (string-width pname) 6))) ""))
         (base (format "%s %s" icon pname)))
    (if (and dir-str (not (string-empty-p dir-str)))
        (let* ((total-str (format "%s  %s" base (propertize dir-str 'face 'hellmacs-splash-hint))))
          (if (<= (string-width total-str) max-width)
              total-str
            (hellmacs-splash--truncate-str total-str max-width)))
      (hellmacs-splash--truncate-str base max-width))))

(defun hellmacs-splash--insert-file-button (path max-width)
  "Insert an interactive button for opening file PATH formatted to MAX-WIDTH."
  (let* ((formatted (hellmacs-splash--format-file-entry path max-width))
         (len (string-width formatted)))
    (insert-text-button formatted
                        'action (lambda (_) (find-file path))
                        'follow-link t
                        'help-echo (format "Open %s" path)
                        'face 'hellmacs-splash-item
                        'mouse-face 'hellmacs-splash-item-active)
    (when (< len max-width)
      (insert (make-string (- max-width len) ?\s)))))

(defun hellmacs-splash--insert-project-button (path max-width)
  "Insert an interactive button for switching to project PATH formatted to MAX-WIDTH."
  (let* ((formatted (hellmacs-splash--format-project-entry path max-width))
         (len (string-width formatted)))
    (insert-text-button formatted
                        'action (lambda (_)
                                  (if (and (fboundp 'projectile-switch-project-by-name)
                                           (featurep 'projectile))
                                      (projectile-switch-project-by-name path)
                                    (project-switch-project path)))
                        'follow-link t
                        'help-echo (format "Summon project %s" path)
                        'face 'hellmacs-splash-item
                        'mouse-face 'hellmacs-splash-item-active)
    (when (< len max-width)
      (insert (make-string (- max-width len) ?\s)))))

(defun hellmacs-splash--split-buttons-into-rows (buttons max-width gap-len)
  "Partition BUTTONS into balanced rows such that no row exceeds MAX-WIDTH."
  (let (rows current-row (current-width 0))
    (dolist (b buttons)
      (let* ((label (nth 0 b))
             (b-width (+ (string-width label) 6)))
        (if (and current-row (> (+ current-width gap-len b-width) max-width))
            (progn
              (push (nreverse current-row) rows)
              (setq current-row (list b)
                    current-width b-width))
          (push b current-row)
          (setq current-width (if (= (length current-row) 1)
                                  b-width
                                (+ current-width gap-len b-width))))))
    (when current-row
      (push (nreverse current-row) rows))
    (nreverse rows)))

;;; Splash Rendering ---------------------------------------------------------

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

    ;; 2. Interactive SVG Sprite Action Buttons (Two Centered Columns)
    (let* ((button-pairs
            `((("Ignite File" find-file "Find file (C-x C-f)" "ignite.svg" "🔥")
               ("Summon Project" hellmacs-splash--action-project "Switch project (C-x p p)" "forge.svg" "⚙"))
              (("Grimoires" hellmacs-splash--action-buffer "Switch buffer (C-x b)" "skull.svg" "💀")
               ("Hell Shell" hellmacs-splash--action-shell "Spawn shell" "shell.svg" "⚡"))
              (("Relic Chamber" hellmacs-splash--action-plugins "Plugin and module manager (C-c h p)" "marketplace.svg" "📦")
               ("Grimoire Manual" hellmacs-info-manual "Hellmacs Info manual (C-c h i)" "manual.svg" "📖"))
              (("IntelliJ Exorcism" hellmacs-where-is-intellij "IntelliJ key finder (C-c h k)" "intellij.svg" "💡")
               ("Forge Source" hellmacs-splash--action-github "Hellmacs GitHub repository" "github.svg" "🐙"))
              (("Dark Beacon (WIP)" hellmacs-splash--action-beacon "Official portal (WIP)" "website.svg" "🔮")
               nil)))
           (col-btn-width 26)
           (col-gap "      ")
           (col-gap-len (string-width col-gap))
           (grid-width (+ (* col-btn-width 2) col-gap-len))
           (left-pad (make-string (max 0 (/ (- width grid-width) 2)) ?\s)))
      (dolist (pair button-pairs)
        (let ((b1 (nth 0 pair))
              (b2 (nth 1 pair)))
          (insert left-pad)
          (hellmacs-splash--insert-button (nth 0 b1) (nth 1 b1) (nth 2 b1) (nth 3 b1) (nth 4 b1) col-btn-width)
          (when b2
            (insert col-gap)
            (hellmacs-splash--insert-button (nth 0 b2) (nth 1 b2) (nth 2 b2) (nth 3 b2) (nth 4 b2) col-btn-width))
          (insert "\n\n")))
      (insert "\n")) ; Breathing room before utility lists

    ;; 3. Dynamic Two-Column Utility Core (Recents & Projects)
    (let* ((col-width (max 32 (min 38 (/ (- width 8) 2))))
           (gap "    ")
           (gap-len (string-width gap))
           (table-width (+ (* col-width 2) gap-len))
           (table-indent (make-string (max 0 (/ (- width table-width) 2)) ?\s))
           (recents (hellmacs-splash--get-recents 5))
           (projects (hellmacs-splash--get-projects 5))
           (max-rows (max 1 (max (length recents) (length projects)))))

      ;; Headers
      (insert table-indent
              (propertize (truncate-string-to-width "RECENT SACRIFICES" col-width nil ?\s)
                          'face 'hellmacs-splash-section-heading)
              gap
              (propertize (truncate-string-to-width "ACTIVE FORGES" col-width nil ?\s)
                          'face 'hellmacs-splash-section-heading)
              "\n")
      ;; Underlines
      (insert table-indent
              (propertize (make-string col-width ?─) 'face 'hellmacs-splash-border)
              gap
              (propertize (make-string col-width ?─) 'face 'hellmacs-splash-border)
              "\n")

      ;; Rows
      (dotimes (i max-rows)
        (let ((file (nth i recents))
              (proj (nth i projects)))
          (insert table-indent)
          ;; Left Column (Recents)
          (if file
              (hellmacs-splash--insert-file-button file col-width)
            (if (= i 0)
                (insert (propertize (truncate-string-to-width "No sacrifices recorded yet" col-width nil ?\s)
                                    'face 'hellmacs-splash-hint))
              (insert (make-string col-width ?\s))))
          (insert gap)
          ;; Right Column (Projects)
          (if proj
              (hellmacs-splash--insert-project-button proj col-width)
            (if (= i 0)
                (insert (propertize (truncate-string-to-width "No forges discovered yet" col-width nil ?\s)
                                    'face 'hellmacs-splash-hint))
              (insert (make-string col-width ?\s))))
          (insert "\n")))
      (insert "\n\n"))

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
  "C-c h p" #'hellmacs-plugins
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
                        "  Hellmacs Altar")
                "  Hellmacs Altar"))
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
