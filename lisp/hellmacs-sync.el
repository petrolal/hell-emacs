;;; hellmacs-sync.el --- Install packages and write the synced profile -*- lexical-binding: t; -*-

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

;; `hellmacs-sync' is the equivalent of `doom sync'. Run it (usually as
;; `bin/hellmacs sync') whenever you change your `hellmacs!' block, a
;; packages.el, or a module's autoload.el. It:
;;
;;   1. reads your init.el's `hellmacs!' block and every packages.el
;;   2. installs and builds anything missing, through Elpaca
;;   3. writes a profile (see "Synced profile" in hellmacs-modules.el)
;;      so that startup can activate packages without Elpaca
;;
;; Startup notices when the profile is out of date and falls back to
;; activating packages live, so forgetting to sync slows startup down
;; but never breaks it.
;;
;; Not loaded at startup; `bin/hellmacs' (lisp/hellmacs-cli.el) and
;; `M-x hellmacs-sync' load it.

;;; Code:

(require 'hellmacs-lib)
(require 'hellmacs)
(require 'hellmacs-packages)
(require 'hellmacs-keybinds)
(require 'hellmacs-modules)
(require 'hellmacs-treesit)

(defvar hellmacs-sync-functions nil
  "Functions run, in order, at the end of every `hellmacs-sync'.
Called with no arguments after packages are installed and the profile
is written. A module's cli.el adds to it, e.g. to download a tool the
module needs. An error fails the sync.")

;; Registered first, so a module's own sync steps (which may want a
;; grammar) come after it. What to build was declared by the modules'
;; cli.el files, all loaded by the time this runs.
(add-hook 'hellmacs-sync-functions #'hellmacs-treesit-sync -90)
(add-hook 'hellmacs-sync-functions #'hellmacs-net-sync -95) ; before the JVM modules' installs

(defun hellmacs-sync--log (format-string &rest args)
  "Report progress: FORMAT-STRING with ARGS, on stdout in batch mode."
  (let ((msg (apply #'format format-string args)))
    (if noninteractive
        (princ (concat msg "\n"))
      (message "Hellmacs sync: %s" msg))))

(defun hellmacs-sync-download-verified (url dest sha256 label)
  "Download URL to DEST, but only keep it if its SHA-256 is SHA256.
LABEL names the file in errors. It goes through a .part file, so
nothing ever sees a bad or half-written download. For a module's sync
step that fetches a pinned tool."
  (when hellmacs-net-offline
    (error "Offline install: %s isn't installed, and the bundle doesn't carry it (%s)" label url))
  (let ((tmp (concat dest ".part")))
    (make-directory (file-name-directory dest) t)
    (unwind-protect
        (progn
          ;; Through `hellmacs-mirrors', the proxy and CAs, like every
          ;; Hellmacs fetch; streamed to disk when curl is there.
          (hellmacs-net-download url tmp)
          (unless (equal (hellmacs-file-sha256 tmp) sha256)
            (error "%s download from %s failed its SHA-256 check; not installed" label url))
          (rename-file tmp dest t))
      ;; Only left if the download failed, or failed its check.
      (when (file-exists-p tmp)
        (delete-file tmp)))))

(defun hellmacs-sync-install-zip (label url sha256 dir marker install-fn)
  "Install LABEL from the zip at URL, pinned by SHA256, into DIR.
The download is checked (`hellmacs-sync-download-verified') and unpacked
into a temporary directory; INSTALL-FN is called with that directory to
move what it needs into place. MARKER then records SHA256 (see
`hellmacs-marker-current-p'). Nothing is left behind on failure."
  (unless (executable-find "unzip")
    (error "unzip is needed to install %s" label))
  (let ((zip (expand-file-name (concat (file-name-base url) ".zip") dir))
        (stage (make-temp-file "hellmacs-unzip" t)))
    (unwind-protect
        (progn
          (hellmacs-sync-download-verified url zip sha256 label)
          (with-temp-buffer
            (unless (zerop (call-process "unzip" nil t nil "-q" "-o" zip "-d" stage))
              (error "Unpacking %s failed: %s" label (buffer-string))))
          (funcall install-fn stage)
          (hellmacs-marker-write marker sha256))
      (delete-directory stage t)
      (when (file-exists-p zip) (delete-file zip)))))

(defun hellmacs-sync-install-binary (label url sha256 dest marker)
  "Install LABEL, a single executable at URL pinned by SHA256, as DEST.
The download is checked (`hellmacs-sync-download-verified'), made
executable, and MARKER records SHA256 (`hellmacs-marker-current-p')."
  (hellmacs-sync-download-verified url dest sha256 label)
  (set-file-modes dest #o755)
  (hellmacs-marker-write marker sha256))

(defconst hellmacs-npm-registry "https://registry.npmjs.org/"
  "npm's registry; `hellmacs-mirrors' can point it at a company mirror.")

(defun hellmacs-npm-environment ()
  "npm's settings for Hellmacs' installs, as environment entries.
Its cache under Hellmacs' own (not ~/.npm), the registry (or its mirror),
the proxy and CA bundle `hellmacs-net' uses, and no update check."
  (let ((proxy (hellmacs-net-proxy))
        (ca (hellmacs-net-ca-file)))
    (delq nil
          (list (concat "npm_config_cache=" (expand-file-name "npm/" hellmacs-cache-dir))
                (concat "npm_config_registry=" (hellmacs-net-rewrite hellmacs-npm-registry))
                "npm_config_update_notifier=false"
                (and proxy (concat "npm_config_proxy=" proxy))
                (and proxy (concat "npm_config_https_proxy=" proxy))
                (when-let* ((hosts (and proxy (hellmacs-net-no-proxy))))
                  (concat "npm_config_noproxy=" (string-join hosts ",")))
                (and ca (concat "npm_config_cafile=" ca))))))

(defun hellmacs-sync-npm-install (label lock-dir dir)
  "Install LABEL's npm packages into DIR, exactly as LOCK-DIR's lockfile pins them.
LOCK-DIR (a module's directory) holds package.json and package-lock.json;
they are copied to DIR and installed with `npm ci', which checks every
package against the lockfile's integrity hash. Install scripts don't run.
The lockfile's SHA-256 is recorded (`hellmacs-npm-installed-p')."
  (when hellmacs-net-offline
    (error "Offline install: %s isn't installed, and the bundle doesn't carry it" label))
  (unless (executable-find "npm")
    (error "Node.js and npm are needed to install %s" label))
  (make-directory dir t)
  (let ((marker (expand-file-name ".hellmacs-lock-sha256" dir))
        (default-directory (file-name-as-directory dir)))
    (when (file-exists-p marker) (delete-file marker))
    (dolist (file '("package.json" "package-lock.json"))
      (copy-file (expand-file-name file lock-dir) (expand-file-name file dir) t))
    (with-hellmacs-network
      (let ((process-environment (append (hellmacs-npm-environment) process-environment)))
        (with-temp-buffer
          (unless (zerop (call-process "npm" nil t nil "ci" "--ignore-scripts" "--no-audit" "--no-fund"))
            (error "npm couldn't install %s: %s" label (string-trim (buffer-string)))))))
    (hellmacs-marker-write marker (hellmacs-file-sha256 (expand-file-name "package-lock.json" lock-dir)))))

(defun hellmacs-sync--packages ()
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
      (pcase-dolist (`(,name . ,plist) (reverse hellmacs-packages))
        (when (hellmacs-package--order name plist)
          (visit name))))
    (nreverse ordered)))

(defun hellmacs-sync--autoloads-file (e)
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

(defun hellmacs-sync--make-autoload (form file)
  "Return the `autoload' form for definition FORM from FILE, or nil.
The function doing this was `make-autoload' until Emacs 30, and is
`loaddefs-generate--make-autoload' since. (`loaddefs-generate' itself
writes file names relative to its output file, which doesn't suit a
profile living outside the checkout.)"
  (funcall (if (fboundp 'loaddefs-generate--make-autoload)
               #'loaddefs-generate--make-autoload
             'make-autoload)
           form file))

(defun hellmacs-sync--module-autoloads ()
  "Return autoload forms for every `;;;###autoload' in modules' autoload.el.
A cookie before a definition yields an `autoload' form; before any
other form, the form itself is kept, as in Emacs' own loaddefs."
  (require 'loaddefs-gen)
  (let (forms)
    (dolist (key (hellmacs-module-list))
      (let ((file (expand-file-name "autoload.el" (hellmacs-module-get key :path))))
        (when (file-exists-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (emacs-lisp-mode)
            (goto-char (point-min))
            (while (re-search-forward "^;;;###autoload[ \t]*$" nil t)
              (let ((form (read (current-buffer))))
                (push (or (hellmacs-sync--make-autoload form (file-name-sans-extension file))
                          form)
                      forms)))))))
    (nreverse forms)))

(defun hellmacs-sync--write (file header data)
  "Write DATA (a list of forms) to FILE, after the comment HEADER."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (let ((print-length nil) (print-level nil) (print-circle nil)
          (print-escape-newlines t) (print-quoted t))
      (insert header "\n")
      (dolist (form data)
        (prin1 form (current-buffer))
        (insert "\n")))))

(defun hellmacs-sync--byte-compile (src dest &optional module)
  "Byte-compile SRC into DEST, quietly, as part of MODULE (a key) if given.
Returns non-nil on success, `no-byte-compile' for a file that asks not
to be compiled (it loads from source); on failure, leaves no DEST behind."
  (make-directory (file-name-directory dest) t)
  (let ((byte-compile-dest-file-function (lambda (_) dest))
        (byte-compile-warnings nil)
        (byte-compile-verbose nil)
        (inhibit-message t)
        (hellmacs--current-module module))
    (pcase (condition-case nil (byte-compile-file src) (error nil))
      ('t t)
      ('no-byte-compile 'no-byte-compile)
      (_ (when (file-exists-p dest) (delete-file dest)) nil))))

(defun hellmacs-sync--compile ()
  "Byte-compile core and the enabled modules' startup files, into `hellmacs-compiled-dir'.
Core is all or nothing (its files inline each other's macros), and
modules are compiled only with it. Whatever fails loads from source."
  (let ((core-dir (expand-file-name "lisp/" hellmacs-compiled-dir))
        ;; packages.el is read, never loaded.
        (sources (seq-remove (lambda (src) (equal (file-name-nondirectory src) "packages.el"))
                             (directory-files-recursively hellmacs-core-dir "\\.el\\'")))
        (count 0)
        failed)
    (when (file-directory-p hellmacs-compiled-dir)
      (delete-directory hellmacs-compiled-dir t))
    ;; Every core file loaded first: their macros must expand, and their
    ;; special variables bind dynamically, in whichever file uses them.
    (dolist (src sources)
      (let ((dir (file-name-nondirectory (directory-file-name (file-name-directory src)))))
        (if (member dir '("lib" "cli"))   ; lisp/lib/net.el: part `net' of `hellmacs-lib'
            (hellmacs-require (intern (concat "hellmacs-" dir)) (intern (file-name-base src)))
          (require (intern (file-name-base src))))))
    (dolist (src sources)
      (pcase (hellmacs-sync--byte-compile
              src (expand-file-name (concat (file-relative-name src hellmacs-core-dir) "c") core-dir))
        ('no-byte-compile)              ; loads from source, by its own choice
        ('nil (push src failed))
        (_ (cl-incf count))))
    (if failed
        (delete-directory core-dir t)
      ;; Written last: without it, startup ignores the compiled core.
      (with-temp-file (expand-file-name "stamp" core-dir) (insert emacs-version))
      (dolist (key (hellmacs-module-list))
        (dolist (file hellmacs-module--compiled-files)
          (let ((src (expand-file-name file (hellmacs-module-get key :path))))
            (when (file-exists-p src)
              (if (hellmacs-sync--byte-compile src (hellmacs-module-compiled-file key file) key)
                  (cl-incf count)
                (push src failed)))))))
    (hellmacs-sync--log "Byte-compiled %d files%s" count
                        (if failed
                            (format "; these load from source: %s"
                                    (mapconcat #'abbreviate-file-name (nreverse failed) ", "))
                          ""))))

(defun hellmacs-sync--write-autoloads (files forms header)
  "Write every package autoloads file in FILES, then FORMS, into one compiled file.
Startup then loads one file instead of one per package. Each file's
`#$' (its own name) is spelled out, and its local variables dropped
\(they say not to byte-compile it)."
  (let ((file (hellmacs-profile-file "autoloads.el")))
    (hellmacs-sync--write file header forms)
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
      (unless (hellmacs-sync--byte-compile file elc)
        (hellmacs-sync--log "Couldn't byte-compile the autoloads; they load from source")))))

(defun hellmacs-sync--write-profile ()
  "Write the profile for the current modules and installed packages."
  (let* ((packages (hellmacs-sync--packages))
         (autoloads (delq nil (mapcar #'hellmacs-sync--autoloads-file packages)))
         (stamp (format ";; Generated by `hellmacs-sync' on %s; don't edit."
                        (format-time-string "%F %T")))
         (profile (hellmacs-profile-file "profile.eld")))
    ;; Gone first: the last sync's profile would still look current, and
    ;; be started from with the files rewritten below. Until this one is
    ;; complete, startup activates packages live instead.
    (when (file-exists-p profile)
      (delete-file profile))
    (hellmacs-sync--write-autoloads
     autoloads
     (hellmacs-sync--module-autoloads)
     (concat ";;; autoloads.el -*- lexical-binding: t; no-native-compile: t -*-\n" stamp))
    (hellmacs-sync--compile)
    ;; Written last: its presence means the rest of the profile is complete.
    (hellmacs-sync--write
     profile
     (concat ";; -*- mode: lisp-data -*-\n" stamp)
     (list (list :emacs-version emacs-version
                 :modules (hellmacs-profile--modules)
                 :inputs (hellmacs-profile--inputs)
                 :packages hellmacs-packages
                 :dependencies hellmacs-module-dependencies
                 :treesit hellmacs-treesit-declarations
                 :load-path (mapcar #'elpaca<-build-dir packages)
                 :autoloads autoloads)))
    packages))

(defun hellmacs-sync--discard-empty-checkout (dir)
  "Delete DIR if it holds only a .git directory; return non-nil if it did.
A treeless clone whose checkout is cut short by the network is left
like this, and Elpaca takes it for a finished clone, so a second sync
would fail the same way. Removing it lets that sync clone again."
  (when (and (file-directory-p dir)
             (equal (directory-files dir nil directory-files-no-dot-files-regexp) '(".git")))
    (delete-directory dir t)
    t))

(defconst hellmacs-sync--elpaca-functions
  '(elpaca-get elpaca-wait elpaca-process-queues elpaca-rebuild elpaca-merge
    elpaca-write-lock-file elpaca-generate-autoloads elpaca--queued elpaca--dependencies
    elpaca<-status elpaca<-recipe elpaca<-package elpaca<-id elpaca<-build-dir elpaca<-source-dir)
  "Elpaca's functions sync and bin/hellmacs use, internal ones included.")

(defun hellmacs-sync--check-elpaca ()
  "Signal an error naming any of `hellmacs-sync--elpaca-functions' Elpaca lacks.
Elpaca is pinned (lisp/hellmacs-elpaca.el), but `upgrade' moves it on,
and its internals change without notice."
  (when-let* ((missing (seq-remove #'fboundp hellmacs-sync--elpaca-functions)))
    (error "This Elpaca lacks %s, which Hellmacs uses; it changed since \
lisp/hellmacs-elpaca.el's pin. Reinstall it at the pin (delete %s, then sync)"
           (mapconcat #'symbol-name missing ", ")
           (abbreviate-file-name (expand-file-name "elpaca/" elpaca-sources-directory)))))

(defun hellmacs-sync--check-failures ()
  "Signal an error naming every declared package Elpaca didn't finish."
  (let ((failed (cl-loop for (name . plist) in hellmacs-packages
                         for e = (and (hellmacs-package--order name plist) (elpaca-get name))
                         when (and e (not (eq (elpaca<-status e) 'finished)))
                         do (hellmacs-sync--discard-empty-checkout (elpaca<-source-dir e))
                         and collect name)))
    (when failed
      (error "These packages failed to install: %s. Run the sync again; \
if they keep failing, see M-x elpaca-log in Emacs"
             (mapconcat #'symbol-name failed ", ")))))

;;;###autoload
(defun hellmacs-sync ()
  "Install every declared package, then write the synced profile.
Run it after changing your `hellmacs!' block, a packages.el, or a
module's autoload.el. Signals an error if a package fails to install."
  (interactive)
  ;; In a running session, packages may already be loaded from a synced
  ;; profile; tell Elpaca startup is over, so it doesn't warn about them.
  (when after-init-time
    (defvar elpaca-after-init-time)
    (setq elpaca-after-init-time (or (bound-and-true-p elpaca-after-init-time)
                                     after-init-time)))
  (hellmacs-sync--log "Reading modules and packages...")
  (hellmacs-modules-read-config)
  (with-hellmacs-network
    (hellmacs-sync--run)))

(defun hellmacs-sync--run ()
  "The rest of `hellmacs-sync', once the config is read."
  (hellmacs-modules-load-cli-files)
  (hellmacs-packages-bootstrap)
  (hellmacs-sync--check-elpaca)
  (hellmacs-sync--log "Modules: %s"
                      (mapconcat (lambda (m) (hellmacs-module-key-string (car m)))
                                 (hellmacs-profile--modules) ", "))
  (hellmacs-sync--log "Installing and building packages (this can take a while)...")
  (hellmacs-modules-install-packages)
  (hellmacs-modules-check-dependencies)
  (hellmacs-sync--check-failures)
  (let ((packages (hellmacs-sync--write-profile)))
    (hellmacs-sync--log "Synced %d packages; profile written to %s"
                        (length packages) (abbreviate-file-name hellmacs-profile-dir))
    (run-hooks 'hellmacs-sync-functions)
    ;; Last: what everything above installed, for `bin/hellmacs verify'.
    (hellmacs-require 'hellmacs-cli 'verify)
    (hellmacs-verify-record-installed)
    (unless noninteractive
      (hellmacs-sync--log "done. Restart Emacs to start from the new profile."))))

(provide 'hellmacs-sync)
;;; hellmacs-sync.el ends here
