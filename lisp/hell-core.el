;;; hell-core.el --- The heart: lifecycle, GC, incremental loading, dirs -*- lexical-binding: t; -*-

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

;; Hell Emacs' heart (Doom v3's lisp/doom.el): what every session needs,
;; whichever modules are enabled. Everything in `lisp/' is engine
;; plumbing: no keybindings, no leader keys, no completion UI, that's
;; the modules'. This file runs the startup lifecycle and keeps Emacs'
;; droppings in Hell Emacs' own XDG directories instead of scattering
;; them across `~'; the stock settings Hell Emacs changes are in
;; hell-emacs.el (Doom's doom-emacs.el).
;;
;; Expects the `hell-*-dir' variables,
;; `hell--gc-cons-threshold' and `hell--gc-cons-percentage' to
;; already be defined -- they're set in `early-init.el', which always
;; loads before this file, and then calls `hell-initialize', as
;; Doom's early-init.el calls `doom-initialize'.
;;
;; The startup itself, from there:
;;
;;   early-init.el            dirs, GC and UI tuning; loads this file
;;   `hell-initialize'    core libraries; interactively, also
;;                            lisp/hell-emacs.el, whose entry point
;;                            replaces Emacs' init file loading with...
;;   `hell-start'         the profile's generated init file
;;                            (lisp/hell-profiles.el), then
;;   `hell-startup'       `hell-startup-functions', which that
;;                            file filled: packages, autoloads, modules,
;;                            your config
;;
;; Batch sessions start the same way:
;;
;;   emacs --batch -l early-init.el -f hell-start -l SCRIPT.el

;;; Code:

(require 'hell-lib)

(defvar native-comp-jit-compilation)
(defvar hell-dir)                  ; early-init.el
(defvar hell-profile)              ; early-init.el
(defvar hell-profile-dir)          ; early-init.el
(defvar hell-user-dir)             ; early-init.el
(defvar hell-cache-dir)            ; early-init.el
(defvar hell-state-dir)            ; early-init.el
(defvar hell--gc-cons-threshold)   ; early-init.el
(defvar hell--gc-cons-percentage)  ; early-init.el

(defgroup hell nil
  "The Hell Emacs distribution."
  :group 'emacs)

;;; Startup lifecycle ----------------------------------------------------
;;
;; Hell Emacs' notion of "startup finished" is when every package is
;; activated, signalled by `hell--packages-ready-hook'. When packages
;; come from a synced profile (see `hell-sync') that's simply
;; `after-init-hook'. Without one, Elpaca activates them asynchronously
;; and it's `elpaca-after-init-hook' instead. `hell-finalize' runs
;; from there.
;;
;; The `hell-first-*' hooks let modules defer work until the user
;; actually needs it, instead of paying for it during boot. Each runs
;; exactly once, and never before `hell-finalize'.

(defvar hell-after-init-hook nil
  "Run once Hell Emacs, its modules and their packages are fully loaded.")

(defvar hell--packages-ready-hook nil
  "Run once every package is activated. Internal; fired by the module system.
Use `hell-after-init-hook' instead.")

(defvar hell-first-input-hook nil
  "Run once, before the first interactive command after startup.")

(defvar hell-first-file-hook nil
  "Run once, when the first file is opened after startup.")

(defvar hell-first-buffer-hook nil
  "Run once, when the first real buffer is displayed after startup.
*scratch*, *Messages* and other `special-mode' buffers don't count.")

(defun hell--own-dirs ()
  "The directories holding Hell Emacs' own files, not the user's."
  (list hell-state-dir hell-cache-dir hell-data-dir))

(defun hell--own-file-p ()
  "Return non-nil if the current buffer visits one of Hell Emacs' own files.
Packages read their state that way (bookmark.el visits the bookmarks
file, for one, when something lists bookmarks); that isn't the user
opening a file."
  (when-let* ((file buffer-file-name))
    (seq-some (lambda (dir) (file-in-directory-p file dir)) (hell--own-dirs))))

(defun hell--real-buffer-p ()
  "Return non-nil if the current buffer counts for `hell-first-buffer-hook'."
  (not (or (minibufferp)
           (member (buffer-name) '("*scratch*" "*Messages*"))
           (derived-mode-p 'special-mode)
           (hell--own-file-p))))

(hell-run-hook-on 'hell-first-input-hook '(pre-command-hook))
(hell-run-hook-on 'hell-first-file-hook
                      '(find-file-hook dired-initial-position-hook)
                      (lambda () (not (hell--own-file-p))))
(hell-run-hook-on 'hell-first-buffer-hook
                      '(find-file-hook window-buffer-change-functions)
                      #'hell--real-buffer-p)

(defun hell--run-packages-ready-h ()
  "Run `hell--packages-ready-hook'.
Each function's errors only warn: one broken function (an error in
`custom-file', say) mustn't keep the GC reset or `hell-finalize',
which come after it, from running."
  (hell-run-hooks 'hell--packages-ready-hook))

(defun hell-finalize ()
  "Mark the end of startup and run `hell-after-init-hook'."
  (when (hell-context-p 'startup)
    (setq hell-init-time
          (float-time (time-subtract (current-time) before-init-time)))
    ;; Files passed on the command line were opened before startup
    ;; finished, so their triggers were ignored; catch up now.
    (when (seq-some (lambda (buffer)
                      (with-current-buffer buffer
                        (and buffer-file-name (not (hell--own-file-p)))))
                    (buffer-list))
      (hell-run-hooks 'hell-first-file-hook 'hell-first-buffer-hook)
      (setq hell-first-file-hook nil
            hell-first-buffer-hook nil))
    (hell-run-hooks 'hell-after-init-hook)
    (hell-context-pop 'startup)))

(add-hook 'hell--packages-ready-hook #'hell-finalize 90)

;;; GC lifecycle -------------------------------------------------------
;;
;; `early-init.el' maxed out `gc-cons-threshold' to get through boot
;; without collection pauses. Left unbounded, pauses get *worse* later:
;; one huge collection lands mid-keystroke. So once startup finishes a
;; bounded value is restored, and then `gcmh' (the "GC magic hack",
;; core's module's: modules/hell/) takes over at the first real buffer.
;; It keeps the threshold high while you work and collects when Emacs
;; goes idle, so pauses stay invisible to typing. Its idle delay adapts
;; to how long collections take (`gcmh-idle-delay' `auto').
;;
;; Emacs builds with the new incremental GC (igc) don't need any of
;; this, and don't get gcmh.

(defun hell--restore-gc-h ()
  "Restore a bounded GC threshold after startup finishes."
  (setq gc-cons-threshold hell--gc-cons-threshold
        gc-cons-percentage hell--gc-cons-percentage))

(add-hook 'hell--packages-ready-hook #'hell--restore-gc-h)

;;; Incremental loading ------------------------------------------------------
;;
;; Some packages are slow to load the first time they're used (a
;; language server client, a REPL). `hell-load-incrementally'
;; queues features to load in the background instead, one at a time,
;; whenever Emacs is idle after startup -- so by the time you need
;; them they're already there, and typing is never blocked for more
;; than one small `require'. In `use-package' blocks, use
;; `:defer-incrementally' (see lisp/hell-packages.el).

(defvar hell-incremental-packages nil
  "Features waiting to be loaded by `hell-load-incrementally'.")

(defcustom hell-incremental-first-idle-timer (if (daemonp) 0 2.0)
  "Idle seconds after startup before incremental loading begins."
  :type 'number
  :group 'hell)

(defcustom hell-incremental-idle-timer 0.75
  "Idle seconds between two incrementally loaded features."
  :type 'number
  :group 'hell)

(defun hell-load-incrementally (features)
  "Queue FEATURES (a list of symbols) to load while Emacs is idle.
They load in order, after startup, one per `hell-incremental-idle-timer'
idle seconds. Features already loaded by then are skipped."
  (dolist (feature features)
    (unless (or (featurep feature) (memq feature hell-incremental-packages))
      (setq hell-incremental-packages
            (append hell-incremental-packages (list feature))))))

(defun hell--load-next-incrementally ()
  "Load the next queued feature, then schedule the one after it."
  (when-let* ((feature (pop hell-incremental-packages)))
    (unless (featurep feature)
      (hell-log "loading %s incrementally" feature)
      (condition-case-unless-debug err
          (let ((inhibit-message t))
            (require feature nil t))
        (error
         (display-warning 'hell (format "Loading %s incrementally failed: %s"
                                            feature (error-message-string err))))))
    (when hell-incremental-packages
      ;; An idle timer created while Emacs is already idle has to count
      ;; from the start of that idle period to fire within it.
      (run-with-idle-timer (if-let* ((idle (current-idle-time)))
                               (time-add idle hell-incremental-idle-timer)
                             hell-incremental-idle-timer)
                           nil #'hell--load-next-incrementally))))

(add-hook 'hell-after-init-hook
          (defun hell--start-incremental-loading-h ()
            (unless noninteractive
              (run-with-idle-timer hell-incremental-first-idle-timer
                                   nil #'hell--load-next-incrementally))))

;;; Directory isolation --------------------------------------------------
;;
;; Keep Emacs' and packages' files out of the git checkout and out of
;; `~', split by kind (see the layout comment in `early-init.el').
;;
;; Most packages build their file paths from `user-emacs-directory'
;; (usually via `locate-user-emacs-file'). Pointing it at the cache dir
;; sends all of those there without configuring each package, as Doom
;; does. It's safe to change here: Emacs has already located init.el.
;; Anything that isn't disposable is redirected explicitly below.

(setq user-emacs-directory hell-cache-dir)

(defun hell-state-file (name)
  "Return the absolute path of NAME inside `hell-state-dir'."
  (expand-file-name name hell-state-dir))

(let ((backup-dir    (hell-state-file "backup/"))
      (auto-save-dir (hell-state-file "auto-save/")))
  (with-file-modes #o700
    (make-directory backup-dir t)
    (make-directory auto-save-dir t))
  (setq backup-directory-alist (list (cons "." backup-dir))
        auto-save-file-name-transforms (list (list ".*" auto-save-dir t))
        auto-save-list-file-prefix (expand-file-name ".saves-" auto-save-dir)))

;; Set before their packages load, so declare them here.
(defvar bookmark-default-file)
(defvar savehist-file)
(defvar save-place-file)
(defvar recentf-save-file)
(defvar tramp-persistency-file-name)
(defvar eshell-directory-name)
(defvar project-list-file)
(defvar transient-history-file)
(defvar transient-levels-file)
(defvar transient-values-file)
(defvar lsp-server-install-dir)

(setq abbrev-file-name            (hell-state-file "abbrev_defs")
      bookmark-default-file       (hell-state-file "bookmarks")
      savehist-file               (hell-state-file "savehist")
      save-place-file             (hell-state-file "save-place")
      recentf-save-file           (hell-state-file "recentf")
      tramp-persistency-file-name (hell-state-file "tramp")
      eshell-directory-name       (hell-state-file "eshell/")
      project-list-file           (hell-state-file "projects")
      transient-history-file      (hell-state-file "transient/history.el")
      transient-levels-file       (hell-state-file "transient/levels.el")
      transient-values-file       (hell-state-file "transient/values.el"))

;; Language servers lsp-mode installs, and the ones the `:lang' modules'
;; sync steps put there: data (reinstallable, but needed to run). Set
;; before lsp-mode or any module's +paths.el reads it.
(setq lsp-server-install-dir (expand-file-name "lsp/" hell-data-dir))

;; Customize writes are user config, so they go next to the user's
;; init.el and config.el -- unless there is no user dir, in which case
;; they're kept as state instead of creating one behind the user's back.
(setq custom-file
      (if (file-directory-p hell-user-dir)
          (expand-file-name "custom.el" hell-user-dir)
        (hell-state-file "custom.el")))

;; Custom vars/faces may reference installed packages, so load
;; `custom-file' only once every package is activated.
(add-hook 'hell--packages-ready-hook
          (defun hell--load-custom-file-h ()
            (load custom-file 'noerror 'nomessage)))

;; Hell Emacs' own files (the bookmarks file, caches, installed packages)
;; aren't what "recent files" means: saving bookmarks, for one, visits
;; the bookmarks file.
(defvar recentf-exclude)
(defvar recentf-auto-cleanup)
(with-eval-after-load 'recentf
  (setq recentf-auto-cleanup 'never)
  (advice-add 'recentf-cleanup :around
              (lambda (orig-fn &rest args)
                (let ((inhibit-message t))
                  (apply orig-fn args))))
  (dolist (dir (hell--own-dirs))
    (add-to-list 'recentf-exclude (concat "\\`" (regexp-quote (file-truename dir))))
    (add-to-list 'recentf-exclude (concat "\\`" (regexp-quote (abbreviate-file-name dir))))))

;; None of these are needed until the user actually does something, so
;; start them lazily instead of paying their file IO at boot.
(add-hook 'hell-first-input-hook #'savehist-mode)
(defun hell--recentf-mode-h ()
  "Turn on `recentf-mode' without its cleanup message."
  (let ((inhibit-message t)) (recentf-mode 1)))
(add-hook 'hell-first-file-hook #'hell--recentf-mode-h)
(add-hook 'hell-first-file-hook #'save-place-mode)

;;; Shell environment ------------------------------------------------------
;;
;; Emacs started from a desktop launcher or a systemd service doesn't
;; get the PATH (and JAVA_HOME, ...) your shell sets up, so it can't
;; find java, jdtls or clojure-lsp. `bin/hell env' saves your
;; shell's environment to `hell-env-file'; if that file exists, it
;; is applied here, before any module runs. Re-run `bin/hell env'
;; after changing your shell's environment.

(defvar hell-env-file (expand-file-name "env" hell-data-dir)
  "Where `bin/hell env' saves the shell environment.
A lisp-data file holding a list of \"VAR=value\" strings.")

(defun hell--read-env-file (file)
  "Return the \"VAR=value\" strings saved in FILE, or nil if it's unusable.
An unusable file (cut short while `bin/hell env' wrote it, say)
only warns: it mustn't stop Emacs from starting."
  (condition-case err
      (with-temp-buffer
        (insert-file-contents file)
        (let ((vars (read (current-buffer))))
          (unless (and (listp vars) (seq-every-p #'stringp vars))
            (error "Not a list of \"VAR=value\" strings"))
          vars))
    (error
     (display-warning
      'hell (format "Ignoring the saved environment %s (%s); run `bin/hell env' again"
                    (abbreviate-file-name file) (error-message-string err)))
     nil)))

(defun hell-load-env-file (&optional file)
  "Apply the environment saved in FILE (default `hell-env-file').
Its variables take precedence over the ones Emacs inherited; the rest
are kept. Updates the variables `exec-path' and `shell-file-name' to
match. Returns non-nil if FILE existed and could be read."
  (let ((file (or file hell-env-file)))
    (when-let* (((file-readable-p file))
                (vars (hell--read-env-file file)))
      ;; Replace, don't stack: a variable saved in FILE drops any earlier
      ;; value of it (from Emacs, or from calling this before).
      (let ((names (mapcar (lambda (v) (car (split-string v "="))) vars)))
        (setq-default process-environment
                      (append vars
                              (seq-remove (lambda (entry)
                                            (member (car (split-string entry "=")) names))
                                          (default-value 'process-environment)))))
      (setq-default exec-path (append (parse-colon-path (getenv "PATH"))
                                      (list exec-directory)))
      (setq-default shell-file-name (or (getenv "SHELL") shell-file-name))
      t)))

(unless noninteractive
  (hell-load-env-file))

;;; User config directory ------------------------------------------------

(defun hell-init-user-dir ()
  "Create `hell-user-dir' with starter init.el, packages.el and config.el.
Existing files are never overwritten."
  (interactive)
  (make-directory hell-user-dir t)
  (dolist (name '("init.el" "packages.el" "config.el"))
    (let ((file (expand-file-name name hell-user-dir)))
      (unless (file-exists-p file)
        (copy-file (expand-file-name (concat "static/" (file-name-base name) ".example.el")
                                     hell-dir)
                   file))))
  ;; `custom-file' was put in the state dir because there was no user
  ;; dir at startup; from now on it belongs here.
  (setq custom-file (expand-file-name "custom.el" hell-user-dir))
  (message "Hell Emacs user config is in %s" (abbreviate-file-name hell-user-dir)))

;;; Bootstrap: initialize, start --------------------------------------------

(defvar hell-before-init-hook nil
  "Run by `hell-initialize', before the profile or any module loads.")

(defvar hell-startup-functions nil
  "Functions `hell-startup' runs, each with the profile's name.
The profile's generated init file adds them, at the depth of their part
\(see lisp/hell-profiles.el): 5 its data, 60 the modules' autoloads,
70 the packages', 80 the modules and your config.")

(defvar hell-profile-generated nil
  "What the profile's init file was generated from: a plist, set by it.")

(define-error 'hell-error "Hell Emacs error")
(define-error 'hell-nosync-error
  "Hell Emacs isn't synced for this Emacs; run `bin/hell sync'" 'hell-error)

(defun hell-init-file ()
  "The profile's generated init file, for this Emacs version.
<profile>/init.MAJOR.MINOR.el, as Doom's init.%d.%d.el: another Emacs
version never loads it. Written by `bin/hell sync'."
  (expand-file-name (format "init.%d.%d.el" emacs-major-version emacs-minor-version)
                    hell-profile-dir))

(defun hell-initialize (&optional interactive)
  "Bootstrap the session: core's libraries, and with INTERACTIVE, its defaults.
Called by early-init.el, in every session (the CLI's too), as Doom's
`doom-initialize'. The profile itself loads later: `hell-start'."
  (require 'hell-packages)
  (require 'hell-modules)
  (require 'hell-treesit)   ; only points Emacs at the grammars sync builds
  (when interactive
    (hell-context-push 'startup)
    (hell-context-push 'emacs)
    (require 'hell-emacs))   ; the stock-Emacs defaults, and the entry point
  (hell-run-hooks 'hell-before-init-hook))

(defun hell-start ()
  "Start Hell Emacs: load the profile's init file, then run `hell-startup'.
Emacs does it itself (the entry point in lisp/hell-emacs.el); batch
sessions call it:

  emacs --batch -l early-init.el -f hell-start -l SCRIPT.el

Signals `hell-nosync-error' if there's no init file: `bin/hell
sync' (or `install') writes it."
  (hell-context-push 'startup)
  (when noninteractive
    (hell-context-push 'cli)
    (require 'hell-emacs))
  (let ((init-file (hell-init-file)))
    (unless (file-exists-p init-file)
      (signal 'hell-nosync-error
              (list (format "%s doesn't exist; run `bin/hell%s sync'"
                            (abbreviate-file-name init-file)
                            (if hell-profile (format " --profile %s" hell-profile) "")))))
    ;; The compiled one, when there is one (`load' prefers it). It's never
    ;; native-compiled (`no-native-compile'): JIT off, or Emacs would
    ;; load its compiler after startup only to skip it (see hell-lib.el).
    (let ((native-comp-jit-compilation nil))
      (load (file-name-sans-extension init-file) nil 'nomessage))
    (hell-startup)))

(defun hell-startup ()
  "Run `hell-startup-functions': packages, autoloads, modules, your config.
As Doom's `doom-startup'."
  (run-hook-with-args 'hell-startup-functions hell-profile)
  ;; Hell Emacs' notion of "started": every package activated, which with a
  ;; synced profile is Emacs' own `after-init-hook'.
  (add-hook 'after-init-hook #'hell--run-packages-ready-h 90))

;; Named, so `hell-reload' re-adding it doesn't stack copies.
(add-hook 'hell-after-init-hook
          (defun hell--report-ready-h ()
            (message "Hell Emacs%s ready in %.2fs (%d GCs)"
                     (if hell-profile (format " [%s]" hell-profile) "")
                     hell-init-time gcs-done)))

(provide 'hell-core)
;;; hell-core.el ends here
