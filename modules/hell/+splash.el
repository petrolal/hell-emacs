;;; hell/+splash.el --- The Altar: GNU Emacs' startup screen, themed -*- lexical-binding: t; -*-

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

;; The Altar is GNU Emacs' own startup screen (`fancy-startup-screen',
;; the `*GNU Emacs*' buffer), not a replacement for it (13.4): the same
;; layout, keys and features (the concise screen beside files given on
;; the command line, the auto-save notice, the newcomer presets, the
;; version line, `C-h C-a'), drawn by Emacs' own code. Hell Emacs only
;; supplies the logo and the words: the chimera skull instead of the GNU
;; logo, a Hell Emacs welcome line and manual, the forge line under the
;; version, and the Altar's buttons at the bottom. With `hell-ux-enable' nil it is the stock screen, untouched.

(require 'seq)
(require 'subr-x)

(defvar hell-dir)
(defvar hell-profile)
(defvar hell-init-time)
(defvar hell-ux-enable)
(defvar browse-url-browser-function)

(autoload 'hell-info-manual "lib/help" nil t)
(autoload 'hell-plugins "hell-plugins" nil t)

(defgroup hell-splash nil
  "The Hell Emacs startup screen."
  :group 'hell)

(defcustom hell-splash-enable t
  "Whether Emacs starts on the Altar (GNU Emacs' startup screen).
Nil is `inhibit-startup-screen': Emacs starts on *scratch*."
  :type 'boolean
  :group 'hell-splash)

(defface hell-splash-welcome
  '((t (:inherit font-lock-comment-face)))
  "Face for the Altar's welcome line (stock: `font-lock-comment-face')."
  :group 'hell-splash)

(defface hell-splash-altar
  '((t (:inherit font-lock-builtin-face)))
  "Face for the Altar's forge line, under the Emacs version."
  :group 'hell-splash)

(defface hell-splash-button
  '((t (:box (:line-width (1 . 1) :color "#3a1c28")
        :background "#1c1e24" :foreground "#f8f8f2" :weight bold)))
  "Face for the Altar's buttons, at the bottom of the screen."
  :group 'hell-splash)

(defface hell-splash-button-active
  '((t (:box (:line-width (1 . 1) :color "#ff5555")
        :background "#282a36" :foreground "#ff79c6" :weight bold)))
  "Face for the Altar's button under the mouse."
  :group 'hell-splash)


(defun hell-splash--themed-p ()
  "Whether the Altar wears Hell Emacs' look (see `hell-ux-enable')."
  (or (not (boundp 'hell-ux-enable)) hell-ux-enable))

;;; The words -----------------------------------------------------------------

(defun hell-splash--browse (url)
  "Return a button action browsing URL, as the stock screen's links do."
  (lambda (_button)
    (let ((browse-url-browser-function 'eww-browse-url))
      (browse-url url))))

(defun hell-splash--startup-text (stock)
  "Return STOCK `fancy-startup-text' with Hell Emacs' welcome and manual.
Only the welcome line before the stock \" operating system.\" is
replaced, and a Hell Emacs manual row put above the stock rows; when a
future Emacs words it differently, STOCK is returned as is."
  (let* ((stock-entry (car stock))
         (rows (cdr (member " operating system.\n\n" stock-entry))))
    (if (null rows)
        stock
      (cons `(:face (variable-pitch hell-splash-welcome)
              "Welcome to "
              :link ("Hell Emacs"
                     ,(hell-splash--browse "https://github.com/petrolal/hell-emacs")
                     "Browse https://github.com/petrolal/hell-emacs")
              ", the infernal JVM forge of "
              :link ("GNU Emacs"
                     ,(hell-splash--browse "https://www.gnu.org/software/emacs/")
                     "Browse https://www.gnu.org/software/emacs/")
              ".\n\n"
              :face variable-pitch
              :link ("Hell Emacs Manual" ,(lambda (_button) (hell-info-manual)))
              "\tThe Hell Emacs guide, using Info\n"
              ,@rows)
            (cdr stock)))))

(defun hell-splash-startup-line ()
  "Return the Altar's forge line: the profile and the startup time."
  (format "Hell Emacs%s // [ JVM FORGE IGNITED ] // Bound in %.2fs with %d collections."
          (if (bound-and-true-p hell-profile) (format " [%s]" hell-profile) "")
          (or (bound-and-true-p hell-init-time)
              (float-time (time-subtract (current-time) before-init-time)))
          gcs-done))

(defun hell-splash--theme-tail (tail-start)
  "Theme the stock tail inserted after TAIL-START in the current buffer.
Adds the forge line after the copyright, and points \"Explore Packages\"
at the Relic Chamber: packages come from `package!', never package.el."
  (save-excursion
    (goto-char tail-start)
    (when (search-forward emacs-copyright nil t)
      (forward-line 1)
      (fancy-splash-insert :face '(variable-pitch hell-splash-altar)
                           (hell-splash-startup-line) "\n")))
  (save-excursion
    (goto-char tail-start)
    (when (search-forward "Explore Packages" nil t)
      (when-let* ((button (button-at (match-beginning 0))))
        (button-put button 'action (lambda (_button) (call-interactively #'hell-plugins)))
        (button-put button 'help-echo
                    "mouse-2, RET: Browse Hell Emacs modules and plugins (the Relic Chamber)")))))

(defun hell-splash--startup-tail-a (fn &rest args)
  "Around `fancy-startup-tail' (FN with ARGS): theme what it inserts."
  (let ((start (point)))
    (prog1 (apply fn args)
      (when (hell-splash--themed-p)
        (hell-splash--theme-tail start)
        (save-excursion
          (goto-char (point-max))
          (hell-splash--insert-buttons))))))

;;; The buttons ---------------------------------------------------------------


(defun hell-splash--buffer ()
  "Switch buffer, as `C-x b' does."
  (interactive)
  (call-interactively (or (keymap-lookup global-map "C-x b") #'switch-to-buffer)))

(defun hell-splash--shell ()
  "Open a shell: vterm when installed, else eshell."
  (interactive)
  (call-interactively (if (fboundp 'vterm) #'vterm #'eshell)))

(defun hell-splash--releases ()
  "Show Hell Emacs' changelog, or its releases page."
  (interactive)
  (let ((changelog (expand-file-name "CHANGELOG.md" hell-dir)))
    (if (file-readable-p changelog)
        (view-file changelog)
      (browse-url "https://github.com/petrolal/hell-emacs/releases"))))

(defconst hell-splash-buttons
  `(("Forge..."
     ("Ignite File" find-file "Find a file (C-x C-f)" "ignite.svg")
     ("Summon Project" project-switch-project "Switch project (C-x p p)" "forge.svg")
     ("Grimoires" hell-splash--buffer "Switch buffer (C-x b)" "skull.svg")
     ("Hell Shell" hell-splash--shell "Open a shell" "shell.svg")
     ("Grimoire Manual" hell-info-manual "The Hell Emacs manual (C-c h i)" "manual.svg")
     ("IntelliJ Exorcism" hell-where-is-intellij "IntelliJ key finder (C-c h k)" "intellij.svg"))
    ("Portals..."
     ("Relic Chamber" hell-plugins "Modules and plugins (C-c h p)" "marketplace.svg")
     ("Forge Source" ,(lambda () (interactive) (browse-url "https://github.com/petrolal/hell-emacs"))
      "Browse https://github.com/petrolal/hell-emacs" "github.svg")
     ("Issue Sanctum" ,(lambda () (interactive) (browse-url "https://github.com/petrolal/hell-emacs/issues"))
      "Browse https://github.com/petrolal/hell-emacs/issues" "github.svg")
     ("Release Grimoires" hell-splash--releases "The changelog and release notes" "manual.svg")))
  "The Altar's buttons, by row: (HEADING (LABEL COMMAND HELP ICON)...).")

(autoload 'hell-where-is-intellij "lib/intellij" nil t)

(defun hell-splash--button-icon (file)
  "Return FILE from assets/buttons/ as an image string, or \"\"."
  (let ((path (expand-file-name (concat "assets/buttons/" file) hell-dir)))
    (if (and (display-graphic-p)
             (image-type-available-p 'svg)
             (file-readable-p path))
        (concat (propertize " " 'display
                            (create-image path 'svg nil :ascent 'center
                                          :max-height 18 :max-width 18))
                " ")
      "")))

(defun hell-splash--insert-buttons ()
  "Insert the Altar's buttons, aligned like the stock \"To start...\" links."
  (fancy-splash-insert :face 'variable-pitch "\n")
  (pcase-dolist (`(,heading . ,buttons) hell-splash-buttons)
    (fancy-splash-insert :face 'variable-pitch (concat "\n" heading "\t"))
    (seq-do-indexed
     (pcase-lambda (`(,label ,command ,help ,icon) i)
       (when (and (> i 0) (zerop (% i 3)))
         (fancy-splash-insert :face 'variable-pitch "\n\t"))
       (insert-text-button (concat " " (hell-splash--button-icon icon) label " ")
                           'action (lambda (_button) (call-interactively command))
                           'follow-link t
                           'help-echo (concat "mouse-2, RET: " help)
                           'face '(hell-splash-button variable-pitch)
                           'mouse-face 'hell-splash-button-active)
       (fancy-splash-insert :face 'variable-pitch " "))
     buttons))
  (insert "\n"))

(defun hell-splash--logo ()
  "Return the Altar's logo file, or nil for GNU Emacs' own."
  (let ((file (expand-file-name "assets/banners/splash.svg" hell-dir)))
    (and (display-graphic-p)
         (image-type-available-p 'svg)
         (file-readable-p file)
         file)))

(defun hell-splash--startup-screen-a (fn &rest args)
  "Around `fancy-startup-screen' (FN with ARGS): Hell Emacs' logo and words."
  (if (not (hell-splash--themed-p))
      (apply fn args)
    (let ((fancy-startup-text (hell-splash--startup-text fancy-startup-text))
          (fancy-splash-image (or fancy-splash-image (hell-splash--logo))))
      (apply fn args))))

(advice-add #'fancy-startup-screen :around #'hell-splash--startup-screen-a)
(advice-add #'fancy-startup-tail :around #'hell-splash--startup-tail-a)

;;; Showing it ----------------------------------------------------------------

(defun hell-splash-buffer ()
  "Return the Altar's buffer, drawn afresh, without displaying it."
  (when-let* ((old (get-buffer "*GNU Emacs*")))
    (kill-buffer old))
  (save-window-excursion
    (display-startup-screen))
  (get-buffer "*GNU Emacs*"))

;;;###autoload
(defun hell-splash ()
  "Return to the Altar, GNU Emacs' startup screen, drawn afresh."
  (interactive)
  (when-let* ((old (get-buffer "*GNU Emacs*")))
    (kill-buffer old))
  (display-startup-screen))

(add-hook 'hell-after-init-hook
          (defun hell-splash--setup-h ()
            ;; Read here, after the user's config.el has had its say.
            (unless hell-splash-enable
              (setq inhibit-startup-screen t))))

(provide 'hell-splash)
;;; +splash.el ends here
