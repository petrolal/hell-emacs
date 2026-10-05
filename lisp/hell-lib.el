;;; hell-lib.el --- Hell Emacs standard library -*- lexical-binding: t; -*-

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

;; Small macros and helpers every other Hell Emacs file (core and
;; modules alike) may use. Modeled on Doom Emacs' `doom-lib.el', cut
;; down to what Hell Emacs actually needs.
;;
;; Naming: the `!'-suffixed macros (`after!', `add-hook!', ...) are
;; user-facing sugar and keep Doom's unprefixed names so config reads
;; the same as in Doom. Everything else is `hell-' prefixed.
;;
;; This file must not depend on any third-party package: it is loaded
;; before the package manager is bootstrapped.

;;; Code:

(require 'cl-lib)
(require 'seq)
(eval-when-compile (require 'subr-x))

(defconst hell-version "1.0.0"
  "Hell Emacs' version, MAJOR.MINOR.PATCH (Semantic Versioning).
A release is the git tag vMAJOR.MINOR.PATCH; CHANGELOG.md says what each
one changed, and docs/guide.md (\"Staying up to date\") which Emacs versions
and platforms it supports.  Between releases, main carries the next
version's number.")

(defvar hell-init-time nil
  "Seconds (a float) Hell Emacs took to start; nil while still starting.
Set by `hell-finalize' in `hell-emacs'.")

;;; Library parts: hell-require ------------------------------------------
;;
;; As in Doom v3, lisp/lib/ (the library) and lisp/cli/ (the CLI's parts)
;; aren't on `load-path': their files have short names (lib/net.el,
;; cli/verify.el) and are loaded as parts of a feature, by
;; (hell-require \='hell-lib \='net), like `doom-require'. Each part
;; ends with (hell-provide \='hell-lib \='net).

(defvar hell--compiled-core-p) ; early-init.el
(defvar hell-compiled-dir)     ; early-init.el
(defvar hell-core-dir)         ; early-init.el

(defun hell--part-file (feature part)
  "The file of PART of FEATURE, without extension: lisp/<dir>/PART.
<dir> is FEATURE without its `hell-' prefix: `hell-lib' is lib/.
From the byte-compiled core when that's what this session loaded."
  (let* ((rel (format "%s/%s" (substring (symbol-name feature) (length "hell-")) part))
         (compiled (and (bound-and-true-p hell--compiled-core-p)
                        (expand-file-name rel (expand-file-name "lisp/" hell-compiled-dir)))))
    (if (and compiled (file-exists-p (concat compiled ".elc")))
        compiled
      (expand-file-name rel (if (boundp 'hell-core-dir)
                                hell-core-dir
                              ;; A child Emacs that loaded only hell-lib
                              ;; (see `hell-net-probe').
                              (file-name-directory (locate-library "hell-lib")))))))

(defun hell-provide (feature part)
  "Record that PART of FEATURE is loaded; each lib/ and cli/ file ends so."
  (put feature 'hell-parts (cons part (remq part (get feature 'hell-parts)))))

(defun hell-featurep (feature &optional part)
  "Non-nil if FEATURE is loaded, or with PART, if that part of it is."
  (if part
      (and (memq part (get feature 'hell-parts)) t)
    (featurep feature)))

(defun hell-require (feature &optional part noerror)
  "Load FEATURE, as `require' does; with PART, that part of it, once.
PART of `hell-lib' is lisp/lib/PART.el, of `hell-cli' lisp/cli/PART.el.
Returns FEATURE; with NOERROR, nil instead of an error if it's missing."
  (cond ((null part) (require feature nil noerror))
        ((hell-featurep feature part) feature)
        ((load (hell--part-file feature part) noerror 'nomessage)
         feature)))

;;; Dotfiles: .hell-emacs, .hellmodule, .hellprofile ---------------------------
;;
;; Doom v3's dotfiles (.doom, .doommodule, .doomprofile), read as
;; `doom-config' reads them: a version string (the Hell Emacs version the
;; file was written for), then an unquoted alist, whose ,forms are
;; evaluated. `hell-dotfile' is `doom-config' (the name
;; `hell-config-' already belongs to lisp/cli/config.el).

(defconst hell-dotfile-names
  '(project ".hell-emacs" module ".hellmodule" profile ".hellprofile")
  "Each type of dotfile, and its file name.")

(defun hell-dotfile-locate (type path &optional dir)
  "The nearest dotfile of TYPE at or above PATH, or nil.
With DIR, the directory it's in instead."
  (let* ((name (or (plist-get hell-dotfile-names type)
                   (error "No such kind of Hell Emacs dotfile: %S" type)))
         (found (locate-dominating-file path name)))
    (and found (if dir (file-name-as-directory found) (expand-file-name name found)))))

(defvar hell--dotfile-cache (make-hash-table :test #'equal)
  "Dotfiles read so far: path -> alist.")

(defun hell-dotfile--read (path)
  "The alist in dotfile PATH, its ,forms evaluated."
  (with-temp-buffer
    (insert-file-contents path)
    (let ((version (ignore-errors (read (current-buffer))))
          (alist (ignore-errors (read (current-buffer)))))
      (unless (stringp version)
        (error "%s: no version string before its alist" (abbreviate-file-name path)))
      (eval (list '\` alist) t))))

(defun hell-dotfile (keys &optional nocache)
  "Return what the nearest dotfile holds: its alist, or the value at KEYS.
KEYS is ([DIR] TYPE KEY...): the search starts at DIR (a string, else
`default-directory') for the dotfile of TYPE (see
`hell-dotfile-names'); each KEY picks a field of the alist, as in
\(hell-dotfile (list dir \\='module \\='depth)). Read once, unless NOCACHE."
  (let* ((keys (if (listp keys) (copy-sequence keys) (list keys)))
         (dir (if (stringp (car keys)) (pop keys) default-directory))
         (path (hell-dotfile-locate (pop keys) dir)))
    (when path
      (let ((value (or (and (not nocache) (gethash path hell--dotfile-cache))
                       (puthash path (hell-dotfile--read path) hell--dotfile-cache))))
        (dolist (key keys value)
          (setq value (alist-get key value)))))))

;;; Logging ----------------------------------------------------------------

(defmacro hell-log (format-string &rest args)
  "Log FORMAT-STRING with ARGS to *Messages*, but only in debug mode.
Debug mode is `init-file-debug' (--debug-init or the DEBUG envvar)."
  `(when init-file-debug
     (let ((inhibit-message (active-minibuffer-window)))
       (message ,(concat "hell: " format-string) ,@args))))

;;; Context ----------------------------------------------------------------
;;
;; What kind of session is running, so code can branch on it cheaply
;; (e.g. skip UI work in the CLI, or re-run setup on `reload').

(defconst hell-contexts
  '(startup   ; Emacs is still booting
    emacs     ; an interactive session
    cli       ; a non-interactive (batch) session
    reload    ; `hell-reload' is re-running the config
    module)   ; a module file is being loaded
  "Valid values for `hell-context'.")

(defvar hell-context '(t)
  "A list of symbols (from `hell-contexts') describing the session.
Use `hell-context-p' to test it and `with-hell-context' to
bind it temporarily; don't `setq' it directly.")

(defun hell-context-p (context)
  "Return non-nil if CONTEXT (a symbol) is active."
  (memq context hell-context))

(defun hell-context-push (context)
  "Activate CONTEXT. Return non-nil if it wasn't already active."
  (unless (memq context hell-contexts)
    (signal 'wrong-type-argument (list 'hell-contexts context)))
  (unless (memq context hell-context)
    (push context hell-context)))

(defun hell-context-pop (context)
  "Deactivate CONTEXT.
Non-destructive: inside `with-hell-context' the list shares its
tail with the outer value, which must stay as it was."
  (setq hell-context (remq context hell-context)))

(defmacro with-hell-context (contexts &rest body)
  "Evaluate BODY with CONTEXTS (a symbol or list) also active."
  (declare (indent 1))
  `(let ((hell-context (append (ensure-list ,contexts) hell-context)))
     ,@body))

;;; Hooks: running -----------------------------------------------------------

(defun hell-run-hooks (&rest hooks)
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
           'hell (format "Error in `%s' from `%s': %s"
                         fn hook (error-message-string err))
           :error)))
       nil))))

(defun hell-run-hook-on (hook-var trigger-hooks &optional predicate)
  "Run HOOK-VAR once, the first time any of TRIGGER-HOOKS fires.
Waits until startup is finished (see `hell-init-time'), and until
PREDICATE (if given) returns non-nil. Afterwards HOOK-VAR is cleared, so
functions added to it later never run."
  (let ((fn (intern (format "hell--run-%s-h" hook-var))))
    (defalias fn
      (lambda (&rest _)
        (when (and hell-init-time
                   ;; The daemon's initial, invisible frame doesn't count.
                   (not (and (daemonp) (not (frame-parameter nil 'client))))
                   (or (null predicate) (funcall predicate)))
          (dolist (hook trigger-hooks)
            (remove-hook hook fn))
          (hell-run-hooks hook-var)
          (set hook-var nil))))
    (dolist (hook trigger-hooks)
      (add-hook hook fn -90))))

;;; Hooks: defining --------------------------------------------------------

(defun hell--resolve-hooks (hooks)
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
  (let ((hooks (hell--resolve-hooks hooks))
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
  "Remove functions from HOOKS. REST is as in `add-hook!'.
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
  (let ((hooks (hell--resolve-hooks hooks)))
    (macroexp-progn
     (cl-loop for hook in hooks
              append (cl-loop for (var val) on var-vals by #'cddr
                              for fn = (intern (format "hell--setq-%s-for-%s-h" var hook))
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

ARGLIST is the advice's argument list, and DOCSTRING its documentation.
In BODY, one or more HOW TARGET pairs come first, where HOW is an
`advice-add' combinator (:around, :before, :override, ...) and TARGET a
function or quoted list of functions; then the body proper."
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

;;; Processes ---------------------------------------------------------------

(defun hell-process-output (program &rest args)
  "Run PROGRAM with ARGS; return (EXIT-CODE . OUTPUT), OUTPUT trimmed.
OUTPUT is stdout and stderr together. EXIT-CODE is 127 when PROGRAM
isn't there, 126 when it can't be run, as a shell says."
  (with-temp-buffer
    (let ((code (condition-case nil
                    (apply #'call-process program nil t nil args)
                  (file-missing 127)
                  (file-error 126))))
      (cons code (string-trim (buffer-string))))))

;;; Files --------------------------------------------------------------------

(defun hell-file-sha256 (file)
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

(defun hell-files-sha256 (files)
  "The SHA-256 of each of FILES, as a table: file -> hex string.
Through sha256sum or shasum, a few hundred files per run, when there's
one; else each read into Emacs (`hell-file-sha256')."
  (let ((table (make-hash-table :test #'equal))
        (command (cond ((executable-find "sha256sum") '("sha256sum"))
                       ((executable-find "shasum") '("shasum" "-a" "256")))))
    (when command
      (let ((files (mapcar #'expand-file-name files)))
        (while files
          (let ((batch (seq-take files 500)))
            (setq files (nthcdr 500 files))
            (with-temp-buffer
              (when (eql 0 (ignore-errors (apply #'call-process (car command) nil t nil
                                                  (append (cdr command) (list "--") batch))))
                ;; One line each, in order: HASH, two spaces (or " *"), the name.
                (goto-char (point-min))
                (dolist (file batch)
                  (when (looking-at "\\\\?\\([0-9a-f]\\{64\\}\\) ")
                    (puthash file (match-string 1) table))
                  (forward-line 1))))))))
    (dolist (file files)
      (unless (gethash (expand-file-name file) table)
        (puthash (expand-file-name file) (hell-file-sha256 file) table)))
    table))

(defun hell-marker-current-p (marker value)
  "Non-nil if the file MARKER exists and holds VALUE (whitespace aside).
Pinned installs write the pin they were made from to a marker file."
  (and (file-exists-p marker)
       (equal (with-temp-buffer (insert-file-contents marker) (string-trim (buffer-string)))
              value)))

(defun hell-marker-write (marker value)
  "Record VALUE in the file MARKER, for `hell-marker-current-p'."
  (with-temp-file marker (insert value "\n")))

(defun hell-platform ()
  "This machine as release assets name it: \"linux-x86_64\", etc.
nil on an operating system no pinned download is made for."
  (when-let* ((os (pcase system-type
                    ('gnu/linux "linux") ('darwin "darwin") ('windows-nt "windows"))))
    (let ((cpu (car (split-string system-configuration "-"))))
      (concat os "-" (if (member cpu '("arm64" "aarch64")) "aarch64" cpu)))))

(defun hell-npm-installed-p (lock-dir dir)
  "Non-nil if DIR holds the npm packages LOCK-DIR's package-lock.json pins.
`hell-sync-npm-install' records the lockfile's SHA-256 in DIR."
  (let ((lock (expand-file-name "package-lock.json" lock-dir)))
    (and (file-exists-p lock)
         (file-directory-p (expand-file-name "node_modules" dir))
         (hell-marker-current-p (expand-file-name ".hell-lock-sha256" dir)
                                (hell-file-sha256 lock)))))

(defun hell-file-pinned-p (file sha256)
  "Non-nil if FILE exists and its bytes have the SHA-256 SHA256."
  (and (file-exists-p file)
        (equal (hell-file-sha256 file) sha256)))

;;; Build output -----------------------------------------------------------

(defconst hell-build-files
  '("pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts")
  "Files at the root of a Maven or Gradle build.")

(defconst hell-ignored-dirs '(".git" ".hg" ".svn" ".idea" "node_modules")
  "Directories no walk of a project's files looks in: VCS, IDE state, npm's.")

(defconst hell-build-output-dirs '("build" "bin" "out" "target" ".gradle")
  "Directories Gradle, Maven, IntelliJ (out/) and JDTLS write output to.")

(defun hell-build-output-regexp (root)
  "Matches a directory of `hell-build-output-dirs' in any module under ROOT.
But not one under a src/ directory: a package named build is source.
Only the part after ROOT counts, so a project kept under ~/src is too."
  (rx bos (literal (directory-file-name root))
      ;; Any directories but src.
      (* "/" (or (seq (not (any "s/")) (* (not "/")))
                 "s" (seq "s" (not (any "r/")) (* (not "/")))
                 "sr" (seq "sr" (not (any "c/")) (* (not "/")))
                 (seq "src" (+ (not "/")))))
      "/" (regexp (regexp-opt hell-build-output-dirs)) eos))

;;; Components -------------------------------------------------------------

(defvar hell-components nil
  "Everything a module downloads, as `hell-component!' declared it.
A list of plists, newest first; read by `bin/hell sbom' and `licenses'.")

(defmacro hell-component! (&rest props)
  "Declare a pinned download this module installs, for SBOM and license report.
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
  `(hell-component-declare (list ,@props)))

(defun hell-component-declare (props)
  "Record the component PROPS. See `hell-component!'."
  (let ((name (or (plist-get props :name) (error "hell-component!: no :name"))))
    (setq hell-components
          (cons props (seq-remove (lambda (c) (equal (plist-get c :name) name))
                                  hell-components)))))

;;; Announcements ----------------------------------------------------------

(defun hell-announce (table event &rest args)
  "Show the message for EVENT in TABLE, formatted with ARGS; return the text.
TABLE is an alist of (EVENT FACE THEMED PLAIN); the PLAIN wording is used
when `hell-ux-enable' is nil."
  (pcase-let ((`(,face ,themed ,plain) (alist-get event table)))
    (let ((text (apply #'format (if (bound-and-true-p hell-ux-enable) themed plain) args)))
      (message "%s" (propertize text 'face face))
      text)))

;;; Reloading code ---------------------------------------------------------

(defvar-local hell-reload-function nil
  "Function that reloads the current buffer's code into the running program.
`C-c h r' (the Crucible) calls it. Each language module sets it in its
buffers: Java hot-swaps into a debug session, Clojure loads into its REPL.")

(provide 'hell-lib)
;;; hell-lib.el ends here
