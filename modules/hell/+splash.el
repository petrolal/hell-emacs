;;; hell/+splash.el --- Native Altar Splash Screen -*- lexical-binding: t; -*-

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

;; Replaces the GNU splash screen with the Altar: a pure, dependency-free
;; GNU Emacs native startup hub displaying our infernal altar artwork,
;; interactive SVG sprite action buttons, dynamic two-column sacrifices
;; & forges dashboard, and dynamic GC benchmark telemetry.

(require 'button)
(require 'image)
(require 'project)
(require 'recentf)
(require 'subr-x)

(defvar hell-dir)
(defvar hell-profile)
(defvar hell-init-time)

(autoload 'hell-info-manual "lib/help" nil t)
(autoload 'hell-plugins "hell-plugins" nil t)
(autoload 'hell-where-is-intellij "lib/intellij" nil t)

(defgroup hell-splash nil
  "The Hell Emacs startup screen."
  :group 'hell)

(defcustom hell-splash-enable t
  "Whether Emacs starts on the Altar (`*hell-emacs*') instead of *scratch*."
  :type 'boolean
  :group 'hell-splash)

;;; Faces --------------------------------------------------------------------

(defface hell-splash-sigil
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for the splash screen's fallback ASCII sigil."
  :group 'hell-splash)

(defface hell-splash-title
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for the primary banner title on the Altar."
  :group 'hell-splash)

(defface hell-splash-tagline
  '((t (:foreground "#ffb86c" :weight bold)))
  "Face for the splash screen's tagline."
  :group 'hell-splash)

(defface hell-splash-altar
  '((t (:foreground "#50fa7b" :weight bold)))
  "Face for the startup-time and GC benchmarking line."
  :group 'hell-splash)

(defface hell-splash-hint
  '((t (:foreground "#6272a4")))
  "Face for the splash screen's key hints and secondary paths."
  :group 'hell-splash)

(defface hell-splash-border
  '((t (:foreground "#ff5555" :weight bold)))
  "Face for separator lines in the dashboard."
  :group 'hell-splash)

(defface hell-splash-section-heading
  '((t (:foreground "#ffb86c" :weight bold)))
  "Face for section headings in the two-column dashboard."
  :group 'hell-splash)

(defface hell-splash-external-heading
  '((t (:foreground "#6272a4" :weight bold :slant italic)))
  "Face for the external portals section heading."
  :group 'hell-splash)

(defface hell-splash-external-border
  '((t (:foreground "#44475a")))
  "Face for subtle footer separator lines."
  :group 'hell-splash)

(defface hell-splash-column-separator
  '((t (:foreground "#44475a")))
  "Face for the vertical separator between recent sacrifices and active forges."
  :group 'hell-splash)

(defface hell-splash-button
  '((t (:box (:line-width (1 . 1) :color "#3a1c28")
        :background "#1c1e24"
        :foreground "#f8f8f2"
        :weight bold)))
  "Face for interactive quick-start sprite buttons on the Altar."
  :group 'hell-splash)

(defface hell-splash-button-active
  '((t (:box (:line-width (1 . 1) :color "#ff5555")
        :background "#282a36"
        :foreground "#ff79c6"
        :weight bold)))
  "Face for active/focused sprite buttons on the Altar."
  :group 'hell-splash)

(defface hell-splash-item
  '((t (:foreground "#f8f8f2")))
  "Face for file and project items in the two-column dashboard."
  :group 'hell-splash)

(defface hell-splash-item-active
  '((t (:foreground "#ff79c6" :underline t :weight bold)))
  "Face for hovered/focused file and project items in the two-column dashboard."
  :group 'hell-splash)

(defconst hell-splash-buffer-name "*hell-emacs*"
  "Name of the native splash screen buffer.")

(defconst hell-splash-sigil
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

(defconst hell-splash-tagline
  (if (and (boundp 'hell-profile) hell-profile)
      (format "HELL EMACS [%s] // [ JVM FORGE IGNITED ] // Bytecode subjugated."
              (upcase hell-profile))
    "HELL EMACS // [ JVM FORGE IGNITED ] // Bytecode subjugated.")
  "The tagline under the emblem.")

(defvar hell-splash--init-gcs nil
  "`gcs-done' recorded when startup finished.")

(add-hook 'hell-after-init-hook
          (defun hell-splash--record-gcs-h ()
            (setq hell-splash--init-gcs gcs-done))
          -90)

(defun hell-splash-startup-line ()
  "Return dynamic startup benchmark statistics."
  (let* ((init-time (or (bound-and-true-p hell-init-time)
                        (and (boundp 'after-init-time) (bound-and-true-p after-init-time) (bound-and-true-p before-init-time)
                             (float-time (time-subtract after-init-time before-init-time)))
                        (and (bound-and-true-p before-init-time)
                             (float-time (time-subtract (current-time) before-init-time)))
                        0.08))
         (gcs (or (bound-and-true-p hell-splash--init-gcs) (and (boundp 'gcs-done) gcs-done) 0)))
    (format "[ALTAR] Bound in %.2f seconds with %d collections."
            init-time gcs)))

(defun hell-splash--insert-centered (text face width)
  "Insert TEXT in FACE, centered in WIDTH columns, then a newline."
  (let ((len (string-width text)))
    (insert (make-string (max 0 (/ (- width len) 2)) ?\s)
            (if face (propertize text 'face face) text)
            "\n")))

(defun hell-splash--ascii-lines ()
  "Return lines of the ASCII banner from assets/ascii/banner-ascii.txt."
  (let ((file (or (let ((f (expand-file-name "assets/ascii/banner-ascii.txt" hell-dir)))
                    (and (file-readable-p f) f))
                  (expand-file-name "assets/banner-ascii.txt" hell-dir))))
    (if (and file (file-readable-p file))
        (with-temp-buffer
          (insert-file-contents file)
          (split-string (buffer-string) "\n" t))
      hell-splash-sigil)))

(defun hell-splash--banner-image (&optional max-w max-h)
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
                             (let* ((path (expand-file-name (concat "assets/" f) hell-dir))
                                    (type (if (string-suffix-p ".svg" f) 'svg 'png)))
                                (and (file-readable-p path)
                                     (image-type-available-p type)
                                     path)))
                           candidates)))
      (when file
        (create-image file (if (string-suffix-p ".svg" file) 'svg 'png) nil
                      :max-width (or max-w 480)
                      :max-height (or max-h 240))))))

(defun hell-splash--button-icon (svg-file fallback-glyph)
  "Return image display property string if SVG-FILE is available and graphical, else FALLBACK-GLYPH."
  (let ((svg-path (expand-file-name (concat "assets/buttons/" svg-file) hell-dir)))
    (if (and (display-graphic-p)
             (image-type-available-p 'svg)
             (file-readable-p svg-path))
        (propertize "  " 'display (create-image svg-path 'svg nil :ascent 'center :max-height 18 :max-width 18))
      (if (and (fboundp 'nerd-icons-octicon) (display-graphic-p))
          (condition-case nil
              (nerd-icons-octicon fallback-glyph :height 0.95)
            (error fallback-glyph))
        fallback-glyph))))

(defun hell-splash--insert-button (label action help svg-file fallback-glyph)
  "Insert an interactive text button for ACTION with SVG-FILE icon or FALLBACK-GLYPH."
  (let* ((icon (hell-splash--button-icon svg-file fallback-glyph))
          (display-text (format " %s %s " icon label)))
    (insert-text-button display-text
                        'action (lambda (_) (call-interactively action))
                        'follow-link t
                        'help-echo help
                        'face 'hell-splash-button
                        'mouse-face 'hell-splash-button-active)))

(defun hell-splash--action-project ()
  "Interactive action for Summon Project."
  (interactive)
  (if (and (fboundp 'projectile-switch-project)
           (featurep 'projectile))
      (call-interactively #'projectile-switch-project)
    (call-interactively #'project-switch-project)))

(defun hell-splash--action-buffer ()
  "Interactive action for Grimoires."
  (interactive)
  (if (fboundp 'consult-buffer)
      (call-interactively #'consult-buffer)
    (call-interactively #'switch-to-buffer)))

(defun hell-splash--action-shell ()
  "Interactive action for Hell Shell."
  (interactive)
  (cond ((fboundp 'vterm)
         (call-interactively #'vterm))
        ((fboundp 'eshell)
         (call-interactively #'eshell))
        (t (call-interactively #'shell))))

(defun hell-splash--action-plugins ()
  "Interactive action for Relic Chamber."
  (interactive)
  (if (fboundp 'hell-plugins)
      (call-interactively #'hell-plugins)
    (call-interactively #'list-packages)))

(defun hell-splash--action-github ()
  "Open the official Hell Emacs repository on GitHub."
  (interactive)
  (browse-url "https://github.com/petrolal/hell-emacs"))

(defun hell-splash--action-issues ()
  "Open the official Hell Emacs issue tracker and forge discussions on GitHub."
  (interactive)
  (browse-url "https://github.com/petrolal/hell-emacs/issues"))

(defun hell-splash--action-releases ()
  "Open the Hell Emacs changelog and release notes."
  (interactive)
  (let ((changelog (expand-file-name "CHANGELOG.md" hell-dir)))
    (if (file-readable-p changelog)
        (view-file changelog)
      (browse-url "https://github.com/petrolal/hell-emacs/releases"))))

(defun hell-splash--action-beacon ()
  "Display the official Dark Beacon portal status."
  (interactive)
  (message "[ALTAR] Dark Beacon portal under construction: https://hell-emacs.org"))

;;; Dynamic Sacrifices & Forges Data -----------------------------------------

(defun hell-splash--get-recents (&optional limit)
  "Return up to LIMIT recent file paths."
  (unless recentf-mode
    (let ((inhibit-message t))
      (recentf-mode 1)))
  (let ((lim (or limit 5)))
    (seq-take (seq-filter (lambda (f) (and (stringp f) (file-exists-p f)))
                          (bound-and-true-p recentf-list))
              lim)))

(defun hell-splash--get-projects (&optional limit)
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

(defun hell-splash--file-icon (file)
  "Return nerd-icons or unicode icon for FILE."
  (if (and (display-graphic-p) (fboundp 'nerd-icons-icon-for-file))
      (condition-case nil
          (nerd-icons-icon-for-file file :height 0.9)
        (error "📄"))
    "📄"))

(defun hell-splash--project-icon (dir)
  "Return nerd-icons or unicode icon for project DIR."
  (if (and (display-graphic-p) (fboundp 'nerd-icons-octicon))
      (condition-case nil
          (nerd-icons-octicon "nf-oct-rocket" :height 0.9)
        (error "🚀"))
    "🚀"))

(defun hell-splash--truncate-str (str max-len)
  "Truncate STR to MAX-LEN columns with ellipsis if needed."
  (if (> (string-width str) max-len)
      (concat (substring str 0 (max 0 (- max-len 1))) "…")
    str))

(defun hell-splash--format-file-entry (path max-width)
  "Format PATH with icon, filename, and directory within MAX-WIDTH."
  (let* ((icon (hell-splash--file-icon path))
         (abbrev (abbreviate-file-name path))
         (fname (file-name-nondirectory abbrev))
         (dir (file-name-directory abbrev))
         (dir-str (if dir (hell-splash--truncate-str dir (max 8 (- max-width (string-width fname) 6))) ""))
         (base (format "%s %s" icon fname)))
    (if (and dir-str (not (string-empty-p dir-str)))
        (let* ((total-str (format "%s  %s" base (propertize dir-str 'face 'hell-splash-hint))))
          (if (<= (string-width total-str) max-width)
              total-str
            (hell-splash--truncate-str total-str max-width)))
      (hell-splash--truncate-str base max-width))))

(defun hell-splash--format-project-entry (path max-width)
  "Format project root PATH with icon, name, and directory within MAX-WIDTH."
  (let* ((icon (hell-splash--project-icon path))
         (clean-path (directory-file-name path))
         (abbrev (abbreviate-file-name clean-path))
         (pname (file-name-nondirectory abbrev))
         (dir (file-name-directory abbrev))
         (dir-str (if dir (hell-splash--truncate-str dir (max 8 (- max-width (string-width pname) 6))) ""))
         (base (format "%s %s" icon pname)))
    (if (and dir-str (not (string-empty-p dir-str)))
        (let* ((total-str (format "%s  %s" base (propertize dir-str 'face 'hell-splash-hint))))
          (if (<= (string-width total-str) max-width)
              total-str
            (hell-splash--truncate-str total-str max-width)))
      (hell-splash--truncate-str base max-width))))

(defun hell-splash--insert-file-button (path max-width)
  "Insert an interactive button for opening file PATH formatted to MAX-WIDTH."
  (let* ((formatted (hell-splash--format-file-entry path max-width))
         (len (string-width formatted)))
    (insert-text-button formatted
                        'action (lambda (_) (find-file path))
                        'follow-link t
                        'help-echo (format "Open %s" path)
                        'face 'hell-splash-item
                        'mouse-face 'hell-splash-item-active)
    (when (< len max-width)
      (insert (make-string (- max-width len) ?\s)))))

(defun hell-splash--insert-project-button (path max-width)
  "Insert an interactive button for switching to project PATH formatted to MAX-WIDTH."
  (let* ((formatted (hell-splash--format-project-entry path max-width))
         (len (string-width formatted)))
    (insert-text-button formatted
                        'action (lambda (_)
                                  (if (and (fboundp 'projectile-switch-project-by-name)
                                           (featurep 'projectile))
                                      (projectile-switch-project-by-name path)
                                    (project-switch-project path)))
                        'follow-link t
                        'help-echo (format "Summon project %s" path)
                        'face 'hell-splash-item
                        'mouse-face 'hell-splash-item-active)
    (when (< len max-width)
      (insert (make-string (- max-width len) ?\s)))))

(defun hell-splash--split-buttons-into-rows (buttons max-width gap-len)
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

(defun hell-splash--render (&optional target-width target-height)
  "Draw the native splash screen into the current buffer, centered in its window."
  (let* ((inhibit-read-only t)
         (window (get-buffer-window (current-buffer)))
         (width (max 40 (or target-width (if window (window-width window) (frame-width)))))
         (height (max 15 (or target-height (if window (window-body-height window) (frame-height)))))
         (compact-p (< height 32))
         (tight-p (< height 24))
         (max-img-h (if compact-p (max 60 (min 130 (* (- height 12) 10))) (min 240 (* (- height 16) 11))))
         (max-img-w (min 480 (max 200 (* width 8))))
         (img (hell-splash--banner-image max-img-w max-img-h))
         (sep (if compact-p "\n" "\n\n")))
    (erase-buffer)

    ;; 1. Banner Emblem & Infernal Tagline
    (if img
        (let* ((img-size (image-size img))
               (img-cols (ceiling (car img-size)))
               (img-lines (ceiling (cdr img-size)))
               (content-height (+ img-lines (if compact-p 18 24)))
               (top-margin (if compact-p 0 (max 0 (min 3 (/ (- height content-height) 3)))))
               (left-margin (max 0 (/ (- width img-cols) 2))))
          (when (> top-margin 0)
            (insert (make-string top-margin ?\n)))
          (insert (make-string left-margin ?\s))
          (insert-image img)
          (insert "\n")
          (hell-splash--insert-centered "HELL EMACS: THE INFERNAL JVM HACKING ENVIRONMENT" 'hell-splash-title width)
          (hell-splash--insert-centered "BYTECODE SUBJUGATED // REPL FIRED" 'hell-splash-tagline width)
          (insert sep))
      ;; Fallback ASCII Sigil
      (let* ((ascii-lines (hell-splash--ascii-lines))
             (sigil-width (apply #'max (mapcar #'string-width ascii-lines)))
             (sigil-indent (make-string (max 0 (/ (- width sigil-width) 2)) ?\s))
             (content-height (+ (length ascii-lines) (if compact-p 18 24)))
             (top-margin (if compact-p 0 (max 0 (min 3 (/ (- height content-height) 3))))))
        (when (> top-margin 0)
          (insert (make-string top-margin ?\n)))
        (dolist (line ascii-lines)
          (insert sigil-indent (propertize line 'face 'hell-splash-sigil) "\n"))
        (insert sep)))

    ;; 2. Workspace Core Action Buttons
    (let* ((core-buttons
            `(("Ignite File" find-file "Find file (C-x C-f)" "ignite.svg" "🔥")
              ("Summon Project" hell-splash--action-project "Switch project (C-x p p)" "forge.svg" "⚙")
              ("Grimoires" hell-splash--action-buffer "Switch buffer (C-x b)" "skull.svg" "💀")
              ("Hell Shell" hell-splash--action-shell "Spawn shell" "shell.svg" "⚡")
              ("Grimoire Manual" hell-info-manual "Hell Emacs Info manual (C-c h i)" "manual.svg" "📖")
              ("IntelliJ Exorcism" hell-where-is-intellij "IntelliJ key finder (C-c h k)" "intellij.svg" "💡")))
           (gap (if (< width 80) "  " "   "))
           (gap-len (string-width gap))
           (button-rows
            (cond
             ((>= width 115)
              (list core-buttons))
             ((>= width 68)
              (list (seq-subseq core-buttons 0 3)
                    (seq-subseq core-buttons 3)))
             (t
              (hell-splash--split-buttons-into-rows core-buttons (max 36 (- width 4)) gap-len)))))
      (dolist (row button-rows)
        (let* ((row-width (+ (apply #'+ (mapcar (lambda (b) (+ (string-width (nth 0 b)) 6)) row))
                             (* gap-len (1- (length row)))))
               (left-pad (make-string (max 0 (/ (- width row-width) 2)) ?\s)))
          (insert left-pad)
          (dolist (b row)
            (hell-splash--insert-button (nth 0 b) (nth 1 b) (nth 2 b) (nth 3 b) (nth 4 b))
            (unless (eq b (car (last row)))
              (insert gap)))
          (insert (if compact-p "\n" "\n\n"))))
      (unless compact-p
        (insert "\n")))

    ;; 3. Dual Columns ("Recent Sacrifices" & "Active Forges")
    (let* ((item-limit (cond (tight-p 2) (compact-p 3) (t 5)))
           (recents (hell-splash--get-recents item-limit))
           (projects (hell-splash--get-projects item-limit))
           (dual-column-p (>= width 76)))
      (if dual-column-p
          ;; Dual Column Layout with Vertical Separator Rule
          (let* ((col-width (if (>= width 86)
                                (max 38 (min 44 (/ (- width 10) 2)))
                              34))
                 (vsep (propertize " │ " 'face 'hell-splash-column-separator))
                 (vsep-len 3)
                 (table-width (+ (* col-width 2) vsep-len))
                 (table-indent (make-string (max 0 (/ (- width table-width) 2)) ?\s))
                 (max-rows (max 1 (max (length recents) (length projects)))))
            ;; Headers
            (insert table-indent
                    (propertize (truncate-string-to-width "RECENT SACRIFICES" col-width nil ?\s)
                                'face 'hell-splash-section-heading)
                    vsep
                    (propertize (truncate-string-to-width "ACTIVE FORGES" col-width nil ?\s)
                                'face 'hell-splash-section-heading)
                    "\n")
            ;; Underlines
            (insert table-indent
                    (propertize (make-string col-width ?─) 'face 'hell-splash-border)
                    (propertize "─┼─" 'face 'hell-splash-column-separator)
                    (propertize (make-string col-width ?─) 'face 'hell-splash-border)
                    "\n")
            ;; Rows
            (dotimes (i max-rows)
              (let ((file (nth i recents))
                    (proj (nth i projects)))
                (insert table-indent)
                ;; Left Column (Recents)
                (if file
                    (hell-splash--insert-file-button file col-width)
                  (if (= i 0)
                      (insert (propertize (truncate-string-to-width "No sacrifices recorded yet" col-width nil ?\s)
                                          'face 'hell-splash-hint))
                    (insert (make-string col-width ?\s))))
                (insert vsep)
                ;; Right Column (Projects)
                (if proj
                    (hell-splash--insert-project-button proj col-width)
                  (if (= i 0)
                      (insert (propertize (truncate-string-to-width "No forges discovered yet" col-width nil ?\s)
                                          'face 'hell-splash-hint))
                    (insert (make-string col-width ?\s))))
                (insert "\n")))
            (insert sep))

        ;; Single Column Stacked Layout (Narrow Screen fallback)
        (let* ((col-width (- width 4))
               (indent "  "))
          (insert indent (propertize "RECENT SACRIFICES" 'face 'hell-splash-section-heading) "\n")
          (insert indent (propertize (make-string (min col-width 38) ?─) 'face 'hell-splash-border) "\n")
          (if recents
              (dolist (file recents)
                (insert indent)
                (hell-splash--insert-file-button file col-width)
                (insert "\n"))
            (insert indent (propertize "No sacrifices recorded yet\n" 'face 'hell-splash-hint)))
          (insert "\n" indent (propertize "ACTIVE FORGES" 'face 'hell-splash-section-heading) "\n")
          (insert indent (propertize (make-string (min col-width 38) ?─) 'face 'hell-splash-border) "\n")
          (if projects
              (dolist (proj projects)
                (insert indent)
                (hell-splash--insert-project-button proj col-width)
                (insert "\n"))
            (insert indent (propertize "No forges discovered yet\n" 'face 'hell-splash-hint)))
          (insert sep))))

    ;; 4. External Portals Bar (below dual columns)
    (let* ((external-links
            `(("Relic Chamber" hell-splash--action-plugins "Plugin and module manager (C-c h p)" "marketplace.svg" "📦")
              ("Forge Source" hell-splash--action-github "Open Hell Emacs GitHub repository" "github.svg" "🐙")
              ("Issue Sanctum" hell-splash--action-issues "Report an issue or discuss in the Forge" "github.svg" "⚡")
              ("Release Grimoires" hell-splash--action-releases "View Hell Emacs changelog and release notes" "manual.svg" "📜")
              ("Dark Beacon (WIP)" hell-splash--action-beacon "Visit official Dark Beacon portal" "website.svg" "🔮")))
           (header-text "─── EXTERNAL SANCTUMS & PORTALS ───")
           (header-pad (make-string (max 0 (/ (- width (string-width header-text)) 2)) ?\s))
           (bgap (if (< width 80) "  " "   "))
           (bgap-len (string-width bgap))
           (rows (cond
                  ((>= width 108)
                   (list external-links))
                  ((>= width 72)
                   (list (seq-subseq external-links 0 3)
                         (seq-subseq external-links 3)))
                  (t
                   (hell-splash--split-buttons-into-rows external-links (max 36 (- width 4)) bgap-len)))))
      (insert header-pad (propertize header-text 'face 'hell-splash-external-heading) "\n\n")
      (dolist (row rows)
        (let* ((row-width (+ (apply #'+ (mapcar (lambda (b) (+ (string-width (nth 0 b)) 6)) row))
                             (* bgap-len (1- (length row)))))
               (left-pad (make-string (max 0 (/ (- width row-width) 2)) ?\s)))
          (insert left-pad)
          (dolist (b row)
            (hell-splash--insert-button (nth 0 b) (nth 1 b) (nth 2 b) (nth 3 b) (nth 4 b))
            (unless (eq b (car (last row)))
              (insert bgap)))
          (insert (if compact-p "\n" "\n\n"))))
      (unless compact-p
        (insert "\n")))

    ;; 5. Telemetry & Benchmark Footer
    (let ((telemetry-line
           (if (and (boundp 'hell-profile) hell-profile)
               (format "HELL EMACS [%s] // [ JVM FORGE IGNITED ] // Bytecode subjugated." (upcase hell-profile))
             "HELL EMACS // [ JVM FORGE IGNITED ] // Bytecode subjugated.")))
      (hell-splash--insert-centered telemetry-line 'hell-splash-tagline width)
      (hell-splash--insert-centered (hell-splash-startup-line) 'hell-splash-altar width))
    (insert "\n")

    ;; 6. Navigation Micro-Hints at the final edge
    (if (>= width 80)
        (hell-splash--insert-centered
         "TAB/S-TAB navigate · RET select · C-x C-f find file · q/ESC dismiss"
         'hell-splash-hint width)
      (hell-splash--insert-centered
       "TAB/S-TAB navigate · RET select · q/ESC dismiss"
       'hell-splash-hint width)
      (hell-splash--insert-centered
       "C-x C-f find file · C-c h i manual · C-c h k keys"
       'hell-splash-hint width))

    ;; Ensure viewport starts at line 1, first button is focused, and echo area is pristine
    (goto-char (point-min))
    (when window
      (set-window-start window (point-min) t))
    (forward-button 1 nil nil t)
    (message nil)))

;;; Keybindings & Mode Definition --------------------------------------------

(defvar-keymap hell-splash-mode-map
  :doc "Keymap for the native Hell Emacs Altar splash screen."
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
  "C-c h i" #'hell-info-manual
  "C-c h k" #'hell-where-is-intellij
  "C-c h p" #'hell-plugins
  "C-h t" #'help-with-tutorial)

(define-derived-mode hell-splash-mode special-mode "Altar"
  "Pure GNU Emacs major mode for the Hell Emacs native Altar splash screen."
  (setq-local revert-buffer-function (lambda (&rest _) (hell-splash--render))
              cursor-type nil
              truncate-lines nil
              buffer-undo-list t
              display-line-numbers nil
              mode-line-format
              (if (and (boundp 'hell-profile) hell-profile)
                  (list "  "
                        (propertize (format " [%s] " (upcase hell-profile))
                                    'face '(:foreground "#16171d" :background "#ff5555" :weight bold))
                        "  Hell Emacs Altar")
                "  Hell Emacs Altar"))
  (add-hook 'window-size-change-functions #'hell-splash--resize-h nil t))

(defun hell-splash--resize-h (window)
  "Redraw the splash screen shown in WINDOW on resize."
  (when (window-live-p window)
    (with-current-buffer (window-buffer window)
      (when (derived-mode-p 'hell-splash-mode)
        (hell-splash--render)))))

(defun hell-splash--get-buffer ()
  "Return the splash buffer, in its mode, without drawing it."
  (let ((buffer (get-buffer-create hell-splash-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hell-splash-mode)
        (hell-splash-mode)))
    buffer))

(defun hell-splash-buffer ()
  "Return the splash buffer, (re)drawn."
  (with-current-buffer (hell-splash--get-buffer)
    (hell-splash--render)
    (current-buffer)))

;;;###autoload
(defun hell-splash ()
  "Return to the Altar: display the native Hell Emacs splash screen."
  (interactive)
  (switch-to-buffer (hell-splash--get-buffer))
  (hell-splash--render))

(defvar hell-splash-buffer-function #'hell-splash-buffer
  "Function returning the startup screen's buffer.")

(defun hell-splash--initial-buffer ()
  "Value for `initial-buffer-choice': the splash screen, unless file arguments were given."
  (cond ((or buffer-file-name (derived-mode-p 'dired-mode))
         (current-buffer))
        (hell-splash-enable
         (funcall hell-splash-buffer-function))
        (t
         (get-scratch-buffer-create))))

(setq initial-buffer-choice #'hell-splash--initial-buffer)

(defun hell-splash--refresh-h (&rest _)
  "Refresh the splash screen buffer once startup telemetry is settled."
  (when-let* ((buffer (get-buffer hell-splash-buffer-name)))
    (with-current-buffer buffer
      (when (derived-mode-p 'hell-splash-mode)
        (hell-splash--render))))
  (message nil))

(add-hook 'hell-after-init-hook #'hell-splash--refresh-h 100)
(add-hook 'window-setup-hook #'hell-splash--refresh-h 100)

(provide 'hell-splash)
;;; +splash.el ends here
