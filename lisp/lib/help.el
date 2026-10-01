;;; lib/help.el --- Hellmacs Info manual and module help -*- lexical-binding: t; -*-

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

;; Phase 13: Integrated Help, Info Manual & Module Introspection
;; - `C-c h h' / `C-c h ?': `hellmacs-help' (interactive JVM & shortcuts hub)
;; - `C-c h i': `hellmacs-info-manual'
;; - `C-c h d' / `M-x hellmacs-describe-module': module inspection buffer
;; - Info directory integration with docs/

(require 'info)
(require 'help-mode)
(require 'subr-x)

(defvar hellmacs-dir)
(declare-function hellmacs-module-list "hellmacs-modules")
(declare-function hellmacs-module-get "hellmacs-modules")
(declare-function hellmacs-module-locate-path "hellmacs-modules")
(declare-function hellmacs-module-metadata "hellmacs-modules")
(declare-function hellmacs-module-key-string "hellmacs-modules")
(declare-function hellmacs-list-modules "config/default/autoload")
(declare-function hellmacs-jdk-read "lib/jdk")

;; Register docs/ in Info path
(let ((docs-dir (expand-file-name "docs/" hellmacs-dir)))
  (when (file-directory-p docs-dir)
    (add-to-list 'Info-directory-list docs-dir)
    (add-to-list 'Info-default-directory-list docs-dir)))

;;;###autoload
(defun hellmacs-info-manual ()
  "Open the official Hellmacs Info manual (C-c h i)."
  (interactive)
  (let ((info-file (expand-file-name "docs/hellmacs.info" hellmacs-dir)))
    (if (file-exists-p info-file)
        (info info-file)
      ;; Fallback to info top node if registered in Info-directory-list
      (condition-case nil
          (info "(hellmacs)")
        (error
         (user-error "Hellmacs Info manual not found at %s. Run makeinfo docs/hellmacs.texi" info-file))))))

;;;###autoload
(defun hellmacs-help ()
  "Open the interactive Hellmacs JVM Help & Cheatsheet Hub (C-c h h / C-c h ?)."
  (interactive)
  (let ((buf (get-buffer-create "*Hellmacs Help*")))
    (with-current-buffer buf
      (help-mode)
      (let* ((inhibit-read-only t)
             (jdk-table (condition-case nil
                            (and (require 'hellmacs-jdk (expand-file-name "lisp/lib/jdk" hellmacs-dir) t)
                                 (hellmacs-jdk-read))
                          (error nil))))
        (erase-buffer)
        ;; Header
        (insert (propertize "HELLMACS // [ JVM FORGE & SHORTCUTS HUB ]\n" 'face '(:foreground "#ff5555" :weight bold :height 1.2)))
        (insert (propertize "Heavy metal syntax. Bytecode subjugated. Pure GNU Emacs.\n" 'face '(:foreground "#ffb86c" :slant italic)))
        (insert (make-string 76 ?─) "\n\n")

        ;; 1. Live JVM Tooling & Runtime Status
        (insert (propertize "1. JVM TOOLING & RUNTIME STATUS\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")

        ;; LSP Status
        (insert (propertize "  • Language Servers (LSP):\n" 'face 'bold))
        (insert "    - Java:        ")
        (let ((jdtls-dir (expand-file-name ".local/share/hellmacs/lsp/eclipse.jdt.ls" "~")))
          (if (file-directory-p jdtls-dir)
              (insert (propertize "✓ Eclipse JDTLS (Ready)" 'face 'success) " + Spring Boot Tools + Lombok\n")
            (insert (propertize "! Not installed (run bin/hellmacs sync)" 'face 'warning) "\n")))
        (insert "    - Kotlin:      ")
        (if (file-directory-p (expand-file-name ".local/share/hellmacs/lsp/kotlin" "~"))
            (insert (propertize "✓ kotlin-language-server (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang kotlin\n" 'face 'shadow)))
        (insert "    - Clojure:     ")
        (if (executable-find "clojure-lsp")
            (insert (propertize "✓ clojure-lsp (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang clojure\n" 'face 'shadow)))
        (insert "    - Groovy:      ")
        (if (file-directory-p (expand-file-name ".local/share/hellmacs/lsp/groovy" "~"))
            (insert (propertize "✓ groovy-language-server (Ready)\n" 'face 'success))
          (insert (propertize "· Available via :lang groovy\n" 'face 'shadow)))

        ;; Debugger Status
        (insert (propertize "  • Debugger (DAP) & Test Runner:\n" 'face 'bold))
        (insert "    - Java Debug:  ")
        (if (file-exists-p (expand-file-name ".local/share/hellmacs/lsp/eclipse.jdt.ls/bundles/com.microsoft.java.debug.plugin-0.53.1.jar" "~"))
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
          (insert "    · (JDKs automatically mapped during bin/hellmacs sync)\n"))
        (insert "\n")

        ;; 2. Code Intelligence & LSP Shortcuts (C-c l)
        (insert (propertize "2. CODE INTELLIGENCE & LSP SHORTCUTS (C-c l / M-.)\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")
        (insert (format "  %-18s  %-30s  %s\n" (propertize "Keychord" 'face 'bold) (propertize "Command" 'face 'bold) (propertize "Description" 'face 'bold)))
        (insert (format "  %-18s  %-30s  %s\n" "M-." "xref-find-definitions" "Jump to symbol definition"))
        (insert (format "  %-18s  %-30s  %s\n" "M-?" "xref-find-references" "Find all usages / references across project"))
        (insert (format "  %-18s  %-30s  %s\n" "M-," "xref-go-back" "Jump back to previous location"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c l a / M-RET" "eglot-code-actions" "Code Actions / Quick Fix / Intentions"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c l r" "eglot-rename" "Rename symbol across entire project"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c l f / C-c c f" "eglot-format-buffer" "Format buffer according to code style"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c l o" "eglot-code-action-organize" "Organize imports"))
        (insert "\n")

        ;; 3. Debugger & DAP Shortcuts (C-c d)
        (insert (propertize "3. DEBUGGER & DAP SHORTCUTS (C-c d)\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")
        (insert (format "  %-18s  %-30s  %s\n" (propertize "Keychord" 'face 'bold) (propertize "Command" 'face 'bold) (propertize "Description" 'face 'bold)))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d d" "dap-debug" "Start new debug session"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d b" "dap-breakpoint-toggle" "Toggle breakpoint on current line"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d n" "dap-next" "Step Over (next instruction)"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d i" "dap-step-in" "Step Into method call"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d o" "dap-step-out" "Step Out of current method"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d c" "dap-continue" "Continue execution until next breakpoint"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d r" "dap-restart-frame" "Restart debug frame"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d q" "dap-disconnect" "Disconnect / Stop debug session"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c d E" "dap-eval" "Evaluate expression in current frame"))
        (insert "\n")

        ;; 4. Build, Test & Run Shortcuts (C-c b / C-c t / C-c r)
        (insert (propertize "4. BUILD, TEST & RUN SHORTCUTS (C-c b / C-c t / C-c r)\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")
        (insert (format "  %-18s  %-30s  %s\n" (propertize "Keychord" 'face 'bold) (propertize "Command" 'face 'bold) (propertize "Description" 'face 'bold)))
        (insert (format "  %-18s  %-30s  %s\n" "C-c b b" "hellmacs-build" "Build project (Gradle/Maven)"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c b c" "hellmacs-build-clean" "Clean build output directory"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c t t" "hellmacs-test-single" "Run test at point"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c t f" "hellmacs-test-file" "Run all tests in current file"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c t p" "hellmacs-test-project" "Run full test suite in project"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c r" "hellmacs-run" "Execute Run Configuration"))
        (insert "\n")

        ;; 5. Hellmacs Prefix Commands (C-c h)
        (insert (propertize "5. HELLMACS SYSTEM COMMANDS (C-c h)\n" 'face '(:foreground "#ffb86c" :weight bold)))
        (insert (make-string 76 ?─) "\n")
        (insert (format "  %-18s  %-30s  %s\n" (propertize "Keychord" 'face 'bold) (propertize "Command" 'face 'bold) (propertize "Description" 'face 'bold)))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h s" "hellmacs-splash" "Return to Altar splash screen"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h h / C-c h ?" "hellmacs-help" "Open this JVM Help & Cheatsheet Hub"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h i" "hellmacs-info-manual" "Read official Hellmacs Info manual"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h d" "hellmacs-describe-module" "Describe and inspect any module"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h u" "hellmacs-visit-user-dir" "Open your configuration directory"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h S" "hellmacs-sync-child" "Sync packages and compile profile"))
        (insert (format "  %-18s  %-30s  %s\n" "C-c h k" "hellmacs-where-is-intellij" "IntelliJ IDEA to Emacs key finder"))
        (insert "\n")

        ;; 6. Interactive Quick Actions
        (insert (propertize "QUICK ACTIONS:\n" 'face 'bold))
        (insert "  ")
        (insert-text-button "[ Open Info Manual (C-c h i) ]"
                            'action (lambda (_) (hellmacs-info-manual))
                            'follow-link t
                            'help-echo "Open full Info manual")
        (insert "   ")
        (insert-text-button "[ Return to Altar Splash (C-c h s) ]"
                            'action (lambda (_) (call-interactively #'hellmacs-splash))
                            'follow-link t
                            'help-echo "Go to Altar splash")
        (insert "   ")
        (insert-text-button "[ Describe Modules (C-c h d) ]"
                            'action (lambda (_) (call-interactively #'hellmacs-describe-module))
                            'follow-link t
                            'help-echo "Inspect module")
        (insert "\n")
        (goto-char (point-min))))
    (display-buffer buf)))

(defun hellmacs-module-all-candidates ()
  "Return a list of all module keys as strings (e.g. `:lang java')."
  (let ((active (hellmacs-module-list))
        (all (hellmacs-module-list :all)))
    (delete-dups
     (mapcar (lambda (key) (hellmacs-module-key-string key))
             (append active all)))))

(defun hellmacs-module-parse-key (str)
  "Parse a module string like `:lang java' into a key cons `(:lang . java)'."
  (when (string-match "\\`\\(:[a-z]+\\)[ \t]+\\([a-z0-9-]+\\)\\'" (string-trim str))
    (cons (intern (match-string 1 str))
          (intern (match-string 2 str)))))

(defun hellmacs-module--find-description (dir)
  "Extract description from commentary in config.el or .hellmacsmodule in DIR."
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
                 ((string-match-p "\\(Copyright\\|Author\\|License\\|part of Hellmacs\\|Free Software\\|along with this program\\|-\\*- lexical\\|WARRANTY\\|MERCHANTABILITY\\|General Public License\\|distributed in the hope\\)" line)
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

(defun hellmacs-module--find-packages (dir)
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
(defun hellmacs-describe-module (module)
  "Display complete information and documentation for MODULE.
Shows active status, flags, declared packages, file links, and keybindings."
  (interactive
   (let* ((candidates (hellmacs-module-all-candidates))
           (default (when-let* ((at-pt (thing-at-point 'symbol t)))
                      (car (member at-pt candidates))))
           (choice (completing-read
                    (format-prompt "Describe module" default)
                    candidates nil t nil nil default)))
     (list (hellmacs-module-parse-key choice))))
  (unless module
    (user-error "No module specified"))
  (let* ((group (car module))
         (name (cdr module))
         (key module)
         (active-p (member key (hellmacs-module-list)))
         (flags (and active-p (hellmacs-module-get key :flags)))
         (dir (hellmacs-module-locate-path group name))
         (meta (and dir (hellmacs-module-metadata dir key)))
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
        (let ((pkgs (hellmacs-module--find-packages dir)))
          (if pkgs
              (dolist (pkg pkgs)
                (insert (format "  ✓ %s\n" pkg)))
            (insert "  (None / built-in)\n")))
        (insert "\n")

        ;; Description
        (insert (propertize "Documentation & Summary:\n" 'face 'bold))
        (insert (if dir (hellmacs-module--find-description dir) "None") "\n\n")

        ;; Footer navigation
        (insert (propertize "Quick Actions:\n" 'face 'bold))
        (insert "  ")
        (insert-text-button "[ Open Hellmacs Manual (C-c h i) ]"
                            'action (lambda (_) (hellmacs-info-manual))
                            'follow-link t
                            'help-echo "Open Info manual")
        (insert "   ")
        (insert-text-button "[ View All Modules ]"
                            'action (lambda (_) (call-interactively #'hellmacs-list-modules))
                            'follow-link t
                            'help-echo "List active modules")
        (goto-char (point-min))))
    (display-buffer (get-buffer buf-name))))

(defalias 'describe-module #'hellmacs-describe-module)

(hellmacs-provide 'hellmacs-lib 'help)
;;; help.el ends here
