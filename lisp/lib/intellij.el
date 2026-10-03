;;; lisp/lib/intellij.el --- IntelliJ IDEA and Eclipse keyfinder -*- lexical-binding: t; -*-

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

;; IntelliJ IDEA and Eclipse to Hell Emacs cheat sheet and interactive
;; search tool (`M-x hell-where-is-intellij' on `C-c h k').
;;
;; Loaded on demand through `(hell-require 'hell-lib 'intellij)'.

;;; Code:

(defconst hell-intellij-actions
  '(;; Finding things
    (:action "Any command / Action search"
     :intellij "Ctrl+Shift+A" :eclipse "Ctrl+3" :key "M-x" :command execute-extended-command
     :category "Finding" :doc "Run any Emacs or Hell Emacs command by name with fuzzy completion.")
    (:action "Find file in project"
     :intellij "Ctrl+Shift+N" :eclipse "Ctrl+Shift+R" :key "C-x p f" :command project-find-file
     :category "Finding" :doc "Fuzzy find and open any file in the current project.")
    (:action "Find class / symbol in project"
     :intellij "Ctrl+N, Ctrl+Alt+Shift+N" :eclipse "Ctrl+Shift+T" :key "C-M-." :command xref-find-apropos
     :category "Finding" :doc "Search for classes, interfaces, and symbols across workspace.")
    (:action "Recent files"
     :intellij "Ctrl+E" :eclipse "—" :key "C-c f r" :command consult-recent-file
     :category "Finding" :doc "Switch to a recently visited file across projects.")
    (:action "Switch buffer / open file"
     :intellij "Ctrl+Tab" :eclipse "Ctrl+E" :key "C-x b" :command consult-buffer
     :category "Finding" :doc "Switch buffer with live preview (also C-x p b for project buffers).")
    (:action "File structure / Imenu"
     :intellij "Ctrl+F12" :eclipse "Ctrl+O" :key "M-g i" :command consult-imenu
     :category "Finding" :doc "Jump to any method, field, or symbol in the current buffer.")
    (:action "Go to line"
     :intellij "Ctrl+G" :eclipse "Ctrl+L" :key "M-g g" :command consult-goto-line
     :category "Finding" :doc "Jump directly to line number with live preview.")
    (:action "Find in current file"
     :intellij "Ctrl+F" :eclipse "Ctrl+F" :key "C-s" :command isearch-forward
     :category "Finding" :doc "Incremental search forward (C-c s s for a list of the matching lines).")
    (:action "Find in project (Ripgrep)"
     :intellij "Ctrl+Shift+F" :eclipse "Ctrl+H" :key "C-c s p" :command consult-ripgrep
     :category "Finding" :doc "Fast ripgrep search across all project files.")
    (:action "Replace / Project replace"
     :intellij "Ctrl+R / Ctrl+Shift+R" :eclipse "Ctrl+F / Ctrl+H" :key "M-% / C-x p r" :command query-replace
     :category "Finding" :doc "Query replace in buffer (M-%) or across project (C-x p r).")
    (:action "Project file tree / Dired"
     :intellij "Alt+1" :eclipse "Package Explorer" :key "C-x p D" :command project-dired
     :category "Finding" :doc "Open project root in Dired with icons and batch editing (wdired).")

    ;; Navigating code
    (:action "Go to declaration / definition"
     :intellij "Ctrl+B, Ctrl+Click" :eclipse "F3" :key "M-." :command xref-find-definitions
     :category "Navigation" :doc "Jump to definition of symbol at point.")
    (:action "Back to previous location"
     :intellij "Ctrl+Alt+Left" :eclipse "Alt+Left" :key "M-," :command xref-go-back
     :category "Navigation" :doc "Jump back to where you were before following definition.")
    (:action "Find usages / references"
     :intellij "Alt+F7" :eclipse "Ctrl+Shift+G" :key "M-?" :command xref-find-references
     :category "Navigation" :doc "List all references to symbol across the workspace.")
    (:action "Go to implementation"
     :intellij "Ctrl+Alt+B" :eclipse "Ctrl+T" :key "C-c c i" :command lsp-find-implementation
     :category "Navigation" :doc "Jump to implementations of the interface or abstract method.")
    (:action "Go to type declaration"
     :intellij "Ctrl+Shift+B" :eclipse "—" :key "C-c c t" :command lsp-find-type-definition
     :category "Navigation" :doc "Jump to definition of the type of the symbol at point.")
    (:action "Type hierarchy"
     :intellij "Ctrl+H" :eclipse "F4" :key "C-c l h" :command lsp-java-type-hierarchy
     :category "Navigation" :doc "Inspect supertypes and subtypes hierarchy in Java buffers.")
    (:action "Quick documentation / Hover"
     :intellij "Ctrl+Q" :eclipse "F2" :key "C-c c k" :command lsp-describe-thing-at-point
     :category "Navigation" :doc "Show documentation and signature at point (or lsp-describe-thing-at-point).")
    (:action "Next error / diagnostic"
     :intellij "F2" :eclipse "Ctrl+." :key "M-x flymake-goto-next-error" :command flymake-goto-next-error
     :category "Navigation" :doc "Jump to next compiler error or linter warning (C-c s e to pick one).")
    (:action "Previous error / diagnostic"
     :intellij "Shift+F2" :eclipse "Ctrl+," :key "M-x flymake-goto-prev-error" :command flymake-goto-prev-error
     :category "Navigation" :doc "Jump to previous compiler error or linter warning.")
    (:action "Problems view / error list"
     :intellij "Alt+6" :eclipse "Problems View" :key "M-x flymake-show-buffer-diagnostics" :command flymake-show-buffer-diagnostics
     :category "Navigation" :doc "Open buffer diagnostics popup.")
    (:action "Last edit location"
     :intellij "Ctrl+Shift+Backspace" :eclipse "Ctrl+Q" :key "C-u C-SPC" :command set-mark-command
     :category "Navigation" :doc "Cycle backward through the global mark ring.")
    (:action "Toggle bookmark / jump"
     :intellij "F11 / Shift+F11" :eclipse "—" :key "C-x r m / C-x r b" :command bookmark-set
     :category "Navigation" :doc "Set named bookmark (C-x r m) or jump to one (C-x r b).")

    ;; Editing and refactoring
    (:action "Code completion"
     :intellij "Ctrl+Space" :eclipse "Ctrl+Space" :key "C-M-i" :command completion-at-point
     :category "Refactoring" :doc "In-buffer completion popup (automatic as you type, or C-M-i on demand).")
    (:action "Quick fix / Intention actions"
     :intellij "Alt+Enter" :eclipse "Ctrl+1" :key "C-c c a" :command lsp-execute-code-action
     :category "Refactoring" :doc "Apply quick-fix, auto-import, or intention action at point.")
    (:action "Rename symbol"
     :intellij "Shift+F6" :eclipse "Alt+Shift+R" :key "C-c c r" :command lsp-rename
     :category "Refactoring" :doc "Workspace-wide semantic rename of class, method, or variable.")
    (:action "Extract method"
     :intellij "Ctrl+Alt+M" :eclipse "Alt+Shift+M" :key "C-c l m" :command lsp-java-extract-method
     :category "Refactoring" :doc "Extract selected code into a new method (Java).")
    (:action "Extract variable"
     :intellij "Ctrl+Alt+V" :eclipse "Alt+Shift+L" :key "C-c l v" :command lsp-java-extract-to-local-variable
     :category "Refactoring" :doc "Extract selected expression into a local variable (Java).")
    (:action "Extract constant"
     :intellij "Ctrl+Alt+C" :eclipse "—" :key "C-c l c" :command lsp-java-extract-to-constant
     :category "Refactoring" :doc "Extract selected expression into a static constant (Java).")
    (:action "Generate getters and setters"
     :intellij "Alt+Insert" :eclipse "Alt+Shift+S" :key "C-c l g" :command lsp-java-generate-getters-and-setters
     :category "Refactoring" :doc "Generate getters, setters, toString, equals/hashCode (C-c l s / C-c l e).")
    (:action "Implement methods"
     :intellij "Ctrl+I" :eclipse "Quick Fix" :key "C-c l i" :command lsp-java-override-methods
     :category "Refactoring" :doc "Implement or override interface/superclass methods (Java).")
    (:action "Organize imports"
     :intellij "Ctrl+Alt+O" :eclipse "Ctrl+Shift+O" :key "C-c c o" :command lsp-organize-imports
     :category "Refactoring" :doc "Sort imports, add missing, and remove unused imports.")
    (:action "Reformat code"
     :intellij "Ctrl+Alt+L" :eclipse "Ctrl+Shift+F" :key "C-c c f" :command lsp-format-buffer
     :category "Refactoring" :doc "Format buffer using project code style (or google-java-format).")
    (:action "Comment line / region"
     :intellij "Ctrl+/" :eclipse "Ctrl+/" :key "C-x C-;" :command comment-line
     :category "Refactoring" :doc "Toggle comment on current line or active region (M-; at end of line).")
    (:action "Delete line"
     :intellij "Ctrl+Y" :eclipse "Ctrl+D" :key "C-S-<backspace>" :command kill-whole-line
     :category "Refactoring" :doc "Kill entire line without leaving blank lines.")
    (:action "Duplicate line"
     :intellij "Ctrl+D" :eclipse "Ctrl+Alt+Down" :key "M-x duplicate-dwim" :command duplicate-dwim
     :category "Refactoring" :doc "Duplicate current line or region below.")
    (:action "Move line up/down"
     :intellij "Ctrl+Shift+Up/Down" :eclipse "Alt+Up/Down" :key "C-x C-t" :command transpose-lines
     :category "Refactoring" :doc "Transpose and swap lines.")
    (:action "Undo / Redo"
     :intellij "Ctrl+Z / Ctrl+Shift+Z" :eclipse "Ctrl+Z / Ctrl+Y" :key "C-/ / C-?" :command undo-only
     :category "Refactoring" :doc "Persistent undo/redo history (C-M-_ in terminal).")
    (:action "Save all buffers"
     :intellij "Ctrl+S" :eclipse "Ctrl+Shift+S" :key "C-x s" :command save-some-buffers
     :category "Refactoring" :doc "Prompt to save all modified file buffers.")

    ;; Build, run, test, debug
    (:action "Build project"
     :intellij "Ctrl+F9" :eclipse "Ctrl+B" :key "C-x p c" :command project-compile
     :category "Build & Debug" :doc "Build project using Maven/Gradle wrapper with clickable errors.")
    (:action "Run configuration"
     :intellij "Shift+F10" :eclipse "Ctrl+F11" :key "C-c r r" :command hell-run
     :category "Build & Debug" :doc "Run a saved run configuration (.run/, .launch, or .hell-emacs/run.eld).")
    (:action "Debug configuration"
     :intellij "Shift+F9" :eclipse "F11" :key "C-c r d" :command hell-run-debug
     :category "Build & Debug" :doc "Debug run configuration under DAP debugger.")
    (:action "Rerun last configuration"
     :intellij "Ctrl+F5" :eclipse "Ctrl+F11" :key "C-c r l" :command hell-run-last
     :category "Build & Debug" :doc "Rerun the last launched configuration.")
    (:action "Run test at point / class"
     :intellij "Ctrl+Shift+F10" :eclipse "Alt+Shift+X T" :key "C-c l t t" :command hell-test-at-point
     :category "Build & Debug" :doc "Run the test method at point (or C-c l t T for entire test class).")
    (:action "View test results / Rerun failures"
     :intellij "Alt+4" :eclipse "JUnit View" :key "C-c l t r" :command hell-test-results
     :category "Build & Debug" :doc "Open JUnit test results view (C-c l t f to rerun failures).")
    (:action "Run with coverage"
     :intellij "Run with Coverage" :eclipse "—" :key "C-c l t c" :command hell-test-coverage
     :category "Build & Debug" :doc "Execute tests with JaCoCo coverage gutters (C-c l t s to show).")
    (:action "Toggle breakpoint"
     :intellij "Ctrl+F8" :eclipse "Ctrl+Shift+B" :key "C-c d b" :command dap-breakpoint-toggle
     :category "Build & Debug" :doc "Toggle breakpoint on current line (C-c d B for conditional).")
    (:action "Step over"
     :intellij "F8" :eclipse "F6" :key "C-c d n" :command dap-next
     :category "Build & Debug" :doc "Step over next line in debugger (then press n to repeat).")
    (:action "Step into"
     :intellij "F7" :eclipse "F5" :key "C-c d i" :command dap-step-in
     :category "Build & Debug" :doc "Step into method at point (then press i to repeat).")
    (:action "Step out"
     :intellij "Shift+F8" :eclipse "F7" :key "C-c d o" :command dap-step-out
     :category "Build & Debug" :doc "Step out of current method (then press o to repeat).")
    (:action "Resume execution"
     :intellij "F9" :eclipse "F8" :key "C-c d c" :command dap-continue
     :category "Build & Debug" :doc "Resume program execution until next breakpoint (then press c to repeat).")
    (:action "Evaluate expression"
     :intellij "Alt+F8" :eclipse "Ctrl+Shift+I" :key "C-c d E" :command dap-eval
     :category "Build & Debug" :doc "Evaluate expression in current debug frame (or C-c d e for point).")
    (:action "Hot-swap / Reload classes"
     :intellij "Ctrl+F9 (while debugging)" :eclipse "Save (debugging)" :key "C-c h r" :command hell-crucible-reload
     :category "Build & Debug" :doc "The Crucible: hot-swap changed bytecode into the debugged JVM.")

    ;; Git and Tools
    (:action "Git status / Commit / Push"
     :intellij "Alt+9, Ctrl+K, Ctrl+Shift+K" :eclipse "Git Staging" :key "C-x g" :command magit-status
     :category "Git & Tools" :doc "Magit status buffer: c c commit, P p push, F p pull, l l log.")
    (:action "Git file blame / history"
     :intellij "Annotate / Show History" :eclipse "Show Annotations" :key "C-c M-g" :command magit-file-dispatch
     :category "Git & Tools" :doc "Magit file actions: b for blame, l for file log.")
    (:action "Open terminal in project"
     :intellij "Alt+F12" :eclipse "—" :key "C-x p s" :command project-shell
     :category "Git & Tools" :doc "Open shell buffer in project root (or C-x p e for eshell).")
    (:action "Database connections (JDBC)"
     :intellij "Database Tool Window" :eclipse "DTP" :key "C-c o d" :command hell-db
     :category "Git & Tools" :doc "Connect to database over JDBC, execute SQL, and inspect tables.")
    (:action "Docker / Containers"
     :intellij "Services / Docker" :eclipse "Docker Tooling" :key "C-c o d" :command docker
     :category "Git & Tools" :doc "Inspect containers, images, volumes, and logs.")
    (:action "Kubernetes clusters"
     :intellij "Services / Kubernetes" :eclipse "—" :key "C-c o k" :command kubel
     :category "Git & Tools" :doc "Inspect pods, logs, deployments, and port-forwards.")
    (:action "Settings / Preferences"
     :intellij "Ctrl+Alt+S" :eclipse "Preferences" :key "C-x d" :command dired
     :category "Editor & UI" :doc "Dired on your configuration directory: C-x d, then ~/.config/hell-emacs/."))
  "Complete registry of IntelliJ IDEA / Eclipse actions and their Hell Emacs key equivalents.")

(defun hell-intellij--format-candidate (entry max-action max-intellij max-key)
  "Format an ENTRY with aligned columns."
  (let* ((action (or (plist-get entry :action) ""))
         (intellij (or (plist-get entry :intellij) ""))
         (key (or (plist-get entry :key) ""))
         (category (or (plist-get entry :category) ""))
         (pad-action (make-string (max 0 (- max-action (string-width action))) ?\s))
         (pad-intellij (make-string (max 0 (- max-intellij (string-width intellij))) ?\s))
         (pad-key (make-string (max 0 (- max-key (string-width key))) ?\s)))
    (format "%s%s  │ %s%s │ %s%s │ %s"
            action pad-action
            intellij pad-intellij
            key pad-key
            category)))

;;;###autoload
(defun hell-where-is-intellij (&optional query)
  "Look up any IntelliJ IDEA or Eclipse key/action and discover its Hell Emacs shortcut.
When invoked interactively, opens a searchable fuzzy prompt.
Selecting a candidate displays full documentation and offers to run the command."
  (interactive)
  (let* ((max-action 38)
         (max-intellij 28)
         (max-key 20)
         (table
          (mapcar (lambda (entry)
                    (cons (hell-intellij--format-candidate entry max-action max-intellij max-key)
                          entry))
                  hell-intellij-actions))
         (prompt (if query (format "Hell Emacs key for [%s]: " query) "Where is IntelliJ action / key: "))
         (choice (completing-read prompt (mapcar #'car table) nil t query))
         (entry (cdr (assoc choice table))))
    (when entry
      (let* ((action (plist-get entry :action))
             (intellij (plist-get entry :intellij))
             (eclipse (plist-get entry :eclipse))
             (key (plist-get entry :key))
             (cmd (plist-get entry :command))
             (doc (plist-get entry :doc))
             (category (plist-get entry :category))
             (msg (format "[%s] %s\n  • Hell Emacs Key:   %s\n  • Command:        %s\n  • IntelliJ Key:   %s\n  • Eclipse Key:    %s\n\n%s"
                          category action (propertize key 'face 'highlight) cmd intellij eclipse doc)))
        (message "%s" msg)
        (when (and (fboundp cmd)
                   (y-or-n-p (format "Run `%s' now? " cmd)))
          (call-interactively cmd))))))


(hell-provide 'hell-lib 'intellij)

;;; intellij.el ends here
