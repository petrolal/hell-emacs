;;; sync.el --- Install packages and write the synced profile -*- lexical-binding: t; -*-

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

;; `hell-sync' is the equivalent of `doom sync'. Run it (usually as
;; `bin/hell sync') whenever you change your `hell!' block, a
;; packages.el, or a module's autoload.el. It:
;;
;;   1. reads your init.el's `hell!' block and every packages.el
;;   2. installs and builds anything missing, through Elpaca
;;   3. writes a profile (see "Synced profile" in hell-modules.el)
;;      so that startup can activate packages without Elpaca
;;
;; As in Doom, startup only replays what the last sync generated: after
;; changing your config's modules or packages, sync again. `bin/hell
;; doctor' says when the config changed since.
;;
;; Part `sync' of `hell-cli' (lisp/cli/, Doom v3's CLI parts): not
;; on `load-path', loaded with (hell-require \='hell-cli \='sync), by
;; bin/hell-sync, by the modules' cli.el files that install tools, and
;; by `M-x hell-sync' (autoloaded in lisp/hell-modules.el).

;;; Code:

(require 'hell-lib)
(require 'hell-core)
(require 'hell-packages)
(require 'hell-modules)
(require 'hell-treesit)
(require 'hell-profiles)

(declare-function elpaca-get "elpaca" (id))
(declare-function elpaca-wait "elpaca" (&optional queue))
(declare-function elpaca-process-queues "elpaca" (&optional queue))
(declare-function elpaca-rebuild "elpaca" (package &optional interactive))
(declare-function elpaca-merge "elpaca" (package &optional interactive))
(declare-function elpaca-write-lock-file "elpaca" (file))
(declare-function elpaca-generate-autoloads "elpaca" (package dir))
(declare-function elpaca--queued "elpaca" ())
(declare-function elpaca--dependencies "elpaca" (e))
(declare-function elpaca<-status "elpaca" (e))
(declare-function elpaca<-recipe "elpaca" (e))
(declare-function elpaca<-package "elpaca" (e))
(declare-function elpaca<-id "elpaca" (e))
(declare-function elpaca<-build-dir "elpaca" (e))
(declare-function elpaca<-source-dir "elpaca" (e))
(declare-function hell-verify-record-installed "cli/verify" ())

(defvar hell-sync-functions nil
  "Functions run, in order, at the end of every `hell-sync'.
Called with no arguments after packages are installed and the profile
is written. A module's cli.el adds to it, e.g. to download a tool the
module needs. An error fails the sync.")

;; Registered first, so a module's own sync steps (which may want a
;; grammar) come after it. What to build was declared by the modules'
;; cli.el files, all loaded by the time this runs.
(add-hook 'hell-sync-functions #'hell-treesit-sync -90)
(add-hook 'hell-sync-functions #'hell-net-sync -95) ; before the JVM modules' installs

(defun hell-sync--log (format-string &rest args)
  "Report progress: FORMAT-STRING with ARGS, on stdout in batch mode."
  (let ((msg (apply #'format format-string args)))
    (if noninteractive
        (princ (concat msg "\n"))
      (message "Hell Emacs sync: %s" msg))))

;;; One sync at a time -----------------------------------------------------------
;;
;; A sync deletes and rewrites the profile, the compiled core and Elpaca's
;; checkouts. Two at once -- `bin/hell sync' in a terminal and `C-c h R' in
;; Emacs, say -- would leave each other's half. So every command that
;; changes what's installed holds the profile's lock: a file holding the
;; PID and host of whoever has it, made only if it doesn't exist yet. One
;; left by a sync that died (its process gone, on this host) is taken over.

(defvar hell-profile-dir)                ; early-init.el
(defvar hell-compiled-dir)

(defvar hell-sync--lock-held nil
  "Non-nil while this session holds the profile's sync lock.")

(defun hell-sync-lock-file ()
  "The profile's sync lock: `with-hell-sync-lock'."
  (expand-file-name "sync.lock" hell-profile-dir))

(defun hell-sync--lock-holder (file)
  "(PID . HOST) in the lock FILE, or nil if it can't be read."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file)
      (let ((data (read (current-buffer))))
        (and (consp data) (natnump (car data)) (stringp (cdr data)) data)))))

(defun hell-sync--lock-stale-p (holder)
  "Non-nil if HOLDER, (PID . HOST) or nil, can't still be syncing.
An unreadable lock is a sync that died writing it; one on another host
\(a shared home directory) can't be checked, so it's never stale."
  (or (null holder)
      (and (equal (cdr holder) (system-name))
           (not (process-attributes (car holder))))))

(defun hell-sync--acquire-lock ()
  "Take the profile's sync lock, or signal an error naming who has it."
  (let ((file (hell-sync-lock-file)))
    (make-directory (file-name-directory file) t)
    (catch 'taken
      (dotimes (_ 2)
        (condition-case nil
            (progn
              ;; `excl': made only if it isn't there, in one step.
              (write-region (prin1-to-string (cons (emacs-pid) (system-name)))
                            nil file nil 'silent nil 'excl)
              (throw 'taken t))
          (file-already-exists
           (let ((holder (hell-sync--lock-holder file)))
             (unless (hell-sync--lock-stale-p holder)
               (error "Another sync is running (PID %d on %s); wait for it, \
or delete %s if it isn't" (car holder) (cdr holder) (abbreviate-file-name file)))
             (delete-file file)))))
      (error "Couldn't take the sync lock %s" (abbreviate-file-name file)))))

(defmacro with-hell-sync-lock (&rest body)
  "Run BODY holding the profile's sync lock; nested, BODY just runs.
Signals an error, before BODY, if another sync holds it."
  (declare (indent 0) (debug t))
  `(if hell-sync--lock-held
       (progn ,@body)
     (hell-sync--acquire-lock)
     (unwind-protect
         (let ((hell-sync--lock-held t))
           ,@body)
       (ignore-errors (delete-file (hell-sync-lock-file))))))

(defun hell-sync-download-verified (url dest sha256 label)
  "Download URL to DEST, but only keep it if its SHA-256 is SHA256.
LABEL names the file in errors. It goes through a .part file, so
nothing ever sees a bad or half-written download. For a module's sync
step that fetches a pinned tool."
  (when hell-net-offline
    (error "Offline install: %s isn't installed, and the bundle doesn't carry it (%s)" label url))
  (let ((tmp (concat dest ".part")))
    (make-directory (file-name-directory dest) t)
    (unwind-protect
        (progn
          ;; Through `hell-mirrors', the proxy and CAs, like every
          ;; Hell Emacs fetch; streamed to disk when curl is there.
          (hell-net-download url tmp)
          (unless (equal (hell-file-sha256 tmp) sha256)
            (error "%s download from %s failed its SHA-256 check; not installed" label url))
          (rename-file tmp dest t))
      ;; Only left if the download failed, or failed its check.
      (when (file-exists-p tmp)
        (delete-file tmp)))))

(defun hell-sync-install-zip (label url sha256 dir marker install-fn)
  "Install LABEL from the zip at URL, pinned by SHA256, into DIR.
The download is checked (`hell-sync-download-verified') and unpacked
into a temporary directory; INSTALL-FN is called with that directory to
move what it needs into place. MARKER then records SHA256 (see
`hell-marker-current-p'). Nothing is left behind on failure."
  (unless (executable-find "unzip")
    (error "unzip is needed to install %s" label))
  (let ((zip (expand-file-name (concat (file-name-base url) ".zip") dir))
        (stage (make-temp-file "hell-unzip" t)))
    (unwind-protect
        (progn
          (hell-sync-download-verified url zip sha256 label)
          (with-temp-buffer
            (unless (zerop (call-process "unzip" nil t nil "-q" "-o" zip "-d" stage))
              (error "Unpacking %s failed: %s" label (buffer-string))))
          (funcall install-fn stage)
          (hell-marker-write marker sha256))
      (delete-directory stage t)
      (when (file-exists-p zip) (delete-file zip)))))

(defun hell-sync-install-binary (label url sha256 dest marker)
  "Install LABEL, a single executable at URL pinned by SHA256, as DEST.
The download is checked (`hell-sync-download-verified'), made
executable, and MARKER records SHA256 (`hell-marker-current-p')."
  (hell-sync-download-verified url dest sha256 label)
  (set-file-modes dest #o755)
  (hell-marker-write marker sha256))

(defconst hell-npm-registry "https://registry.npmjs.org/"
  "The npm registry; `hell-mirrors' can point it at a company mirror.")

(defun hell-npm-environment ()
  "Return npm's settings for Hell Emacs' installs, as environment entries.
Its cache under Hell Emacs' own (not ~/.npm), the registry (or its mirror),
the proxy and CA bundle `hell-net' uses, and no update check."
  (let ((proxy (hell-net-proxy))
        (ca (hell-net-ca-file)))
    (delq nil
          (list (concat "npm_config_cache=" (expand-file-name "npm/" hell-cache-dir))
                (concat "npm_config_registry=" (hell-net-rewrite hell-npm-registry))
                "npm_config_update_notifier=false"
                (and proxy (concat "npm_config_proxy=" proxy))
                (and proxy (concat "npm_config_https_proxy=" proxy))
                (when-let* ((hosts (and proxy (hell-net-no-proxy))))
                  (concat "npm_config_noproxy=" (string-join hosts ",")))
                (and ca (concat "npm_config_cafile=" ca))))))

(defun hell-sync-npm-install (label lock-dir dir)
  "Install LABEL's npm packages into DIR, as LOCK-DIR's lockfile pins them.
LOCK-DIR (a module's directory) holds package.json and package-lock.json;
they are copied to DIR and installed with `npm ci', which checks every
package against the lockfile's integrity hash. Install scripts don't run.
The lockfile's SHA-256 is recorded (`hell-npm-installed-p')."
  (when hell-net-offline
    (error "Offline install: %s isn't installed, and the bundle doesn't carry it" label))
  (unless (executable-find "npm")
    (error "Node.js and npm are needed to install %s" label))
  (make-directory dir t)
  (let ((marker (expand-file-name ".hell-lock-sha256" dir))
        (default-directory (file-name-as-directory dir)))
    (when (file-exists-p marker) (delete-file marker))
    (dolist (file '("package.json" "package-lock.json"))
      (copy-file (expand-file-name file lock-dir) (expand-file-name file dir) t))
    (with-hell-network
      (let ((process-environment (append (hell-npm-environment) process-environment)))
        (with-temp-buffer
          (unless (zerop (call-process "npm" nil t nil "ci" "--ignore-scripts" "--no-audit" "--no-fund"))
            (error "npm couldn't install %s: %s" label (string-trim (buffer-string)))))))
    (hell-marker-write marker (hell-file-sha256 (expand-file-name "package-lock.json" lock-dir)))))

(defun hell-sync--packages ()
  "Return the installed Elpaca records for every declared package.
Includes their dependencies, with each package after the packages it
depends on, so autoloads load in a safe order."
  (let (seen ordered)
    (cl-labels ((visit (id)
                  (unless (memq id seen)
                    (push id seen)
                    (when-let* ((e (elpaca-get id)))
                      (dolist (dep (elpaca--dependencies e))
                        (visit (car dep)))
                      (push e ordered)))))
      (pcase-dolist (`(,name . ,plist) (reverse hell-packages))
        (when (hell-package--order name plist)
          (visit name))))
    (nreverse ordered)))

(defun hell-sync--autoloads-file (e)
  "Return the autoloads file Elpaca generated for package record E, or nil.
Follows the recipe's :autoloads, as `elpaca-activate' does."
  (let* ((recipe (elpaca<-recipe e))
         (member (plist-member recipe :autoloads))
         (key (if member (cadr member) t))
         (file (and key
                    (expand-file-name (if (stringp key) key
                                        (concat (elpaca<-package e) "-autoloads.el"))
                                      (elpaca<-build-dir e)))))
    (and file (file-exists-p file) file)))

(defun hell-sync--write (file header data)
  "Write DATA (a list of forms) to FILE, after the comment HEADER."
  (make-directory (file-name-directory file) t)
  (with-hell-atomic-file file
    (let ((print-length nil) (print-level nil) (print-circle nil)
          (print-escape-newlines t) (print-quoted t))
      (insert header "\n")
      (dolist (form data)
        (prin1 form (current-buffer))
        (insert "\n")))))

(defun hell-sync--byte-compile (src dest &optional module)
  "Byte-compile SRC into DEST, quietly, as part of MODULE (a key) if given.
Returns non-nil on success, `no-byte-compile' for a file that asks not
to be compiled (it loads from source); on failure, leaves no DEST behind."
  (make-directory (file-name-directory dest) t)
  (let ((byte-compile-dest-file-function (lambda (_) dest))
        (byte-compile-warnings nil)
        (byte-compile-verbose nil)
        (inhibit-message t)
        (hell--current-module module))
    (pcase (condition-case nil (byte-compile-file src) (error nil))
      ('t t)
      ('no-byte-compile 'no-byte-compile)
      (_ (when (file-exists-p dest) (delete-file dest)) nil))))

(defun hell-sync--compile ()
  "Byte-compile core and enabled module startup files into `hell-compiled-dir'.
Built next to it (compiled.new/), then swapped in whole: a running
Emacs's autoloads name files there, so they're never missing while a
sync works. If core doesn't compile, the old files stay, without their
stamp: startup then loads core from source, as it must, and running
sessions still find theirs. Returns non-nil if core compiled."
  (let* ((final (directory-file-name hell-compiled-dir))
         (new (concat final ".new"))
         (old (concat final ".old"))
         (compiled (let ((hell-compiled-dir (file-name-as-directory new)))
                     (hell-sync--compile-into))))
    (if compiled
        (progn
          (when (file-directory-p old) (delete-directory old t))
          (when (file-directory-p final) (rename-file final old))
          (rename-file new final)
          (when (file-directory-p old) (delete-directory old t)))
      (when (file-directory-p new) (delete-directory new t))
      (let ((stamp (expand-file-name "lisp/stamp" hell-compiled-dir)))
        (when (file-exists-p stamp) (delete-file stamp))))
    compiled))

(defun hell-sync--compile-into ()
  "Byte-compile core and enabled module startup files into `hell-compiled-dir'.
Core is all or nothing (its files inline each other's macros), and
modules are compiled only with it. Whatever fails loads from source.
Returns non-nil if core compiled. See `hell-sync--compile'."
  (let ((core-dir (expand-file-name "lisp/" hell-compiled-dir))
        ;; packages.el is read, never loaded.
        (sources (seq-remove (lambda (src) (equal (file-name-nondirectory src) "packages.el"))
                             (directory-files-recursively hell-core-dir "\\.el\\'")))
        (count 0)
        failed)
    (when (file-directory-p hell-compiled-dir)
      (delete-directory hell-compiled-dir t))
    ;; Every core file loaded first: their macros must expand, and their
    ;; special variables bind dynamically, in whichever file uses them.
    (dolist (src sources)
      (let ((dir (file-name-nondirectory (directory-file-name (file-name-directory src)))))
        (if (member dir '("lib" "cli"))   ; lisp/lib/net.el: part `net' of `hell-lib'
            (hell-require (intern (concat "hell-" dir)) (intern (file-name-base src)))
          (require (intern (file-name-base src))))))
    (dolist (src sources)
      (pcase (hell-sync--byte-compile
              src (expand-file-name (concat (file-relative-name src hell-core-dir) "c") core-dir))
        ('no-byte-compile)              ; loads from source, by its own choice
        ('nil (push src failed))
        (_ (cl-incf count))))
    (if failed
        (delete-directory core-dir t)
      ;; Written last: without it, startup ignores the compiled core.
      (with-temp-file (expand-file-name "stamp" core-dir) (insert emacs-version))
      (dolist (key (hell-module-list))
        (dolist (file hell-module--compiled-files)
          (let ((src (expand-file-name file (hell-module-get key :path))))
            (when (file-exists-p src)
              (if (hell-sync--byte-compile src (hell-module-compiled-file key file) key)
                  (cl-incf count)
                (push src failed)))))))
    (hell-sync--log "Byte-compiled %d files%s" count
                    (if failed
                            (format "; these load from source: %s"
                                    (mapconcat #'abbreviate-file-name (nreverse failed) ", "))
                          ""))
    ;; Whether core compiled: the init file is compiled only with it.
    (file-exists-p (expand-file-name "stamp" core-dir))))

(defun hell-sync--write-autoloads (files forms header)
  "Write every autoloads file in FILES, then FORMS, into one compiled file.
Return its name. HEADER is the file's first line.
Startup then loads one file instead of one per package. Each file's
`#$' (its own name) is spelled out, and its local variables dropped
\(they say not to byte-compile it)."
  (let ((file (hell-profile-file "autoloads.el")))
    (hell-sync--write file header forms)
    (with-temp-buffer
      (dolist (autoloads (reverse files))
        (save-excursion
          (goto-char (point-min))
          (insert-file-contents autoloads)
          (while (search-forward "#$" nil t)
            (replace-match (prin1-to-string autoloads) t t))
          (goto-char (point-min))
          (while (re-search-forward "^;+ Local Variables:" nil t)
            (let ((start (line-beginning-position)))
              (when (re-search-forward "^;+ End:.*$" nil t)
                (delete-region start (point)))))))
      ;; After the header line (lexical-binding), before the module forms.
      (let ((text (buffer-string)))
        (with-temp-buffer
          (insert-file-contents file)
          (forward-line 2)
          (insert text "\n")
          (write-region nil nil file nil 'silent))))
    (let ((elc (concat file "c")))
      (unless (hell-sync--byte-compile file elc)
        (hell-sync--log "Couldn't byte-compile the autoloads; they load from source")))
    file))

(defun hell-sync--write-profile ()
  "Write the profile for the current modules and installed packages:
the packages' combined autoloads, the byte-compiled core and modules,
the generated init file (lisp/hell-profiles.el) and profile.eld."
  (let* ((packages (hell-sync--packages))
         (autoloads (delq nil (mapcar #'hell-sync--autoloads-file packages)))
         (load-path-dirs (mapcar #'elpaca<-build-dir packages))
         (stamp (format ";; Generated by `hell-sync' on %s; don't edit."
                        (format-time-string "%F %T")))
         (profile (hell-profile-file "profile.eld")))
    ;; Gone first: until this sync is complete, startup can't mistake the
    ;; last one's files for current.
    (when (file-exists-p profile)
      (delete-file profile))
    (hell-profile-delete-init)
    (let* ((autoloads-file
            (hell-sync--write-autoloads
             autoloads nil
             (concat ";;; autoloads.el -*- lexical-binding: t; no-native-compile: t -*-\n" stamp)))
           (compiled (hell-sync--compile)))
      (hell-profile-generate (list :load-path load-path-dirs :autoloads autoloads-file)
                             compiled))
    ;; Written last: for `bin/hell doctor', which compares it with the config.
    (hell-sync--write
     profile
     (concat ";; -*- mode: lisp-data -*-\n" stamp)
     (list (list :emacs-version emacs-version
                 :modules (hell-profile--modules)
                 :inputs (hell-profile--inputs)
                 :packages hell-packages
                 :dependencies hell-module-dependencies
                 :treesit hell-treesit-declarations
                 :load-path load-path-dirs
                 :autoloads autoloads)))
    packages))

(defun hell-sync--discard-empty-checkout (dir)
  "Delete DIR if it holds only a .git directory; return non-nil if it did.
A treeless clone whose checkout is cut short by the network is left
like this, and Elpaca takes it for a finished clone, so a second sync
would fail the same way. Removing it lets that sync clone again."
  (when (and (file-directory-p dir)
             (equal (directory-files dir nil directory-files-no-dot-files-regexp) '(".git")))
    (delete-directory dir t)
    t))

(defconst hell-sync--elpaca-functions
  '(elpaca-get elpaca-wait elpaca-process-queues elpaca-rebuild elpaca-merge
    elpaca-write-lock-file elpaca-generate-autoloads elpaca--queued elpaca--dependencies
    elpaca<-status elpaca<-recipe elpaca<-package elpaca<-id elpaca<-build-dir elpaca<-source-dir)
  "Elpaca's functions sync and bin/hell use, internal ones included.")

(defun hell-sync--check-elpaca ()
  "Signal an error naming any of `hell-sync--elpaca-functions' Elpaca lacks.
Elpaca is pinned (lisp/hell-elpaca.el), but `upgrade' moves it on,
and its internals change without notice."
  (when-let* ((missing (seq-remove #'fboundp hell-sync--elpaca-functions)))
    (error "This Elpaca lacks %s, which Hell Emacs uses; it changed since \
lisp/hell-elpaca.el's pin. Reinstall it at the pin (delete %s, then sync)"
           (mapconcat #'symbol-name missing ", ")
           (abbreviate-file-name (expand-file-name "elpaca/" elpaca-sources-directory)))))

(defun hell-sync--check-failures ()
  "Signal an error naming every declared package Elpaca didn't finish."
  (let ((failed (cl-loop for (name . plist) in hell-packages
                         for e = (and (hell-package--order name plist) (elpaca-get name))
                         when (and e (not (eq (elpaca<-status e) 'finished)))
                         do (hell-sync--discard-empty-checkout (elpaca<-source-dir e))
                         and collect name)))
    (when failed
      (error "These packages failed to install: %s. Run the sync again; \
if they keep failing, see M-x elpaca-log in Emacs"
             (mapconcat #'symbol-name failed ", ")))))

;;;###autoload
(defun hell-sync ()
  "Install every declared package, then write the synced profile.
Run it after changing your `hell!' block, a packages.el, or a
module's autoload.el. Signals an error if a package fails to install."
  (interactive)
  ;; In a running session, packages may already be loaded from a synced
  ;; profile; tell Elpaca startup is over, so it doesn't warn about them.
  (when after-init-time
    (defvar elpaca-after-init-time)
    (setq elpaca-after-init-time (or (bound-and-true-p elpaca-after-init-time)
                                     after-init-time)))
  (with-hell-sync-lock
    (hell-sync--log "Reading modules and packages...")
    (hell-modules-read-config)
    (with-hell-network
      (hell-sync--run))))

(defun hell-sync--run ()
  "The rest of `hell-sync', once the config is read."
  (hell-modules-load-cli-files)
  (hell-packages-bootstrap)
  (hell-sync--check-elpaca)
  (hell-sync--log "Modules: %s"
                  (mapconcat (lambda (m) (hell-module-key-string (car m)))
                                 (hell-profile--modules) ", "))
  (hell-sync--log "Installing and building packages (this can take a while)...")
  (hell-modules-install-packages)
  (hell-sync--finish)
  (unless noninteractive
    (hell-sync--log "done. Restart Emacs to start from the new profile.")))

(defun hell-sync--finish ()
  "Everything a sync does once its packages are installed; return them.
Checks the modules' dependencies and that every package built, writes
the profile, runs `hell-sync-functions' (servers, grammars, the
truststore) and records what's installed. `hell-sync' and `bin/hell
upgrade' both end with it, so they can't drift apart."
  (hell-modules-check-dependencies)
  (hell-sync--check-failures)
  (let ((packages (hell-sync--write-profile)))
    (hell-sync--log "Synced %d packages; profile written to %s"
                    (length packages) (abbreviate-file-name (hell-init-file)))
    (run-hooks 'hell-sync-functions)
    ;; Last: what everything above installed, for `bin/hell verify'.
    (hell-require 'hell-cli 'verify)
    (hell-verify-record-installed)
    packages))

(hell-provide 'hell-cli 'sync)
;;; sync.el ends here
