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
;; Commands print plain text on stdout and exit 0 on success, 1 on failure.

;;; Code:

(require 'hellmacs-sync)
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

(defun hellmacs-cli-command-file (command)
  "The file defining COMMAND: bin/hellmacs-COMMAND, else its family's
\(upgrade-self is bin/hellmacs-upgrade's), as Doom v3's bin/doom-COMMAND.
Nil if there's none."
  (when (string-match-p "\\`[a-z][a-z-]*\\'" command)
    (seq-some (lambda (name)
                (let ((file (expand-file-name (concat "bin/hellmacs-" name) hellmacs-dir)))
                  (and (file-regular-p file) file)))
              (list command (car (split-string command "-"))))))

(defvar hellmacs-cli--loaded-commands nil
  "Command files `hellmacs-cli-load' has loaded this session.")

(defun hellmacs-cli-load (&rest commands)
  "Load the file of each of COMMANDS, once; with none, every command's."
  (dolist (file (if commands
                    (mapcar #'hellmacs-cli-command-file commands)
                  (file-expand-wildcards (expand-file-name "bin/hellmacs-*" hellmacs-dir))))
    (when (and file (not (member file hellmacs-cli--loaded-commands)))
      (push file hellmacs-cli--loaded-commands)
      (load file nil 'nomessage 'nosuffix))))

;;; help & dispatch ------------------------------------------------------------

(defun hellmacs-cli-help (&rest _)
  "Print usage."
  (hellmacs-cli--say "\
Usage: bin/hellmacs [--profile NAME] COMMAND [OPTIONS]

--profile NAME (or HELLMACS_PROFILE=NAME) acts on a named profile: a
separate config (~/.config/hellmacs-NAME) with its own packages. Start
Emacs on it with `emacs --init-directory DIR --profile NAME'.

Commands:
  install [--env] [--no-config] [--from-bundle FILE]
             First-time setup: create your config (~/.config/hellmacs), sync,
             optionally save your shell environment, then run doctor.
             --from-bundle: install from an offline bundle (see `bundle'),
             checking every file's SHA-256, with no network access at all.
  sync       Install/build every package your modules and packages.el declare,
             and write the profile Emacs starts from. Run it after changing
             your hellmacs! block, a packages.el or a module's autoload.el.
  upgrade [--packages] [--channel stable|main]
             Update Hellmacs and every unpinned package, then sync. Hellmacs
             moves to its channel's latest: stable, the latest release (the
             default; `hellmacs-upgrade-channel'), or main, the development
             branch. --packages: only update packages.
  version    Show Hellmacs' version, its update channel and the Emacs it runs on.
  verify     Check that every file sync installed is unchanged (its SHA-256),
             and every package at the commit sync installed (and your lock
             file pins). Fails on any difference.
  lock       Record the exact commit of every package in
             ~/.config/hellmacs/packages.lock.eld; later syncs install those.
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
  gc [-n]    Delete installed packages nothing declares any more.
             -n, --dry-run: only list them.
  env [--clear]
             Save your shell's environment (PATH, JAVA_HOME, ...) for Emacs to
             load at startup; --clear removes it.
  doctor     Check Emacs, tools and your config for problems.
             With --network, also check that the hosts Hellmacs fetches from
             can be reached (always, when a proxy, CA or mirror is set).
  test [REGEXP]
             Run Hellmacs' own test suites (only tests matching REGEXP),
             in temporary directories.
  help       Show this help.

Environment: EMACS (Emacs binary), HELLMACSDIR (your config dir),
XDG_DATA_HOME, XDG_CACHE_HOME, XDG_STATE_HOME."))

(defun hellmacs-cli-main ()
  "Run the bin/hellmacs command in `command-line-args-left', then exit."
  (let* ((args (delete "--" (copy-sequence command-line-args-left)))
         (command (pcase (car args)
                    ((or 'nil "-h" "--help") "help")
                    (c c)))
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
      (kill-emacs 1))
    (condition-case err
        (progn (apply fn (cdr args))
               (kill-emacs (if (zerop hellmacs-cli--problems) 0 1)))
      (error
       (hellmacs-cli--say "Error: %s" (error-message-string err))
       (kill-emacs 1)))))

(provide 'hellmacs-cli)
;;; hellmacs-cli.el ends here
