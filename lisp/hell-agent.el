;;; hell-agent.el --- Hell Emacs Agentic IDE: Workspace, Specs, Steering & Hooks -*- lexical-binding: t; -*-

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

;; Core Spec-Driven & Agentic IDE workflow for Hell Emacs:
;;   1. 3-Column Workspace with Smart Left Sidebar (`C-c w 1..3', `C-c w w'):
;;      - Left View 1 (`C-c w 1'): Project Explorer (`Treemacs' or Dired).
;;      - Left View 2 (`C-c w 2'): `*Hell Specs*' interactive spec progress
;;        panel (`[done/total]' progress bar, links to `requirements.md',
;;        `design.md', `tasks.md', and `[+ New Spec]').
;;      - Left View 3 (`C-c w 3'): `*Hell Forge*' interactive Steering & Agent
;;        Hooks control panel with `[ON]' / `[OFF]' toggles via `RET' or click.
;;      - Center: Editor with contextual phase progress `header-line-format'
;;        when `hell-spec-mode' is active.
;;      - Right (`side: right', width 0.38): Agent panel (`agent-shell' or
;;        `gptel') with status `header-line-format'.
;;   2. Interactive Spec Pipeline (`hell-spec-mode'):
;;      - Auto-enabled in `openspec/' and `specs/' `.md'/`.org' buffers.
;;      - `hell-spec-advance-phase' (`C-c s a'): Requirements -> Design -> Tasks.
;;      - Inline clickable task overlays (`[▶ Run Task]' -> `[⏳ Running...]')
;;        on `- [ ] ...' lines in `tasks.md'.
;;      - `hell-spec-execute-task' (`C-c s e') & `hell-spec-toggle-task' (`C-c s t').
;;   3. Visual Agent Hooks (`hell-hooks' / `hell-agent-hooks-mode'):
;;      - Reads project rules from `.hell-hooks.el', `.dir-locals.el', or
;;        `hell-agent-hooks' in tuple `(event glob-pattern cmd-or-prompt)' or
;;        plist format, with discrete echo-area and header-line notifications.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'seq)
(require 'subr-x)

(defvar hell-dir)
(defvar hell-state-dir)
(defvar recentf-list)
(defvar agent-shell-system-prompt)
(defvar agent-shell-cwd-function)
(defvar agent-shell-display-action)
(defvar agent-shell-preferred-agent-config)
(defvar gptel--system-message)
(defvar gptel-default-mode)
(defvar treemacs-position)
(defvar treemacs-width)
(defvar treemacs-display-in-side-window)

(declare-function hell-leader-def "hell/autoload/keybinds" (&rest bindings))
(declare-function hell-llm-project-root "tools/llm/autoload" ())
(declare-function hell-llm-chat "tools/llm/autoload" (&optional arg))
(declare-function hell-llm-quick-chat "tools/llm/autoload" (prompt))
(declare-function hell-llm-send "tools/llm/autoload" (&optional arg))
(declare-function agent-shell "agent-shell" (&optional arg))
(declare-function agent-shell-toggle "agent-shell" ())
(declare-function agent-shell-new-shell "agent-shell" ())
(declare-function agent-shell-buffers "agent-shell" ())
(declare-function agent-shell-project-buffers "agent-shell" (&optional cwd))
(declare-function agent-shell-send-region "agent-shell" (&optional pick-shell))
(declare-function agent-shell-send-file "agent-shell" (&optional prompt-for-file pick-shell))
(declare-function agent-shell--display-and-insert-context "agent-shell" (shell-buffer text))
(declare-function gptel "gptel" (name &optional key initial interactivep))
(declare-function gptel-request "gptel-request" (&optional prompt &rest args))
(declare-function treemacs "treemacs" (&optional arg))
(declare-function treemacs-get-local-window "treemacs-scope" ())
(declare-function treemacs-select-window "treemacs" (&optional arg))
(declare-function treemacs-add-and-display-current-project-exclusively "treemacs" ())

(defgroup hell-agent nil
  "Hell Emacs spec-driven and agentic IDE workflow."
  :group 'tools
  :prefix "hell-")

(defcustom hell-spec-directory "openspec"
  "Default directory name relative to project root for specifications.
Can be \"openspec\" or \"specs\"."
  :type 'string
  :group 'hell-agent)

(defcustom hell-agent-window-width 0.38
  "Width of the right-hand agent side window as a fraction of the frame."
  :type 'number
  :group 'hell-agent)

(defcustom hell-agent-treemacs-window-width 32
  "Width in columns of the left-hand sidebar window."
  :type 'integer
  :group 'hell-agent)

(defcustom hell-agent-preferred-provider nil
  "Preferred agent provider symbol.
One of `claude-code', `gemini', `codex', `opencode', or `gptel'.
When nil, automatically detects available CLI or falls back to `gptel'."
  :type '(choice (const :tag "Auto-detect" nil)
                 (const :tag "Claude Code CLI" claude-code)
                 (const :tag "Gemini CLI" gemini)
                 (const :tag "Codex CLI" codex)
                 (const :tag "OpenCode CLI" opencode)
                 (const :tag "GPTel Native Elisp" gptel))
  :group 'hell-agent)

(defcustom hell-agent-steering-files
  '("AGENTS.md"
    "CLAUDE.md"
    ".hell/steering/product.md"
    ".hell/steering/tech.md"
    ".hell/steering/structure.md"
    ".hell/steering/project.md"
    "openspec/project.md")
  "Project-relative paths checked automatically for agent steering context."
  :type '(repeat string)
  :group 'hell-agent)

(defcustom hell-agent-steering-max-chars 16000
  "Maximum characters read across steering files when building system context."
  :type 'integer
  :group 'hell-agent)

(defconst hell-specs-panel-buffer "*Hell Specs*"
  "Name of the left-sidebar Specifications overview buffer (`C-c w 2').")

(defconst hell-forge-panel-buffer "*Hell Forge*"
  "Name of the left-sidebar Steering & Agent Hooks buffer (`C-c w 3').")

(defvar hell-agent--last-hook-status nil
  "Last triggered Agent Hook message shown in the header line.")

(defvar hell-agent-hooks)

(defvar hell-spec--running-tasks (make-hash-table :test #'equal)
  "Table mapping (FILE . LINE-TEXT) to running status for task overlays.")

;;; 1. Project & Workspace Helpers --------------------------------------------

(defun hell-agent-project-root (&optional dir)
  "Return the project root for DIR (or `default-directory'), or nil if none."
  (let ((target (or dir default-directory)))
    (or (when-let* ((proj (project-current nil target)))
          (expand-file-name (project-root proj)))
        (when-let* ((git-root (locate-dominating-file target ".git")))
          (expand-file-name git-root)))))

(defun hell-agent-project-root-or-default (&optional dir)
  "Return the project root for DIR, falling back to `default-directory'."
  (expand-file-name (or (hell-agent-project-root dir)
                        dir
                        default-directory)))

;;;###autoload
(defun hell-agent-known-projects ()
  "Return list of known project roots from `project.el' state without heavy I/O."
  (if (and (fboundp 'project-known-project-roots)
           (bound-and-true-p project--list)
           (not (eq project--list 'unset)))
      (project-known-project-roots)
    (let ((file (if (boundp 'project-list-file)
                    project-list-file
                  (expand-file-name "projects" hell-state-dir))))
      (when (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (let ((data (ignore-errors (read (current-buffer)))))
            (when (listp data)
              (delq nil (mapcar #'car-safe data)))))))))

;;;###autoload
(defun hell-agent-recent-specs (&optional limit)
  "Return up to LIMIT existing spec files across current and recent projects."
  (let ((max-count (or limit 6))
        (roots (delete-dups
                (delq nil
                      (cons (hell-agent-project-root)
                            (hell-agent-known-projects)))))
        (candidates nil))
    (when (bound-and-true-p recentf-list)
      (dolist (f recentf-list)
        (when (and (string-match-p
                    "\\(?:/openspec/\\|/specs/\\).*\\.\\(?:md\\|org\\)\\'"
                    f)
                   (file-readable-p f))
          (cl-pushnew (expand-file-name f) candidates :test #'equal))))
    (dolist (root roots)
      (when (< (length candidates) max-count)
        (dolist (subdir '("openspec" "specs"))
          (let ((sdir (expand-file-name subdir root)))
            (when (file-directory-p sdir)
              (dolist (f (directory-files-recursively
                          sdir "\\.\\(?:md\\|org\\)\\'" nil))
                (when (and (< (length candidates) max-count)
                           (file-readable-p f))
                  (cl-pushnew (expand-file-name f) candidates :test #'equal))))))))
    (seq-take (nreverse candidates) max-count)))

;;; 2. Three-Column Workspace & Smart Left Sidebar (`C-c w 1..3') -------------

(defun hell-agent-right-window-action ()
  "Return the `display-buffer' action for the right-hand Agent side window."
  `((display-buffer-reuse-window display-buffer-in-side-window)
    (side . right)
    (slot . 0)
    (window-width . ,hell-agent-window-width)
    (preserve-size . (t . nil))))

(defun hell-agent-left-window-action ()
  "Return the `display-buffer' action for the left-hand sidebar window."
  `((display-buffer-reuse-window display-buffer-in-side-window)
    (side . left)
    (slot . 0)
    (window-width . ,hell-agent-treemacs-window-width)
    (preserve-size . (t . nil))))

;;;###autoload
(defun hell-agent-setup-display-rules ()
  "Install `display-buffer-alist' rules for the 3-column Hell Emacs layout."
  (let ((right (hell-agent-right-window-action))
        (left (hell-agent-left-window-action)))
    (dolist (pat '("\\`\\*gptel"
                   "\\`\\*hell-spec"
                   "\\`\\*mcp-hub\\*\\'"
                   "\\`\\*hell-agent-hooks\\*\\'"
                   "\\(?:Agent\\|agent-shell\\)"))
      (setf (alist-get pat display-buffer-alist nil nil #'equal) right))
    (dolist (pat '("\\`\\*Treemacs"
                   "\\`\\*Hell Specs\\*\\'"
                   "\\`\\*Hell Forge\\*\\'"))
      (setf (alist-get pat display-buffer-alist nil nil #'equal) left))))

(defun hell-workspace--center-window ()
  "Return the primary non-side editing window in the current frame."
  (or (seq-find (lambda (w)
                  (not (window-parameter w 'window-side)))
                (window-list))
      (selected-window)))

(defun hell-workspace--open-in-center (file)
  "Open FILE in the center editing window without disturbing sidebars."
  (let ((win (hell-workspace--center-window)))
    (select-window win)
    (find-file file)))

(defun hell-workspace--sidebar-header (active-tab)
  "Build the left sidebar's `header-line-format' highlighting ACTIVE-TAB (1..3)."
  (let ((tabs `((1 "1:Files" hell-workspace-sidebar-explorer)
                (2 "2:Specs" hell-workspace-sidebar-specs)
                (3 "3:Forge" hell-workspace-sidebar-forge))))
    (concat
     " "
     (mapconcat
      (pcase-lambda (`(,idx ,label ,cmd))
        (let ((map (make-sparse-keymap)))
          (keymap-set map "<header-line> <mouse-1>"
                      (lambda () (interactive) (call-interactively cmd)))
          (propertize (format "[%s]" label)
                      'face (if (= idx active-tab)
                                'font-lock-keyword-face
                              'font-lock-comment-face)
                      'mouse-face 'highlight
                      'help-echo (format "Switch left sidebar to %s (C-c w %d)" label idx)
                      'keymap map)))
      tabs
      " "))))

(defun hell-workspace--close-left-side-windows ()
  "Delete any currently visible left side windows so a new view can take slot 0."
  (dolist (win (window-list))
    (when (eq (window-parameter win 'window-side) 'left)
      (ignore-errors (delete-window win)))))

;;;###autoload
(defun hell-workspace-sidebar-explorer ()
  "Switch the left sidebar to View 1: Project File Explorer (`C-c w 1')."
  (interactive)
  (hell-agent-setup-display-rules)
  (let* ((root (hell-agent-project-root-or-default))
         (default-directory root)
         (center (hell-workspace--center-window)))
    (dolist (b (list hell-specs-panel-buffer hell-forge-panel-buffer))
      (when-let* ((buf (get-buffer b))
                  (win (get-buffer-window buf)))
        (ignore-errors (delete-window win))))
    (if (fboundp 'treemacs)
        (progn
          (setq treemacs-position 'left
                treemacs-width hell-agent-treemacs-window-width
                treemacs-display-in-side-window t)
          (save-selected-window
            (if (fboundp 'treemacs-add-and-display-current-project-exclusively)
                (let ((inhibit-message t))
                  (unless (and (fboundp 'treemacs-get-local-window)
                               (treemacs-get-local-window))
                    (treemacs-add-and-display-current-project-exclusively)))
              (treemacs))))
      (let ((buf (dired-noselect root)))
        (with-current-buffer buf
          (setq-local header-line-format (hell-workspace--sidebar-header 1)))
        (display-buffer buf (hell-agent-left-window-action))))
    (when (window-live-p center)
      (select-window center))))

;;; View 2: `*Hell Specs*' Sidebar Panel (`C-c w 2') --------------------------

(defun hell-spec--discover-suites (&optional root)
  "Discover specification directories in project ROOT.
Returns a list of plists with `:name', `:dir', `:req', `:design', `:tasks',
`:done', and `:total'."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (dirs nil)
         (suites nil))
    (dolist (sub '("openspec" "specs"))
      (let ((base (expand-file-name sub proj-root)))
        (when (file-directory-p base)
          (when (or (file-exists-p (expand-file-name "requirements.md" base))
                    (file-exists-p (expand-file-name "design.md" base))
                    (file-exists-p (expand-file-name "tasks.md" base)))
            (push (cons (file-name-nondirectory (directory-file-name proj-root))
                        base)
                  dirs))
          (dolist (child (directory-files base t "\\`[^.]"))
            (when (and (file-directory-p child)
                       (or (file-exists-p (expand-file-name "requirements.md" child))
                           (file-exists-p (expand-file-name "design.md" child))
                           (file-exists-p (expand-file-name "tasks.md" child))))
              (push (cons (file-name-nondirectory child) child) dirs))))))
    (pcase-dolist (`(,name . ,dir) (nreverse dirs))
      (let* ((req (expand-file-name "requirements.md" dir))
             (des (expand-file-name "design.md" dir))
             (tsk (expand-file-name "tasks.md" dir))
             (counts (hell-spec--task-counts tsk)))
        (push (list :name name
                    :dir dir
                    :req req
                    :design des
                    :tasks tsk
                    :done (car counts)
                    :total (cdr counts))
              suites)))
    (nreverse suites)))

(defun hell-spec--task-counts (tasks-file)
  "Return `(DONE . TOTAL)' checkbox task counts in TASKS-FILE (or its buffer)."
  (let ((buf (and tasks-file (find-buffer-visiting tasks-file))))
    (if (and (not buf) (not (and tasks-file (file-readable-p tasks-file))))
        '(0 . 0)
      (let ((done 0)
            (total 0))
        (with-temp-buffer
          (if buf
              (insert-buffer-substring buf)
            (insert-file-contents tasks-file))
          (goto-char (point-min))
          (while (re-search-forward "^[ \t]*[-*+][ \t]+\\[\\([ xX-]\\)\\][ \t]+" nil t)
            (cl-incf total)
            (when (member (match-string 1) '("x" "X"))
              (cl-incf done))))
        (cons done total)))))

(defun hell-spec--progress-bar (done total &optional width)
  "Render a compact ASCII/Unicode progress bar for DONE of TOTAL tasks."
  (let* ((w (or width 8))
         (filled (if (> total 0) (round (* w (/ (float done) total))) 0))
         (empty (max 0 (- w filled))))
    (format "[%s%s %d/%d]"
            (propertize (make-string filled ?■) 'face 'success)
            (propertize (make-string empty ?□) 'face 'shadow)
            done total)))

(defvar-keymap hell-specs-panel-mode-map
  :doc "Keymap for `*Hell Specs*' sidebar panel."
  :parent special-mode-map
  "g" #'hell-workspace-sidebar-specs
  "n" #'hell-spec-create
  "1" #'hell-workspace-sidebar-explorer
  "2" #'hell-workspace-sidebar-specs
  "3" #'hell-workspace-sidebar-forge)

(define-derived-mode hell-specs-panel-mode special-mode "HellSpecs"
  "Major mode for the `*Hell Specs*' left sidebar panel."
  (setq-local buffer-read-only t
              truncate-lines t
              header-line-format (hell-workspace--sidebar-header 2)))

(defun hell-specs-panel--render (root)
  "Render the `*Hell Specs*' sidebar buffer for project ROOT."
  (let ((inhibit-read-only t)
        (suites (hell-spec--discover-suites root)))
    (erase-buffer)
    (hell-specs-panel-mode)
    (setq default-directory root)
    (insert "\n "
            (propertize "HELL SPECS" 'face 'font-lock-keyword-face)
            "  ")
    (insert-text-button "[+ New Spec]"
                        'action (lambda (_b) (call-interactively #'hell-spec-create))
                        'follow-link t
                        'face 'font-lock-constant-face
                        'help-echo "Create a new spec suite (C-c s n)")
    (insert "\n "
            (propertize (make-string 28 ?─) 'face 'shadow)
            "\n\n")
    (if (null suites)
        (insert (propertize " No specs in project yet.\n Press `n' or `C-c s n'\n to scaffold openspec/.\n"
                            'face 'font-lock-comment-face))
      (dolist (s suites)
        (let ((name (plist-get s :name))
              (done (plist-get s :done))
              (total (plist-get s :total))
              (req (plist-get s :req))
              (des (plist-get s :design))
              (tsk (plist-get s :tasks)))
          (insert " " (propertize (concat "◆ " name) 'face 'font-lock-function-name-face) "\n")
          (insert "   " (hell-spec--progress-bar done total) "\n")
          (dolist (item `(("1. requirements.md" . ,req)
                          ("2. design.md" . ,des)
                          ("3. tasks.md" . ,tsk)))
            (insert "   ├─ ")
            (insert-text-button
             (car item)
             'action (let ((target (cdr item)))
                       (lambda (_b) (hell-workspace--open-in-center target)))
             'follow-link t
             'face (if (file-exists-p (cdr item))
                       'font-lock-string-face
                     'shadow)
             'help-echo (format "Open %s in editor" (car item)))
            (insert "\n"))
          (insert "\n"))))
    (goto-char (point-min))
    (set-buffer-modified-p nil)))

;;;###autoload
(defun hell-workspace-sidebar-specs ()
  "Switch the left sidebar to View 2: Specifications Panel (`C-c w 2')."
  (interactive)
  (hell-agent-setup-display-rules)
  (let* ((root (hell-agent-project-root-or-default))
         (buf (get-buffer-create hell-specs-panel-buffer)))
    (hell-workspace--close-left-side-windows)
    (with-current-buffer buf
      (hell-specs-panel--render root))
    (display-buffer buf (hell-agent-left-window-action))))

;;; View 3: `*Hell Forge*' Steering & Agent Hooks Sidebar (`C-c w 3') ---------

(defvar-keymap hell-forge-panel-mode-map
  :doc "Keymap for `*Hell Forge*' sidebar panel."
  :parent special-mode-map
  "g" #'hell-workspace-sidebar-forge
  "a" #'hell-agent-hooks-add-rule
  "h" #'hell-agent-hooks-mode
  "i" #'hell-agent-inject-steering
  "s" #'hell-agent-steering-edit
  "l" #'hell-agent-hooks-show-log
  "1" #'hell-workspace-sidebar-explorer
  "2" #'hell-workspace-sidebar-specs
  "3" #'hell-workspace-sidebar-forge)

(define-derived-mode hell-forge-panel-mode special-mode "HellForge"
  "Major mode for the `*Hell Forge*' Steering & Agent Hooks sidebar panel."
  (setq-local buffer-read-only t
              truncate-lines t
              header-line-format (hell-workspace--sidebar-header 3)))

(defun hell-hooks-toggle-rule (rule-name)
  "Toggle `:enabled' state of Agent Hook RULE-NAME and refresh `*Hell Forge*'."
  (interactive "sToggle hook rule: ")
  (hell-hooks--ensure-project-rules)
  (setq hell-agent-hooks
        (mapcar (lambda (rule)
                  (if (equal (plist-get rule :name) rule-name)
                      (let ((cur (if (plist-member rule :enabled)
                                     (plist-get rule :enabled)
                                   t)))
                        (plist-put (copy-sequence rule) :enabled (not cur)))
                    rule))
                hell-agent-hooks))
  (when (get-buffer hell-forge-panel-buffer)
    (with-current-buffer hell-forge-panel-buffer
      (let ((pt (point)))
        (hell-forge-panel--render (hell-agent-project-root-or-default))
        (goto-char (min pt (point-max))))))
  (message "[Hell Hook] Toggled rule %S" rule-name))

(defun hell-forge-panel--render (root)
  "Render the `*Hell Forge*' Steering & Agent Hooks sidebar for project ROOT."
  (hell-hooks--ensure-project-rules root)
  (let ((inhibit-read-only t)
        (steering (hell-agent-discover-steering-files root)))
    (erase-buffer)
    (hell-forge-panel-mode)
    (setq default-directory root)
    ;; 1. Steering Section
    (insert "\n "
            (propertize "STEERING RULES" 'face 'font-lock-keyword-face)
            " ")
    (insert-text-button "[+Edit]"
                        'action (lambda (_b)
                                  (select-window (hell-workspace--center-window))
                                  (call-interactively #'hell-agent-steering-edit))
                        'follow-link t
                        'face 'font-lock-constant-face
                        'help-echo "Edit or create project steering file")
    (insert " ")
    (insert-text-button "[↻Inject]"
                        'action (lambda (_b) (call-interactively #'hell-agent-inject-steering))
                        'follow-link t
                        'face 'font-lock-builtin-face
                        'help-echo "Inject steering files into active agent")
    (insert "\n "
            (propertize (make-string 28 ?─) 'face 'shadow)
            "\n")
    (if (null steering)
        (insert (propertize " No AGENTS.md or CLAUDE.md.\n Click [+Edit] to create one.\n"
                            'face 'font-lock-comment-face))
      (dolist (f steering)
        (let ((rel (file-relative-name f root)))
          (insert "  • ")
          (insert-text-button
           rel
           'action (let ((target f))
                     (lambda (_b) (hell-workspace--open-in-center target)))
           'follow-link t
           'face 'font-lock-string-face
           'help-echo (format "Open %s" rel))
          (insert "\n"))))

    ;; 2. Agent Hooks Section
    (insert "\n "
            (propertize "AGENT HOOKS" 'face 'font-lock-keyword-face)
            "  ")
    (let ((on (bound-and-true-p hell-agent-hooks-mode)))
      (insert-text-button
       (if on "[MODE: ON]" "[MODE: OFF]")
       'action (lambda (_b)
                 (hell-agent-hooks-mode (if (bound-and-true-p hell-agent-hooks-mode) -1 1))
                 (hell-forge-panel--render root))
       'follow-link t
       'face (if on 'success 'shadow)
       'help-echo "Toggle hell-agent-hooks-mode"))
    (insert "\n "
            (propertize (make-string 28 ?─) 'face 'shadow)
            "\n")
    (dolist (rule hell-agent-hooks)
      (let* ((name (or (plist-get rule :name) "hook"))
             (enabled (if (plist-member rule :enabled)
                          (plist-get rule :enabled)
                        t))
             (match (or (plist-get rule :glob) (plist-get rule :match) "*")))
        (insert "  ")
        (insert-text-button
         (if enabled "[ON] " "[OFF]")
         'action (let ((nm name))
                   (lambda (_b) (hell-hooks-toggle-rule nm)))
         'follow-link t
         'face (if enabled 'success 'shadow)
         'help-echo (format "RET/click: Toggle hook %s" name))
        (insert " " (propertize name 'face 'font-lock-function-name-face) "\n")
        (insert "        " (propertize match 'face 'font-lock-comment-face) "\n")))
    (insert "\n  ")
    (insert-text-button "[+ Add Hook]"
                        'action (lambda (_b) (call-interactively #'hell-agent-hooks-add-rule))
                        'follow-link t
                        'face 'font-lock-constant-face)
    (insert "  ")
    (insert-text-button "[View Log]"
                        'action (lambda (_b) (call-interactively #'hell-agent-hooks-show-log))
                        'follow-link t
                        'face 'font-lock-doc-face)
    (insert "\n")
    (when hell-agent--last-hook-status
      (insert "\n "
              (propertize (concat "⚡ " hell-agent--last-hook-status)
                          'face 'font-lock-builtin-face)
              "\n"))
    (goto-char (point-min))
    (set-buffer-modified-p nil)))

;;;###autoload
(defun hell-workspace-sidebar-forge ()
  "Switch the left sidebar to View 3: Agent Hooks & Steering (`C-c w 3')."
  (interactive)
  (hell-agent-setup-display-rules)
  (let* ((root (hell-agent-project-root-or-default))
         (buf (get-buffer-create hell-forge-panel-buffer)))
    (hell-workspace--close-left-side-windows)
    (with-current-buffer buf
      (hell-forge-panel--render root))
    (display-buffer buf (hell-agent-left-window-action))))

(defun hell-agent--find-initial-project-file (root)
  "Find the best initial file to show in the center window for project ROOT."
  (or (seq-find #'file-readable-p
                (mapcar (lambda (rel) (expand-file-name rel root))
                        '("openspec/tasks.md"
                          "openspec/requirements.md"
                          "specs/tasks.md"
                          "specs/requirements.md"
                          "AGENTS.md"
                          "CLAUDE.md"
                          "README.md"
                          "README.org")))
      root))

;;;###autoload
(defun hell-workspace-layout ()
  "Arrange the current frame into the 3-column Hell Emacs workspace layout.
Left: Project Explorer / Specs / Forge sidebar (`C-c w 1..3').
Center: Active code or spec buffer with phase progress header bar.
Right: Agent Shell (or GPTel fallback) side window with status header bar."
  (interactive)
  (hell-agent-setup-display-rules)
  (let* ((root (hell-agent-project-root-or-default))
         (default-directory root)
         (center-win (hell-workspace--center-window)))
    ;; 1. Left column: Explorer (or Specs panel if treemacs isn't installed).
    (save-selected-window
      (hell-workspace-sidebar-explorer))
    ;; 2. Right column: Agent Shell (or GPTel chat buffer).
    (save-selected-window
      (hell-agent-open-side-window root))
    (when (window-live-p center-win)
      (select-window center-win))))

;;;###autoload
(defun hell-workspace-open (&optional project-dir)
  "Open PROJECT-DIR in the 3-column layout (Sidebar | Code/Spec | Agent)."
  (interactive
   (list (if (fboundp 'project-prompt-project-dir)
             (project-prompt-project-dir)
           (read-directory-name "Open Workspace Project: "
                                default-directory nil t))))
  (let* ((root (file-name-as-directory
                (expand-file-name (or project-dir default-directory))))
         (default-directory root)
         (entry (hell-agent--find-initial-project-file root)))
    (when (fboundp 'project-remember-project)
      (when-let* ((proj (project-current nil root)))
        (project-remember-project proj)))
    (delete-other-windows)
    (if (file-directory-p entry)
        (dired entry)
      (find-file entry))
    (hell-workspace-layout)
    (message "[FORGE WORKSPACE] Loaded %s" (abbreviate-file-name root))))

;;; 3. Steering & Right-Column Agent Header Line ------------------------------

;;;###autoload
(defun hell-agent-discover-steering-files (&optional root)
  "Discover steering and specification context files in project ROOT.
Checks `AGENTS.md', `CLAUDE.md', `.hell/steering/*.md', and `openspec/*.md'."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (found nil))
    (dolist (rel hell-agent-steering-files)
      (let ((full (expand-file-name rel proj-root)))
        (when (file-readable-p full)
          (cl-pushnew full found :test #'equal))))
    (dolist (subdir '(".hell/steering" "openspec"))
      (let ((dir (expand-file-name subdir proj-root)))
        (when (file-directory-p dir)
          (dolist (f (directory-files dir t "\\.md\\'"))
            (when (file-readable-p f)
              (cl-pushnew f found :test #'equal))))))
    (nreverse found)))

;;;###autoload
(defun hell-agent-steering-context (&optional root)
  "Build a consolidated steering prompt string for project ROOT.
Returns nil if no steering files exist in the project."
  (let ((proj-root (hell-agent-project-root-or-default root))
        (files (hell-agent-discover-steering-files root))
        (chunks nil)
        (total 0))
    (dolist (file files)
      (when (< total hell-agent-steering-max-chars)
        (let* ((rel (file-relative-name file proj-root))
               (content (with-temp-buffer
                          (insert-file-contents
                           file nil 0
                           (max 512 (- hell-agent-steering-max-chars total)))
                          (string-trim (buffer-string)))))
          (unless (string-empty-p content)
            (setq total (+ total (length content)))
            (push (format "### Steering File: %s\n%s" rel content) chunks)))))
    (when chunks
      (concat
       "You are operating inside Hell Emacs (Spec-Driven Agentic IDE).\n"
       "Follow these project steering rules and specifications strictly:\n\n"
       (string-join (nreverse chunks) "\n\n")))))

(defun hell-agent--provider-label ()
  "Return human-readable label for the active agent provider."
  (pcase hell-agent-preferred-provider
    ('claude-code "Claude Code")
    ('gemini "Gemini CLI")
    ('codex "Codex CLI")
    ('opencode "OpenCode")
    ('gptel "GPTel Elisp")
    (_ (or (and (executable-find "claude") "Claude Code")
           (and (executable-find "gemini") "Gemini CLI")
           (and (executable-find "codex") "Codex CLI")
           (and (executable-find "opencode") "OpenCode")
           "GPTel Elisp"))))

(defun hell-agent--header-line (&optional root)
  "Build the right-hand Agent buffer's `header-line-format' for ROOT."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (provider (hell-agent--provider-label))
         (has-spec (or (file-directory-p (expand-file-name "openspec" proj-root))
                       (file-directory-p (expand-file-name "specs" proj-root))))
         (mode-badge (if has-spec "[Spec Mode]" "[Chat Mode]"))
         (steering (mapcar (lambda (f) (file-name-nondirectory f))
                           (seq-take (hell-agent-discover-steering-files proj-root) 3)))
         (ctx-label (if steering
                        (string-join steering ", ")
                      "no steering files")))
    (concat
     " "
     (propertize (format "⚡ %s" provider) 'face 'font-lock-keyword-face)
     " "
     (propertize mode-badge 'face (if has-spec 'success 'font-lock-builtin-face))
     "  │  Context: "
     (propertize ctx-label 'face 'font-lock-doc-face))))

(defun hell-agent--install-header-line (buf &optional root)
  "Attach the Agent status `header-line-format' to buffer BUF for ROOT."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq-local header-line-format (hell-agent--header-line root)))))

;;;###autoload
(defun hell-agent-inject-steering (&optional root)
  "Detect steering files in ROOT and inject them into `agent-shell' and `gptel'."
  (interactive)
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (files (hell-agent-discover-steering-files proj-root))
         (context (hell-agent-steering-context proj-root)))
    (if (null files)
        (when (called-interactively-p 'any)
          (message "No steering files (AGENTS.md, CLAUDE.md, .hell/steering/, openspec/) in %s"
                   (abbreviate-file-name proj-root)))
      (setq agent-shell-system-prompt context)
      (when (boundp 'gptel--system-message)
        (setq gptel--system-message context))
      (when (and (called-interactively-p 'any)
                 (fboundp 'agent-shell-project-buffers))
        (when-let* ((buf (car (agent-shell-project-buffers proj-root))))
          (hell-agent--install-header-line buf proj-root)
          (when (fboundp 'agent-shell--display-and-insert-context)
            (agent-shell--display-and-insert-context
             buf
             (concat "Load and follow project steering files:\n"
                     (mapconcat (lambda (f)
                                  (concat "@" (file-relative-name f proj-root)))
                                files
                                " "))))))
      (when (called-interactively-p 'any)
        (message "[HELL STEERING] Injected %d steering file(s): %s"
                 (length files)
                 (mapconcat (lambda (f) (file-relative-name f proj-root))
                            files ", ")))
      context)))

;;;###autoload
(defun hell-agent-steering-edit ()
  "Open or create `.hell/steering/project.md' (or `AGENTS.md') in project root."
  (interactive)
  (let* ((root (hell-agent-project-root-or-default))
         (agents (expand-file-name "AGENTS.md" root))
         (hell-steering (expand-file-name ".hell/steering/project.md" root))
         (target (if (file-exists-p agents) agents hell-steering)))
    (unless (file-exists-p target)
      (make-directory (file-name-directory target) t)
      (with-temp-file target
        (insert "# Project Steering Rules\n\n"
                "## Architecture & Conventions\n"
                "- Follow existing module boundaries and naming conventions.\n"
                "- Keep startup fast and avoid eager dependencies.\n\n"
                "## Verification & Quality Gates\n"
                "- Validate all changes with project tests and linters before finishing.\n")))
    (find-file target)))

(defun hell-agent--external-cli-available-p ()
  "Return non-nil if an external ACP agent CLI is installed on PATH."
  (and (not (eq hell-agent-preferred-provider 'gptel))
       (seq-some #'executable-find '("claude" "gemini" "opencode" "codex"))))

;;;###autoload
(defun hell-gptel-chat (&optional arg)
  "Open or switch to a project-anchored `gptel' chat buffer in the right window.
With prefix ARG, prompt for the chat buffer name."
  (interactive "P")
  (hell-agent-setup-display-rules)
  (let* ((root (hell-agent-project-root-or-default))
         (steering (hell-agent-inject-steering root))
         (proj-name (file-name-nondirectory (directory-file-name root)))
         (buf-name (if arg
                       (read-string "GPTel buffer name: "
                                    (format "*gptel: %s*" proj-name))
                     (format "*gptel: %s*" proj-name)))
         (default-directory root))
    (if (not (require 'gptel nil t))
        (user-error "Package `gptel' is not installed yet; run `bin/hell sync'")
      (let ((buf (gptel buf-name nil
                        (when (use-region-p)
                          (buffer-substring-no-properties
                           (region-beginning) (region-end)))
                        nil)))
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (when steering
              (setq-local gptel--system-message steering))
            (hell-agent--install-header-line buf root)))
        (display-buffer buf (hell-agent-right-window-action))))))

(defun hell-agent-open-side-window (&optional root)
  "Open or reuse the project agent buffer in the right side window for ROOT."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (default-directory proj-root))
    (hell-agent-setup-display-rules)
    (hell-agent-inject-steering proj-root)
    (cond
     ((eq hell-agent-preferred-provider 'gptel)
      (hell-gptel-chat))
     ((and (fboundp 'agent-shell-project-buffers)
           (car (agent-shell-project-buffers proj-root)))
      (let ((buf (car (agent-shell-project-buffers proj-root))))
        (hell-agent--install-header-line buf proj-root)
        (display-buffer buf (hell-agent-right-window-action))))
     ((and (hell-agent--external-cli-available-p)
           (fboundp 'agent-shell))
      (setq agent-shell-display-action (hell-agent-right-window-action))
      (call-interactively #'agent-shell)
      (when (fboundp 'agent-shell-project-buffers)
        (when-let* ((buf (car (agent-shell-project-buffers proj-root))))
          (hell-agent--install-header-line buf proj-root))))
     ((require 'gptel nil t)
      (hell-gptel-chat))
     (t
      (message "Run `bin/hell sync' to install agent-shell and gptel")))))

;;;###autoload
(defun hell-agent-toggle ()
  "Toggle the project's `agent-shell' in the right side window with steering."
  (interactive)
  (let* ((root (hell-agent-project-root-or-default))
         (default-directory root))
    (hell-agent-setup-display-rules)
    (hell-agent-inject-steering root)
    (setq agent-shell-display-action (hell-agent-right-window-action))
    (if (and (not (eq hell-agent-preferred-provider 'gptel))
             (fboundp 'agent-shell-toggle)
             (or (hell-agent--external-cli-available-p)
                 (and (fboundp 'agent-shell-project-buffers)
                      (agent-shell-project-buffers root))))
        (progn
          (call-interactively #'agent-shell-toggle)
          (when (fboundp 'agent-shell-project-buffers)
            (when-let* ((buf (car (agent-shell-project-buffers root))))
              (hell-agent--install-header-line buf root))))
      (hell-gptel-chat))))

;;;###autoload
(defun hell-agent-start ()
  "Start a new agent session anchored at the project root with steering."
  (interactive)
  (let* ((root (hell-agent-project-root-or-default))
         (default-directory root))
    (hell-agent-setup-display-rules)
    (hell-agent-inject-steering root)
    (setq agent-shell-display-action (hell-agent-right-window-action))
    (if (and (not (eq hell-agent-preferred-provider 'gptel))
             (fboundp 'agent-shell-new-shell)
             (hell-agent--external-cli-available-p))
        (progn
          (call-interactively #'agent-shell-new-shell)
          (when (fboundp 'agent-shell-project-buffers)
            (when-let* ((buf (car (agent-shell-project-buffers root))))
              (hell-agent--install-header-line buf root))))
      (hell-gptel-chat))))

;;;###autoload
(defun hell-agent-select ()
  "Choose which CLI/provider to use (Claude Code, Gemini, Codex, OpenCode, GPTel)."
  (interactive)
  (let* ((choices '(("Claude Code (claude)" . claude-code)
                    ("Gemini CLI (gemini)" . gemini)
                    ("Codex CLI (codex)" . codex)
                    ("OpenCode CLI (opencode)" . opencode)
                    ("GPTel Native (Elisp)" . gptel)))
         (picked (completing-read "Select Hell Agent Provider: " choices nil t))
         (sym (cdr (assoc picked choices))))
    (setq hell-agent-preferred-provider sym)
    (unless (eq sym 'gptel)
      (setq agent-shell-preferred-agent-config sym))
    (message "[HELL AGENT] Selected provider: %s" picked)
    (hell-agent-toggle)))

;;;###autoload
(defun hell-agent-send-region ()
  "Send the active region or the current buffer to the active project agent."
  (interactive)
  (let* ((root (hell-agent-project-root-or-default))
         (default-directory root)
         (has-region (use-region-p))
         (text (if has-region
                   (buffer-substring-no-properties (region-beginning) (region-end))
                 (buffer-substring-no-properties (point-min) (point-max))))
         (label (or (and buffer-file-name (file-relative-name buffer-file-name root))
                    (buffer-name))))
    (hell-agent-setup-display-rules)
    (cond
     ((and (not (eq hell-agent-preferred-provider 'gptel))
           has-region
           (fboundp 'agent-shell-send-region)
           (or (hell-agent--external-cli-available-p)
               (and (fboundp 'agent-shell-project-buffers)
                    (agent-shell-project-buffers root))))
      (call-interactively #'agent-shell-send-region))
     ((and (not (eq hell-agent-preferred-provider 'gptel))
           (not has-region)
           buffer-file-name
           (fboundp 'agent-shell-send-file)
           (or (hell-agent--external-cli-available-p)
               (and (fboundp 'agent-shell-project-buffers)
                    (agent-shell-project-buffers root))))
      (agent-shell-send-file nil))
     (t
      (let* ((proj-name (file-name-nondirectory (directory-file-name root)))
             (buf-name (format "*gptel: %s*" proj-name))
             (payload (format "Context from `%s`:\n```\n%s\n```\n" label text)))
        (if (require 'gptel nil t)
            (let ((buf (gptel buf-name nil payload nil)))
              (hell-agent--install-header-line buf root)
              (display-buffer buf (hell-agent-right-window-action)))
          (kill-new payload)
          (message "Copied %s to kill-ring (run `bin/hell sync' to install gptel)"
                   label)))))))

;;;###autoload
(defun hell-agent-send-file (&optional prompt-for-file)
  "Send the current visited file (or prompt with PROMPT-FOR-FILE) to the agent."
  (interactive "P")
  (let ((default-directory (hell-agent-project-root-or-default)))
    (if (fboundp 'agent-shell-send-file)
        (agent-shell-send-file prompt-for-file)
      (hell-agent-send-region))))

;;; 4. Spec-Driven Workflow & `hell-spec-mode' (Header Bar & Inline Overlays) -

(defun hell-spec--resolve-dir (&optional root feature)
  "Resolve the specification directory inside project ROOT for FEATURE."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (base-dir (cond
                    ((file-directory-p (expand-file-name "openspec" proj-root))
                     (expand-file-name "openspec" proj-root))
                    ((file-directory-p (expand-file-name "specs" proj-root))
                     (expand-file-name "specs" proj-root))
                    (t
                     (expand-file-name hell-spec-directory proj-root)))))
    (if (and feature (not (string-empty-p (string-trim feature))))
        (expand-file-name (string-trim feature) base-dir)
      base-dir)))

(defun hell-spec--requirements-template (title)
  "Return the structured EARS `requirements.md' template for TITLE."
  (format "# Requirements Specification: %s

## 1. Overview
Describe the problem statement, context, and business or engineering value of **%s**.

## 2. User Stories & Acceptance Criteria (EARS Notation)

### Requirement 1: Core Functionality
**User Story:** As a developer/user, I want %s, so that I can achieve reliable and fast results.

#### Acceptance Criteria
1. WHEN the feature is invoked with valid inputs, THE SYSTEM SHALL execute the workflow and produce deterministic output.
2. IF an invalid input or missing dependency is detected, THEN THE SYSTEM SHALL report a clear diagnostic without corrupting state.
3. WHILE the operation runs, THE SYSTEM SHALL preserve editor responsiveness and layout integrity.

## 3. Non-Functional Requirements
- **Performance:** Zero impact on Emacs startup time (< 0.35s).
- **Security:** Never hardcode credentials; respect project boundaries.
- **Compatibility:** Must byte-compile cleanly without warnings on Emacs 29.1+.
" title title title))

(defun hell-spec--design-template (title)
  "Return the structured `design.md' template for TITLE."
  (format "# Technical Design: %s

## 1. Architecture Overview
High-level architecture and how **%s** integrates with existing modules.

```
+-------------------+       +-------------------+       +-------------------+
|   Spec / Tasks    | ----> |   Core Workflow   | ----> |  Agent / Runtime  |
+-------------------+       +-------------------+       +-------------------+
```

## 2. Components & Interfaces
- **Primary Module:** Responsibilities, entry points, and public API.
- **State & Storage:** Where transient and persistent data live (`hell-state-dir`, `hell-cache-dir`).

## 3. Data Models & Configuration
- Custom variables (`defcustom`), data structures, and file formats.

## 4. Error Handling & Edge Cases
- Graceful degradation when external CLIs or network services are unavailable.

## 5. Verification Plan
- Automated ERT unit tests (`make test`).
- Byte-compilation gate (`make compile`).
" title title))

(defun hell-spec--tasks-template (title)
  "Return the structured `tasks.md' template for TITLE."
  (format "# Implementation Plan: %s

Use `C-c s e` (`M-x hell-spec-execute-task`) or click `[▶ Run Task]` on any task below to send it (along with `requirements.md` and `design.md`) to the Agent.

## Phase 1: Foundation & Scaffolding
- [ ] 1.1 Define core data structures, configuration variables, and module entry points for %s _(Req 1.1)_
- [ ] 1.2 Implement error handling and boundary validation _(Req 1.2)_

## Phase 2: Core Implementation & Integration
- [ ] 2.1 Implement the primary workflow and interactive commands _(Req 1.1, 1.3)_
- [ ] 2.2 Integrate keybindings, window layout rules, and autoloads _(Req 1.3)_

## Phase 3: Verification & Quality Gate
- [ ] 3.1 Add unit tests and validate byte-compilation without warnings _(NFR)_
" title title))

(defun hell-spec--current-phase ()
  "Return `requirements', `design', `tasks', or `spec' for current buffer."
  (let ((name (and buffer-file-name (file-name-nondirectory buffer-file-name))))
    (cond
     ((equal name "requirements.md") 'requirements)
     ((equal name "design.md") 'design)
     ((equal name "tasks.md") 'tasks)
     (t 'spec))))

(defun hell-spec--header-line ()
  "Build the contextual phase progress `header-line-format' for `hell-spec-mode'."
  (let* ((phase (hell-spec--current-phase))
         (dir (if buffer-file-name
                  (file-name-directory buffer-file-name)
                (hell-spec--resolve-dir)))
         (counts (hell-spec--task-counts (expand-file-name "tasks.md" dir)))
         (badge (lambda (p label file)
                  (let ((active (eq phase p))
                        (map (make-sparse-keymap)))
                    (keymap-set map "<header-line> <mouse-1>"
                                (lambda ()
                                  (interactive)
                                  (find-file (expand-file-name file dir))))
                    (propertize label
                                'face (if active
                                          '(:inherit success :weight bold)
                                        'font-lock-comment-face)
                                'mouse-face 'highlight
                                'help-echo (format "Open %s" file)
                                'keymap map))))
         (action-label (pcase phase
                         ('requirements "[C-c s a: Generate Design ──▶]")
                         ('design "[C-c s a: Generate Tasks ──▶]")
                         ('tasks (format "[C-c s e: ▶ Run Task | C-c s t: Toggle (%d/%d)]"
                                         (car counts) (cdr counts)))
                         (_ "[C-c s a: Advance Phase | C-c s e: Execute Task]"))))
    (concat
     " "
     (funcall badge 'requirements "[1. Requirements]" "requirements.md")
     (propertize " ──▶ " 'face 'shadow)
     (funcall badge 'design "[2. Design]" "design.md")
     (propertize " ──▶ " 'face 'shadow)
     (funcall badge 'tasks "[3. Tasks]" "tasks.md")
     (propertize "   │   " 'face 'shadow)
     (propertize action-label 'face 'font-lock-keyword-face))))

;;; Inline Clickable Task Overlays in `tasks.md' ------------------------------

(defun hell-spec--clear-task-overlays ()
  "Remove all `hell-spec-task' overlays from the current buffer."
  (remove-overlays (point-min) (point-max) 'hell-spec-task t))

(defun hell-spec--make-task-overlay (bol eol task-text done-p)
  "Create an inline action overlay on line BOL..EOL for TASK-TEXT (DONE-P)."
  (let* ((key (cons (or buffer-file-name (buffer-name)) task-text))
         (running-p (and (not done-p) (gethash key hell-spec--running-tasks)))
         (ov (make-overlay bol eol nil t nil))
         (map (make-sparse-keymap))
         (run-at-line (lambda ()
                        (interactive)
                        (goto-char bol)
                        (hell-spec-execute-task)))
         (toggle-at-line (lambda ()
                           (interactive)
                           (goto-char bol)
                           (hell-spec-toggle-task)))
         (badge (cond
                 (done-p
                  (propertize " [✓ Done] "
                              'face '(:inherit success :weight bold)
                              'mouse-face 'highlight
                              'help-echo "Click or C-c s t to reopen task"
                              'keymap (progn
                                        (keymap-set map "<mouse-1>" toggle-at-line)
                                        (keymap-set map "RET" toggle-at-line)
                                        map)))
                 (running-p
                  (propertize " [⏳ Running...] "
                              'face '(:inherit warning :weight bold)
                              'mouse-face 'highlight
                              'help-echo "Dispatched to Agent (click or C-c s t when complete)"
                              'keymap (progn
                                        (keymap-set map "<mouse-1>" toggle-at-line)
                                        (keymap-set map "RET" toggle-at-line)
                                        map)))
                 (t
                  (propertize " [▶ Run Task] "
                              'face '(:inherit font-lock-constant-face :weight bold)
                              'mouse-face 'highlight
                              'help-echo "Click or press C-c s e to send task + spec to Agent"
                              'keymap (progn
                                        (keymap-set map "<mouse-1>" run-at-line)
                                        (keymap-set map "RET" run-at-line)
                                        map))))))
    (overlay-put ov 'hell-spec-task t)
    (overlay-put ov 'evaporate t)
    (overlay-put ov 'after-string badge)
    ov))

(defun hell-spec-refresh-overlays ()
  "Refresh inline `[▶ Run Task]' / `[⏳ Running...]' overlays in current buffer."
  (interactive)
  (when (bound-and-true-p hell-spec-mode)
    (hell-spec--clear-task-overlays)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^[ \t]*[-*+][ \t]+\\[\\([ xX-]\\)\\][ \t]+\\(.+\\)$"
              nil t)
        (let ((state (match-string 1))
              (task (string-trim (match-string 2)))
              (bol (line-beginning-position))
              (eol (line-end-position)))
          (hell-spec--make-task-overlay
           bol eol task (member state '("x" "X"))))))))

;;;###autoload
(defun hell-spec-toggle-task ()
  "Toggle the Markdown checkbox (`- [ ]' <-> `- [x]') on the current line."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (re-search-forward
         "^\\([ \t]*[-*+][ \t]+\\[\\)\\([ xX-]\\)\\(\\][ \t]+\\)\\(.+\\)$"
         (line-end-position) t)
        (let* ((was-done (member (match-string 2) '("x" "X")))
               (new-mark (if was-done " " "x"))
               (task (string-trim (match-string 4)))
               (key (cons (or buffer-file-name (buffer-name)) task)))
          (replace-match new-mark t t nil 2)
          (remhash key hell-spec--running-tasks)
          (when (bound-and-true-p hell-spec-mode)
            (hell-spec-refresh-overlays)
            (setq-local header-line-format (hell-spec--header-line)))
          (when-let* ((sbuf (get-buffer hell-specs-panel-buffer)))
            (with-current-buffer sbuf
              (hell-specs-panel--render (hell-agent-project-root-or-default))))
          (message "[HELL SPEC] Marked task %s: %s"
                   (if was-done "pending [ ]" "completed [x]")
                   task))
      (user-error "No Markdown checkbox task (`- [ ] ...') on current line"))))

(defvar-keymap hell-spec-mode-map
  :doc "Keymap for `hell-spec-mode'."
  "C-c s a" #'hell-spec-advance-phase
  "C-c s e" #'hell-spec-execute-task
  "C-c s t" #'hell-spec-toggle-task)

;;;###autoload
(define-minor-mode hell-spec-mode
  "Minor mode for interactive Spec-Driven Development in `openspec/' and `specs/'.
Displays the 3-phase progress header bar (`Requirements -> Design -> Tasks')
and attaches clickable `[▶ Run Task]' inline overlays to task lines."
  :lighter " HellSpec"
  :keymap hell-spec-mode-map
  :group 'hell-agent
  (if hell-spec-mode
      (progn
        (setq-local header-line-format (hell-spec--header-line))
        (hell-spec-refresh-overlays)
        (add-hook 'after-save-hook #'hell-spec-refresh-overlays nil t))
    (kill-local-variable 'header-line-format)
    (hell-spec--clear-task-overlays)
    (remove-hook 'after-save-hook #'hell-spec-refresh-overlays t)))

;;;###autoload
(defun hell-spec-maybe-enable-h ()
  "Enable `hell-spec-mode' automatically for `.md'/`.org' files in spec dirs."
  (when (and buffer-file-name
             (string-match-p
              "\\(?:/openspec/\\|/specs/\\).*\\.\\(?:md\\|org\\)\\'"
              buffer-file-name))
    (hell-spec-mode 1)))

(add-hook 'find-file-hook #'hell-spec-maybe-enable-h)

;;;###autoload
(defun hell-spec-create (&optional feature-name project-dir)
  "Create or open the specification structure (`openspec/' or `specs/').
Generates `requirements.md', `design.md', and `tasks.md' from structured
templates if they do not exist yet, and opens them in the workspace.
With prefix argument, also prompts for PROJECT-DIR."
  (interactive
   (let* ((pdir (if current-prefix-arg
                    (read-directory-name "Project root for Spec: "
                                         (hell-agent-project-root-or-default))
                  (hell-agent-project-root-or-default)))
          (feat (read-string
                 "Spec feature name (leave empty for root openspec/): ")))
     (list (unless (string-empty-p (string-trim feat)) (string-trim feat))
           pdir)))
  (let* ((root (file-name-as-directory
                (expand-file-name
                 (or project-dir (hell-agent-project-root-or-default)))))
         (spec-dir (hell-spec--resolve-dir root feature-name))
         (title (or feature-name
                    (file-name-nondirectory (directory-file-name root))))
         (req-file (expand-file-name "requirements.md" spec-dir))
         (des-file (expand-file-name "design.md" spec-dir))
         (tsk-file (expand-file-name "tasks.md" spec-dir))
         (created nil))
    (make-directory spec-dir t)
    (dolist (pair (list (cons req-file (hell-spec--requirements-template title))
                        (cons des-file (hell-spec--design-template title))
                        (cons tsk-file (hell-spec--tasks-template title))))
      (unless (file-exists-p (car pair))
        (with-temp-file (car pair)
          (insert (cdr pair)))
        (push (file-name-nondirectory (car pair)) created)))
    (with-current-buffer (find-file-noselect tsk-file)
      (hell-spec-mode 1))
    (with-current-buffer (find-file-noselect des-file)
      (hell-spec-mode 1))
    (find-file req-file)
    (hell-spec-mode 1)
    (when-let* ((sbuf (get-buffer hell-specs-panel-buffer)))
      (with-current-buffer sbuf
        (hell-specs-panel--render root)))
    (message "[HELL SPEC] %s in %s"
             (if created
                 (format "Created %s" (string-join (nreverse created) ", "))
               "Opened existing spec suite")
             (abbreviate-file-name spec-dir))))

;;;###autoload
(defun hell-spec-open ()
  "Prompt for a specification file and open it."
  (interactive)
  (let* ((root (hell-agent-project-root-or-default))
         (specs (hell-agent-recent-specs 30)))
    (if (null specs)
        (if (y-or-n-p "No specs found in project. Create spec suite now? ")
            (call-interactively #'hell-spec-create)
          (message "No specification files found"))
      (let* ((rel-alist (mapcar (lambda (f)
                                  (cons (if (file-in-directory-p f root)
                                            (file-relative-name f root)
                                          (abbreviate-file-name f))
                                        f))
                                specs))
             (choice (completing-read "Open Spec: " rel-alist nil t)))
        (when-let* ((target (cdr (assoc choice rel-alist))))
          (find-file target)
          (hell-spec-mode 1))))))

(defun hell-spec--read-file-if-exists (file)
  "Return the trimmed text of FILE if readable, or nil."
  (when (and file (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (string-trim (buffer-string)))))

(defun hell-spec--dispatch-prompt-to-agent (root prompt &optional use-gptel)
  "Send PROMPT to the project agent for ROOT (or `gptel' when USE-GPTEL)."
  (hell-agent-setup-display-rules)
  (let ((steering (hell-agent-inject-steering root)))
    (if (and (not use-gptel)
             (or (hell-agent--external-cli-available-p)
                 (and (fboundp 'agent-shell-project-buffers)
                      (agent-shell-project-buffers root))))
        (let ((default-directory root))
          (require 'agent-shell)
          (setq agent-shell-display-action (hell-agent-right-window-action))
          (let ((shell-buf (or (car (agent-shell-project-buffers root))
                               (save-window-excursion
                                 (call-interactively #'agent-shell)
                                 (car (agent-shell-project-buffers root))))))
            (if (and shell-buf (fboundp 'agent-shell--display-and-insert-context))
                (progn
                  (hell-agent--install-header-line shell-buf root)
                  (display-buffer shell-buf (hell-agent-right-window-action))
                  (agent-shell--display-and-insert-context shell-buf prompt))
              (kill-new prompt)
              (call-interactively #'agent-shell))))
      (if (require 'gptel nil t)
          (let* ((default-directory root)
                 (buf-name (format "*gptel-spec: %s*"
                                   (file-name-nondirectory
                                    (directory-file-name root))))
                 (buf (gptel buf-name nil prompt nil)))
            (when (buffer-live-p buf)
              (with-current-buffer buf
                (when steering
                  (setq-local gptel--system-message steering))
                (hell-agent--install-header-line buf root)))
            (display-buffer buf (hell-agent-right-window-action)))
        (kill-new prompt)
        (message "[HELL SPEC] Copied prompt to kill-ring (run `bin/hell sync' to install agent packages)")))))

;;;###autoload
(defun hell-spec-advance-phase (&optional use-gptel)
  "Advance the current specification to the next phase (`C-c s a'):
- From `requirements.md': sends requirements + `AGENTS.md' to the Agent to
  generate/update `design.md', then opens `design.md'.
- From `design.md': sends requirements + design to the Agent to generate the
  implementation checklist in `tasks.md', then opens `tasks.md'.
- From `tasks.md': executes the current or next pending task (`- [ ] ...').
With prefix argument USE-GPTEL, forces native `gptel' fallback."
  (interactive "P")
  (let* ((cur-dir (if buffer-file-name
                      (file-name-directory buffer-file-name)
                    (hell-spec--resolve-dir)))
         (root (hell-agent-project-root-or-default cur-dir))
         (spec-dir (if (or (file-exists-p (expand-file-name "requirements.md" cur-dir))
                           (file-exists-p (expand-file-name "design.md" cur-dir))
                           (file-exists-p (expand-file-name "tasks.md" cur-dir)))
                       cur-dir
                     (hell-spec--resolve-dir root)))
         (title (file-name-nondirectory (directory-file-name spec-dir)))
         (req-file (expand-file-name "requirements.md" spec-dir))
         (des-file (expand-file-name "design.md" spec-dir))
         (tsk-file (expand-file-name "tasks.md" spec-dir))
         (phase (hell-spec--current-phase)))
    (pcase phase
      ('requirements
       (unless (file-exists-p des-file)
         (with-temp-file des-file
           (insert (hell-spec--design-template title))))
       (let* ((req-text (or (hell-spec--read-file-if-exists req-file)
                            (buffer-substring-no-properties (point-min) (point-max))))
              (prompt (format
                       "Based on the following `requirements.md` and project steering rules, generate or refine the technical architecture in `%s` (`design.md`):\n\n## Requirements (`%s`)\n%s\n"
                       (file-relative-name des-file root)
                       (file-relative-name req-file root)
                       req-text)))
         (find-file des-file)
         (hell-spec-mode 1)
         (hell-spec--dispatch-prompt-to-agent root prompt use-gptel)
         (message "[HELL SPEC] Phase 1 ──▶ Phase 2 (`design.md') dispatched to Agent")))
      ('design
       (unless (file-exists-p tsk-file)
         (with-temp-file tsk-file
           (insert (hell-spec--tasks-template title))))
       (let* ((req-text (or (hell-spec--read-file-if-exists req-file) ""))
              (des-text (or (hell-spec--read-file-if-exists des-file)
                            (buffer-substring-no-properties (point-min) (point-max))))
              (prompt (format
                       "Based on `requirements.md` and `design.md`, generate an actionable, step-by-step implementation checklist in `%s` (`tasks.md`) using `- [ ] 1.1 ...` format:\n\n## Requirements\n%s\n\n## Technical Design\n%s\n"
                       (file-relative-name tsk-file root)
                       req-text
                       des-text)))
         (find-file tsk-file)
         (hell-spec-mode 1)
         (hell-spec--dispatch-prompt-to-agent root prompt use-gptel)
         (message "[HELL SPEC] Phase 2 ──▶ Phase 3 (`tasks.md') dispatched to Agent")))
      ('tasks
       (unless (save-excursion
                 (beginning-of-line)
                 (looking-at-p "^[ \t]*[-*+][ \t]+\\[ \\]"))
         (goto-char (point-min))
         (re-search-forward "^[ \t]*[-*+][ \t]+\\[ \\]" nil t)
         (beginning-of-line))
       (hell-spec-execute-task use-gptel))
      (_
       (if (file-exists-p req-file)
           (progn
             (find-file req-file)
             (hell-spec-mode 1))
         (call-interactively #'hell-spec-create))))))

(defun hell-spec--extract-task-at-point ()
  "Extract the task item under point (Markdown checkbox, Org TODO, or region)."
  (cond
   ((use-region-p)
    (string-trim (buffer-substring-no-properties (region-beginning) (region-end))))
   (t
    (save-excursion
      (beginning-of-line)
      (let ((line (string-trim (thing-at-point 'line t))))
        (cond
         ;; Markdown checkbox task: `- [ ] ...' or `* [ ] ...'
         ((string-match "\\`[-*+][ \t]+\\[[ xX-]\\][ \t]+\\(.+\\)\\'" line)
          (match-string 1 line))
         ;; Org-mode TODO heading: `* TODO ...'
         ((string-match "\\`\\*+[ \t]+\\(?:TODO\\|NEXT\\|DOING\\|IN-PROGRESS\\)[ \t]+\\(.+\\)\\'" line)
          (match-string 1 line))
         ;; Numbered task line: `1. ...'
         ((string-match "\\`[0-9]+\\(?:\\.[0-9]+\\)*\\.?[ \t]+\\(.+\\)\\'" line)
          (match-string 1 line))
         ((not (string-empty-p line))
          line)
         (t
          (user-error "No task found at point (expected `- [ ] ...', Org `TODO', or active region)"))))))))

;;;###autoload
(defun hell-spec-execute-task (&optional use-gptel)
  "Send task at point with `design.md' and `requirements.md' to the Agent.
Updates the inline task overlay on the current line to `[⏳ Running...]'."
  (interactive "P")
  (let* ((task (hell-spec--extract-task-at-point))
         (cur-dir (if buffer-file-name
                      (file-name-directory buffer-file-name)
                    (hell-spec--resolve-dir)))
         (root (hell-agent-project-root-or-default cur-dir))
         (spec-dir (if (or (file-exists-p (expand-file-name "requirements.md" cur-dir))
                           (file-exists-p (expand-file-name "design.md" cur-dir)))
                       cur-dir
                     (hell-spec--resolve-dir root)))
         (req-file (expand-file-name "requirements.md" spec-dir))
         (des-file (expand-file-name "design.md" spec-dir))
         (tsk-file (or buffer-file-name (expand-file-name "tasks.md" spec-dir)))
         (req-text (hell-spec--read-file-if-exists req-file))
         (des-text (hell-spec--read-file-if-exists des-file))
         (key (cons (or buffer-file-name (buffer-name)) task))
         (prompt
          (concat
           "Implement the following specification task in this project:\n\n"
           "## Task to Implement\n"
           (format "- **Task:** %s\n" task)
           (if tsk-file
               (format "- **Source:** `%s`\n\n" (file-relative-name tsk-file root))
             "\n")
           (if req-text
               (format "## Requirements (`%s`)\n%s\n\n"
                       (file-relative-name req-file root) req-text)
             "")
           (if des-text
               (format "## Technical Design (`%s`)\n%s\n\n"
                       (file-relative-name des-file root) des-text)
             "")
           "## Instructions\n"
           "1. Implement the task adhering strictly to the Requirements and Technical Design above.\n"
           "2. Verify your changes compile/pass tests.\n"
           "3. Mark the task as `- [x]` in `tasks.md` once verified.\n")))
    (puthash key t hell-spec--running-tasks)
    (when (bound-and-true-p hell-spec-mode)
      (hell-spec-refresh-overlays))
    (hell-spec--dispatch-prompt-to-agent root prompt use-gptel)
    (message "[HELL SPEC] Dispatched task [⏳ Running...]: %s" task)))

;;;###autoload
(defun hell-spec-generate-with-ai (feature-prompt)
  "Generate spec drafts (`requirements.md', `design.md', `tasks.md') via `gptel'.
FEATURE-PROMPT describes the feature to specify."
  (interactive "sDescribe feature to generate Spec for: ")
  (when (string-empty-p (string-trim feature-prompt))
    (user-error "Feature description cannot be empty"))
  (require 'gptel)
  (let* ((root (hell-agent-project-root-or-default))
         (out-buf (get-buffer-create "*hell-spec-draft*"))
         (steering (hell-agent-steering-context root))
         (query (concat
                 (if steering (concat steering "\n\n") "")
                 "Generate a complete Spec-Driven Development specification for:\n"
                 feature-prompt "\n\n"
                 "Structure your response into three Markdown sections:\n"
                 "1. `requirements.md` (with User Stories and EARS WHEN/THE SYSTEM SHALL criteria)\n"
                 "2. `design.md` (Architecture, Components, Data Models, Verification Plan)\n"
                 "3. `tasks.md` (Actionable implementation checklist using `- [ ] 1.1 ...`)\n")))
    (with-current-buffer out-buf
      (setq default-directory root)
      (erase-buffer)
      (if (fboundp 'markdown-mode) (markdown-mode) (org-mode))
      (insert "# Generating Specification Draft...\n\nFeature: " feature-prompt "\n\n"))
    (hell-agent-setup-display-rules)
    (display-buffer out-buf (hell-agent-right-window-action))
    (gptel-request
     query
     :buffer out-buf
     :callback
     (lambda (response info)
       (when (buffer-live-p out-buf)
         (with-current-buffer out-buf
           (goto-char (point-max))
           (if (stringp response)
               (insert response "\n")
             (insert (format "Error generating spec: %s\n"
                             (or (plist-get info :status) "Request failed"))))))))))

;;; 5. Visual Agent Hooks (`hell-hooks' / `.hell-hooks.el') -------------------

(defcustom hell-agent-hooks
  '((:name "src-background-check"
     :event after-save
     :glob "src/**/*.{el,java,kt,clj,scala}"
     :match "\\`\\(?:src\\|lisp\\|modules\\|sources\\)/.*\\.\\(?:el\\|java\\|kt\\|clj\\|scala\\|py\\|ts\\|js\\|go\\|rs\\)\\'"
     :action (:log "Saved source file %s")
     :enabled t)
    (:name "spec-updated-notify"
     :event after-save
     :glob "openspec/**/*.md"
     :match "\\`\\(?:openspec\\|specs\\)/.*\\.md\\'"
     :action (:log "Specification updated: %s")
     :enabled t))
  "List of Agent Hook rules evaluated when `hell-agent-hooks-mode' is active.
Rules can be plists or 3-element tuples `(EVENT GLOB-PATTERN CMD-OR-PROMPT)'
loaded from `.hell-hooks.el' or `.dir-locals.el'."
  :type '(repeat sexp)
  :group 'hell-agent)

(put 'hell-agent-hooks 'safe-local-variable #'listp)

(defconst hell-agent-hooks-buffer "*hell-agent-hooks*"
  "Buffer recording asynchronous Agent Hook executions.")

(defun hell-hooks--glob-to-regexp (pattern)
  "Convert glob PATTERN (e.g. `src/**/*.kt') into an Emacs regular expression."
  (if (or (string-prefix-p "\\`" pattern)
          (string-prefix-p "^" pattern)
          (string-suffix-p "\\'" pattern))
      pattern
    (let ((i 0)
          (len (length pattern))
          (out "\\`"))
      (while (< i len)
        (let ((c (aref pattern i)))
          (cond
           ((and (eq c ?*)
                 (< (1+ i) len)
                 (eq (aref pattern (1+ i)) ?*))
            (setq i (+ i 2))
            (when (and (< i len) (eq (aref pattern i) ?/))
              (setq i (1+ i)))
            (setq out (concat out "\\(?:.+?/.*\\|.*\\)")))
           ((eq c ?*)
            (setq out (concat out "[^/]*")
                  i (1+ i)))
           ((eq c ??)
            (setq out (concat out "[^/]")
                  i (1+ i)))
           ((eq c ?{)
            (let ((close (string-search "}" pattern i)))
              (if close
                  (let ((alts (split-string (substring pattern (1+ i) close) ",")))
                    (setq out (concat out "\\(?:"
                                      (mapconcat #'regexp-quote alts "\\|")
                                      "\\)")
                          i (1+ close)))
                (setq out (concat out "\\{")
                      i (1+ i)))))
           (t
            (setq out (concat out (regexp-quote (char-to-string c)))
                  i (1+ i))))))
      (concat out "\\'"))))

(defun hell-hooks--normalize-rule (entry &optional idx)
  "Normalize ENTRY (either a plist or `(EVENT GLOB ACTION)' tuple) into a plist."
  (if (keywordp (car-safe entry))
      (let ((copy (copy-sequence entry)))
        (when (and (plist-get copy :glob) (not (plist-get copy :match)))
          (setq copy (plist-put copy :match
                                (hell-hooks--glob-to-regexp (plist-get copy :glob)))))
        (unless (plist-member copy :enabled)
          (setq copy (plist-put copy :enabled t)))
        copy)
    (pcase entry
      (`(,event ,glob ,action)
       (list :name (format "hook-%d:%s" (or idx 1) glob)
             :event event
             :glob glob
             :match (hell-hooks--glob-to-regexp glob)
             :action (cond
                      ((stringp action) `(:shell ,action))
                      (t action))
             :enabled t))
      (_ entry))))

(defun hell-hooks--ensure-project-rules (&optional root)
  "Load `.hell-hooks.el' from project ROOT and normalize `hell-agent-hooks'."
  (let* ((proj-root (hell-agent-project-root-or-default root))
         (hooks-file (expand-file-name ".hell-hooks.el" proj-root)))
    (when (file-readable-p hooks-file)
      (with-temp-buffer
        (insert-file-contents hooks-file)
        (goto-char (point-min))
        (let ((raw (ignore-errors (read (current-buffer))))
              (idx 0))
          (when (listp raw)
            (dolist (item raw)
              (cl-incf idx)
              (let ((norm (hell-hooks--normalize-rule item idx)))
                (unless (seq-find (lambda (r)
                                    (equal (plist-get r :name) (plist-get norm :name)))
                                  hell-agent-hooks)
                  (push norm hell-agent-hooks))))))))
    (setq hell-agent-hooks
          (seq-map-indexed (lambda (r i) (hell-hooks--normalize-rule r (1+ i)))
                           hell-agent-hooks))))

(defun hell-agent-hooks--log (format-string &rest args)
  "Append a timestamped log line to `hell-agent-hooks-buffer' and notify."
  (let ((msg (apply #'format format-string args)))
    (setq hell-agent--last-hook-status msg)
    (with-current-buffer (get-buffer-create hell-agent-hooks-buffer)
      (goto-char (point-max))
      (insert (format-time-string "[%H:%M:%S] ") msg "\n"))))

(defun hell-agent-hooks--execute-rule (rule file root)
  "Execute RULE's `:action' for saved FILE in project ROOT."
  (let* ((name (or (plist-get rule :name) "unnamed-hook"))
         (rel (file-relative-name file root))
         (action (plist-get rule :action)))
    (pcase action
      (`(:shell ,cmd-template)
       (let* ((default-directory root)
              (cmd (if (string-search "%s" cmd-template)
                       (format cmd-template (shell-quote-argument rel))
                     cmd-template))
              (buf (get-buffer-create hell-agent-hooks-buffer)))
         (hell-agent-hooks--log "[%s] Running: %s" name cmd)
         (message "[Hell Hook ⚡ %s] Running `%s'..." name cmd)
         (make-process
          :name (format "hell-agent-hook-%s" name)
          :buffer buf
          :command (list (or (executable-find "bash") "/bin/sh") "-c" cmd)
          :noquery t
          :sentinel
          (lambda (proc _event)
            (when (memq (process-status proc) '(exit signal))
              (hell-agent-hooks--log "[%s] Finished (exit %d)"
                                     name (process-exit-status proc)))))))
      (`(:agent ,prompt-template)
       (let ((msg (if (string-search "%s" prompt-template)
                      (format prompt-template rel)
                    (format "%s (%s)" prompt-template rel))))
         (hell-agent-hooks--log "[%s] Agent notified: %s" name msg)
         (message "[Hell Hook ⚡ %s] Notified agent for %s" name rel)
         (when (fboundp 'agent-shell-project-buffers)
           (when-let* ((shell-buf (car (agent-shell-project-buffers root))))
             (when (fboundp 'agent-shell--display-and-insert-context)
               (agent-shell--display-and-insert-context shell-buf msg))))))
      (`(:log ,msg-template)
       (let ((msg (if (string-search "%s" msg-template)
                      (format msg-template rel)
                    msg-template)))
         (hell-agent-hooks--log "[%s] %s" name msg)
         (message "[Hell Hook ⚡ %s] %s" name msg)))
      ((pred functionp)
       (hell-agent-hooks--log "[%s] Function hook on %s" name rel)
       (funcall action file)))))

(defun hell-agent-hooks--after-save-h ()
  "Run matching `hell-agent-hooks' rules after saving the current buffer."
  (when (and (bound-and-true-p hell-agent-hooks-mode)
             buffer-file-name)
    (let* ((root (hell-agent-project-root-or-default))
           (rel (file-relative-name buffer-file-name root)))
      (hell-hooks--ensure-project-rules root)
      (dolist (rule hell-agent-hooks)
        (let ((enabled (if (plist-member rule :enabled)
                           (plist-get rule :enabled)
                         t))
              (event (or (plist-get rule :event) 'after-save))
              (pattern (plist-get rule :match)))
          (when (and enabled
                     (eq event 'after-save)
                     (stringp pattern)
                     (string-match-p pattern rel))
            (condition-case err
                (hell-agent-hooks--execute-rule rule buffer-file-name root)
              (error
               (hell-agent-hooks--log "[ERROR] Hook %S failed: %s"
                                      (plist-get rule :name)
                                      (error-message-string err))))))))))

;;;###autoload
(define-minor-mode hell-agent-hooks-mode
  "Opt-in event-driven Agent Hooks mode for Hell Emacs.
Disabled by default. Can be enabled per buffer or per project via
`.hell-hooks.el', `.dir-locals.el', or `M-x hell-agent-hooks-mode'."
  :lighter " HellHooks"
  :group 'hell-agent
  (if hell-agent-hooks-mode
      (add-hook 'after-save-hook #'hell-agent-hooks--after-save-h nil t)
    (remove-hook 'after-save-hook #'hell-agent-hooks--after-save-h t)))

;;;###autoload
(defun hell-agent-hooks-add-rule (name glob-pattern action-type payload)
  "Interactively register an Agent Hook rule in `hell-agent-hooks'.
NAME is the rule's identifier, GLOB-PATTERN matches project-relative paths
\(e.g. `src/**/*.kt'), ACTION-TYPE is `shell', `agent', or `log', and PAYLOAD
is the command or prompt template (`%s' is replaced by relative file path)."
  (interactive
   (let* ((nm (read-string "Hook rule name (e.g. test-on-save): "))
          (gl (read-string "Glob or regexp (e.g. src/**/*.kt): " "src/**/*"))
          (act (intern (completing-read "Hook action type: " '("shell" "agent" "log") nil t)))
          (pl (read-string
               (pcase act
                 ('shell "Shell command (%s = file): ")
                 ('agent "Agent prompt (%s = file): ")
                 (_ "Log message (%s = file): ")))))
     (list nm gl act pl)))
  (let ((rule (list :name name
                    :event 'after-save
                    :glob glob-pattern
                    :match (hell-hooks--glob-to-regexp glob-pattern)
                    :action (list (intern (concat ":" (symbol-name action-type)))
                                  payload)
                    :enabled t)))
    (setq hell-agent-hooks
          (cons rule (seq-remove (lambda (r) (equal (plist-get r :name) name))
                                 hell-agent-hooks)))
    (hell-agent-hooks-mode 1)
    (when-let* ((fbuf (get-buffer hell-forge-panel-buffer)))
      (with-current-buffer fbuf
        (hell-forge-panel--render (hell-agent-project-root-or-default))))
    (message "[HELL HOOKS] Registered rule %S (%s) and enabled `hell-agent-hooks-mode'"
             name glob-pattern)))

;;;###autoload
(defun hell-agent-hooks-show-log ()
  "Display the `*hell-agent-hooks*' log buffer in the right side window."
  (interactive)
  (hell-agent-setup-display-rules)
  (let ((buf (get-buffer-create hell-agent-hooks-buffer)))
    (display-buffer buf (hell-agent-right-window-action))))

;;; 6. Global Keybindings Registration (`C-c a', `C-c s', `C-c w') ------------

;;;###autoload
(defun hell-agent-register-global-keys ()
  "Register `C-c a' (Agent), `C-c s' (Specs), and `C-c w' (Workspace) globally."
  (unless (fboundp 'hell-leader-def)
    (load (expand-file-name "modules/hell/autoload/keybinds.el" hell-dir) nil t))
  (hell-leader-def
    ;; Hell Agent prefix (`C-c a')
    "a"   "Hell Agent"
    "a a" '("toggle project agent" . hell-agent-toggle)
    "a A" '("new project agent" . hell-agent-start)
    "a s" '("select agent provider" . hell-agent-select)
    "a r" '("send region/buffer to agent" . hell-agent-send-region)
    "a f" '("send file to agent" . hell-agent-send-file)
    "a c" '("gptel native chat" . hell-gptel-chat)
    "a e" '("execute spec task in agent" . hell-spec-execute-task)
    "a i" '("inject steering context" . hell-agent-inject-steering)

    ;; Hell Specs prefix (`C-c s')
    "s w" '("open project workspace" . hell-workspace-open)
    "s l" '("3-column workspace layout" . hell-workspace-layout)
    "s n" '("create project spec suite" . hell-spec-create)
    "s a" '("advance spec phase" . hell-spec-advance-phase)
    "s o" '("open spec file" . hell-spec-open)
    "s e" '("execute spec task at point" . hell-spec-execute-task)
    "s t" '("toggle spec task checkbox" . hell-spec-toggle-task)
    "s g" '("generate spec with ai" . hell-spec-generate-with-ai)
    "s i" '("inject project steering" . hell-agent-inject-steering)
    "s S" '("edit steering rules" . hell-agent-steering-edit)
    "s h" '("toggle agent hooks mode" . hell-agent-hooks-mode)
    "s H" '("add agent hook rule" . hell-agent-hooks-add-rule)
    "s L" '("view agent hooks log" . hell-agent-hooks-show-log)

    ;; Hell Workspace & Left Sidebar Switcher prefix (`C-c w')
    "w"   "Hell Workspace"
    "w w" '("open 3-column workspace" . hell-workspace-open)
    "w l" '("arrange 3-column layout" . hell-workspace-layout)
    "w 1" '("sidebar: project files" . hell-workspace-sidebar-explorer)
    "w 2" '("sidebar: specs panel" . hell-workspace-sidebar-specs)
    "w 3" '("sidebar: hooks & steering" . hell-workspace-sidebar-forge)))

(provide 'hell-agent)
;;; hell-agent.el ends here
