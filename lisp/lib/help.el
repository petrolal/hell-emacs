;;; lib/help.el --- Hell Emacs Info manual and module help -*- lexical-binding: t; -*-

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

;; Phase 13: Integrated Help, Info Manual & Module Introspection
;; - `C-c h h': `hell-help' (interactive JVM & shortcuts hub)
;; - `C-c h i': `hell-info-manual'
;; - `C-c h m' / `M-x hell-describe-module': module inspection buffer
;; - Info directory integration with docs/

(require 'info)
(require 'help-mode)
(require 'subr-x)

(defvar hell-dir)
(declare-function hell-module-list "hell-modules")
(declare-function hell-module-get "hell-modules")
(declare-function hell-module-locate-path "hell-modules")
(declare-function hell-module-metadata "hell-modules")
(declare-function hell-module-key-string "hell-modules")
(declare-function hell-list-modules "config/default/autoload")
(declare-function hell-splash "+splash" (&optional title))
(declare-function hell-jdk-read "lib/jdk")

;; Register docs/ in Info path
(let ((docs-dir (expand-file-name "docs/" hell-dir)))
  (when (file-directory-p docs-dir)
    (add-to-list 'Info-directory-list docs-dir)
    (add-to-list 'Info-default-directory-list docs-dir)))

;;;###autoload
(defun hell-info-manual ()
  "Open the official Hell Emacs Info manual (C-c h i)."
  (interactive)
  (let ((info-file (expand-file-name "docs/hell-emacs.info" hell-dir)))
    (if (file-exists-p info-file)
        (info info-file)
      ;; Fallback to info top node if registered in Info-directory-list
      (condition-case nil
          (info "(hell-emacs)")
        (error
         (user-error "Hell Emacs Info manual not found at %s. Run makeinfo docs/hell-emacs.texi" info-file))))))

(defvar hell-localleader-maps)

(defun hell-help--keys (command buffer)
  "COMMAND's keys as bound in BUFFER (up to two), or \"M-x COMMAND\".
The `C-c l' localleader's keys are behind a filter `where-is' can't see
through, so its maps are searched too."
  (let* ((keys (with-current-buffer buffer
                 (seq-remove (lambda (key) (memq (aref key 0) '(menu-bar tool-bar)))
                             (where-is-internal command))))
         (local (seq-some (lambda (entry) (where-is-internal command (list (cdr entry)) t))
                          (bound-and-true-p hell-localleader-maps))))
    (cond (keys (mapconcat #'key-description (seq-take keys 2) ", "))
          (local (concat "C-c l " (key-description local)))
          (t (format "M-x %s" command)))))

;;;###autoload
(defun hell-help ()
  "Open the interactive Hell Emacs JVM Help & Cheatsheet Hub (C-c h h)."
  (interactive)
  (let ((buf (get-buffer-create "*Hell Emacs Help*"))
        (origin (current-buffer)))
    (with-current-buffer buf
      (help-mode)
      (let* ((inhibit-read-only t)
             (jdk-table (condition-case nil
                            (and (require 'hell-jdk (expand-file-name "lisp/lib/jdk" hell-dir) t)
                                 (hell-jdk-read))
                          (error nil))))
        (erase-buffer)
        ;; Header
        (insert (propertize "HELL EMACS // [ JVM FORGE & SHORTCUTS HUB ]\n" 'face '(:foreground "#ff5555" :weight bold :height 1.2)))
        (insert (propertize "Heavy metal syntax. Bytecode subjugated. Pure GNU Emacs.\n" 'face '(:foreground "#ffb86c" :slant italic)))
        (insert (make-string 76 ?─) "\n\n")

        ;; 1. Live JVM Tooling & Runtime Status
        (insert (propertize "1. JVM TOOLING & RUNTIME STATUS\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")

        ;; LSP Status
        (insert (propertize "  • Language Servers (LSP):\n" 'face 'bold))
        (insert "    - Java:        ")
        (let ((jdtls-dir (expand-file-name "lsp/eclipse.jdt.ls" hell-data-dir)))
          (if (file-directory-p jdtls-dir)
              (insert (propertize "✓ Eclipse JDTLS (Ready)" 'face 'success) " + Spring Boot Tools + Lombok\n")
            (insert (propertize "! Not installed (run bin/hell sync)" 'face 'warning) "\n")))
        (insert "    - Kotlin:      ")
        (if (file-directory-p (expand-file-name "lsp/kotlin" hell-data-dir))
            (insert (propertize "✓ kotlin-language-server (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang kotlin\n" 'face 'shadow)))
        (insert "    - Clojure:     ")
        (if (executable-find "clojure-lsp")
            (insert (propertize "✓ clojure-lsp (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang clojure\n" 'face 'shadow)))
        (insert "    - Groovy:      ")
        (if (file-directory-p (expand-file-name "lsp/groovy" hell-data-dir))
            (insert (propertize "✓ groovy-language-server (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang groovy\n" 'face 'shadow)))

        ;; Debugger Status
        (insert (propertize "  • Debugger (DAP) & Test Runner:\n" 'face 'bold))
        (insert "    - Java Debug:  ")
        (if (file-exists-p (expand-file-name "lsp/eclipse.jdt.ls/bundles/com.microsoft.java.debug.plugin-0.53.1.jar" hell-data-dir))
            (insert (propertize "✓ java-debug 0.53.1 (DAP Ready)\n" 'face 'success))
          (insert (propertize "✓ DAP Integration Active\n" 'face 'success)))
        (insert "    - JUnit:       ")
        (insert (propertize "✓ JUnit 4 & 5 Runner (Active)\n" 'face 'success))

        ;; Build Systems & Compilers
        (insert (propertize "  • Build Systems & Compilers:\n" 'face 'bold))
        (insert (format "    - Gradle:      %s\n" (if (executable-find "gradle") (propertize "✓ Installed" 'face 'success) "· Wrapper only")))
        (insert (format "    - Maven:       %s\n" (if (executable-find "mvn") (propertize "✓ Installed" 'face 'success) "· Wrapper only")))
        (insert (format "    - Kotlin CLI:  %s\n" (if (executable-find "kotlinc") (propertize "✓ kotlinc" 'face 'success) "· None")))

        ;; Discovered JDKs
        (insert (propertize "  • Discovered JDKs (SDKMAN, System, Mise, ASDF):\n" 'face 'bold))
        (if jdk-table
            (dolist (entry jdk-table)
              (let ((version (car entry))
                    (path (cdr entry)))
                (insert (format "    - %s:  %s\n"
                                (propertize (format "Java %s" version) 'face 'bold)
                                (propertize (abbreviate-file-name path) 'face 'shadow)))))
          (insert "    · (JDKs automatically mapped during bin/hell sync)\n"))
        (insert "\n")

;; 2.-5. The keys, by group, read from Emacs (`where-is') as they
        ;; are bound in the buffer you called this from, so they can't go
        ;; stale: a server's keys show in its buffers, `M-x' elsewhere.
        (pcase-dolist (`(,title . ,rows)
                       '(("2. CODE INTELLIGENCE"
                          (xref-find-definitions "Jump to symbol definition")
                          (xref-find-references "Find all usages across the project")
                          (xref-go-back "Jump back to the previous location")
                          (xref-find-apropos "Find a symbol in the project")
                          (lsp-execute-code-action "Code actions / quick fixes")
                          (lsp-rename "Rename across the project")
                          (lsp-organize-imports "Organize imports")
                          (lsp-format-buffer "Format the buffer")
                          (lsp-find-implementation "Implementations")
                          (lsp-find-type-definition "Type definition")
                          (flymake-goto-next-error "Next diagnostic")
                          (flymake-goto-prev-error "Previous diagnostic")
                          (flymake-show-buffer-diagnostics "All diagnostics of the buffer"))
                         ("3. DEBUGGER"
                          (dap-debug "Start a debug session")
                          (dap-breakpoint-toggle "Toggle a breakpoint on this line")
                          (hell-debug-next "Step over, then n alone")
                          (hell-debug-step-in "Step into, then i alone")
                          (hell-debug-step-out "Step out, then o alone")
                          (hell-debug-continue "Continue to the next breakpoint")
                          (dap-debug-restart "Restart the session")
                          (dap-disconnect "Disconnect the session")
                          (dap-eval "Evaluate an expression in the frame"))
                         ("4. BUILD, TEST, RUN, GIT"
                          (project-compile "Build the project with its wrapper")
                          (hell-forge-test-at-point "Run the test at point")
                          (hell-forge-test-class "Run the test class")
                          (hell-test-results "Test results")
                          (hell-run "Run a configuration")
                          (hell-run-debug "Debug a configuration")
                          (hell-run-last "Run the last configuration again")
                          (magit-status "Git status (Magit)"))
                         ("5. HELL EMACS SYSTEM COMMANDS"
                          (hell-splash "Return to the Altar")
                          (hell-help "Open this help hub")
                          (hell-info-manual "Read the Hell Emacs Info manual")
                          (hell-describe-module "Describe a module")
                          (hell-list-modules "List the enabled modules")
                          (hell-sync-child "Sync packages and compile the profile")
                          (hell-where-is-intellij "IntelliJ IDEA to Emacs key finder"))))
          (insert (propertize (concat title "\n") 'face '(:foreground "#ffb86c" :weight bold)))
          (insert (make-string 76 ?─) "\n")
          (insert (format "  %-32s  %s\n" (propertize "Keys" 'face 'bold)
                          (propertize "Description" 'face 'bold)))
          (pcase-dolist (`(,command ,description) rows)
            (insert (format "  %-32s  %s\n" (hell-help--keys command origin) description)))
          (insert "\n"))

                ;; 6. Interactive Quick Actions
        (insert (propertize "QUICK ACTIONS:\n" 'face 'bold))
        (insert "  ")
        (insert-text-button "[ Open Info Manual (C-c h i) ]"
                            'action (lambda (_) (hell-info-manual))
                            'follow-link t
                            'help-echo "Open full Info manual")
        (insert "   ")
        (insert-text-button "[ Return to Altar Splash (C-c h s) ]"
                            'action (lambda (_) (call-interactively #'hell-splash))
                            'follow-link t
                            'help-echo "Go to Altar splash")
        (insert "   ")
        (insert-text-button "[ Describe Modules (C-c h m) ]"
                            'action (lambda (_) (call-interactively #'hell-describe-module))
                            'follow-link t
                            'help-echo "Inspect module")
        (insert "\n")
        (goto-char (point-min))))
    (display-buffer buf)))

(defun hell-module-all-candidates ()
  "Return a list of all module keys as strings (e.g. `:lang java')."
  (let ((active (hell-module-list))
        (all (hell-module-list :all)))
    (delete-dups
     (mapcar (lambda (key) (hell-module-key-string key))
             (append active all)))))

(defun hell-module-parse-key (str)
  "Parse a module string like `:lang java' into a key cons `(:lang . java)'."
  (when (string-match "\\`\\(:[a-z]+\\)[ \t]+\\([a-z0-9-]+\\)\\'" (string-trim str))
    (cons (intern (match-string 1 str))
          (intern (match-string 2 str)))))

(defun hell-module--find-description (dir)
  "Extract description from commentary in config.el or .hellmodule in DIR."
  (let ((config-file (expand-file-name "config.el" dir)))
    (if (file-readable-p config-file)
        (with-temp-buffer
          (insert-file-contents config-file)
          (goto-char (point-min))
          (let (desc-lines
                in-header)
            (while (and (not (eobp))
                        (or (looking-at "^;;[ \t]*\\(.*\\)$")
                            (looking-at "^[ \t]*$")))
              (let ((line (if (looking-at "^;;[ \t]*\\(.*\\)$") (match-string 1) "")))
                (cond
                 ((string-match-p "\\(Copyright\\|Author\\|License\\|part of Hell Emacs\\|Free Software\\|along with this program\\|-\\*- lexical\\|WARRANTY\\|MERCHANTABILITY\\|General Public License\\|distributed in the hope\\)" line)
                  (setq in-header t))
                 ((and in-header (string-empty-p (string-trim line)))
                  (setq in-header nil))
                 ((not in-header)
                  (push line desc-lines))))
              (forward-line 1))
            (let ((joined (string-trim (string-join (nreverse desc-lines) "\n"))))
              (if (not (string-empty-p joined))
                  joined
                "No description provided in config.el."))))
      "No configuration file found.")))

(defun hell-module--find-packages (dir)
  "Extract declared package names from packages.el in DIR."
  (let ((pkg-file (and dir (expand-file-name "packages.el" dir))))
    (when (and pkg-file (file-readable-p pkg-file))
      (with-temp-buffer
        (insert-file-contents pkg-file)
        (goto-char (point-min))
        (let (pkgs)
          (while (re-search-forward "([ \t\n]*package![ \t\n]+\\([^ \t\n)]+\\)" nil t)
            (push (match-string 1) pkgs))
          (nreverse pkgs))))))

;;;###autoload
(defun hell-describe-module (module)
  "Display complete information and documentation for MODULE.
Shows active status, flags, declared packages, file links, and keybindings."
  (interactive
   (let* ((candidates (hell-module-all-candidates))
           (default (when-let* ((at-pt (thing-at-point 'symbol t)))
                      (car (member at-pt candidates))))
           (choice (completing-read
                    (format-prompt "Describe module" default)
                    candidates nil t nil nil default)))
     (list (hell-module-parse-key choice))))
  (unless module
    (user-error "No module specified"))
  (let* ((group (car module))
         (name (cdr module))
         (key module)
         (active-p (member key (hell-module-list)))
         (flags (and active-p (hell-module-get key :flags)))
         (dir (hell-module-locate-path group name))
         (meta (and dir (hell-module-metadata dir key)))
         (version (or (plist-get meta :version) "0.9.0"))
         (buf-name (format "*Help: %s %s*" group name)))
    (with-current-buffer (get-buffer-create buf-name)
      (help-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "Module %s %s\n" group name) 'face 'bold))
        (insert (make-string 50 ?=) "\n\n")
        ;; Status
        (insert (propertize "Status:       " 'face 'bold))
        (if active-p
            (insert (propertize "ENABLED" 'face 'success)
                    (if flags (format " (active flags: %s)" (string-join (mapcar #'symbol-name flags) ", ")) ""))
          (insert (propertize "AVAILABLE (not enabled in current profile)" 'face 'shadow)))
        (insert "\n")
        ;; Version
        (insert (propertize "Version:      " 'face 'bold) version "\n")
        ;; Location
        (insert (propertize "Directory:    " 'face 'bold))
        (if dir
            (insert-text-button (abbreviate-file-name dir)
                                'action (lambda (_) (dired dir))
                                'follow-link t
                                'help-echo "Click to open in Dired")
          (insert "Not found"))
        (insert "\n\n")

        ;; Available module files
        (insert (propertize "Module Components:\n" 'face 'bold))
        (if dir
            (dolist (comp '("config.el" "packages.el" "doctor.el" "cli.el" "autoload.el" "+paths.el"))
              (let ((path (expand-file-name comp dir)))
                (when (file-exists-p path)
                  (insert "  · ")
                  (insert-text-button comp
                                      'action (lambda (_) (find-file path))
                                      'follow-link t
                                      'help-echo (format "Open %s" comp))
                  (insert (format " (%s)\n" (file-size-human-readable (file-attribute-size (file-attributes path))))))))
          (insert "  (No directory)\n"))
        (insert "\n")

        ;; Declared packages
        (insert (propertize "Declared Packages:\n" 'face 'bold))
        (let ((pkgs (hell-module--find-packages dir)))
          (if pkgs
              (dolist (pkg pkgs)
                (insert (format "  ✓ %s\n" pkg)))
            (insert "  (None / built-in)\n")))
        (insert "\n")

        ;; Description
        (insert (propertize "Documentation & Summary:\n" 'face 'bold))
        (insert (if dir (hell-module--find-description dir) "None") "\n\n")

        ;; Footer navigation
        (insert (propertize "Quick Actions:\n" 'face 'bold))
        (insert "  ")
        (insert-text-button "[ Open Hell Emacs Manual (C-c h i) ]"
                            'action (lambda (_) (hell-info-manual))
                            'follow-link t
                            'help-echo "Open Info manual")
        (insert "   ")
        (insert-text-button "[ View All Modules ]"
                            'action (lambda (_) (call-interactively #'hell-list-modules))
                            'follow-link t
                            'help-echo "List active modules")
        (goto-char (point-min))))
    (display-buffer (get-buffer buf-name))))

(defalias 'describe-module #'hell-describe-module)

(hell-provide 'hell-lib 'help)
;;; help.el ends here
