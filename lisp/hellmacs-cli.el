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

;;; Output ---------------------------------------------------------------------

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

;;; sync -----------------------------------------------------------------------

(defun hellmacs-cli-sync (&rest _)
  "Install/build every declared package and write the profile."
  (hellmacs-sync))

;;; install --------------------------------------------------------------------

(defun hellmacs-cli--option (args option)
  "The value following OPTION in ARGS, nil if OPTION isn't there.
An error if it's there without a value."
  (when-let* ((tail (member option args)))
    (let ((value (cadr tail)))
      (when (or (null value) (string-prefix-p "-" value))
        (error "%s needs a value" option))
      value)))

(defun hellmacs-cli-install (&rest args)
  "First-time setup: create the user config, sync, optionally save the env.
ARGS may contain --env (also run `env'), --no-config (don't create
the user config directory) and --from-bundle FILE (install from an
offline bundle, with no network access at all)."
  (let* ((bundle (hellmacs-cli--option args "--from-bundle"))
         (hellmacs-net-offline (and bundle t)))
    (hellmacs-cli--say "Setting up Hellmacs in %s%s" (abbreviate-file-name hellmacs-dir)
                       (if bundle ", offline" ""))
    (unless (member "--no-config" args)
      (let ((existed (file-directory-p hellmacs-user-dir)))
        (hellmacs-init-user-dir)
        (hellmacs-cli--say "%s your config in %s"
                           (if existed "Kept" "Created")
                           (abbreviate-file-name hellmacs-user-dir))))
    (when bundle
      ;; Without a config directory, there's nowhere for the lock file:
      ;; the packages stay at the bundle's commits anyway.
      (hellmacs-bundle-install bundle (not (file-directory-p hellmacs-user-dir))))
    (hellmacs-sync)
    (when (member "--env" args)
      (hellmacs-cli-env))
    (hellmacs-cli--say "")
    (hellmacs-cli-doctor)
    (hellmacs-cli--say "\nDone. Start Emacs with:  emacs --init-directory %s"
                       (abbreviate-file-name (directory-file-name hellmacs-dir)))))

;;; bundle -------------------------------------------------------------------

(defun hellmacs-cli--read-modules (spec)
  "SPEC, the text of a `hellmacs!' block's arguments, as a list."
  (let ((modules (condition-case nil
                     (car (read-from-string (concat "(" spec ")")))
                   (error (error "--modules: can't read %S" spec)))))
    (unless (keywordp (car modules))
      (error "--modules must start with a group, as in \":lang java kotlin :tools lsp\""))
    modules))

(defun hellmacs-cli-bundle (&rest args)
  "Sync, then pack everything installed into an offline bundle.
ARGS: the bundle's file name, and optionally --modules SPEC (read
before this runs, by `hellmacs-cli-main')."
  (let* ((spec (hellmacs-cli--option args "--modules"))
         (files (remove spec (seq-remove (lambda (a) (string-prefix-p "-" a)) args)))
         (out (car files)))
    (unless (and out (null (cdr files)))
      (error "Usage: bin/hellmacs bundle OUT.tar.zst [--modules SPEC]"))
    (hellmacs-sync)
    (hellmacs-cli--say "Packing the bundle...")
    (let ((manifest (hellmacs-bundle-create out)))
      (hellmacs-cli--say "Bundled %d files (%s before compression) into %s"
                         (cl-count :file (plist-get manifest :entries) :key #'cadr)
                         (file-size-human-readable (hellmacs-bundle-size manifest))
                         (abbreviate-file-name (expand-file-name out)))
      (hellmacs-cli--say "  For %s, Emacs %s; modules: %s"
                         (plist-get manifest :platform) emacs-major-version
                         (mapconcat (lambda (m) (hellmacs-bundle--module-string (car m) (cadr m)))
                                    (plist-get manifest :modules) ", "))
      (hellmacs-cli--say "  SHA-256: %s" (hellmacs-file-sha256 out))
      (hellmacs-cli--say "Install it with:  bin/hellmacs install --from-bundle %s" (file-name-nondirectory out))
      (when spec
        (hellmacs-cli--say "\nNote: this machine's profile is now synced for those modules; \
`bin/hellmacs sync' goes back to yours. (`bin/hellmacs --profile NAME bundle ...' keeps them apart.)")))))

;;; env ------------------------------------------------------------------------

(defvar hellmacs-env-deny
  '("^DBUS_SESSION_BUS_ADDRESS$" "^GPG_AGENT_INFO$" "^\\(SSH\\|GPG\\)_TTY$"
    "^SSH_\\(AUTH_SOCK\\|AGENT_PID\\|CLIENT\\|CONNECTION\\)$"
    "^DISPLAY$" "^WAYLAND_DISPLAY$" "^XAUTHORITY$" "^XDG_SESSION_\\|^XDG_VTNR$"
    "^TERM$" "^TERM_PROGRAM" "^COLORTERM$" "^COLUMNS$" "^LINES$"
    "^INSIDE_EMACS$" "^EMACS" "^TMUX" "^STY$" "^WINDOWID$"
    "^PWD$" "^OLDPWD$" "^SHLVL$" "^_$" "^HOME$" "^R_SESSION_TMPDIR$"
    ;; Which Hellmacs config the command ran on: saved, it would send any
    ;; bin/hellmacs run from inside Emacs to that one.
    "^HELLMACS_PROFILE$" "^HELLMACSDIR$"
    ;; Secrets: the file is plain text, and every process Emacs starts
    ;; would get them.
    "TOKEN" "SECRET" "PASSWORD" "PASSWD" "PASSPHRASE" "CREDENTIAL"
    "API_?KEY" "PRIVATE_?KEY")
  "Regexps of variables `bin/hellmacs env' never saves.
They describe the terminal or session the command ran in, not your
shell setup, and would be wrong -- or harmful -- inside Emacs later;
or they look like secrets (tokens, passwords, API keys), which don't
belong in a saved file. Matched against the name, ignoring case.")

(defun hellmacs-cli-env (&rest args)
  "Save the current shell environment for Emacs to load at startup.
With --clear in ARGS, delete the saved environment instead."
  (if (member "--clear" args)
      (progn
        (when (file-exists-p hellmacs-env-file)
          (delete-file hellmacs-env-file))
        (hellmacs-cli--say "Removed the saved environment (%s)"
                           (abbreviate-file-name hellmacs-env-file)))
    (let ((vars (seq-remove
                 (lambda (entry)
                   (let ((name (car (split-string entry "=")))
                         (case-fold-search t))
                     (seq-some (lambda (re) (string-match-p re name)) hellmacs-env-deny)))
                 ;; `initial-environment' is what bin/hellmacs was run with,
                 ;; before Emacs (or early-init.el) changed anything.
                 initial-environment)))
      (make-directory (file-name-directory hellmacs-env-file) t)
      ;; Yours alone to read, even an older file written before.
      (when (file-exists-p hellmacs-env-file)
        (set-file-modes hellmacs-env-file #o600))
      (with-file-modes #o600
        (with-temp-file hellmacs-env-file
          (insert ";; -*- mode: lisp-data -*-\n"
                  ";; Saved by `bin/hellmacs env' on " (format-time-string "%F %T")
                  ". Re-run it after changing your shell's environment.\n")
          (let ((print-escape-newlines t))
            (prin1 (sort vars #'string<) (current-buffer)))
          (insert "\n")))
      (hellmacs-cli--say "Saved %d environment variables to %s (PATH has %d entries)"
                         (length vars) (abbreviate-file-name hellmacs-env-file)
                         (length (parse-colon-path (getenv "PATH")))))))

;;; lock -----------------------------------------------------------------------

(defun hellmacs-cli--write-lock ()
  "Write `hellmacs-lock-file' for every package Elpaca has queued."
  (defvar elpaca-lock-file-functions)
  (let ((elpaca-lock-file-functions nil)) ; lock everything, not just init-time orders
    (make-directory (file-name-directory hellmacs-lock-file) t)
    (elpaca-write-lock-file hellmacs-lock-file))
  (hellmacs-cli--say "Locked %d packages in %s"
                     (length (elpaca--queued)) (abbreviate-file-name hellmacs-lock-file)))

(defun hellmacs-cli-lock (&rest _)
  "Sync, then record the exact commit of every installed package."
  (hellmacs-sync)
  (hellmacs-cli--write-lock))

;;; sbom and licenses -----------------------------------------------------------

(defun hellmacs-cli-sbom (&rest args)
  "Write a CycloneDX bill of materials of everything installed.
ARGS: the file to write it to; without one, it goes to stdout."
  (let ((files (seq-remove (lambda (a) (string-prefix-p "-" a)) args)))
    (when (cdr files)
      (error "Usage: bin/hellmacs sbom [OUT.json]"))
    (let* ((components (hellmacs-compliance-components))
           (json (let ((json-encoding-pretty-print t))
                   (json-encode (hellmacs-compliance-cyclonedx-sbom components)))))
      (if-let* ((out (car files)))
          (progn
            (with-temp-file out (insert json "\n"))
            (hellmacs-cli--say "Wrote %d components to %s" (length components)
                               (abbreviate-file-name (expand-file-name out))))
        (hellmacs-cli--say "%s" json)))))

(defun hellmacs-cli--component-label (c)
  "C's name and version, a package's commit shortened, and its kind."
  (let ((version (or (plist-get c :version) "")))
    (format "%s %s (%s)" (plist-get c :name)
            (if (eq (plist-get c :kind) 'package) (truncate-string-to-width version 12) version)
            (plist-get c :kind))))

(defun hellmacs-cli-licenses (&rest _)
  "List the license of everything installed; fail if one isn't known."
  (let* ((components (sort (hellmacs-compliance-components)
                           (lambda (a b)
                             (let ((la (or (plist-get a :license) "")) (lb (or (plist-get b :license) "")))
                               (if (equal la lb)
                                   (string< (plist-get a :name) (plist-get b :name))
                                 (string< la lb))))))
         (known (seq-filter (lambda (c) (plist-get c :license)) components))
         (width (apply #'max 10 (mapcar (lambda (c) (length (plist-get c :license))) known)))
         (problems (hellmacs-compliance-license-problems components)))
    (hellmacs-cli--say "Licenses of what's installed (%d components):" (length components))
    (dolist (c known)
      (hellmacs-cli--say "  %s  %s" (string-pad (plist-get c :license) width)
                         (hellmacs-cli--component-label c)))
    (hellmacs-cli--say "\nBy license:")
    (dolist (group (seq-group-by (lambda (c) (or (plist-get c :license) "UNKNOWN")) components))
      (hellmacs-cli--say "  %s  %d" (string-pad (car group) width) (length (cdr group))))
    (when problems
      (hellmacs-cli--say "\nTo look at:")
      (pcase-dolist (`(,c . ,why) problems)
        (pcase why
          ('unknown
           (hellmacs-cli--check 'error "%s: no license found in its headers, LICENSE file or declaration"
                                (hellmacs-cli--component-label c)))
          ('unlisted
           (hellmacs-cli--check 'warn "%s: %s, not on SPDX's list: check its terms before you ship it"
                                (hellmacs-cli--component-label c) (plist-get c :license))))))))

;;; upgrade --------------------------------------------------------------------

(defvar hellmacs-upgrade-channel 'stable
  "What `bin/hellmacs upgrade' moves Hellmacs itself to: `stable', the latest
release (the tag vMAJOR.MINOR.PATCH), or `main', the development branch.
`upgrade --channel NAME' overrides it for one run. Set it in your init.el.")

(defvar hellmacs-upgrade-verify-tags nil
  "Non-nil: the stable channel only checks out a release whose tag's signature
`git verify-tag' accepts (the signer's key must be in your keyring).")

(defun hellmacs-cli--latest-release (tags)
  "The highest release among TAGS, vMAJOR.MINOR.PATCH by version; nil if none.
Pre-releases (v1.0.0-rc.1) and other tags don't count."
  (car (sort (seq-filter (lambda (tag) (string-match-p "\\`v[0-9]+\\.[0-9]+\\.[0-9]+\\'" tag)) tags)
             (lambda (a b) (version-list-< (version-to-list (substring b 1))
                                           (version-to-list (substring a 1)))))))

(defun hellmacs-cli--upgrade-to-release (git)
  "Check out the latest release: the stable channel.
GIT runs git in `hellmacs-dir'."
  (let ((fetch (with-hellmacs-network (funcall git "fetch" "--quiet" "--tags" "origin"))))
    (unless (zerop (car fetch))
      (error "git fetch failed in %s:\n%s" hellmacs-dir (cdr fetch))))
  (let* ((tags (split-string (cdr (funcall git "tag" "--list" "v*")) "\n" t))
         (release (hellmacs-cli--latest-release tags))
         (current (let ((exact (funcall git "describe" "--tags" "--exact-match")))
                    (and (zerop (car exact)) (cdr exact))))
         (before (truncate-string-to-width (cdr (funcall git "rev-parse" "HEAD")) 7)))
    (cond
     ((null release)
      (hellmacs-cli--say "Hellmacs has no release yet on the stable channel; staying at %s. \
`upgrade --channel main' follows the development branch." before)
      nil)
     ((equal current release)
      (hellmacs-cli--say "Hellmacs is already on its latest release, %s." release))
     (t
      (when hellmacs-upgrade-verify-tags
        (let ((verify (funcall git "verify-tag" release)))
          (unless (zerop (car verify))
            (error "Release %s isn't signed by a key you trust (`hellmacs-upgrade-verify-tags'); not checked out:\n%s"
                   release (cdr verify)))))
      (let ((checkout (funcall git "checkout" "--quiet" release)))
        (unless (zerop (car checkout))
          (error "git checkout %s failed in %s:\n%s" release hellmacs-dir (cdr checkout))))
      (hellmacs-cli--say "Hellmacs is on release %s (it was at %s)." release (or current before))))))

(defun hellmacs-cli--upgrade-to-main (git)
  "Pull the development branch (main channel), GIT running git in `hellmacs-dir'.
From a release (a detached HEAD), the branch is checked out first."
  (unless (zerop (car (funcall git "symbolic-ref" "-q" "HEAD")))
    (let* ((head (funcall git "symbolic-ref" "--short" "refs/remotes/origin/HEAD"))
           (branch (if (zerop (car head)) (string-remove-prefix "origin/" (cdr head)) "main"))
           (checkout (funcall git "checkout" "--quiet" branch)))
      (unless (zerop (car checkout))
        (error "git checkout %s failed in %s:\n%s" branch hellmacs-dir (cdr checkout)))))
  (if (not (zerop (car (funcall git "rev-parse" "--abbrev-ref" "@{upstream}"))))
      (progn (hellmacs-cli--say "Hellmacs' branch has no upstream to pull from; skipping its update.") nil)
    (let ((before (cdr (funcall git "rev-parse" "HEAD")))
          (pull (with-hellmacs-network (funcall git "pull" "--ff-only"))))
      (unless (zerop (car pull))
        (error "git pull failed in %s:\n%s" hellmacs-dir (cdr pull)))
      (let ((after (cdr (funcall git "rev-parse" "HEAD"))))
        (hellmacs-cli--say (if (equal before after)
                               "Hellmacs is already up to date."
                             (format "Updated Hellmacs %s -> %s"
                                     (truncate-string-to-width before 7)
                                     (truncate-string-to-width after 7))))))))

(defun hellmacs-cli-upgrade-self (&rest args)
  "Move Hellmacs itself to its channel's latest, with git, when that's safe.
ARGS may hold --channel stable|main (default `hellmacs-upgrade-channel').
Run by `bin/hellmacs upgrade' first, so the package update that follows
runs the new code."
  (let ((channel (if-let* ((name (hellmacs-cli--option args "--channel"))) (intern name) hellmacs-upgrade-channel))
        (git (lambda (&rest args) (apply #'hellmacs-cli--run "git" "-C" hellmacs-dir args))))
    (unless (memq channel '(stable main))
      (error "No channel `%s': it's stable (the latest release) or main" channel))
    (cond
     ((not (zerop (car (funcall git "rev-parse" "--git-dir"))))
      (hellmacs-cli--say "Hellmacs isn't a git checkout; skipping its update.") nil)
     ((not (string-empty-p (cdr (funcall git "status" "--porcelain" "--untracked-files=no"))))
      (hellmacs-cli--say "Hellmacs has uncommitted changes; skipping its update.") nil)
     ((eq channel 'stable) (hellmacs-cli--upgrade-to-release git))
     (t (hellmacs-cli--upgrade-to-main git)))))

;;; verify -------------------------------------------------------------------

(defun hellmacs-cli-verify (&rest _)
  "Check that everything sync installed is still as it left it.
And as the lock file pins it. Every installed file against the SHA-256 sync recorded, every package
against its commit (and your lock file); fails on any difference."
  (let* ((manifest (hellmacs-profile-file "installed.eld"))
         (lock (and (file-exists-p hellmacs-lock-file) hellmacs-lock-file))
         (problems (hellmacs-verify-problems manifest lock)))
    (if problems
        (progn
          (hellmacs-cli--say "Not as sync installed it:")
          (dolist (problem problems)
            (hellmacs-cli--check 'error "%s" problem))
          (hellmacs-cli--say "Delete what changed (a server's directory, a jar) and run `bin/hellmacs sync': \
it reinstalls what's missing. Undo a package's local changes with git, in its directory."))
      (pcase-let ((`(,files . ,packages) (hellmacs-verify-summary manifest)))
        (hellmacs-cli--check 'ok "%d files and %d package%s are as sync installed them%s"
                             files packages (if (= packages 1) "" "s")
                             (if lock ", and as your lock file pins them" ""))))))

;;; version --------------------------------------------------------------------

(defun hellmacs-cli-version (&rest _)
  "Say Hellmacs' version (and its commit), its update channel and Emacs'."
  (let ((described (hellmacs-cli--run "git" "-C" hellmacs-dir "describe" "--tags" "--always" "--dirty")))
    (hellmacs-cli--say "Hellmacs %s%s" hellmacs-version
                       (if (zerop (car described)) (format " (%s)" (cdr described)) "")))
  (hellmacs-cli--say "Update channel: %s (`hellmacs-upgrade-channel')" hellmacs-upgrade-channel)
  (hellmacs-cli--say "Emacs %s on %s" emacs-version system-configuration))

(defun hellmacs-cli--detached (packages)
  "The Elpaca records among PACKAGES whose git checkout is on a detached HEAD.
Asks every checkout at once (`git symbolic-ref': 1 when detached, 128
when it isn't a git checkout at all)."
  (let* ((present (seq-filter (lambda (e) (file-directory-p (elpaca<-source-dir e))) packages))
         (codes (hellmacs-cli--run-all
                 (mapcar (lambda (e) (list "git" "-C" (elpaca<-source-dir e) "symbolic-ref" "-q" "HEAD"))
                         present))))
    (cl-loop for e in present for code in codes
             when (eql code 1) collect e)))

(defun hellmacs-cli--reattach (e)
  "Put package E's detached git checkout back on its branch.
Installing at an exact commit (from the lock file) leaves the checkout
on a detached HEAD, which has no upstream to update from."
  (let* ((dir (elpaca<-source-dir e))
         (git (lambda (&rest args) (apply #'hellmacs-cli--run "git" "-C" dir args))))
    (let ((branch (or (plist-get (elpaca<-recipe e) :branch)
                      (let ((head (funcall git "symbolic-ref" "--short" "refs/remotes/origin/HEAD")))
                        (and (zerop (car head))
                             (string-remove-prefix "origin/" (cdr head)))))))
      (unless (and branch (zerop (car (funcall git "checkout" "-q" branch))))
        (hellmacs-cli--say "  ! couldn't find the branch of %s; leaving it at its current commit"
                           (elpaca<-id e))))))

(defun hellmacs-cli-upgrade (&rest _)
  "Update every unpinned package, then re-sync.
`bin/hellmacs upgrade' runs `upgrade-self' before this, unless given
--packages. Rewrites the lock file if you have one."
  (let ((locked (file-exists-p hellmacs-lock-file)))
    (hellmacs-sync--log "Reading modules and packages...")
    (hellmacs-modules-read-config)
    (with-hellmacs-network
      (hellmacs-cli--upgrade-packages))
    (when locked
      (hellmacs-cli--write-lock))
    ;; New default modules come with updates; your block may miss them.
    (when-let* ((lines (hellmacs-config-report-lines)))
      (hellmacs-cli--say "")
      (mapc (lambda (line) (hellmacs-cli--say "%s" line)) lines))))

(defun hellmacs-cli--upgrade-packages ()
  "Fetch and merge every unpinned package, then write the profile. For `upgrade'."
  (hellmacs-packages-bootstrap)
  (hellmacs-sync--check-elpaca)
  ;; Install from the lock first, so upgrading starts from what's locked.
  (hellmacs-modules-install-packages)
  (let ((pinned (cl-loop for (name . plist) in hellmacs-packages
                         when (plist-get plist :pin) collect name))
        (ids (mapcar #'car (elpaca--queued))))
    (hellmacs-sync--log "Updating %d packages%s..."
                        (- (length ids) (length pinned))
                        (if pinned (format " (%d pinned, skipped)" (length pinned)) ""))
    (let ((ids (seq-remove (lambda (id) (memq id pinned)) ids)))
      ;; Usually none is detached (only after installing from the lock):
      ;; every checkout is asked at once, and only those are fixed.
      (mapc #'hellmacs-cli--reattach
            (hellmacs-cli--detached (delq nil (mapcar #'elpaca-get ids))))
      (dolist (id ids)
        (elpaca-merge id 'fetch)))
    (elpaca-process-queues)
    (hellmacs--elpaca-wait))
  (hellmacs-sync--check-failures)
  (hellmacs-sync--log "Synced %d packages" (length (hellmacs-sync--write-profile)))
  (hellmacs-verify-record-installed))

;;; config -------------------------------------------------------------------

(defun hellmacs-cli-config (&rest args)
  "List the default modules your `hellmacs!' block misses.
With --add-defaults in ARGS, add them (keeping a backup of init.el)."
  (if (not (member "--add-defaults" args))
      (if-let* ((lines (hellmacs-config-report-lines)))
          (mapc (lambda (line) (hellmacs-cli--say "%s" line)) lines)
        (hellmacs-cli--say "Your hellmacs! block has every module that's on by default."))
    (if-let* ((added (hellmacs-config-add-defaults)))
        (progn
          (hellmacs-cli--say "Added %d modules to %s (the old one is %s):"
                             (length added)
                             (abbreviate-file-name (expand-file-name "init.el" hellmacs-user-dir))
                             (file-name-nondirectory hellmacs-config-last-backup))
          (dolist (m added)
            (hellmacs-cli--say "  %s" (string-trim (cdr m))))
          (hellmacs-cli--say "Now run `bin/hellmacs sync' to install them."))
      (hellmacs-cli--say "Nothing to add: your hellmacs! block has every module that's on by default."))))

;;; gc -------------------------------------------------------------------------

(defun hellmacs-cli-gc (&rest args)
  "Delete installed packages nothing declares any more.
With -n or --dry-run in ARGS, only list them."
  (let ((dry-run (or (member "-n" args) (member "--dry-run" args))))
    (hellmacs-sync)
    (let* ((keep (cl-loop for (_ . e) in (elpaca--queued)
                          collect (file-name-as-directory (elpaca<-build-dir e))
                          collect (file-name-as-directory (elpaca<-source-dir e))))
           (orphans (cl-loop for root in (list elpaca-builds-directory elpaca-sources-directory)
                             when (file-directory-p root)
                             append (cl-loop for dir in (directory-files root t "\\`[^.]")
                                             for d = (file-name-as-directory dir)
                                             when (and (file-directory-p d) (not (member d keep)))
                                             collect d))))
      (if (null orphans)
          (hellmacs-cli--say "Nothing to clean up.")
        (dolist (dir orphans)
          (hellmacs-cli--say "%s %s" (if dry-run "Would delete" "Deleting")
                             (abbreviate-file-name (directory-file-name dir)))
          (unless dry-run
            (delete-directory dir 'recursive)))
        (hellmacs-cli--say "%s %d orphaned package directories."
                           (if dry-run "Found" "Deleted") (length orphans))))))

;;; test -----------------------------------------------------------------------

(defun hellmacs-cli-test (&rest args)
  "Run Hellmacs' test suites (test/test-*.el) with ERT, then exit.
ARGS, if any, is an ERT selector regexp: only matching tests run.
bin/hellmacs points every Hellmacs directory at a temporary one first."
  (require 'ert)
  (let ((dir (expand-file-name "test/" hellmacs-dir)))
    (add-to-list 'load-path dir)
    (dolist (file (directory-files dir t "\\`test-.*\\.el\\'"))
      (load file nil 'nomessage))
    ;; Exits Emacs itself, with a failing status if any test failed.
    (ert-run-tests-batch-and-exit (if args (car args) t))))

;;; doctor ---------------------------------------------------------------------

(defun hellmacs-cli--version (program &rest args)
  "Return the first line PROGRAM prints for ARGS, or nil if it isn't installed."
  (when (executable-find program)
    (car (split-string (cdr (apply #'hellmacs-cli--run program args)) "\n"))))

;; The API a module's doctor.el uses.

(defun hellmacs-doctor-ok (format-string &rest args)
  "Report a passing check (FORMAT-STRING, ARGS) from a module's doctor.el."
  (apply #'hellmacs-cli--check 'ok format-string args))

(defun hellmacs-doctor-info (format-string &rest args)
  "Report a neutral fact (FORMAT-STRING, ARGS) from a module's doctor.el."
  (apply #'hellmacs-cli--check 'info format-string args))

(defun hellmacs-doctor-warn (format-string &rest args)
  "Report something optional that's missing (FORMAT-STRING, ARGS)."
  (apply #'hellmacs-cli--check 'warn format-string args))

(defun hellmacs-doctor-error (format-string &rest args)
  "Report a problem that breaks the module (FORMAT-STRING, ARGS).
Makes `bin/hellmacs doctor' exit with a failure."
  (apply #'hellmacs-cli--check 'error format-string args))

(defun hellmacs-doctor-executable (program why &optional required &rest version-args)
  "Check that PROGRAM is on the PATH; WHY says what it's needed for.
If found, show its version (running it with VERSION-ARGS) or its path.
If missing, warn -- or report an error if REQUIRED is non-nil.
Returns PROGRAM's path, or nil."
  (if-let* ((path (executable-find program)))
      (progn (hellmacs-doctor-ok "%s: %s" program
                                 (or (and version-args (apply #'hellmacs-cli--version program version-args))
                                     (abbreviate-file-name path)))
             path)
    (funcall (if required #'hellmacs-doctor-error #'hellmacs-doctor-warn)
             "%s not found -- %s" program why)
    nil))

(defun hellmacs-doctor-node (why min-major)
  "Check Node.js and npm, which WHY needs (a server installed with npm).
MIN-MAJOR is the oldest Node release it runs on. Errors when missing or
too old: the server can't be installed or started without it."
  (let ((node (executable-find "node")))
    (if (not node)
        (hellmacs-doctor-error "node not found -- %s is an npm package; install Node.js %d+" why min-major)
      (let* ((version (or (hellmacs-cli--version "node" "--version") ""))
             (major (and (string-match "\\`v?\\([0-9]+\\)" version)
                         (string-to-number (match-string 1 version)))))
        (if (and major (< major min-major))
            (hellmacs-doctor-error "Node %s is too old for %s (it needs %d+)" version why min-major)
          (hellmacs-doctor-ok "node: %s" version)))
      (unless (executable-find "npm")
        (hellmacs-doctor-error "npm not found -- `bin/hellmacs sync' installs %s with it" why)))))

(cl-defun hellmacs-doctor-pinned (label version valid present &key where stale-note missing-note)
  "Check the pinned install of LABEL (release VERSION) that sync makes.
VALID is non-nil if it's the pinned release; PRESENT, if something is
installed at all. WHERE, the install directory, is shown when it's valid.
STALE-NOTE and MISSING-NOTE are appended to the error and warning."
  (cond (valid
         (if where
             (hellmacs-doctor-ok "%s %s installed in %s" label version (abbreviate-file-name where))
           (hellmacs-doctor-ok "%s %s installed" label version)))
        (present
         (hellmacs-doctor-error "The installed %s isn't the pinned %s%s; `bin/hellmacs sync' replaces it"
                                label version (or stale-note "")))
        (t
         (hellmacs-doctor-warn "%s isn't installed yet; `bin/hellmacs sync' installs it%s"
                               label (or missing-note "")))))

;; Hellmacs never installs fonts (it writes only to its own directories),
;; so a missing Nerd Font is reported with the command that installs one.
(defun hellmacs-doctor-nerd-font (consequence)
  "Check that a Nerd Font is installed; CONSEQUENCE says what happens without."
  (if (not (executable-find "fc-list"))
      (hellmacs-doctor-info "fc-list not found; can't tell whether a Nerd Font is installed")
    (if-let* ((families (ignore-errors
                          (process-lines "fc-list" ":charset=f07b" "family"))))
        (hellmacs-doctor-ok "Nerd Font glyphs: %s" (car (split-string (car families) ",")))
      (hellmacs-doctor-warn "No Nerd Font installed: %s. Install one with M-x nerd-icons-install-fonts (into ~/.local/share/fonts), or from your distribution"
                            consequence))))

(defun hellmacs-doctor-treesit (lang)
  "Check what building and loading LANG's tree-sitter grammar needs.
Run for every grammar a module declares (`hellmacs-treesit!')."
  (if (not (and (fboundp 'treesit-available-p) (treesit-available-p)))
      (hellmacs-doctor-error "This Emacs has no tree-sitter support, which +tree-sitter needs")
    (if (hellmacs-treesit-installed-p lang)
        (hellmacs-doctor-ok "tree-sitter %s grammar: %s" lang
                            (abbreviate-file-name (hellmacs-treesit-library lang)))
      (if (file-exists-p (hellmacs-treesit-library lang))
          (hellmacs-doctor-warn "The tree-sitter %s grammar isn't the pinned commit; `bin/hellmacs sync' rebuilds it" lang)
        (hellmacs-doctor-warn "The tree-sitter %s grammar isn't built yet; `bin/hellmacs sync' builds it" lang))
      (unless (executable-find "git")
        (hellmacs-doctor-error "git is needed to fetch the %s grammar" lang))
      (unless (seq-some #'executable-find '("cc" "gcc" "clang"))
        (hellmacs-doctor-error "No C compiler (cc, gcc or clang) to build the %s grammar" lang)))))

;;; The network --------------------------------------------------------------

(declare-function url-host "url-parse")

(defvar hellmacs-cli--probe-network nil
  "Non-nil while doctor checks that hosts can be reached.
On with --network, or whenever a proxy, CA bundle or mirror is set.")

(defvar hellmacs-cli--probed nil
  "(URL . RESULT) of the hosts this doctor run probed, so each is probed once.")

(defun hellmacs-cli--redact (url)
  "URL without its password."
  (replace-regexp-in-string "\\(//[^:/@]+\\):[^@/]*@" "\\1:***@" url))

(defun hellmacs-doctor-reachable (url why)
  "Check that URL's host can be reached; WHY says what it's needed for.
It is probed as Hellmacs' fetches reach it (`hellmacs-net-probe'): its
mirror, the proxy, the CAs. Only when doctor checks the network."
  (when hellmacs-cli--probe-network
    (require 'url-parse)
    (let* ((target (hellmacs-net-rewrite url))
           (host (url-host (url-generic-parse-url target)))
           (result (if-let* ((cached (assoc target hellmacs-cli--probed)))
                       (cdr cached)
                     (cdr (car (push (cons target (hellmacs-net-probe target)) hellmacs-cli--probed)))))
           (proxy (and (hellmacs-net--proxied-p host) (hellmacs-cli--redact (hellmacs-net-proxy)))))
      (pcase result
        ('nil (hellmacs-doctor-ok "Reaches %s%s (%s)" host (if proxy " through the proxy" "") why))
        (`(tls . ,message)
         (hellmacs-doctor-error "%s's certificate isn't trusted: %s. %s" host message
                                (if hellmacs-ca-bundle
                                    (format "The CA that signs it is missing from `hellmacs-ca-bundle' (%s)"
                                            (abbreviate-file-name hellmacs-ca-bundle))
                                  "If your network inspects TLS, set `hellmacs-ca-bundle' to your company's CA (a PEM file)")))
        (`(proxy . ,message)
         (hellmacs-doctor-error "Can't reach %s through the proxy %s: %s" host proxy message))
        (`(,_ . ,message)
         (hellmacs-doctor-error "Can't reach %s (%s): %s%s" host why message
                                (if (hellmacs-net-proxy) "" "; behind a proxy, set `hellmacs-proxy'")))))))

(defun hellmacs-cli--package-hosts ()
  "The hosts the installed packages are fetched from, as \"https://HOST/\" URLs."
  (let (hosts)
    (dolist (config (file-expand-wildcards (expand-file-name "*/.git/config" elpaca-sources-directory)))
      (with-temp-buffer
        (insert-file-contents config)
        (when (re-search-forward "^[ \t]*url = \\(https?://[^/\n]+/\\)" nil t)
          (cl-pushnew (match-string 1) hosts :test #'equal))))
    (sort hosts #'string<)))

(defun hellmacs-cli--doctor-network ()
  "Report the proxy, CA and mirrors in use, and check the package hosts."
  (hellmacs-cli--say "\nNetwork")
  (if-let* ((proxy (hellmacs-net-proxy)))
      (progn
        (hellmacs-doctor-info "Proxy: %s (%s)" (hellmacs-cli--redact proxy)
                              (if hellmacs-proxy "`hellmacs-proxy'" "from the environment"))
        (when-let* ((hosts (hellmacs-net-no-proxy)))
          (hellmacs-doctor-info "Reached directly: %s" (string-join hosts ", "))))
    (hellmacs-doctor-info "No proxy"))
  (when hellmacs-ca-bundle
    (let ((ca (expand-file-name hellmacs-ca-bundle)))
      (if (not (file-readable-p ca))
          (hellmacs-doctor-error "`hellmacs-ca-bundle' is %s, which can't be read" (abbreviate-file-name ca))
        (let ((count (length (hellmacs-net--pem-certificates ca))))
          (if (zerop count)
              (hellmacs-doctor-error "`hellmacs-ca-bundle' (%s) holds no PEM certificate" (abbreviate-file-name ca))
            (hellmacs-doctor-ok "Corporate CA: %s (%d certificate%s)" (abbreviate-file-name ca)
                                count (if (= count 1) "" "s"))))
        (if (hellmacs-net-truststore-current-p)
            (hellmacs-doctor-ok "JVM truststore: %s" (abbreviate-file-name hellmacs-net-truststore))
          (hellmacs-doctor-warn "The JVM truststore isn't built or is older than your CA; `bin/hellmacs sync' builds it")))))
  (pcase-dolist (`(,from . ,to) hellmacs-mirrors)
    (hellmacs-doctor-info "Mirror: %s -> %s" from to))
  (cond
   (hellmacs-net-offline
    (hellmacs-doctor-info "Hosts not checked (an offline install)"))
   ((not hellmacs-cli--probe-network)
    (hellmacs-doctor-info "Hosts not checked (no proxy, CA or mirror set); `bin/hellmacs doctor --network' checks them"))
   (t
    (dolist (url (or (hellmacs-cli--package-hosts) '("https://github.com/")))
      (hellmacs-doctor-reachable url "packages")))))

(defun hellmacs-cli--wsl-p ()
  "Non-nil if running inside Windows Subsystem for Linux (WSL)."
  (and (eq system-type 'gnu/linux)
       (or (file-exists-p "/proc/sys/fs/binfmt_misc/WSLInterop")
           (string-match-p "Microsoft\\|WSL" (or (ignore-errors (operating-system-release)) "")))))

(defun hellmacs-cli--doctor-platform ()
  "Check and report platform-specific considerations (WSL, macOS, Linux)."
  (cond
   ((hellmacs-cli--wsl-p)
    (hellmacs-cli--check 'ok "Platform: Linux under Windows WSL2")
    (when (or (string-prefix-p "/mnt/" (expand-file-name hellmacs-dir))
              (string-prefix-p "/mnt/" (expand-file-name hellmacs-user-dir)))
      (hellmacs-cli--check 'warn "Hellmacs or config is on a Windows mount (/mnt/...). Store them on the Linux filesystem (~/...) for native performance")))
   ((eq system-type 'darwin)
    (hellmacs-cli--check 'ok "Platform: macOS (%s)" (or (and (boundp 'system-configuration) system-configuration) "darwin"))
    (unless (file-exists-p hellmacs-env-file)
      (hellmacs-cli--check 'info "macOS GUI launchers need shell PATH; run `bin/hellmacs env' if GUI Emacs can't find tools")))
   (t
    (hellmacs-cli--check 'ok "Platform: %s (%s)" (symbol-name system-type) (or (and (boundp 'system-configuration) system-configuration) "unix")))))

(defun hellmacs-cli-doctor (&rest args)
  "Check Emacs, required and optional tools, and the state of the config.
With --network in ARGS, also check that the hosts Hellmacs fetches from
can be reached (always done when a proxy, CA bundle or mirror is set)."
  (setq hellmacs-cli--problems 0
        hellmacs-cli--probed nil
        hellmacs-cli--probe-network (and (not hellmacs-net-offline)
                                         (or (member "--network" args) (hellmacs-net-proxy)
                                             hellmacs-ca-bundle hellmacs-mirrors)
                                         t))
  (hellmacs-cli--say "Emacs")
  (if (version< emacs-version "29.1")
      (hellmacs-cli--check 'error "Emacs %s is too old; Hellmacs needs 29.1+" emacs-version)
    (hellmacs-cli--check 'ok "Emacs %s" emacs-version))
  (when (string-match-p "\\.[5-9][0-9]\\'" emacs-version)
    (hellmacs-cli--check 'warn "This is a development build of Emacs; expect breakage"))
  (if (and (fboundp 'native-comp-available-p) (native-comp-available-p))
      (hellmacs-cli--check 'ok "Native compilation available")
    (hellmacs-cli--check 'info "No native compilation (optional; makes packages faster)"))
  (hellmacs-cli--doctor-platform)

  (hellmacs-cli--say "\nRequired tools")
  (if-let* ((git (hellmacs-cli--version "git" "--version")))
      (hellmacs-cli--check 'ok "%s" git)
    (hellmacs-cli--check 'error "git not found; it's needed to install packages"))

  (hellmacs-cli--doctor-network)

  ;; Each enabled module checks its own requirements (doctor.el), after
  ;; the modules it needs (`depends-on!', read from the packages.el
  ;; files). `hellmacs-cli-main' has read the config already.
  (hellmacs-modules-read-packages)
  (dolist (key (hellmacs-module-list))
    (let ((file (expand-file-name "doctor.el" (hellmacs-module-get key :path)))
          (missing (hellmacs-module-missing-dependencies key))
          (grammars (hellmacs-treesit-module-languages key)))
      (when (or missing grammars (file-exists-p file))
        (hellmacs-cli--say "\nModule %s %s" (car key) (cdr key))
        (dolist (dep missing)
          (hellmacs-cli--check 'error "Needs %s; add it to your hellmacs! block"
                               (hellmacs-module-dependency-string dep)))
        (when (file-exists-p file)
          (hellmacs-module--load key "doctor.el"))
        (dolist (lang grammars)
          (hellmacs-doctor-treesit lang)))))

  (hellmacs-cli--say "\nConfiguration")
  (hellmacs-cli--check 'info "Profile: %s" (or hellmacs-profile "default"))
  (if (file-directory-p hellmacs-user-dir)
      (hellmacs-cli--check 'ok "Your config: %s" (abbreviate-file-name hellmacs-user-dir))
    (hellmacs-cli--check 'info "No user config yet (%s); using the defaults. `bin/hellmacs install' creates one"
                         (abbreviate-file-name hellmacs-user-dir)))
  (hellmacs-cli--check 'info "Modules: %s"
                       (mapconcat (lambda (k) (format "%s %s" (car k) (cdr k)))
                                  (hellmacs-module-list) ", "))
  (dolist (line (hellmacs-config-report-lines))
    (hellmacs-cli--check 'info "%s" (string-trim line)))
  (let* ((profile (hellmacs-profile-read))
         (reason (and profile (hellmacs-profile--stale-reason profile))))
    (cond ((null profile)
           (hellmacs-cli--check 'error "Not synced yet; run `bin/hellmacs sync'"))
          (reason
           (hellmacs-cli--check 'error "Out of sync (%s); run `bin/hellmacs sync'" reason))
          (t (hellmacs-cli--check 'ok "Synced: %d packages" (length (plist-get profile :load-path))))))
  (cond ((hellmacs-compiled-core-current-p)
         (hellmacs-cli--check 'ok "Byte-compiled: core and the enabled modules (%s)"
                              (abbreviate-file-name hellmacs-compiled-dir)))
        ((file-exists-p (expand-file-name "lisp/stamp" hellmacs-compiled-dir))
         (hellmacs-cli--check 'info "Core changed since the last sync, so it loads from source (slower) until `bin/hellmacs sync'"))
        (t (hellmacs-cli--check 'info "Not byte-compiled yet; `bin/hellmacs sync' compiles core and the modules")))
  (if (file-exists-p hellmacs-lock-file)
      (hellmacs-cli--check 'ok "Packages locked (%s)" (abbreviate-file-name hellmacs-lock-file))
    (hellmacs-cli--check 'info "Packages not locked; `bin/hellmacs lock' pins their exact versions"))
  (if (file-exists-p hellmacs-env-file)
      (hellmacs-cli--check 'ok "Shell environment saved on %s"
                           (format-time-string "%F" (file-attribute-modification-time
                                                     (file-attributes hellmacs-env-file))))
    (hellmacs-cli--check 'info "No saved shell environment; run `bin/hellmacs env' if Emacs can't find your tools"))
  (dolist (legacy '("var/" "etc/"))
    (let ((dir (expand-file-name legacy hellmacs-dir)))
      (when (file-directory-p dir)
        (hellmacs-cli--check 'warn "%s is left over from an older Hellmacs; nothing uses it, safe to delete"
                             (abbreviate-file-name dir)))))

  (hellmacs-cli--say "")
  (if (zerop hellmacs-cli--problems)
      (hellmacs-cli--say "No problems found.")
    ;; `hellmacs-cli-main' turns these into a failing exit code.
    (hellmacs-cli--say "%d problem(s) found." hellmacs-cli--problems)))

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
