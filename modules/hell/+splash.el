;;; hell/+splash.el --- The Altar: Hell Emacs Workspace Dashboard -*- lexical-binding: t; -*-

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

;; The Altar: a centered, workspace-oriented startup dashboard for
;; Hell Emacs (replacing GNU Emacs' stock FSF links in `*GNU Emacs*').
;; Displays the Hell Emacs logo, startup telemetry, 1-key quick actions
;; (`p' Open Project Workspace, `n' New Project with Specs, `a' Open Agent,
;; `s' Open Spec), Recent Workspaces (`1'..`5' to launch a full 3-column
;; workspace in one keystroke), and Recent Specifications formatted as
;; `[project-name] -> relative/path/spec.md'.
;; With `hell-ux-enable' nil it falls back to the stock startup screen.

;;; Code:

(require 'seq)
(require 'subr-x)

(defvar hell-dir)
(defvar hell-profile)
(defvar hell-init-time)
(defvar hell-ux-enable)

(declare-function nerd-icons-octicon "nerd-icons" (icon-name &rest args))
(declare-function hell-agent-project-root "hell-agent" (&optional dir))
(declare-function hell-agent-register-global-keys "hell-agent" ())

(autoload 'hell-info-manual "lib/help" nil t)
(autoload 'hell-plugins "hell-plugins" nil t)
(autoload 'hell-where-is-intellij "lib/intellij" nil t)
(autoload 'hell-workspace-open "hell-agent" nil t)
(autoload 'hell-workspace-layout "hell-agent" nil t)
(autoload 'hell-agent-toggle "hell-agent" nil t)
(autoload 'hell-agent-select "hell-agent" nil t)
(autoload 'hell-agent-known-projects "hell-agent" nil t)
(autoload 'hell-agent-recent-specs "hell-agent" nil t)
(autoload 'hell-agent-project-root "hell-agent" nil)
(autoload 'hell-agent-register-global-keys "hell-agent" nil)
(autoload 'hell-spec-create "hell-agent" nil t)
(autoload 'hell-spec-open "hell-agent" nil t)
(autoload 'hell-agent-hooks-mode "hell-agent" nil t)

(defgroup hell-splash nil
  "The Hell Emacs workspace startup dashboard (the Altar)."
  :group 'hell)

(defcustom hell-splash-enable t
  "Whether Emacs starts on the Altar (Hell Emacs' workspace dashboard).
Nil sets `inhibit-startup-screen' so Emacs starts on `*scratch*'."
  :type 'boolean
  :group 'hell-splash)

(defcustom hell-splash-line-spacing 0.25
  "Extra space between the Altar's lines, as `line-spacing', for legibility."
  :type '(choice (const :tag "Emacs' default" nil) number)
  :group 'hell-splash)

(defconst hell-splash--buffer-name "*GNU Emacs*"
  "The Altar's buffer name (`display-startup-screen' uses `*GNU Emacs*').")

(defconst hell-splash--block-width 74
  "Target width in columns of the centered dashboard content block.")

(defface hell-splash-welcome
  '((t (:inherit font-lock-keyword-face :weight bold)))
  "Face for the Altar's title and section headers."
  :group 'hell-splash)

(defface hell-splash-altar
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the Altar's forge telemetry line."
  :group 'hell-splash)

(defface hell-splash-key
  '((t (:inherit font-lock-constant-face :weight bold)))
  "Face for 1-key shortcut badges (`[p]', `[a]', `[1-5]') on the Altar."
  :group 'hell-splash)

(defface hell-splash-button
  '((t (:box nil :inherit font-lock-function-name-face :weight bold)))
  "Face for the Altar's borderless action buttons."
  :group 'hell-splash)

(defface hell-splash-button-active
  '((t (:box nil :inherit highlight :weight bold)))
  "Face for the Altar's button under the mouse."
  :group 'hell-splash)

(defun hell-splash--themed-p ()
  "Whether the Altar wears Hell Emacs' workspace look (`hell-ux-enable')."
  (or (not (boundp 'hell-ux-enable)) hell-ux-enable))

(defun hell-splash-startup-line ()
  "Return the Altar's forge line: the profile and the startup time."
  (format "Hell Emacs%s // [ FORGE IGNITED ] // Bound in %.2fs with %d GCs."
          (if (bound-and-true-p hell-profile) (format " [%s]" hell-profile) "")
          (or (bound-and-true-p hell-init-time)
              (float-time (time-subtract (current-time) before-init-time)))
          gcs-done))

(defun hell-splash--logo ()
  "Return the Altar's logo file, or nil when unavailable."
  (let ((file (expand-file-name "assets/banners/splash.svg" hell-dir)))
    (and (display-graphic-p)
         (image-type-available-p 'svg)
         (file-readable-p file)
         file)))

(defun hell-splash--icon (octicon-name fallback)
  "Return a `nerd-icons' glyph for OCTICON-NAME, or FALLBACK string."
  (or (and (require 'nerd-icons nil t)
           (fboundp 'nerd-icons-octicon)
           (ignore-errors
             (concat (nerd-icons-octicon octicon-name :face 'hell-splash-welcome) " ")))
      fallback))

;;; Horizontal Centering & Formatting Helpers ---------------------------------

(defun hell-splash--window-width ()
  "Return the current width of the splash window, or 100 in batch mode."
  (if-let* ((win (get-buffer-window hell-splash--buffer-name t)))
      (window-body-width win)
    (window-body-width)))

(defun hell-splash--pad (width)
  "Return left-padding whitespace to center a line/block of WIDTH columns."
  (let* ((win-w (hell-splash--window-width))
         (margin (max 4 (/ (- win-w width) 2))))
    (make-string margin ?\s)))

(defun hell-splash--insert-centered-line (text &optional face)
  "Insert TEXT centered horizontally in the window, optionally with FACE."
  (let ((pad (hell-splash--pad (string-width text))))
    (insert pad (if face (propertize text 'face face) text) "\n")))

(defun hell-splash--command-key-hint (command)
  "Return the live global keybinding string for COMMAND."
  (let ((raw (substitute-command-keys
              (format "\\<global-map>\\[%s]" command))))
    (if (string-prefix-p "M-x " raw)
        ""
      (format "(%s)" raw))))

(defun hell-splash--format-spec-label (spec-file)
  "Format SPEC-FILE as `[project-name] -> relative/path/spec.md'."
  (let* ((dir (file-name-directory spec-file))
         (root (or (ignore-errors (hell-agent-project-root dir))
                   (locate-dominating-file dir ".git")
                   (when-let* ((os (locate-dominating-file dir "openspec")))
                     os)
                   (when-let* ((sp (locate-dominating-file dir "specs")))
                     sp)))
         (proj-name (if root
                        (file-name-nondirectory
                         (directory-file-name (expand-file-name root)))
                      "workspace"))
         (rel-path (if root
                       (file-relative-name spec-file (expand-file-name root))
                     (abbreviate-file-name spec-file))))
    (format "[%s] -> %s" proj-name rel-path)))

;;; Workspace Splash Mode & Keymap --------------------------------------------

(defvar-local hell-splash--recent-projects nil
  "List of recent project roots displayed on the current splash buffer.")

(defun hell-splash-open-recent-project (index)
  "Open the INDEX-th (1-based) recent project from the splash screen."
  (let ((proj (nth (1- index) hell-splash--recent-projects)))
    (if proj
        (hell-workspace-open proj)
      (call-interactively #'hell-workspace-open))))

(defvar-keymap hell-splash-mode-map
  :doc "Keymap for `hell-splash-mode' (Hell Emacs Workspace Altar)."
  :parent special-mode-map
  "p" #'hell-workspace-open
  "n" #'hell-spec-create
  "a" #'hell-agent-toggle
  "A" #'hell-agent-select
  "s" #'hell-spec-open
  "w" #'hell-workspace-layout
  "h" #'hell-agent-hooks-mode
  "m" #'hell-info-manual
  "P" #'hell-plugins
  "k" #'hell-where-is-intellij
  "g" #'hell-splash
  "TAB" #'forward-button
  "<backtab>" #'backward-button
  "1" (lambda () (interactive) (hell-splash-open-recent-project 1))
  "2" (lambda () (interactive) (hell-splash-open-recent-project 2))
  "3" (lambda () (interactive) (hell-splash-open-recent-project 3))
  "4" (lambda () (interactive) (hell-splash-open-recent-project 4))
  "5" (lambda () (interactive) (hell-splash-open-recent-project 5)))

(defun hell-splash--on-window-resize-h (&optional _frame)
  "Re-center the Altar dashboard when the window width changes."
  (when-let* ((buf (get-buffer hell-splash--buffer-name))
              (win (get-buffer-window buf t)))
    (with-current-buffer buf
      (when (derived-mode-p 'hell-splash-mode)
        (let ((pt (point)))
          (hell-splash--render-workspace)
          (goto-char (min pt (point-max))))))))

(define-derived-mode hell-splash-mode special-mode "Altar"
  "Major mode for the Hell Emacs Workspace startup screen."
  (setq-local buffer-read-only t
              truncate-lines t
              cursor-type nil
              line-spacing hell-splash-line-spacing)
  (add-hook 'window-size-change-functions #'hell-splash--on-window-resize-h nil t))

;;; Rendering the Centered Workspace Dashboard --------------------------------

(defun hell-splash--insert-section-title (icon-name title)
  "Insert a centered section header with ICON-NAME and TITLE."
  (let ((margin (hell-splash--pad hell-splash--block-width)))
    (insert margin
            (hell-splash--icon icon-name "◆ ")
            (propertize title 'face 'hell-splash-welcome)
            "\n")))

(defun hell-splash--insert-action-row (key icon-name label command desc)
  "Insert a centered quick-action row with KEY, ICON-NAME, LABEL, COMMAND, DESC."
  (let* ((margin (hell-splash--pad hell-splash--block-width))
         (key-badge (propertize (format "[%s]" key) 'face 'hell-splash-key))
         (icon (hell-splash--icon icon-name ""))
         (key-hint (hell-splash--command-key-hint command))
         (padded-label (format "%-23s" label)))
    (insert margin "  " key-badge "  " icon)
    (insert-text-button padded-label
                        'action (lambda (_btn) (call-interactively command))
                        'follow-link t
                        'help-echo (format "%s %s" desc key-hint)
                        'face 'hell-splash-button
                        'mouse-face 'hell-splash-button-active)
    (insert " " (propertize desc 'face 'font-lock-comment-face))
    (unless (string-empty-p key-hint)
      (insert " " (propertize key-hint 'face 'font-lock-doc-face)))
    (insert "\n")))

(defun hell-splash--render-workspace ()
  "Populate the current buffer with the centered Hell Emacs workspace dashboard."
  (ignore-errors (hell-agent-register-global-keys))
  (let ((inhibit-read-only t)
        (projects (seq-take (or (ignore-errors (hell-agent-known-projects)) nil) 5))
        (specs (or (ignore-errors (hell-agent-recent-specs 5)) nil))
        (block-pad (hell-splash--pad hell-splash--block-width)))
    (erase-buffer)
    (hell-splash-mode)
    (setq-local hell-splash--recent-projects projects)
    (insert "\n")

    ;; 1. Centered Logo / Banner
    (if-let* ((logo (hell-splash--logo)))
        (let* ((img (create-image logo 'svg nil :max-height 180))
               (img-w (car (image-size img)))
               (win-w (hell-splash--window-width))
               (align (max 4 (round (/ (- win-w img-w) 2.0)))))
          (insert (propertize " " 'display `(space :align-to ,align)))
          (insert-image img)
          (insert "\n\n"))
      (let* ((banner-lines
              '("╦ ╦╔═╗╦  ╦    ╔═╗╔╦╗╔═╗╔═╗╔═╗  //  THE INFERNAL FORGE"
                "╠═╣║╣ ║  ║    ║╣ ║║║╠═╣║  ╚═╗  //  Spec-Driven & Agentic IDE"
                "╩ ╩╚═╝╩═╝╩═╝  ╚═╝╩ ╩╩ ╩╚═╝╚═╝  //  ACP · GPTel · MCP · FIM"))
             (banner-pad (hell-splash--pad
                          (apply #'max (mapcar #'string-width banner-lines)))))
        (dolist (line banner-lines)
          (insert banner-pad (propertize line 'face 'hell-splash-welcome) "\n")))
      (insert "\n"))

    ;; 2. Centered Telemetry Line
    (hell-splash--insert-centered-line (hell-splash-startup-line) 'hell-splash-altar)
    (insert "\n")

    ;; 3. Quick Actions (live keybindings via `substitute-command-keys')
    (hell-splash--insert-section-title "nf-oct-zap" "Quick Actions")
    (hell-splash--insert-action-row
     "p" "nf-oct-repo" "Open Project Workspace" #'hell-workspace-open
     "Select project & open 3-column layout")
    (hell-splash--insert-action-row
     "n" "nf-oct-file_code" "New Project with Specs" #'hell-spec-create
     "Scaffold openspec/ (requirements, design, tasks)")
    (hell-splash--insert-action-row
     "a" "nf-oct-hubot" "Open Project Agent" #'hell-agent-toggle
     "Launch agent-shell with steering")
    (hell-splash--insert-action-row
     "A" "nf-oct-gear" "Select Agent Provider" #'hell-agent-select
     "Choose Claude, Gemini, Codex, OpenCode or GPTel")
    (hell-splash--insert-action-row
     "s" "nf-oct-book" "Open Specification" #'hell-spec-open
     "Jump to requirements.md, design.md, or tasks.md")
    (hell-splash--insert-action-row
     "P" "nf-oct-package" "Relic Chamber" #'hell-plugins
     "Manage Hell Emacs modules & plugins")
    (hell-splash--insert-action-row
     "m" "nf-oct-mortar_board" "Hell Emacs Manual" #'hell-info-manual
     "Read the Hell Emacs Info manual")
    (insert "\n")

    ;; 4. Recent Workspaces (1-key launchers)
    (hell-splash--insert-section-title "nf-oct-project" "Recent Workspaces (1-key launch)")
    (if (null projects)
        (insert block-pad "  "
                (propertize "No recent projects recorded yet. Press [p] to open a project.\n"
                            'face 'font-lock-comment-face))
      (seq-do-indexed
       (lambda (proj idx)
         (let* ((num (1+ idx))
                (name (file-name-nondirectory (directory-file-name proj)))
                (abbr (abbreviate-file-name proj))
                (badge (propertize (format "[%d]" num) 'face 'hell-splash-key)))
           (insert block-pad "  " badge "  " (hell-splash--icon "nf-oct-file_directory" ""))
           (insert-text-button
            (format "%-22s" name)
            'action (lambda (_btn) (hell-workspace-open proj))
            'follow-link t
            'help-echo (format "Open 3-column workspace at %s" abbr)
            'face 'hell-splash-button
            'mouse-face 'hell-splash-button-active)
           (insert "  " (propertize abbr 'face 'font-lock-comment-face) "\n")))
       projects))
    (insert "\n")

    ;; 5. Recent Specifications (`[project-name] -> relative/path/spec.md')
    (hell-splash--insert-section-title "nf-oct-checklist" "Recent Specifications")
    (if (null specs)
        (insert block-pad "  "
                (propertize "No specs found. Press [n] to create requirements.md, design.md & tasks.md.\n"
                            'face 'font-lock-comment-face))
      (dolist (spec specs)
        (let ((label (hell-splash--format-spec-label spec))
              (abbr (abbreviate-file-name spec)))
          (insert block-pad "  "
                  (propertize "•" 'face 'hell-splash-key)
                  "    "
                  (hell-splash--icon "nf-oct-markdown" ""))
          (insert-text-button
           label
           'action (lambda (_btn) (find-file spec))
           'follow-link t
           'help-echo (format "Open specification %s" abbr)
           'face 'hell-splash-button
           'mouse-face 'hell-splash-button-active)
          (insert "\n"))))

    (insert "\n")
    (hell-splash--insert-centered-line
     "[p] Project  [n] New Spec  [a] Agent  [A] Provider  [s] Specs  [1-5] Workspace  [q] Quit"
     'font-lock-comment-face)
    (goto-char (point-min))
    (forward-button 1 nil nil t)
    (set-buffer-modified-p nil)))

(defun hell-splash--display-screen-a (fn &rest args)
  "Override `display-startup-screen' (FN with ARGS) with the Workspace Altar."
  (if (not (hell-splash--themed-p))
      (apply fn args)
    (let ((buf (get-buffer-create hell-splash--buffer-name)))
      (with-current-buffer buf
        (hell-splash--render-workspace))
      (switch-to-buffer buf)
      (delete-other-windows))))

(advice-add #'display-startup-screen :around #'hell-splash--display-screen-a)

;;; Showing it ----------------------------------------------------------------

(defun hell-splash-buffer ()
  "Return the Altar's buffer, drawn afresh, without displaying it."
  (let ((buf (get-buffer-create hell-splash--buffer-name)))
    (with-current-buffer buf
      (hell-splash--render-workspace))
    buf))

;;;###autoload
(defun hell-splash (&optional _title)
  "Display the Altar, Hell Emacs' workspace startup dashboard."
  (interactive)
  (let ((buf (hell-splash-buffer)))
    (switch-to-buffer buf)
    (delete-other-windows)))

(add-hook 'hell-after-init-hook
          (defun hell-splash--setup-h ()
            ;; Read here, after the user's config.el has had its say.
            (unless hell-splash-enable
              (setq inhibit-startup-screen t))))

(provide 'hell-splash)
;;; +splash.el ends here
