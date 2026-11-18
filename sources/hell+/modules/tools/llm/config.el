;;; tools/llm/config.el -*- lexical-binding: t; -*-

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

;; Agentic AI IDE stack for Hell Emacs:
;;   1. `hell-agent' (`lisp/hell-agent.el'): Spec-Driven Development
;;      (`hell-spec-create', `hell-spec-execute-task'), Steering rules discovery
;;      (`AGENTS.md', `CLAUDE.md', `.hell/steering/', `openspec/'), opt-in
;;      Agent Hooks (`hell-agent-hooks-mode'), and 3-column workspace layout.
;;   2. `agent-shell' (via `acp.el'): native Emacs comint buffers for external
;;      ACP agents (Claude Code, Gemini CLI, OpenCode, Codex) anchored at the
;;      project root (`project.el') in the right side window.
;;   3. `gptel' + `mcp.el': native Elisp chat and Spec fallback in Org/Markdown
;;      buffers with project-scoped tool-use and MCP server integration.
;;   4. `minuet': inline Fill-in-the-Middle (FIM) ghost-text completion tuned
;;      to coexist cleanly with `:completion corfu' and stock GNU Emacs keys.
;;
;; All components are strictly lazy-loaded (`:defer t') with zero network or
;; subprocess activity during Emacs startup. API keys are resolved on demand
;; from environment variables (`getenv') or `auth-source' (~/.authinfo.gpg).

;;; Code:

(require 'cl-lib)

(defvar agent-shell-cwd-function)
(defvar agent-shell-dot-subdir-function)
(defvar agent-shell-display-action)
(defvar gptel-backend)
(defvar gptel-model)
(defvar gptel-default-mode)
(defvar gptel-use-tools)
(defvar gptel-track-media)
(defvar mcp-hub-servers)
(defvar minuet-provider)
(defvar minuet-active-mode-map)
(defvar minuet-auto-suggestion-debounce-delay)
(defvar minuet-auto-suggestion-throttle-delay)
(defvar minuet-auto-suggestion-block-predicates)
(defvar minuet-openai-fim-compatible-options)
(defvar minuet-claude-options)
(defvar minuet-gemini-options)
(defvar minuet-codestral-options)

(declare-function hell-llm-api-key "tools/llm/autoload" (host &optional env-var user))
(declare-function hell-llm-project-root "tools/llm/autoload" ())
(declare-function hell-llm-dot-subdir "tools/llm/autoload" (subdir))
(declare-function hell-llm-agent-toggle "tools/llm/autoload" ())
(declare-function hell-llm-agent-new "tools/llm/autoload" ())
(declare-function hell-llm-agent-send-dwim "tools/llm/autoload" ())
(declare-function hell-llm-agent-send-file "tools/llm/autoload" (&optional prompt-for-file))
(declare-function hell-llm-chat "tools/llm/autoload" (&optional arg))
(declare-function hell-llm-quick-chat "tools/llm/autoload" (prompt))
(declare-function hell-llm-send "tools/llm/autoload" (&optional arg))
(declare-function hell-llm-register-gptel-tools "tools/llm/autoload" ())
(declare-function hell-llm-corfu-active-p "tools/llm/autoload" ())

(declare-function hell-workspace-open "hell-agent" (&optional project-dir))
(declare-function hell-workspace-layout "hell-agent" ())
(declare-function hell-workspace-sidebar-explorer "hell-agent" ())
(declare-function hell-workspace-sidebar-specs "hell-agent" ())
(declare-function hell-workspace-sidebar-forge "hell-agent" ())
(declare-function hell-agent-toggle "hell-agent" ())
(declare-function hell-agent-start "hell-agent" ())
(declare-function hell-agent-select "hell-agent" ())
(declare-function hell-agent-send-region "hell-agent" ())
(declare-function hell-agent-send-file "hell-agent" (&optional prompt-for-file))
(declare-function hell-gptel-chat "hell-agent" (&optional arg))
(declare-function hell-agent-inject-steering "hell-agent" (&optional root))
(declare-function hell-agent-steering-edit "hell-agent" ())
(declare-function hell-spec-create "hell-agent" (&optional feature-name project-dir))
(declare-function hell-spec-advance-phase "hell-agent" (&optional use-gptel))
(declare-function hell-spec-open "hell-agent" ())
(declare-function hell-spec-execute-task "hell-agent" (&optional use-gptel))
(declare-function hell-spec-toggle-task "hell-agent" ())
(declare-function hell-spec-generate-with-ai "hell-agent" (feature-prompt))
(declare-function hell-agent-hooks-mode "hell-agent" (&optional arg))
(declare-function hell-agent-hooks-add-rule "hell-agent" (name glob-pattern action-type payload))
(declare-function hell-agent-hooks-show-log "hell-agent" ())

(declare-function agent-shell "agent-shell" (&optional arg))
(declare-function agent-shell-toggle "agent-shell" ())
(declare-function agent-shell-new-shell "agent-shell" ())
(declare-function agent-shell-send-region "agent-shell" (&optional pick-shell))
(declare-function agent-shell-send-file "agent-shell" (&optional prompt-for-file pick-shell))
(declare-function agent-shell-send-dwim "agent-shell" (&optional arg))
(declare-function agent-shell-prompt-compose "agent-shell" ())

(declare-function gptel "gptel" (name &optional key initial interactivep))
(declare-function gptel-send "gptel" (&optional arg))
(declare-function gptel-menu "gptel-transient" ())
(declare-function gptel-rewrite "gptel-rewrite" ())
(declare-function gptel-make-anthropic "gptel-anthropic" (name &rest args))
(declare-function gptel-make-gemini "gptel-gemini" (name &rest args))
(declare-function gptel-make-openai "gptel-openai" (name &rest args))
(declare-function gptel-make-ollama "gptel-ollama" (name &rest args))
(declare-function gptel-mcp-connect "gptel-integrations" (&optional servers server-callback interactive))
(declare-function gptel-mcp-disconnect "gptel-integrations" (&optional servers interactive))

(declare-function mcp-hub "mcp-hub" (&optional start))
(declare-function mcp-hub-start-all-server "mcp-hub" (&optional callback servers syncp))

(declare-function minuet-show-suggestion "minuet" ())
(declare-function minuet-auto-suggestion-mode "minuet" (&optional arg))
(declare-function minuet-accept-suggestion "minuet" ())
(declare-function minuet-accept-suggestion-line "minuet" (&optional n))
(declare-function minuet-accept-suggestion-word "minuet" (&optional n))
(declare-function minuet-dismiss-suggestion "minuet" ())
(declare-function minuet-next-suggestion "minuet" ())
(declare-function minuet-previous-suggestion "minuet" ())
(declare-function minuet-complete-with-minibuffer "minuet" ())
(declare-function minuet-configure-provider "minuet" ())

;;; Autoloads for `hell-agent' (`lisp/hell-agent.el') -------------------------

(autoload 'hell-workspace-open "hell-agent"
  "Open PROJECT-DIR in the 3-column Hell Emacs layout." t)
(autoload 'hell-workspace-layout "hell-agent"
  "Arrange the current frame into the 3-column Hell Emacs workspace layout." t)
(autoload 'hell-workspace-sidebar-explorer "hell-agent"
  "Switch the left sidebar to View 1: Project File Explorer (`C-c w 1')." t)
(autoload 'hell-workspace-sidebar-specs "hell-agent"
  "Switch the left sidebar to View 2: Specifications Panel (`C-c w 2')." t)
(autoload 'hell-workspace-sidebar-forge "hell-agent"
  "Switch the left sidebar to View 3: Agent Hooks & Steering (`C-c w 3')." t)
(autoload 'hell-agent-toggle "hell-agent"
  "Toggle the project's `agent-shell' (with steering) in the right side window." t)
(autoload 'hell-agent-start "hell-agent"
  "Start a new agent session anchored at the project root with steering." t)
(autoload 'hell-agent-select "hell-agent"
  "Choose which CLI/provider to use (Claude, Gemini, Codex, OpenCode, GPTel)." t)
(autoload 'hell-agent-send-region "hell-agent"
  "Send active region or current buffer to the active project agent." t)
(autoload 'hell-agent-send-file "hell-agent"
  "Send the current visited file to the project agent." t)
(autoload 'hell-gptel-chat "hell-agent"
  "Open or switch to a project-anchored `gptel' chat buffer." t)
(autoload 'hell-agent-inject-steering "hell-agent"
  "Detect steering files in ROOT and inject them into `agent-shell' and `gptel'." t)
(autoload 'hell-agent-steering-edit "hell-agent"
  "Open or create `.hell/steering/project.md' (or `AGENTS.md') in project root." t)
(autoload 'hell-spec-create "hell-agent"
  "Create or open the specification structure (`openspec/' or `specs/')." t)
(autoload 'hell-spec-advance-phase "hell-agent"
  "Advance specification phase (Requirements -> Design -> Tasks)." t)
(autoload 'hell-spec-open "hell-agent"
  "Prompt for a specification file and open it." t)
(autoload 'hell-spec-execute-task "hell-agent"
  "Send task at point with `design.md' and `requirements.md' to the Agent." t)
(autoload 'hell-spec-toggle-task "hell-agent"
  "Toggle the Markdown checkbox (`- [ ]' <-> `- [x]') on the current line." t)
(autoload 'hell-spec-generate-with-ai "hell-agent"
  "Generate `requirements.md', `design.md', and `tasks.md' drafts via `gptel'." t)
(autoload 'hell-agent-hooks-mode "hell-agent"
  "Opt-in event-driven Agent Hooks minor mode." t)
(autoload 'hell-agent-hooks-add-rule "hell-agent"
  "Interactively register an Agent Hook rule in `hell-agent-hooks'." t)
(autoload 'hell-agent-hooks-show-log "hell-agent"
  "Display the `*hell-agent-hooks*' execution log buffer." t)

;;; 3-Column Workspace Window Management (`display-buffer-alist') -------------
;;
;; Left column:   Explorer / `*Hell Specs*' / `*Hell Forge*' (width 32, left)
;; Center column: Code or Specification document (`.md' / `.org')
;; Right column:  Agent Shell / GPTel / Hooks (`(side . right)', width 0.38)

(defconst hell-llm-side-window-action
  '((display-buffer-reuse-window display-buffer-in-side-window)
    (side . right)
    (slot . 0)
    (window-width . 0.38)
    (preserve-size . (t . nil)))
  "Display action placing AI agent and chat buffers in the right side window.")

(defconst hell-llm-left-window-action
  '((display-buffer-reuse-window display-buffer-in-side-window)
    (side . left)
    (slot . 0)
    (window-width . 32)
    (preserve-size . (t . nil)))
  "Display action placing left sidebar buffers in the left side window.")

(dolist (rule `(("\\`\\*Treemacs" ,@hell-llm-left-window-action)
                ("\\`\\*Hell Specs\\*\\'" ,@hell-llm-left-window-action)
                ("\\`\\*Hell Forge\\*\\'" ,@hell-llm-left-window-action)
                ("\\`\\*gptel" ,@hell-llm-side-window-action)
                ("\\`\\*hell-spec" ,@hell-llm-side-window-action)
                ("\\`\\*hell-agent-hooks\\*\\'" ,@hell-llm-side-window-action)
                ("\\`\\*mcp-hub\\*\\'" ,@hell-llm-side-window-action)
                ("\\(?:Agent\\|agent-shell\\)" ,@hell-llm-side-window-action)))
  (add-to-list 'display-buffer-alist rule))

;;; Keybindings: `C-c a' (Agent), `C-c s' (Specs) & `C-c w' (Workspace) -------

(hell-leader-def
  ;; Hell Agent & Inline FIM prefix (`C-c a')
  "a"   "Hell Agent"
  "a a" '("toggle project agent" . hell-agent-toggle)
  "a A" '("new project agent" . hell-agent-start)
  "a s" '("select agent provider" . hell-agent-select)
  "a r" '("send region/buffer to agent" . hell-agent-send-region)
  "a f" '("send file to agent" . hell-agent-send-file)
  "a c" '("gptel native chat" . hell-gptel-chat)
  "a e" '("execute spec task in agent" . hell-spec-execute-task)
  "a S" '("inject steering into agent" . hell-agent-inject-steering)
  "a p" '("compose agent prompt" . agent-shell-prompt-compose)
  "a q" '("quick ai query" . hell-llm-quick-chat)
  "a m" '("gptel menu & tools" . gptel-menu)
  "a w" '("gptel rewrite" . gptel-rewrite)
  "a M" '("mcp server hub" . mcp-hub)
  "a C" '("connect mcp tools" . gptel-mcp-connect)
  "a i" '("inline fim suggestion" . minuet-show-suggestion)
  "a I" '("toggle auto inline fim" . minuet-auto-suggestion-mode)
  "a y" '("accept inline suggestion" . minuet-accept-suggestion)
  "a k" '("clear inline suggestion" . minuet-dismiss-suggestion)
  "a n" '("next inline suggestion" . minuet-next-suggestion)
  "a N" '("previous inline suggestion" . minuet-previous-suggestion)

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
  "w 3" '("sidebar: hooks & steering" . hell-workspace-sidebar-forge)

  ;; Compatible entries under `C-c c' (code) and `C-c o' (open)
  "c A" '("ai assistant" . hell-gptel-chat)
  "o a" '("ai agent shell" . hell-agent-toggle)
  "o A" '("ai chat (gptel)" . hell-gptel-chat))

;;; 1. Agent Shell (`agent-shell' via `acp.el') -------------------------------

(use-package acp
  :defer t)

(use-package agent-shell
  :defer t
  :commands (agent-shell
             agent-shell-toggle
             agent-shell-new-shell
             agent-shell-send-region
             agent-shell-send-file
             agent-shell-send-dwim
             agent-shell-prompt-compose)
  :init
  (setq agent-shell-cwd-function #'hell-llm-project-root
        agent-shell-dot-subdir-function #'hell-llm-dot-subdir
        agent-shell-display-action hell-llm-side-window-action))

;;; 2. Native Elisp Layer (`gptel' + `mcp.el') --------------------------------

(use-package mcp-hub
  :defer t
  :commands (mcp-hub mcp-hub-start-all-server)
  :init
  (unless (boundp 'mcp-hub-servers)
    (setq mcp-hub-servers nil)))

(autoload 'gptel-mcp-connect "gptel-integrations"
  "Add gptel tools from MCP servers using the mcp package." t)
(autoload 'gptel-mcp-disconnect "gptel-integrations"
  "Remove gptel tools provided by MCP servers." t)

(use-package gptel
  :defer t
  :commands (gptel gptel-send gptel-menu gptel-rewrite gptel-request)
  :init
  (setq gptel-default-mode 'org-mode
        gptel-track-media t)
  :config
  (require 'gptel-integrations nil t)
  (hell-llm-register-gptel-tools)

  ;; Register external and local (Ollama) backends lazily with auth-source / env keys.
  (let ((claude (gptel-make-anthropic "Claude"
                  :stream t
                  :key (lambda ()
                         (hell-llm-api-key "api.anthropic.com" "ANTHROPIC_API_KEY"))))
        (gemini (gptel-make-gemini "Gemini"
                  :stream t
                  :key (lambda ()
                         (hell-llm-api-key "generativelanguage.googleapis.com" "GEMINI_API_KEY"))))
        (openai (gptel-make-openai "OpenAI"
                  :stream t
                  :key (lambda ()
                         (hell-llm-api-key "api.openai.com" "OPENAI_API_KEY"))))
        (ollama (gptel-make-ollama "Ollama"
                  :host (or (getenv "OLLAMA_HOST") "localhost:11434")
                  :stream t
                  :models '(qwen2.5-coder:latest
                            deepseek-coder-v2:latest
                            llama3.1:latest))))
    (cond
     ((hell-llm-api-key "api.anthropic.com" "ANTHROPIC_API_KEY")
      (setq gptel-backend claude
            gptel-model 'claude-sonnet-4-20250514))
     ((hell-llm-api-key "generativelanguage.googleapis.com" "GEMINI_API_KEY")
      (setq gptel-backend gemini
            gptel-model 'gemini-2.5-pro))
     ((hell-llm-api-key "api.openai.com" "OPENAI_API_KEY")
      (setq gptel-backend openai
            gptel-model 'gpt-4o))
     (t
      (setq gptel-backend ollama
            gptel-model 'qwen2.5-coder:latest)))))

;;; 3. Inline FIM Autocomplete (`minuet') -------------------------------------
;;
;; Configured so inline ghost text never collides with `:completion corfu'
;; (`RET', `TAB', `M-n', `M-p', `C-n', `C-p') or stock GNU Emacs editing keys:
;;   - When Corfu's popup is open (`hell-llm-corfu-active-p'), Minuet pauses
;;     auto-suggestions.
;;   - While a Minuet suggestion overlay is active (`minuet-active-mode-map'):
;;       `M-RET'     accepts full suggestion
;;       `M-<right>' accepts next word
;;       `M-<down>'  accepts next line
;;       `M-]'/`M-[' cycles next/previous suggestion
;;       `C-g'       dismisses suggestion

(use-package minuet
  :defer t
  :commands (minuet-show-suggestion
             minuet-auto-suggestion-mode
             minuet-accept-suggestion
             minuet-accept-suggestion-line
             minuet-accept-suggestion-word
             minuet-dismiss-suggestion
             minuet-next-suggestion
             minuet-previous-suggestion
             minuet-complete-with-minibuffer
             minuet-configure-provider)
  :init
  (setq minuet-auto-suggestion-debounce-delay 0.4
        minuet-auto-suggestion-throttle-delay 1.0)
  :config
  (add-to-list 'minuet-auto-suggestion-block-predicates #'hell-llm-corfu-active-p)

  (keymap-set minuet-active-mode-map "M-RET" #'minuet-accept-suggestion)
  (keymap-set minuet-active-mode-map "M-<right>" #'minuet-accept-suggestion-word)
  (keymap-set minuet-active-mode-map "M-<down>" #'minuet-accept-suggestion-line)
  (keymap-set minuet-active-mode-map "M-]" #'minuet-next-suggestion)
  (keymap-set minuet-active-mode-map "M-[" #'minuet-previous-suggestion)
  (keymap-set minuet-active-mode-map "C-g" #'minuet-dismiss-suggestion)

  ;; Secure API key resolution via environment variables or `auth-source'.
  (plist-put minuet-codestral-options :api-key
             (lambda () (hell-llm-api-key "codestral.mistral.ai" "CODESTRAL_API_KEY")))
  (plist-put minuet-gemini-options :api-key
             (lambda () (hell-llm-api-key "generativelanguage.googleapis.com" "GEMINI_API_KEY")))
  (plist-put minuet-claude-options :api-key
             (lambda () (hell-llm-api-key "api.anthropic.com" "ANTHROPIC_API_KEY")))
  ;; Local Ollama FIM fallback (OpenAI-compatible FIM endpoint).
  (plist-put minuet-openai-fim-compatible-options :end-point
             (format "http://%s/v1/completions"
                     (or (getenv "OLLAMA_HOST") "localhost:11434")))
  (plist-put minuet-openai-fim-compatible-options :name "Ollama")
  (plist-put minuet-openai-fim-compatible-options :model "qwen2.5-coder:7b")
  (plist-put minuet-openai-fim-compatible-options :api-key "TERM")

  (setq minuet-provider
        (cond
         ((hell-llm-api-key "codestral.mistral.ai" "CODESTRAL_API_KEY") 'codestral)
         ((hell-llm-api-key "generativelanguage.googleapis.com" "GEMINI_API_KEY") 'gemini)
         ((hell-llm-api-key "api.anthropic.com" "ANTHROPIC_API_KEY") 'claude)
         (t 'openai-fim-compatible))))

(provide 'tools-llm-config)
;;; config.el ends here
