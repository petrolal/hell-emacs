;;; hell-cli.el --- The bin/hell command-line tool -*- lexical-binding: t; -*-

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

;; `bin/hell' runs Emacs in batch mode, loads early-init.el and this
;; file, and calls `hell-cli-main' with the command-line arguments.
;; Each command is a `hell-cli-COMMAND' function; see `hell-cli-help'.
;;
;; Commands print plain text on stdout. Exit codes, as `doom's:
;;   0  success
;;   1  no error, but the command couldn't complete (a check failed)
;;   2  an error, inside Hell Emacs or the command
;;   3  a problem with Emacs or the install (bin/hell says which)
;;   5  no such command
;;   6  a wrong, missing or extra option

;;; Code:

(eval-and-compile (hell-require 'hell-cli 'sync))
(eval-and-compile
  (hell-require 'hell-cli 'bundle)
  (hell-require 'hell-cli 'config)
  (hell-require 'hell-cli 'compliance)
  (hell-require 'hell-cli 'verify)
  (hell-require 'hell-cli 'check))

(require 'subr-x)
(declare-function backtrace-to-string "backtrace" (&optional frames))

;;; Output -----------------------------------------------------------------------

(defvar hell-cli--last-topic nil
  "The troubleshooting topic the last warning or error pointed to.")

(defun hell-cli--say (format-string &rest args)
  "Print FORMAT-STRING with ARGS, and a newline, on stdout.
A line that starts with a blank one is a section's heading: the next
warning of a section points to its troubleshooting entry again."
  (when (string-prefix-p "\n" format-string)
    (setq hell-cli--last-topic nil))
  (princ (concat (apply #'format format-string args) "\n")))

(defvar hell-cli--problems 0
  "How many `error'-level results `hell-cli--check' printed.")

(defun hell-cli-doctor-docs (topic)
  "Return where TOPIC's troubleshooting entry is.
That's this checkout's guide, so it matches the Hell Emacs that printed
it, and works offline."
  (format "%s#doctor-%s" (abbreviate-file-name (expand-file-name "docs/guide.md" hell-dir))
          topic))

(defun hell-cli--check (level format-string &rest args)
  "Print a check result. LEVEL is `ok', `warn', `error' or `info'.
FORMAT-STRING and ARGS are as in `format'.
FORMAT-STRING may be preceded by `:topic' and a symbol: a warning or an
error then points to that troubleshooting entry in docs/guide.md
\(\"What doctor's messages mean\"), once for a run of lines on the same
topic."
  (let ((topic nil))
    (when (eq format-string :topic)
      (setq topic (pop args)
            format-string (pop args)))
    (when (eq level 'error) (cl-incf hell-cli--problems))
    (hell-cli--say "  %s %s"
                   (pcase level ('ok "✓") ('warn "!") ('error "✗") (_ "·"))
                       (apply #'format format-string args))
    (if (not (memq level '(warn error)))
        (setq hell-cli--last-topic nil)
      (when (and topic (not (eq topic hell-cli--last-topic)))
        (hell-cli--say "      see %s" (hell-cli-doctor-docs topic)))
      (setq hell-cli--last-topic topic))))

(defcustom hell-cli-jobs 16
  "How many processes `hell-cli--run-all' runs at once."
  :type 'natnum
  :group 'hell)

(defun hell-cli--run-all (commands)
  "Run COMMANDS, each a list (PROGRAM ARG...), up to `hell-cli-jobs' at once.
Return their exit codes, in order (127 when PROGRAM can't be started)."
  (let* ((codes (make-vector (length commands) nil))
         (queue (seq-map-indexed #'cons commands))
         (running 0))
    (while (or queue (> running 0))
      (while (and queue (< running hell-cli-jobs))
        (pcase-let ((`(,command . ,i) (pop queue)))
          (condition-case nil
              (progn
                (make-process :name "hell-job" :command command :noquery t
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

(define-obsolete-function-alias 'hell-cli--run #'hell-process-output "1.1")

;;; Shared by several commands -------------------------------------------------

(defun hell-cli--option (args option)
  "The value following OPTION in ARGS, nil if OPTION isn't there.
An error if it's there without a value."
  (when-let* ((tail (member option args)))
    (let ((value (cadr tail)))
      (when (or (null value) (string-prefix-p "-" value))
        (error "%s needs a value" option))
      value)))

(defun hell-cli--flag (args name)
  "Return whether ARGS turn the flag NAME on, off, or neither.
That's t for --NAME, `no' for --no-NAME, else nil, as Doom's
--flag/--no-flag options."
  (cond ((member (concat "--no-" name) args) 'no)
        ((member (concat "--" name) args) t)))

(defun hell-cli-force-p (&optional args)
  "Non-nil if every prompt is to be accepted: `bin/hell -!' (--force).
That's when ARGS hold -! or --force, or HELL_FORCE is set."
  (or (member (getenv "HELL_FORCE") '("1" "t" "true" "yes"))
      (and args (or (member "-!" args) (member "--force" args)))))

(defun hell-cli--yes-p (prompt &optional default)
  "Ask PROMPT, a yes-or-no question; return non-nil for yes.
Without a person to answer (no terminal), return DEFAULT; with
`bin/hell -!', t."
  (cond ((hell-cli-force-p) t)
        ((not (getenv "__HELLTTY")) default)
        (t (y-or-n-p prompt))))

(defun hell-cli--read-modules (spec)
  "SPEC, the text of a `hell!' block's arguments, as a list."
  (let ((modules (condition-case nil
                     (car (read-from-string (concat "(" spec ")")))
                   (error (error "--modules: can't read %S" spec)))))
    (unless (keywordp (car modules))
      (error "--modules must start with a group, as in \":lang java kotlin :tools lsp\""))
    modules))

(defcustom hell-upgrade-channel 'stable
  "What `bin/hell upgrade' moves Hell Emacs itself to.
Either `stable', the latest release (the tag vMAJOR.MINOR.PATCH), or
`main', the development branch.
`upgrade --channel NAME' overrides it for one run. Set it in your init.el."
  :type '(choice (const stable) (const main))
  :group 'hell)

(defcustom hell-upgrade-verify-tags t
  "Non-nil if the stable channel only checks out signed releases.
That's a release whose tag's signature `git verify-tag' accepts (the
signer's key must be in your keyring). Releases are signed, so it's on;
nil checks out whatever tag the remote has, signed or not."
  :type 'boolean
  :group 'hell)

;;; Commands: bin/hell-COMMAND ------------------------------------------

(defvar hell-cli-commands (make-hash-table :test #'equal)
  "Table of registered CLI commands: NAME -> plist of (:name :fn :doc :args).")

(defmacro defcli! (name arglist &optional docstring &rest body)
  "Define a Hell Emacs CLI command NAME with ARGLIST, DOCSTRING, and BODY.
NAME is a symbol or list of symbols (for subcommands, e.g. `(profile list)')."
  (declare (doc-string 3) (indent defun))
  (let* ((doc (if (stringp docstring) docstring ""))
         (actual-body (if (stringp docstring) body (cons docstring body)))
         (cmd-name (if (consp name)
                       (mapconcat #'symbol-name name " ")
                     (symbol-name name)))
         (fn-name (intern (concat "hell-cli-" (replace-regexp-in-string " " "-" cmd-name)))))
    `(progn
       (defun ,fn-name ,arglist
         ,doc
         ,@actual-body)
       (puthash ,cmd-name
                (list :name ',name
                      :fn ',fn-name
                      :doc ,doc
                      :arglist ',arglist)
                hell-cli-commands))))

(defvar hell-cli-load-path
  (append (list (expand-file-name "bin/" hell-dir)
                (expand-file-name "bin/" hell-user-dir))
          (when-let* ((path (getenv "HELLPATH")))
            (split-string path path-separator t)))
  "Directories searched for hell-COMMAND files, in order, as `$PATH' is.
Hell Emacs' bin/, your config's bin/, then $HELLPATH's directories
\(colon-separated), as Doom's `doom-cli-load-path' and $DOOMPATH.")

(defconst hell-cli-aliases
  '(("s" . "sync") ("up" . "upgrade") ("doc" . "doctor") ("pf" . "profile")
    ("h" . "help") ("v" . "version") ("lint" . "check"))
  "Short names of commands, as `doom's.")

(defun hell-cli-command-file (command)
  "Return the file defining COMMAND.
That's bin/hell-COMMAND, else its family's
\(upgrade-self is bin/hell-upgrade's), as Doom v3's bin/doom-COMMAND,
in the first of `hell-cli-load-path' that has it. Nil if there's none."
  (when (string-match-p "\\`[a-z][a-z-]*\\'" command)
    (seq-some (lambda (name)
                (seq-some (lambda (dir)
                            (let ((file (expand-file-name (concat "hell-" name) dir)))
                              (and (file-regular-p file) file)))
                          hell-cli-load-path))
              (list command (car (split-string command "-"))))))

(defvar hell-cli--loaded-commands nil
  "Command files `hell-cli-load' has loaded this session.")

(defun hell-cli-load (&rest commands)
  "Load the file of each of COMMANDS, once; with none, every command's."
  (dolist (file (if commands
                    (mapcar #'hell-cli-command-file commands)
                  (mapcan (lambda (dir) (file-expand-wildcards (expand-file-name "hell-*" dir)))
                          hell-cli-load-path)))
    (when (and file (not (member file hell-cli--loaded-commands)))
      (push file hell-cli--loaded-commands)
      (load file nil 'nomessage 'nosuffix))))

;;; help & dispatch ------------------------------------------------------------

(defun hell-cli-help (&optional command &rest _)
  "Print usage for COMMAND or overall usage if COMMAND is nil."
  (if (and command (not (string-empty-p command)))
      (let* ((cmd (or (cdr (assoc command hell-cli-aliases)) command))
             (fn (intern-soft (concat "hell-cli-" cmd))))
        (unless (and fn (fboundp fn))
          (hell-cli-load cmd)
          (setq fn (intern-soft (concat "hell-cli-" cmd))))
        (if (and fn (fboundp fn))
            (let ((doc (documentation fn t)))
              (hell-cli--say "Usage: bin/hell %s [OPTIONS] [ARGS]\n" cmd)
              (if (and doc (not (string-empty-p doc)))
                  (hell-cli--say "%s" doc)
                (hell-cli--say "No detailed help available for `%s'." cmd)))
          (hell-cli--say "bin/hell: unknown command `%s'\n" command)
          (hell-cli-help)))
    (hell-cli--say "\
Usage: bin/hell [OPTIONS] COMMAND [ARGS]

Options (before the command):
  -p, --profile NAME   Act on a named profile: a separate config
                       (~/.config/hell-emacs-NAME) with its own packages.
                       Start Emacs on it with `bin/hell -p NAME emacs'.
  --helldir DIR        Use the config in DIR instead of ~/.config/hell-emacs.
  -D, --debug          Debug output, and backtraces on errors.
  -!, --force          Don't ask: accept every prompt.

Commands (short names in brackets):
  install [--[no-]config] [--[no-]env] [--[no-]install] [--aot] [--from-bundle FILE [--sha256 HEX]]
             First-time setup: create your config (~/.config/hell-emacs), sync,
             save your shell environment (it asks, unless --env or --no-env),
             then run doctor. --no-install: don't sync yet.
             --aot: native-compile packages ahead of time.
             --from-bundle: install from an offline bundle (see `bundle'),
             checking every file's SHA-256, with no network access at all;
             --sha256: the SHA-256 `bundle' printed, proving it's that bundle.
  sync [s]   Install/build every package your modules and packages.el declare,
             and generate the init file Emacs starts from. Run it after
             changing your hell! block, a packages.el or a module's
             autoloads, as `doom sync'.
  upgrade [up] [--packages] [--channel stable|main]
             Update Hell Emacs and every unpinned package, then sync. Hell Emacs
             moves to its channel's latest: stable, the latest release (the
             default; `hell-upgrade-channel'), or main, the development
             branch. --packages: only update packages.
  emacs [--vanilla] [--sandbox] [-- EMACS-ARGS]
             Start Emacs on this Hell Emacs (and --profile). --vanilla: Emacs
             with no config at all (emacs -Q), to tell Hell Emacs' problems
             from Emacs'. --sandbox: start in an isolated temporary profile.
  profile [pf] list | sync --all
             List the profiles there are, and whether each is synced; or sync
             all of them.
  doctor [doc]
             Check Emacs, tools and your config for problems.
             With --network, also check that the hosts Hell Emacs fetches from
             can be reached (always, when a proxy, CA or mirror is set).
  info       Print what a bug report needs: Hell Emacs, Emacs, system, config.
  version [v]
             Show Hell Emacs' version, its update channel and the Emacs it runs on.
  env [--clear]
             Save your shell's environment (PATH, JAVA_HOME, ...) for Emacs to
             load at startup; --clear removes it.
  gc [-n]    Delete installed packages nothing declares any more.
             -n, --dry-run: only list them.
  lock       Record the exact commit of every package in
             ~/.config/hell-emacs/packages.lock.eld; later syncs install those.
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
             List the modules on by default that your hell! block misses
             (made from an older template?); --add-defaults adds them, keeping
             a backup of init.el. Then run sync.
  check [lint] [TARGETS...] [-o OUT] [--format FORMAT] [--strict] [--trust]
             Run unified static analysis and linting quality gate across
             detected languages (Clojure, Kotlin, Java, Scala, Groovy,
             Emacs Lisp, Common Lisp), generating diagnostic report.
             Checks that run the project's own code (./gradlew, pre-commit,
             byte-compile...) ask first, or are skipped; --trust runs them.
  help [h] [COMMAND]
             Show this help, or detailed help and options for COMMAND.

More commands: a hell-NAME file in your config's bin/, or in a directory
on $HELLPATH, is `bin/hell NAME'; and enabled modules add theirs.

Environment: EMACS (Emacs binary), HELLDIR (your config dir),
HELL_PROFILE, HELLPATH, DEBUG, XDG_DATA_HOME, XDG_CACHE_HOME,
XDG_STATE_HOME.")))

(defun hell-cli-main ()
  "Run the bin/hell command in `command-line-args-left', then exit."
  (let* ((args (delete "--" (copy-sequence command-line-args-left)))
         (command (pcase (car args)
                    ((or 'nil "-h" "--help") "help")
                    (c (or (cdr (assoc c hell-cli-aliases)) c))))
         fn)
    (setq command-line-args-left nil)
    ;; early-init.el tuned these for an interactive boot, which a batch
    ;; session never finishes, so they'd never be restored.
    (setq file-name-handler-alist hell--file-name-handler-alist
          gc-cons-threshold (* 128 1024 1024)
          gc-cons-percentage 0.1)
    (hell-context-push 'cli)
    ;; If help for a specific command is requested via `help COMMAND' or `COMMAND --help' / `-h':
    (if (equal command "help")
        (let ((subcmd (cadr args)))
          (hell-cli-help subcmd)
          (kill-emacs 0))
      (when (or (member "-h" (cdr args)) (member "--help" (cdr args)))
        (hell-cli-help command)
        (kill-emacs 0)))
    ;; Before the config is read: the modules decide which cli.el files load.
    (when (equal command "bundle")
      (condition-case err
          (when-let* ((spec (hell-cli--option args "--modules")))
            (setq hell-modules-override (hell-cli--read-modules spec)))
        (error
         (hell-cli--say "Error: %s" (error-message-string err))
         (kill-emacs 1))))
    ;; Enabled modules may add commands and sync steps (their cli.el).
    (hell-modules-read-config)
    (hell-modules-load-cli-files)
    ;; A module's cli.el may define the command; else it's bin/hell-COMMAND.
    (unless (fboundp (intern-soft (concat "hell-cli-" command)))
      (when-let* ((file (hell-cli-command-file command)))
        (hell-cli-load command)))
    (setq fn (intern-soft (concat "hell-cli-" command)))
    (unless (and fn (fboundp fn) (not (string-prefix-p "-" command)))
      (hell-cli--say "bin/hell: unknown command `%s'\n" command)
      (hell-cli-help)
      (kill-emacs 5))
    (condition-case err
        (progn (apply fn (cdr args))
               (kill-emacs (if (zerop hell-cli--problems) 0 1)))
      (user-error
       (hell-cli--say "Error: %s" (error-message-string err))
       (kill-emacs 6))
      (error
       (hell-cli--say "Error: %s" (error-message-string err))
       (when init-file-debug
         (require 'backtrace)
         (hell-cli--say "%s" (backtrace-to-string)))
       (kill-emacs 2)))))

(provide 'hell-cli)
;;; hell-cli.el ends here
