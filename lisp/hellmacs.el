;;; hellmacs.el --- The heart: lifecycle, GC, incremental loading, dirs -*- lexical-binding: t; -*-

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

;; Hellmacs' heart (Doom v3's lisp/doom.el): what every session needs,
;; whichever modules are enabled. Everything in `lisp/' is engine
;; plumbing: no keybindings, no leader keys, no completion UI, that's
;; the modules'. This file runs the startup lifecycle and keeps Emacs'
;; droppings in Hellmacs' own XDG directories instead of scattering
;; them across `~'; the stock settings Hellmacs changes are in
;; hellmacs-emacs.el (Doom's doom-emacs.el).
;;
;; Expects the `hellmacs-*-dir' variables,
;; `hellmacs--gc-cons-threshold' and `hellmacs--gc-cons-percentage' to
;; already be defined -- they're set in `early-init.el', which always
;; loads before this file.

;;; Code:

;;; Startup lifecycle ----------------------------------------------------
;;
;; Hellmacs' notion of "startup finished" is when every package is
;; activated, signalled by `hellmacs--packages-ready-hook'. When packages
;; come from a synced profile (see `hellmacs-sync') that's simply
;; `after-init-hook'. Without one, Elpaca activates them asynchronously
;; and it's `elpaca-after-init-hook' instead. `hellmacs-finalize' runs
;; from there.
;;
;; The `hellmacs-first-*' hooks let modules defer work until the user
;; actually needs it, instead of paying for it during boot. Each runs
;; exactly once, and never before `hellmacs-finalize'.

(defvar hellmacs-after-init-hook nil
  "Run once Hellmacs, its modules and their packages are fully loaded.")

(defvar hellmacs--packages-ready-hook nil
  "Run once every package is activated. Internal; fired by the module system.
Use `hellmacs-after-init-hook' instead.")

(defvar hellmacs-first-input-hook nil
  "Run once, before the first interactive command after startup.")

(defvar hellmacs-first-file-hook nil
  "Run once, when the first file is opened after startup.")

(defvar hellmacs-first-buffer-hook nil
  "Run once, when the first real buffer is displayed after startup.
*scratch*, *Messages* and other `special-mode' buffers don't count.")

(defun hellmacs--own-dirs ()
  "The directories holding Hellmacs' own files, not the user's."
  (list hellmacs-state-dir hellmacs-cache-dir hellmacs-data-dir))

(defun hellmacs--own-file-p ()
  "Return non-nil if the current buffer visits one of Hellmacs' own files.
Packages read their state that way (bookmark.el visits the bookmarks
file, for one, when the dashboard lists bookmarks); that isn't the user
opening a file."
  (when-let* ((file buffer-file-name))
    (seq-some (lambda (dir) (file-in-directory-p file dir)) (hellmacs--own-dirs))))

(defun hellmacs--real-buffer-p ()
  "Return non-nil if the current buffer counts for `hellmacs-first-buffer-hook'."
  (not (or (minibufferp)
           (member (buffer-name) '("*scratch*" "*Messages*"))
           (derived-mode-p 'special-mode)
           (hellmacs--own-file-p))))

(hellmacs-run-hook-on 'hellmacs-first-input-hook '(pre-command-hook))
(hellmacs-run-hook-on 'hellmacs-first-file-hook
                      '(find-file-hook dired-initial-position-hook)
                      (lambda () (not (hellmacs--own-file-p))))
(hellmacs-run-hook-on 'hellmacs-first-buffer-hook
                      '(find-file-hook window-buffer-change-functions)
                      #'hellmacs--real-buffer-p)

(defun hellmacs-finalize ()
  "Mark the end of startup and run `hellmacs-after-init-hook'."
  (when (hellmacs-context-p 'startup)
    (setq hellmacs-init-time
          (float-time (time-subtract (current-time) before-init-time)))
    ;; Files passed on the command line were opened before startup
    ;; finished, so their triggers were ignored; catch up now.
    (when (seq-some (lambda (buffer)
                      (with-current-buffer buffer
                        (and buffer-file-name (not (hellmacs--own-file-p)))))
                    (buffer-list))
      (hellmacs-run-hooks 'hellmacs-first-file-hook 'hellmacs-first-buffer-hook)
      (setq hellmacs-first-file-hook nil
            hellmacs-first-buffer-hook nil))
    (hellmacs-run-hooks 'hellmacs-after-init-hook)
    (hellmacs-context-pop 'startup)))

(add-hook 'hellmacs--packages-ready-hook #'hellmacs-finalize 90)

;;; GC lifecycle -------------------------------------------------------
;;
;; `early-init.el' maxed out `gc-cons-threshold' to get through boot
;; without collection pauses. Left unbounded, pauses get *worse* later:
;; one huge collection lands mid-keystroke. So once startup finishes a
;; bounded value is restored, and then `gcmh' (the "GC magic hack",
;; declared in lisp/packages.el) takes over at the first real buffer.
;; It keeps the threshold high while you work and collects when Emacs
;; goes idle, so pauses stay invisible to typing. Its idle delay adapts
;; to how long collections take (`gcmh-idle-delay' `auto').
;;
;; Emacs builds with the new incremental GC (igc) don't need any of
;; this, and don't get gcmh.

(defun hellmacs--restore-gc-h ()
  "Restore a bounded GC threshold after startup finishes."
  (setq gc-cons-threshold hellmacs--gc-cons-threshold
        gc-cons-percentage hellmacs--gc-cons-percentage))

(add-hook 'hellmacs--packages-ready-hook #'hellmacs--restore-gc-h)

(unless (fboundp 'igc-info)
  (setq gcmh-idle-delay 'auto              ; scale the delay with GC time...
        gcmh-auto-idle-delay-factor 10     ; ...collect after 10x the last GC's duration idle
        gcmh-high-cons-threshold (* 64 1024 1024))
  (add-hook 'hellmacs-first-buffer-hook
            (defun hellmacs--start-gcmh-h ()
              ;; Unless the user disabled it with (package! gcmh :disable t).
              (when (fboundp 'gcmh-mode)
                (gcmh-mode 1)))))

;;; Incremental loading ------------------------------------------------------
;;
;; Some packages are slow to load the first time they're used (a
;; language server client, a REPL). `hellmacs-load-incrementally'
;; queues features to load in the background instead, one at a time,
;; whenever Emacs is idle after startup -- so by the time you need
;; them they're already there, and typing is never blocked for more
;; than one small `require'. In `use-package' blocks, use
;; `:defer-incrementally' (see lisp/hellmacs-packages.el).

(defvar hellmacs-incremental-packages nil
  "Features waiting to be loaded by `hellmacs-load-incrementally'.")

(defvar hellmacs-incremental-first-idle-timer (if (daemonp) 0 2.0)
  "Idle seconds after startup before incremental loading begins.")

(defvar hellmacs-incremental-idle-timer 0.75
  "Idle seconds between two incrementally loaded features.")

(defun hellmacs-load-incrementally (features)
  "Queue FEATURES (a list of symbols) to load while Emacs is idle.
They load in order, after startup, one per `hellmacs-incremental-idle-timer'
idle seconds. Features already loaded by then are skipped."
  (dolist (feature features)
    (unless (or (featurep feature) (memq feature hellmacs-incremental-packages))
      (setq hellmacs-incremental-packages
            (append hellmacs-incremental-packages (list feature))))))

(defun hellmacs--load-next-incrementally ()
  "Load the next queued feature, then schedule the one after it."
  (when-let* ((feature (pop hellmacs-incremental-packages)))
    (unless (featurep feature)
      (hellmacs-log "loading %s incrementally" feature)
      (condition-case-unless-debug err
          (let ((inhibit-message t))
            (require feature nil t))
        (error
         (display-warning 'hellmacs (format "Loading %s incrementally failed: %s"
                                            feature (error-message-string err))))))
    (when hellmacs-incremental-packages
      ;; An idle timer created while Emacs is already idle has to count
      ;; from the start of that idle period to fire within it.
      (run-with-idle-timer (if-let* ((idle (current-idle-time)))
                               (time-add idle hellmacs-incremental-idle-timer)
                             hellmacs-incremental-idle-timer)
                           nil #'hellmacs--load-next-incrementally))))

(add-hook 'hellmacs-after-init-hook
          (defun hellmacs--start-incremental-loading-h ()
            (unless noninteractive
              (run-with-idle-timer hellmacs-incremental-first-idle-timer
                                   nil #'hellmacs--load-next-incrementally))))

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

(setq user-emacs-directory hellmacs-cache-dir)

(defun hellmacs-state-file (name)
  "Return the absolute path of NAME inside `hellmacs-state-dir'."
  (expand-file-name name hellmacs-state-dir))

(let ((backup-dir    (hellmacs-state-file "backup/"))
      (auto-save-dir (hellmacs-state-file "auto-save/")))
  (with-file-modes #o700
    (make-directory backup-dir t)
    (make-directory auto-save-dir t))
  (setq backup-directory-alist (list (cons "." backup-dir))
        auto-save-file-name-transforms (list (list ".*" auto-save-dir t))
        auto-save-list-file-prefix (expand-file-name ".saves-" auto-save-dir)))

(setq abbrev-file-name            (hellmacs-state-file "abbrev_defs")
      bookmark-default-file       (hellmacs-state-file "bookmarks")
      savehist-file               (hellmacs-state-file "savehist")
      save-place-file             (hellmacs-state-file "save-place")
      recentf-save-file           (hellmacs-state-file "recentf")
      tramp-persistency-file-name (hellmacs-state-file "tramp")
      eshell-directory-name       (hellmacs-state-file "eshell/")
      project-list-file           (hellmacs-state-file "projects")
      transient-history-file      (hellmacs-state-file "transient/history.el")
      transient-levels-file       (hellmacs-state-file "transient/levels.el")
      transient-values-file       (hellmacs-state-file "transient/values.el"))

;; Language servers lsp-mode installs, and the ones the `:lang' modules'
;; sync steps put there: data (reinstallable, but needed to run). Set
;; before lsp-mode or any module's +paths.el reads it.
(setq lsp-server-install-dir (expand-file-name "lsp/" hellmacs-data-dir))

;; Customize writes are user config, so they go next to the user's
;; init.el and config.el -- unless there is no user dir, in which case
;; they're kept as state instead of creating one behind the user's back.
(setq custom-file
      (if (file-directory-p hellmacs-user-dir)
          (expand-file-name "custom.el" hellmacs-user-dir)
        (hellmacs-state-file "custom.el")))

;; Custom vars/faces may reference installed packages, so load
;; `custom-file' only once every package is activated.
(add-hook 'hellmacs--packages-ready-hook
          (defun hellmacs--load-custom-file-h ()
            (load custom-file 'noerror 'nomessage)))

;; Hellmacs' own files (the bookmarks file, caches, installed packages)
;; aren't what "recent files" means: saving bookmarks, for one, visits
;; the bookmarks file.
(defvar recentf-exclude)
(with-eval-after-load 'recentf
  (dolist (dir (hellmacs--own-dirs))
    (add-to-list 'recentf-exclude (concat "\\`" (regexp-quote (file-truename dir))))
    (add-to-list 'recentf-exclude (concat "\\`" (regexp-quote (abbreviate-file-name dir))))))

;; None of these are needed until the user actually does something, so
;; start them lazily instead of paying their file IO at boot.
(add-hook 'hellmacs-first-input-hook #'savehist-mode)
(add-hook 'hellmacs-first-file-hook #'recentf-mode)
(add-hook 'hellmacs-first-file-hook #'save-place-mode)

;;; Shell environment ------------------------------------------------------
;;
;; Emacs started from a desktop launcher or a systemd service doesn't
;; get the PATH (and JAVA_HOME, ...) your shell sets up, so it can't
;; find java, jdtls or clojure-lsp. `bin/hellmacs env' saves your
;; shell's environment to `hellmacs-env-file'; if that file exists, it
;; is applied here, before any module runs. Re-run `bin/hellmacs env'
;; after changing your shell's environment.

(defvar hellmacs-env-file (expand-file-name "env" hellmacs-data-dir)
  "Where `bin/hellmacs env' saves the shell environment.
A lisp-data file holding a list of \"VAR=value\" strings.")

(defun hellmacs--read-env-file (file)
  "Return the \"VAR=value\" strings saved in FILE, or nil if it's unusable.
An unusable file (cut short while `bin/hellmacs env' wrote it, say)
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
      'hellmacs (format "Ignoring the saved environment %s (%s); run `bin/hellmacs env' again"
                        (abbreviate-file-name file) (error-message-string err)))
     nil)))

(defun hellmacs-load-env-file (&optional file)
  "Apply the environment saved in FILE (default `hellmacs-env-file').
Its variables take precedence over the ones Emacs inherited; the rest
are kept. Updates `exec-path' and `shell-file-name' to match. Returns
non-nil if FILE existed and could be read."
  (let ((file (or file hellmacs-env-file)))
    (when-let* (((file-readable-p file))
                (vars (hellmacs--read-env-file file)))
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
  (hellmacs-load-env-file))

;;; User config directory ------------------------------------------------

(defun hellmacs-init-user-dir ()
  "Create `hellmacs-user-dir' with starter init.el, packages.el and config.el.
Existing files are never overwritten."
  (interactive)
  (make-directory hellmacs-user-dir t)
  (dolist (name '("init.el" "packages.el" "config.el"))
    (let ((file (expand-file-name name hellmacs-user-dir)))
      (unless (file-exists-p file)
        (copy-file (expand-file-name (concat "static/" (file-name-base name) ".example.el")
                                     hellmacs-dir)
                   file))))
  ;; `custom-file' was put in the state dir because there was no user
  ;; dir at startup; from now on it belongs here.
  (setq custom-file (expand-file-name "custom.el" hellmacs-user-dir))
  (message "Hellmacs user config is in %s" (abbreviate-file-name hellmacs-user-dir)))

(provide 'hellmacs)
;;; hellmacs.el ends here
