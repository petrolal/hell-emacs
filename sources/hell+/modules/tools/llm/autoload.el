;;; tools/llm/autoload.el -*- lexical-binding: t; -*-

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

;; Autoloaded helpers and interactive commands for the `:tools llm'
;; agentic stack (`agent-shell' via `acp.el', `gptel' + `mcp.el' tools,
;; and `minuet' inline FIM completion).

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'subr-x)

(defvar hell-state-dir)
(defvar corfu--candidates)
(defvar minuet--current-overlay)
(defvar gptel-tools)
(defvar gptel-use-tools)
(defvar gptel-default-mode)

(declare-function auth-source-search "auth-source" (&rest spec))
(declare-function hell-process-output "hell-lib" (program &rest args))
(declare-function agent-shell "agent-shell" (&optional arg))
(declare-function agent-shell-toggle "agent-shell" ())
(declare-function agent-shell-new-shell "agent-shell" ())
(declare-function agent-shell-send-region "agent-shell" (&optional pick-shell))
(declare-function agent-shell-send-dwim "agent-shell" (&optional arg))
(declare-function agent-shell-send-file "agent-shell" (&optional prompt-for-file pick-shell))
(declare-function gptel "gptel" (name &optional key initial interactivep))
(declare-function gptel-send "gptel" (&optional arg))
(declare-function gptel-menu "gptel" ())
(declare-function gptel-request "gptel-request" (&optional prompt &rest args))
(declare-function gptel-make-tool "gptel-request" (&rest slots))
(declare-function minuet-dismiss-suggestion "minuet" ())

;;; Security & Environment Helpers --------------------------------------------

;;;###autoload
(defun hell-llm-api-key (host &optional env-var user)
  "Retrieve an API key for HOST from ENV-VAR or `auth-source'.
First checks environment variable ENV-VAR if non-nil and non-empty.
Falls back to searching `auth-source' for HOST (and USER, defaulting to
\"apikey\"). Returns the secret string, or nil if unavailable."
  (or (and env-var
           (let ((val (getenv env-var)))
             (and val (not (string-empty-p val)) val)))
      (when (require 'auth-source nil t)
        (when-let* ((entry (car (auth-source-search
                                 :host host
                                 :user (or user "apikey")
                                 :max 1)))
                    (secret (plist-get entry :secret)))
          (if (functionp secret)
              (funcall secret)
            secret)))))

;;;###autoload
(defun hell-llm-project-root ()
  "Return the root directory of the current project, or `default-directory'."
  (expand-file-name
   (or (when-let* ((proj (project-current nil)))
         (project-root proj))
       default-directory)))

;;;###autoload
(defun hell-llm-dot-subdir (subdir)
  "Resolve `agent-shell' SUBDIR inside `hell-state-dir' instead of the repo."
  (let* ((root (hell-llm-project-root))
         (slug (replace-regexp-in-string "[^A-Za-z0-9._-]" "_"
                                         (directory-file-name root))))
    (expand-file-name (format "agent-shell/%s/%s" slug subdir)
                      hell-state-dir)))

;;; 1. Agent Shell (ACP) Commands ---------------------------------------------

;;;###autoload
(defun hell-llm-agent-toggle ()
  "Toggle or start an `agent-shell' buffer anchored at the project root."
  (interactive)
  (let ((default-directory (hell-llm-project-root)))
    (if (fboundp 'agent-shell-toggle)
        (call-interactively #'agent-shell-toggle)
      (call-interactively #'agent-shell))))

;;;###autoload
(defun hell-llm-agent-new ()
  "Start a new `agent-shell' session anchored at the current project root."
  (interactive)
  (let ((default-directory (hell-llm-project-root)))
    (call-interactively #'agent-shell-new-shell)))

;;;###autoload
(defun hell-llm-agent-send-dwim ()
  "Send the active region or context at point to the project's `agent-shell'."
  (interactive)
  (let ((default-directory (hell-llm-project-root)))
    (if (use-region-p)
        (call-interactively #'agent-shell-send-region)
      (call-interactively #'agent-shell-send-dwim))))

;;;###autoload
(defun hell-llm-agent-send-file (&optional prompt-for-file)
  "Send the current file (or prompt when PROMPT-FOR-FILE is non-nil) to agent."
  (interactive "P")
  (let ((default-directory (hell-llm-project-root)))
    (agent-shell-send-file prompt-for-file)))

;;; 2. Native Elisp LLM (`gptel' + `mcp.el' + Tools) --------------------------

;;;###autoload
(defun hell-llm-chat (&optional arg)
  "Open or switch to a project-anchored `gptel' chat buffer.
With prefix ARG, prompt for the chat buffer name."
  (interactive "P")
  (let* ((root (hell-llm-project-root))
         (proj-name (file-name-nondirectory (directory-file-name root)))
         (buf-name (if arg
                       (read-string "GPTel buffer name: "
                                    (format "*gptel: %s*" proj-name))
                     (format "*gptel: %s*" proj-name)))
         (default-directory root)
         (buf (gptel buf-name nil
                     (when (use-region-p)
                       (buffer-substring-no-properties
                        (region-beginning) (region-end)))
                     nil)))
    (display-buffer buf)))

;;;###autoload
(defun hell-llm-send (&optional arg)
  "Send the current prompt or active region with `gptel-send'.
With prefix ARG, open `gptel-menu' for transient options and tools."
  (interactive "P")
  (if arg
      (call-interactively #'gptel-menu)
    (call-interactively #'gptel-send)))

;;;###autoload
(defun hell-llm-quick-chat (prompt)
  "Send a quick PROMPT to `gptel' (with active region context if any).
Displays the streamed answer in the `*gptel-quick*' popup buffer."
  (interactive
   (list (read-string
          (if (use-region-p)
              "Quick AI prompt (with selected region): "
            "Quick AI prompt: "))))
  (when (string-empty-p (string-trim prompt))
    (user-error "Prompt cannot be empty"))
  (require 'gptel)
  (let* ((root (hell-llm-project-root))
         (context (when (use-region-p)
                    (buffer-substring-no-properties
                     (region-beginning) (region-end))))
         (full-prompt (if context
                          (format "%s\n\n```\n%s\n```" prompt context)
                        prompt))
         (out-buf (get-buffer-create "*gptel-quick*")))
    (with-current-buffer out-buf
      (setq default-directory root)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (if (and (boundp 'gptel-default-mode)
                 (fboundp gptel-default-mode))
            (funcall gptel-default-mode)
          (org-mode))
        (insert (format "* Prompt\n%s\n\n* Response\nThinking..." prompt))))
    (display-buffer out-buf)
    (gptel-request
     full-prompt
     :buffer out-buf
     :callback
     (lambda (response info)
       (when (buffer-live-p out-buf)
         (with-current-buffer out-buf
           (let ((inhibit-read-only t))
             (goto-char (point-min))
             (when (search-forward "\n* Response\n" nil t)
               (delete-region (point) (point-max)))
             (goto-char (point-max))
             (if (stringp response)
                 (insert response "\n")
               (insert (format "Error: %s\n"
                               (or (plist-get info :status)
                                   "Request failed")))))))))))

;;; Project-Scoped Agentic Tools for `gptel' ----------------------------------

(defun hell-llm--safe-project-path (rel-path)
  "Resolve REL-PATH inside `(hell-llm-project-root)' and guard against escape."
  (let* ((root (file-name-as-directory (file-truename (hell-llm-project-root))))
         (target (file-truename (expand-file-name rel-path root))))
    (unless (file-in-directory-p target root)
      (error "Path %S escapes project root %S" rel-path root))
    target))

(defun hell-llm--tool-read-file (path)
  "Read file at PATH inside the current project root."
  (let ((file (hell-llm--safe-project-path path)))
    (unless (file-readable-p file)
      (error "File is not readable: %s" path))
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun hell-llm--tool-edit-file (path target replacement)
  "Replace TARGET with REPLACEMENT in file PATH inside the current project.
If TARGET is empty and file does not exist, create the file with REPLACEMENT."
  (let ((file (hell-llm--safe-project-path path)))
    (if (and (string-empty-p target) (not (file-exists-p file)))
        (progn
          (make-directory (file-name-directory file) t)
          (with-temp-file file
            (insert replacement))
          (format "Created %s (%d chars)" path (length replacement)))
      (unless (file-readable-p file)
        (error "File does not exist: %s" path))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (unless (search-forward target nil t)
          (error "Target text not found in %s" path))
        (replace-match replacement t t)
        (write-region (point-min) (point-max) file nil 'silent)
        (when-let* ((buf (find-buffer-visiting file)))
          (with-current-buffer buf
            (revert-buffer t t t)))
        (format "Updated %s" path)))))

(defun hell-llm--tool-run-shell (command)
  "Run shell COMMAND in `(hell-llm-project-root)' and return output."
  (let* ((default-directory (hell-llm-project-root))
         (shell (or (executable-find "bash") (executable-find "sh") "/bin/sh"))
         (res (hell-process-output shell "-c" command)))
    (format "Exit code: %d\nOutput:\n%s" (car res) (cdr res))))

(defun hell-llm--tool-list-files ()
  "Return newline-separated list of files in the current project."
  (let ((root (hell-llm-project-root)))
    (if-let* ((proj (project-current nil root)))
        (mapconcat (lambda (f) (file-relative-name f root))
                   (cl-subseq (project-files proj)
                              0 (min 400 (length (project-files proj))))
                   "\n")
      (mapconcat #'identity
                 (directory-files root nil directory-files-no-dot-files-regexp)
                 "\n"))))

;;;###autoload
(defun hell-llm-register-gptel-tools ()
  "Register project-scoped agentic tools in `gptel'."
  (when (fboundp 'gptel-make-tool)
    (let ((tools
           (list
            (gptel-make-tool
             :name "read_project_file"
             :function #'hell-llm--tool-read-file
             :description "Read the full contents of a file relative to the current project root."
             :args '((:name "path"
                      :type string
                      :description "Relative path to the file from the project root."))
             :category "hell-project")
            (gptel-make-tool
             :name "edit_project_file"
             :function #'hell-llm--tool-edit-file
             :description "Edit a file in the project by replacing exact target text with replacement text, or create a new file when target is empty."
             :args '((:name "path"
                      :type string
                      :description "Relative path to the file from the project root.")
                     (:name "target"
                      :type string
                      :description "Exact existing text to replace (empty string to create a new file).")
                     (:name "replacement"
                      :type string
                      :description "Replacement text to write."))
             :category "hell-project"
             :confirm t)
            (gptel-make-tool
             :name "run_project_shell"
             :function #'hell-llm--tool-run-shell
             :description "Execute a shell command in the current project root directory and return its exit code and output."
             :args '((:name "command"
                      :type string
                      :description "Shell command to run in the project root."))
             :category "hell-project"
             :confirm t)
            (gptel-make-tool
             :name "list_project_files"
             :function #'hell-llm--tool-list-files
             :description "List files tracked in the current project root."
             :args nil
             :category "hell-project"))))
      (setq gptel-use-tools t)
      (dolist (tool tools)
        (cl-pushnew tool gptel-tools :test #'equal)))))

;;; 3. Inline FIM (`minuet') & Corfu Coexistence ------------------------------

;;;###autoload
(defun hell-llm-corfu-active-p ()
  "Return non-nil when Corfu's completion popup is currently visible.
Used in `minuet-auto-suggestion-block-predicates' so inline FIM never
collides with Corfu."
  (and (boundp 'corfu--candidates)
       (not (null corfu--candidates))))

(provide 'tools-llm-autoload)
;;; autoload.el ends here
