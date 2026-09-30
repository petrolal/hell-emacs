;;; hellmacs-cli.el --- The bin/hellmacs command-line tool -*- lexical-binding: t; -*-

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

;; `bin/hellmacs' runs Emacs in batch mode, loads early-init.el and this
;; file, and calls `hellmacs-cli-main' with the command-line arguments.
;; Each command is a `hellmacs-cli-COMMAND' function; see `hellmacs-cli-help'.
;;
;; Commands print plain text on stdout. Exit codes, as `doom's:
;;   0  success
;;   1  no error, but the command couldn't complete (a check failed)
;;   2  an error, inside Hellmacs or the command
;;   3  a problem with Emacs or the install (bin/hellmacs says which)
;;   5  no such command
;;   6  a wrong, missing or extra option

;;; Code:

(eval-and-compile (hellmacs-require 'hellmacs-cli 'sync))
(eval-and-compile
  (hellmacs-require 'hellmacs-cli 'bundle)
  (hellmacs-require 'hellmacs-cli 'config)
  (hellmacs-require 'hellmacs-cli 'compliance)
  (hellmacs-require 'hellmacs-cli 'verify))

;;; Output -----------------------------------------------------------------------

(defun hellmacs-cli--say (format-string &rest args)
  "Print FORMAT-STRING with ARGS, and a newline, on stdout."
  (princ (concat (apply #'format format-string args) "\n")))

(defvar hellmacs-cli--problems 0
  "How many `error'-level results `hellmacs-cli--check' printed.")

(defun hellmacs-cli--check (level format-string &rest args)
  "Print a check result. LEVEL is `ok', `warn', `error' or `info'."
  (when (eq level 'error) (cl-incf hellmacs-cli--problems))
  (hellmacs-cli--say "  %s %s"
                     (pcase level ('ok "✓") ('warn "!") ('error "✗") (_ "·"))
                     (apply #'format format-string args)))

(defvar hellmacs-cli-jobs 16
  "How many processes `hellmacs-cli--run-all' runs at once.")

(defun hellmacs-cli--run-all (commands)
  "Run COMMANDS, each a list (PROGRAM ARG...), up to `hellmacs-cli-jobs' at once.
Return their exit codes, in order (127 when PROGRAM can't be started)."
  (let* ((codes (make-vector (length commands) nil))
         (queue (seq-map-indexed #'cons commands))
         (running 0))
    (while (or queue (> running 0))
      (while (and queue (< running hellmacs-cli-jobs))
        (pcase-let ((`(,command . ,i) (pop queue)))
          (condition-case nil
              (progn
                (make-process :name "hellmacs-job" :command command :noquery t
                              :connection-type 'pipe :buffer nil
                              :sentinel (lambda (proc _)
                                          (unless (process-live-p proc)
                                            (aset codes i (process-exit-status proc))
                                            (cl-decf running))))
                (cl-incf running))
            (file-missing (aset codes i 127))
            ;; There, but not runnable (permission denied): the shell's code.
            (file-error (aset codes i 126)))))
      (when (> running 0)
        ;; Exits without output don't end the wait early: keep it short.
        (accept-process-output nil 0.005)))
    (append codes nil)))

(defun hellmacs-cli--run (program &rest args)
  "Run PROGRAM with ARGS; return (EXIT-CODE . OUTPUT), OUTPUT trimmed."
  (with-temp-buffer
    (let ((code (condition-case nil
                    (apply #'call-process program nil t nil args)
                  (file-missing 127))))
      (cons code (string-trim (buffer-string))))))

;;; Shared by several commands -------------------------------------------------

(defun hellmacs-cli--option (args option)
  "The value following OPTION in ARGS, nil if OPTION isn't there.
An error if it's there without a value."
  (when-let* ((tail (member option args)))
    (let ((value (cadr tail)))
      (when (or (null value) (string-prefix-p "-" value))
        (error "%s needs a value" option))
      value)))

(defun hellmacs-cli--flag (args name)
  "Whether ARGS say --NAME (t), --no-NAME (`no'), or neither (nil), as Doom's
--flag/--no-flag options."
  (cond ((member (concat "--no-" name) args) 'no)
        ((member (concat "--" name) args) t)))

(defun hellmacs-cli-force-p ()
  "Non-nil if every prompt is to be accepted: `bin/hellmacs -!' (--force)."
  (member (getenv "HELLMACS_FORCE") '("1" "t" "true" "yes")))

(defun hellmacs-cli--yes-p (prompt &optional default)
  "Ask PROMPT, a yes-or-no question; return non-nil for yes.
Without a person to answer (no terminal), return DEFAULT; with
`bin/hellmacs -!', t."
  (cond ((hellmacs-cli-force-p) t)
        ((not (getenv "__HELLMACSTTY")) default)
        (t (y-or-n-p prompt))))

(defun hellmacs-cli--read-modules (spec)
  "SPEC, the text of a `hellmacs!' block's arguments, as a list."
  (let ((modules (condition-case nil
                     (car (read-from-string (concat "(" spec ")")))
                   (error (error "--modules: can't read %S" spec)))))
    (unless (keywordp (car modules))
      (error "--modules must start with a group, as in \":lang java kotlin :tools lsp\""))
    modules))

(defvar hellmacs-upgrade-channel 'stable
  "What `bin/hellmacs upgrade' moves Hellmacs itself to: `stable', the latest
release (the tag vMAJOR.MINOR.PATCH), or `main', the development branch.
`upgrade --channel NAME' overrides it for one run. Set it in your init.el.")

(defvar hellmacs-upgrade-verify-tags nil
  "Non-nil: the stable channel only checks out a release whose tag's signature
`git verify-tag' accepts (the signer's key must be in your keyring).")

;;; Commands: bin/hellmacs-COMMAND ------------------------------------------

(defvar hellmacs-cli-load-path
  (append (list (expand-file-name "bin/" hellmacs-dir)
                (expand-file-name "bin/" hellmacs-user-dir))
          (when-let* ((path (getenv "HELLMACSPATH")))
            (split-string path path-separator t)))
  "Directories searched for hellmacs-COMMAND files, in order, as `$PATH' is.
Hellmacs' bin/, your config's bin/, then $HELLMACSPATH's directories
\(colon-separated), as Doom's `doom-cli-load-path' and $DOOMPATH.")

(defconst hellmacs-cli-aliases
  '(("s" . "sync") ("up" . "upgrade") ("doc" . "doctor") ("pf" . "profile")
    ("h" . "help") ("v" . "version"))
  "Short names of commands, as `doom's.")

(defun hellmacs-cli-command-file (command)
  "The file defining COMMAND: bin/hellmacs-COMMAND, else its family's
\(upgrade-self is bin/hellmacs-upgrade's), as Doom v3's bin/doom-COMMAND,
in the first of `hellmacs-cli-load-path' that has it. Nil if there's none."
  (when (string-match-p "\\`[a-z][a-z-]*\\'" command)
    (seq-some (lambda (name)
                (seq-some (lambda (dir)
                            (let ((file (expand-file-name (concat "hellmacs-" name) dir)))
                              (and (file-regular-p file) file)))
                          hellmacs-cli-load-path))
              (list command (car (split-string command "-"))))))

(defvar hellmacs-cli--loaded-commands nil
  "Command files `hellmacs-cli-load' has loaded this session.")

(defun hellmacs-cli-load (&rest commands)
  "Load the file of each of COMMANDS, once; with none, every command's."
  (dolist (file (if commands
                    (mapcar #'hellmacs-cli-command-file commands)
                  (mapcan (lambda (dir) (file-expand-wildcards (expand-file-name "hellmacs-*" dir)))
                          hellmacs-cli-load-path)))
    (when (and file (not (member file hellmacs-cli--loaded-commands)))
      (push file hellmacs-cli--loaded-commands)
      (load file nil 'nomessage 'nosuffix))))

;;; help & dispatch ------------------------------------------------------------

(defun hellmacs-cli-help (&rest _)
  "Print usage."
  (hellmacs-cli--say "\
Usage: bin/hellmacs [OPTIONS] COMMAND [ARGS]

Options (before the command):
  -p, --profile NAME   Act on a named profile: a separate config
                       (~/.config/hellmacs-NAME) with its own packages.
                       Start Emacs on it with `bin/hellmacs -p NAME emacs'.
  --hellmacsdir DIR    Use the config in DIR instead of ~/.config/hellmacs.
  -D, --debug          Debug output, and backtraces on errors.
  -!, --force          Don't ask: accept every prompt.

Commands (short names in brackets):
  install [--[no-]config] [--[no-]env] [--[no-]install] [--from-bundle FILE]
             First-time setup: create your config (~/.config/hellmacs), sync,
             save your shell environment (it asks, unless --env or --no-env),
             then run doctor. --no-install: don't sync yet.
             --from-bundle: install from an offline bundle (see `bundle'),
             checking every file's SHA-256, with no network access at all.
  sync [s]   Install/build every package your modules and packages.el declare,
             and generate the init file Emacs starts from. Run it after
             changing your hellmacs! block, a packages.el or a module's
             autoloads, as `doom sync'.
  upgrade [up] [--packages] [--channel stable|main]
             Update Hellmacs and every unpinned package, then sync. Hellmacs
             moves to its channel's latest: stable, the latest release (the
             default; `hellmacs-upgrade-channel'), or main, the development
             branch. --packages: only update packages.
  emacs [--vanilla] [-- EMACS-ARGS]
             Start Emacs on this Hellmacs (and --profile). --vanilla: Emacs
             with no config at all (emacs -Q), to tell Hellmacs' problems
             from Emacs'.
  profile [pf] list | sync --all
             List the profiles there are, and whether each is synced; or sync
             all of them.
  doctor [doc]
             Check Emacs, tools and your config for problems.
             With --network, also check that the hosts Hellmacs fetches from
             can be reached (always, when a proxy, CA or mirror is set).
  info       Print what a bug report needs: Hellmacs, Emacs, system, config.
  version [v]
             Show Hellmacs' version, its update channel and the Emacs it runs on.
  env [--clear]
             Save your shell's environment (PATH, JAVA_HOME, ...) for Emacs to
             load at startup; --clear removes it.
  gc [-n]    Delete installed packages nothing declares any more.
             -n, --dry-run: only list them.
  lock       Record the exact commit of every package in
             ~/.config/hellmacs/packages.lock.eld; later syncs install those.
  verify     Check that every file sync installed is unchanged (its SHA-256),
             and every package at the commit sync installed (and your lock
             file pins). Fails on any difference.
  bundle OUT.tar.zst [--modules SPEC]
             Sync, then pack everything a sync installs (packages, language
             servers, grammars, the lock file) into one archive, for machines
             without internet. It's for this platform and Emacs version, and
             for your modules, or SPEC's (--modules \":lang java :tools lsp\").
             .tar.gz, .tar.xz and .tar work too.
  sbom [OUT.json]
             Write a CycloneDX (JSON) bill of materials of everything installed:
             packages at their commits, language servers, jars and grammars,
             with their pins and licenses. Without OUT.json, to stdout.
  licenses   List the license of everything installed; fails if one isn't
             known, and flags licenses outside SPDX's list.
  config [--add-defaults]
             List the modules on by default that your hellmacs! block misses
             (made from an older template?); --add-defaults adds them, keeping
             a backup of init.el. Then run sync.
  help [h]   Show this help.

More commands: a hellmacs-NAME file in your config's bin/, or in a directory
on $HELLMACSPATH, is `bin/hellmacs NAME'; and enabled modules add theirs.

Environment: EMACS (Emacs binary), HELLMACSDIR (your config dir),
HELLMACS_PROFILE, HELLMACSPATH, DEBUG, XDG_DATA_HOME, XDG_CACHE_HOME,
XDG_STATE_HOME."))

(defun hellmacs-cli-main ()
  "Run the bin/hellmacs command in `command-line-args-left', then exit."
  (let* ((args (delete "--" (copy-sequence command-line-args-left)))
         (command (pcase (car args)
                    ((or 'nil "-h" "--help") "help")
                    (c (or (cdr (assoc c hellmacs-cli-aliases)) c))))
         fn)
    (setq command-line-args-left nil)
    ;; early-init.el tuned these for an interactive boot, which a batch
    ;; session never finishes, so they'd never be restored.
    (setq file-name-handler-alist hellmacs--file-name-handler-alist
          gc-cons-threshold (* 128 1024 1024)
          gc-cons-percentage 0.1)
    (hellmacs-context-push 'cli)
    ;; Before the config is read: the modules decide which cli.el files load.
    (when (equal command "bundle")
      (condition-case err
          (when-let* ((spec (hellmacs-cli--option args "--modules")))
            (setq hellmacs-modules-override (hellmacs-cli--read-modules spec)))
        (error
         (hellmacs-cli--say "Error: %s" (error-message-string err))
         (kill-emacs 1))))
    ;; Enabled modules may add commands and sync steps (their cli.el).
    (hellmacs-modules-read-config)
    (hellmacs-modules-load-cli-files)
    ;; A module's cli.el may define the command; else it's bin/hellmacs-COMMAND.
    (unless (fboundp (intern-soft (concat "hellmacs-cli-" command)))
      (when-let* ((file (hellmacs-cli-command-file command)))
        (hellmacs-cli-load command)))
    (setq fn (intern-soft (concat "hellmacs-cli-" command)))
    (unless (and fn (fboundp fn) (not (string-prefix-p "-" command)))
      (hellmacs-cli--say "bin/hellmacs: unknown command `%s'\n" command)
      (hellmacs-cli-help)
      (kill-emacs 5))
    (condition-case err
        (progn (apply fn (cdr args))
               (kill-emacs (if (zerop hellmacs-cli--problems) 0 1)))
      (user-error
       (hellmacs-cli--say "Error: %s" (error-message-string err))
       (kill-emacs 6))
      (error
       (hellmacs-cli--say "Error: %s" (error-message-string err))
       (when init-file-debug
         (hellmacs-cli--say "%s" (backtrace-to-string)))
       (kill-emacs 2)))))

(provide 'hellmacs-cli)
;;; hellmacs-cli.el ends here
