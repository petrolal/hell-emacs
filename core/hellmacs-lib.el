;;; hellmacs-lib.el --- Hellmacs standard library -*- lexical-binding: t; -*-

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

;; Small macros and helpers every other Hellmacs file (core and
;; modules alike) may use. Modeled on Doom Emacs' `doom-lib.el', cut
;; down to what Hellmacs actually needs.
;;
;; Naming: the `!'-suffixed macros (`after!', `add-hook!', ...) are
;; user-facing sugar and keep Doom's unprefixed names so config reads
;; the same as in Doom. Everything else is `hellmacs-' prefixed.
;;
;; This file must not depend on any third-party package: it is loaded
;; before the package manager is bootstrapped.

;;; Code:

(require 'cl-lib)
(require 'seq)
(eval-when-compile (require 'subr-x))

(defconst hellmacs-version "0.9.0"
  "Hellmacs' version, MAJOR.MINOR.PATCH (Semantic Versioning).
A release is the git tag vMAJOR.MINOR.PATCH; CHANGELOG.md says what each
one changed, and docs/releases.md which Emacs versions and platforms it
supports. Between releases, main carries the next version's number.")

(defvar hellmacs-init-time nil
  "Seconds (a float) Hellmacs took to start; nil while still starting.
Set by `hellmacs-finalize' in `hellmacs-core'.")

;;; Logging ----------------------------------------------------------------

(defmacro hellmacs-log (format-string &rest args)
  "Log FORMAT-STRING with ARGS to *Messages*, but only in debug mode.
Debug mode is `init-file-debug' (--debug-init or the DEBUG envvar)."
  `(when init-file-debug
     (let ((inhibit-message (active-minibuffer-window)))
       (message ,(concat "hellmacs: " format-string) ,@args))))

;;; Context ----------------------------------------------------------------
;;
;; What kind of session is running, so code can branch on it cheaply
;; (e.g. skip UI work in the CLI, or re-run setup on `reload').

(defconst hellmacs-contexts
  '(startup   ; Emacs is still booting
    emacs     ; an interactive session
    cli       ; a non-interactive (batch) session
    reload    ; `hellmacs-reload' is re-running the config
    module)   ; a module file is being loaded
  "Valid values for `hellmacs-context'.")

(defvar hellmacs-context '(t)
  "A list of symbols (from `hellmacs-contexts') describing the session.
Use `hellmacs-context-p' to test it and `with-hellmacs-context' to
bind it temporarily; don't `setq' it directly.")

(defun hellmacs-context-p (context)
  "Return non-nil if CONTEXT (a symbol) is active."
  (memq context hellmacs-context))

(defun hellmacs-context-push (context)
  "Activate CONTEXT. Return non-nil if it wasn't already active."
  (unless (memq context hellmacs-contexts)
    (signal 'wrong-type-argument (list 'hellmacs-contexts context)))
  (unless (memq context hellmacs-context)
    (push context hellmacs-context)))

(defun hellmacs-context-pop (context)
  "Deactivate CONTEXT.
Non-destructive: inside `with-hellmacs-context' the list shares its
tail with the outer value, which must stay as it was."
  (setq hellmacs-context (remq context hellmacs-context)))

(defmacro with-hellmacs-context (contexts &rest body)
  "Evaluate BODY with CONTEXTS (a symbol or list) also active."
  (declare (indent 1))
  `(let ((hellmacs-context (append (ensure-list ,contexts) hellmacs-context)))
     ,@body))

;;; Hooks: running -----------------------------------------------------------

(defun hellmacs-run-hooks (&rest hooks)
  "Run HOOKS, isolating errors per function.
Unlike `run-hooks', one broken function warns and is skipped instead of
aborting every function after it."
  (dolist (hook hooks)
    (run-hook-wrapped
     hook
     (lambda (fn)
       (condition-case-unless-debug err
           (funcall fn)
         (error
          (display-warning
           'hellmacs (format "Error in `%s' from `%s': %s"
                             fn hook (error-message-string err))
           :error)))
       nil))))

(defun hellmacs-run-hook-on (hook-var trigger-hooks &optional predicate)
  "Run HOOK-VAR once, the first time any of TRIGGER-HOOKS fires.
Waits until startup is finished (see `hellmacs-init-time'), and until
PREDICATE (if given) returns non-nil. Afterwards HOOK-VAR is cleared, so
functions added to it later never run."
  (let ((fn (intern (format "hellmacs--run-%s-h" hook-var))))
    (defalias fn
      (lambda (&rest _)
        (when (and hellmacs-init-time
                   ;; The daemon's initial, invisible frame doesn't count.
                   (not (and (daemonp) (not (frame-parameter nil 'client))))
                   (or (null predicate) (funcall predicate)))
          (dolist (hook trigger-hooks)
            (remove-hook hook fn))
          (hellmacs-run-hooks hook-var)
          (set hook-var nil))))
    (dolist (hook trigger-hooks)
      (add-hook hook fn -90))))

;;; Hooks: defining --------------------------------------------------------

(defun hellmacs--resolve-hooks (hooks)
  "Normalize HOOKS (as given to `add-hook!') into a list of hook symbols.
A quoted symbol or list is used as-is; an unquoted mode name `foo-mode'
becomes `foo-mode-hook'."
  (if (memq (car-safe hooks) '(quote function))
      (ensure-list (cadr hooks))
    (mapcar (lambda (h) (intern (format "%s-hook" h)))
            (ensure-list hooks))))

(defmacro add-hook! (hooks &rest rest)
  "Add functions (or a body of forms) to HOOKS.

HOOKS is a quoted hook or list of hooks, or an unquoted mode or list of
modes (`-hook' is appended to each).

REST may start with keyword options:
  :append     add to the end of the hook (depth 90)
  :local      add buffer-locally
  :depth N    explicit depth
  :remove     remove instead of add

followed by either:
  - quoted or sharp-quoted function symbols: #\\='foo #\\='bar
  - `defun' forms: each is defined and added
  - arbitrary forms, wrapped in a lambda

  (add-hook! \\='prog-mode-hook #\\='display-line-numbers-mode)
  (add-hook! (text-mode prog-mode) (setq-local fill-column 100))
  (add-hook! \\='after-init-hook
    (defun my-thing-h () ...))"
  (declare (indent defun))
  (let ((hooks (hellmacs--resolve-hooks hooks))
        depth local remove fns defuns)
    (while (keywordp (car rest))
      (pcase (pop rest)
        (:append (setq depth 90))
        (:local  (setq local t))
        (:depth  (setq depth (pop rest)))
        (:remove (setq remove t))))
    (cond ((eq (car-safe (car rest)) 'defun)
           (setq defuns rest
                 fns (mapcar (lambda (d) `#',(cadr d)) rest)))
          ((and rest (seq-every-p (lambda (x) (memq (car-safe x) '(quote function))) rest))
           (setq fns rest))
          (rest
           (setq fns (list `(lambda (&rest _) ,@rest)))))
    `(progn
       ,@defuns
       ,@(cl-loop for hook in hooks
                  append (cl-loop for fn in fns
                                  collect (if remove
                                              `(remove-hook ',hook ,fn ,local)
                                            `(add-hook ',hook ,fn ,depth ,local))))
       nil)))

(defmacro remove-hook! (hooks &rest rest)
  "Remove functions from HOOKS. Takes the same arguments as `add-hook!'.
Lambdas can't be removed this way; use named functions (e.g. `defun'
forms) for anything you may want to remove later."
  (declare (indent defun))
  `(add-hook! ,hooks :remove ,@rest))

(defmacro setq-hook! (hooks &rest var-vals)
  "Set buffer-local VAR-VALS pairs whenever HOOKS run.
HOOKS is as in `add-hook!'. Each pair gets its own named hook function,
so re-evaluating the form replaces rather than duplicates it.

  (setq-hook! \\='java-mode-hook tab-width 4 fill-column 120)"
  (declare (indent 1))
  (let ((hooks (hellmacs--resolve-hooks hooks)))
    (macroexp-progn
     (cl-loop for hook in hooks
              append (cl-loop for (var val) on var-vals by #'cddr
                              for fn = (intern (format "hellmacs--setq-%s-for-%s-h" var hook))
                              collect `(defalias ',fn
                                         (lambda (&rest _) (setq-local ,var ,val))
                                         ,(format "Set `%s' locally in `%s'." var hook))
                              collect `(add-hook ',hook #',fn -90))))))

;;; Loading ----------------------------------------------------------------

(defmacro after! (features &rest body)
  "Evaluate BODY once FEATURES are loaded (immediately if they already are).
FEATURES is a feature symbol, or a list of them, all of which must be
loaded. Unlike `with-eval-after-load', the feature name is not quoted.

  (after! consult ...)
  (after! (consult vertico) ...)"
  (declare (indent defun) (debug t))
  (if (symbolp features)
      `(with-eval-after-load ',features ,@body)
    (let ((features (if (eq (car features) :and) (cdr features) features)))
      (if (cdr features)
          `(after! ,(car features) (after! ,(cdr features) ,@body))
        `(after! ,(car features) ,@body)))))

;;; Definers -----------------------------------------------------------------

(defmacro defadvice! (symbol arglist &optional docstring &rest body)
  "Define an advice called SYMBOL and add it to one or more functions.

  (defadvice! my-quiet-save-a (fn &rest args)
    \"Save without messages.\"
    :around #\\='save-buffer
    (let ((inhibit-message t)) (apply fn args)))

After the docstring come one or more HOW TARGET pairs, where HOW is an
`advice-add' combinator (:around, :before, :override, ...) and TARGET a
function or quoted list of functions; then the body."
  (declare (indent defun) (doc-string 3))
  (unless (stringp docstring)
    (push docstring body)
    (setq docstring nil))
  (let (where)
    (while (keywordp (car body))
      (push (cons (pop body) (pop body)) where))
    `(progn
       (defun ,symbol ,arglist ,docstring ,@body)
       ,@(cl-loop for (how . targets) in (nreverse where)
                  append (cl-loop for target in (ensure-list (eval targets t))
                                  collect `(advice-add #',target ,how #',symbol))))))

;;; Closures -----------------------------------------------------------------

(defmacro cmd! (&rest body)
  "Return an interactive command that evaluates BODY. Handy for keybindings.

  (keymap-set global-map \"C-c x\" (cmd! (message \"hi\")))"
  (declare (indent defun))
  `(lambda (&rest _) (interactive) ,@body))

;;; Files --------------------------------------------------------------------

(defun hellmacs-file-sha256 (file)
  "Return the SHA-256 of FILE's bytes, as a hex string.
Through sha256sum or shasum when there's one, which streams the file:
downloads and bundles run to hundreds of megabytes. Else read into Emacs."
  (let ((file (expand-file-name file)))
    (or (when-let* ((command (cond ((executable-find "sha256sum") '("sha256sum"))
                                   ((executable-find "shasum") '("shasum" "-a" "256")))))
          (with-temp-buffer
            (and (eql 0 (ignore-errors (apply #'call-process (car command) nil t nil
                                              (append (cdr command) (list "--" file)))))
                 (progn (goto-char (point-min)) (looking-at "[0-9a-f]\\{64\\}\\_>"))
                 (match-string 0))))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally file)
          (secure-hash 'sha256 (current-buffer))))))

(defun hellmacs-marker-current-p (marker value)
  "Non-nil if the file MARKER exists and holds VALUE (whitespace aside).
Pinned installs write the pin they were made from to a marker file."
  (and (file-exists-p marker)
       (equal (with-temp-buffer (insert-file-contents marker) (string-trim (buffer-string)))
              value)))

(defun hellmacs-marker-write (marker value)
  "Record VALUE in the file MARKER, for `hellmacs-marker-current-p'."
  (with-temp-file marker (insert value "\n")))

(defun hellmacs-platform ()
  "This machine as release assets name it: \"linux-x86_64\", \"darwin-aarch64\"...
nil on an operating system no pinned download is made for."
  (when-let* ((os (pcase system-type
                    ('gnu/linux "linux") ('darwin "darwin") ('windows-nt "windows"))))
    (let ((cpu (car (split-string system-configuration "-"))))
      (concat os "-" (if (member cpu '("arm64" "aarch64")) "aarch64" cpu)))))

(defun hellmacs-npm-installed-p (lock-dir dir)
  "Non-nil if DIR holds the npm packages LOCK-DIR's package-lock.json pins.
`hellmacs-sync-npm-install' records the lockfile's SHA-256 in DIR."
  (let ((lock (expand-file-name "package-lock.json" lock-dir)))
    (and (file-exists-p lock)
         (file-directory-p (expand-file-name "node_modules" dir))
         (hellmacs-marker-current-p (expand-file-name ".hellmacs-lock-sha256" dir)
                                    (hellmacs-file-sha256 lock)))))

(defun hellmacs-file-pinned-p (file sha256)
  "Non-nil if FILE exists and its bytes have the SHA-256 SHA256."
  (and (file-exists-p file)
       (equal (hellmacs-file-sha256 file) sha256)))

;;; Build output -----------------------------------------------------------

(defconst hellmacs-build-files
  '("pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts")
  "Files at the root of a Maven or Gradle build.")

(defconst hellmacs-ignored-dirs '(".git" ".hg" ".svn" ".idea" "node_modules")
  "Directories no walk of a project's files looks in: VCS, IDE state, npm's.")

(defconst hellmacs-build-output-dirs '("build" "bin" "out" "target" ".gradle")
  "Directories Gradle, Maven, IntelliJ (out/) and JDTLS (bin/) write output to.")

(defun hellmacs-build-output-regexp (root)
  "Matches a directory of `hellmacs-build-output-dirs' in any module under ROOT.
But not one under a src/ directory: a package named build is source.
Only the part after ROOT counts, so a project kept under ~/src is too."
  (rx bos (literal (directory-file-name root))
      ;; Any directories but src.
      (* "/" (or (seq (not (any "s/")) (* (not "/")))
                 "s" (seq "s" (not (any "r/")) (* (not "/")))
                 "sr" (seq "sr" (not (any "c/")) (* (not "/")))
                 (seq "src" (+ (not "/")))))
      "/" (regexp (regexp-opt hellmacs-build-output-dirs)) eos))

;;; Components -------------------------------------------------------------

(defvar hellmacs-components nil
  "Everything a module downloads, as `hellmacs-component!' declared it.
A list of plists, newest first; read by `bin/hellmacs sbom' and `licenses'.")

(defmacro hellmacs-component! (&rest props)
  "Declare a pinned download this module installs, for the SBOM and license report.
Put it in the module's +paths.el, next to the pin. PROPS (evaluated):

  :name     what it is, as its project calls it (required)
  :version  the pinned release
  :license  its SPDX license expression, from its release; a
            LicenseRef-NAME for a license outside SPDX's list
  :url      where it's downloaded from
  :sha256   the download's pinned SHA-256
  :sha256s  every platform's pin, when :sha256 is this platform's
  :path     the file or directory it's installed as: it's only
            reported once that exists
  :npm      non-nil if :path is an npm install, whose package-lock.json
            lists what else it installed

A later declaration with the same :name replaces the earlier one."
  `(hellmacs-component-declare (list ,@props)))

(defun hellmacs-component-declare (props)
  "Record the component PROPS. See `hellmacs-component!'."
  (let ((name (or (plist-get props :name) (error "hellmacs-component!: no :name"))))
    (setq hellmacs-components
          (cons props (seq-remove (lambda (c) (equal (plist-get c :name) name))
                                  hellmacs-components)))))

;;; Announcements ----------------------------------------------------------

(defun hellmacs-announce (table event &rest args)
  "Show the message for EVENT in TABLE, formatted with ARGS; return the text.
TABLE is an alist of (EVENT FACE THEMED PLAIN); the PLAIN wording is used
when `hellmacs-ux-enable' is nil."
  (pcase-let ((`(,face ,themed ,plain) (alist-get event table)))
    (let ((text (apply #'format (if (bound-and-true-p hellmacs-ux-enable) themed plain) args)))
      (message "%s" (propertize text 'face face))
      text)))

;;; Reloading code ---------------------------------------------------------

(defvar-local hellmacs-reload-function nil
  "Function that reloads the current buffer's code into the running program.
`C-c h r' (the Crucible) calls it. Each language module sets it in its
buffers: Java hot-swaps into a debug session, Clojure loads into its REPL.")

;;; Display ----------------------------------------------------------------

(defun hellmacs-nerd-font-p (&optional frame)
  "Non-nil if FRAME (default: the selected one) can draw Nerd Font icons.
Only a graphical frame can say: it needs some font with the Nerd Font
glyphs (checked on nf-fa-folder, which every Nerd Font has), not only
the \"Symbols Nerd Font Mono\" nerd-icons asks for by name. A terminal
can't tell which font it uses, so this is nil there; the `:ui'
modules have their own options to force icons in a terminal.
The answer is kept per frame (the mode-line asks on every window
switch), until a font changes."
  (let ((frame (or frame (selected-frame))))
    (and (display-graphic-p frame)
         (let ((known (frame-parameter frame 'hellmacs--nerd-font)))
           (unless known
             (setq known (if (with-selected-frame frame (char-displayable-p #xf07b)) 'yes 'no))
             (set-frame-parameter frame 'hellmacs--nerd-font known))
           (eq known 'yes)))))

(defun hellmacs--forget-nerd-font-h ()
  "A font changed: find out again, per frame, whether it draws icons."
  (dolist (frame (frame-list))
    (set-frame-parameter frame 'hellmacs--nerd-font nil)))
(add-hook 'after-setting-font-hook #'hellmacs--forget-nerd-font-h)

(defun hellmacs-icons-p (tty-icons &optional frame)
  "Non-nil if FRAME (default: the selected one) should draw icons.
A graphical frame needs a Nerd Font (`hellmacs-nerd-font-p'); a
terminal draws them only if TTY-ICONS, the caller's option, is non-nil."
  (if (display-graphic-p frame)
      (hellmacs-nerd-font-p frame)
    tty-icons))

(provide 'hellmacs-lib)
;;; hellmacs-lib.el ends here
