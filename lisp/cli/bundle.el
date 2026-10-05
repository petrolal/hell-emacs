;;; lisp/cli/bundle.el --- Offline bundles -*- lexical-binding: t; -*-

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

;; Installing Hell Emacs where there is no internet (Phase 12.1).
;;
;; `bin/hell bundle OUT.tar.zst', on a connected machine, syncs, then
;; packs everything that sync installed into one archive:
;;
;;   hell-bundle/manifest.eld       every file below, with its SHA-256
;;   hell-bundle/packages.lock.eld  the exact commit of every package
;;   data/...                           from `hell-data-dir': Elpaca's
;;                                      repositories, builds and recipe
;;                                      caches, the pinned servers and jars,
;;                                      the tree-sitter grammars
;;
;; What goes under data/ is what `hell-bundle-functions' name: core
;; adds Elpaca's packages and the grammars, and each module's cli.el its
;; pinned installs. So a bundle carries what the enabled modules need;
;; `bundle --modules' packs another set.
;;
;; `bin/hell install --from-bundle FILE' unpacks it next to
;; `hell-data-dir', checks every sum, and only then moves it into
;; place. Then it syncs with `hell-net-offline' set, so nothing is
;; fetched: whatever the bundle lacks fails the install, named, rather
;; than reaching for the network.
;;
;; A bundle is for one platform (grammars and clojure-lsp are native code)
;; and one Emacs major version (the packages are byte-compiled); the
;; install refuses any other. Its sums catch a damaged or altered file,
;; but they travel with it: get the bundle itself from a place you trust,
;; and compare its own SHA-256, which `bundle' prints.

;;; Code:

(eval-and-compile (hell-require 'hell-cli 'sync))

(defvar elpaca-cache-directory)
(declare-function elpaca-write-lock-file "elpaca" (file))
(declare-function elpaca<-build-dir "elpaca" (e))
(declare-function elpaca<-source-dir "elpaca" (e))
(declare-function elpaca--queued "elpaca" ())

(defconst hell-bundle-format 1
  "Version of the bundle layout; an install refuses any other.")

(defconst hell-bundle--meta "hell-bundle"
  "The archive's directory holding the manifest and the lock file.")

(defvar hell-bundle-functions nil
  "Functions naming what an offline bundle carries.
Each is called with no arguments, after the sync `bin/hell bundle'
runs, and returns a list of files and directories under
`hell-data-dir' (nils and missing ones are skipped). A directory
is carried whole, and replaces what's there when the bundle is
installed. A module's cli.el adds its pinned installs here.")

;;; What a bundle carries ------------------------------------------------------

(defun hell-bundle--core-paths ()
  "Elpaca, its packages (sources and builds) and caches, and the grammars."
  (append
   (list elpaca-cache-directory
         (expand-file-name "build-env/" hell-data-dir))
   (cl-loop for (_ . e) in (elpaca--queued)
            collect (elpaca<-source-dir e)
            collect (elpaca<-build-dir e))
   (cl-loop for lang in (hell-treesit-wanted)
            collect (hell-treesit-library lang)
            collect (hell-treesit--marker lang))))

(add-hook 'hell-bundle-functions #'hell-bundle--core-paths -90)

(defun hell-bundle--relative (path)
  "PATH relative to `hell-data-dir', without a trailing slash.
An error if it isn't inside it."
  (let ((rel (directory-file-name
              (file-relative-name (directory-file-name (expand-file-name path))
                                  hell-data-dir))))
    (when (or (file-name-absolute-p rel) (member rel '("." ".."))
              (string-prefix-p "../" rel))
      (error "A bundle only carries files from %s, not %s"
             (abbreviate-file-name hell-data-dir) (abbreviate-file-name path)))
    rel))

(defun hell-bundle--roots ()
  "What `hell-bundle-functions' name, relative to `hell-data-dir', sorted.
Missing ones are dropped, and so is anything inside another."
  (let (paths)
    (run-hook-wrapped 'hell-bundle-functions
                      (lambda (fn) (setq paths (append paths (funcall fn))) nil))
    (let ((rels (delete-dups
                 (mapcar #'hell-bundle--relative
                         (seq-filter (lambda (p) (and p (or (file-exists-p p) (file-symlink-p p))))
                                     paths)))))
      (sort (seq-remove (lambda (p)
                          (seq-some (lambda (q) (string-prefix-p (concat q "/") p)) rels))
                        rels)
            #'string<))))

(defun hell-bundle--link-entry (name target)
  "The manifest entry for the symbolic link NAME, pointing to TARGET.
A link into `hell-data-dir' (Elpaca's builds are made of them) is
recorded relative to it, so it's remade there on the installing machine."
  (let ((rel (and (file-name-absolute-p target)
                  (file-relative-name target hell-data-dir))))
    (if (and rel (not (file-name-absolute-p rel)) (not (string-prefix-p "../" rel)))
        (list name :data-link rel)
      (list name :link target))))

(defun hell-bundle--walk (file name)
  "Manifest entries for FILE, called NAME in the bundle, and all it holds.
Symbolic links are recorded, never followed."
  (cond ((file-symlink-p file)
         (list (hell-bundle--link-entry name (file-symlink-p file))))
        ((file-directory-p file)
         (cons (list name :dir)
               (mapcan (lambda (child)
                         (hell-bundle--walk child (concat name "/" (file-name-nondirectory child))))
                       (directory-files file t directory-files-no-dot-files-regexp))))
        ((file-regular-p file)
         (list (list name :file (file-attribute-size (file-attributes file))
                     (hell-file-sha256 file))))))

(defun hell-bundle--entries (roots)
  "Manifest entries for ROOTS (see `hell-bundle--roots'), sorted by name.
Each is (NAME :dir), (NAME :file SIZE SHA256), (NAME :link TARGET) or
\(NAME :data-link TARGET), NAME relative to `hell-data-dir'. The
directories holding each root are listed too."
  (let ((seen (make-hash-table :test #'equal))
        entries)
    (cl-flet ((add (entry)
                (when (string-match-p "\n" (car entry))
                  (error "Can't bundle %s: its name has a newline" (car entry)))
                (unless (gethash (car entry) seen)
                  (puthash (car entry) t seen)
                  (push entry entries))))
      (dolist (root roots)
        (let (prefix)
          (dolist (part (butlast (split-string root "/")))
            (setq prefix (if prefix (concat prefix "/" part) part))
            (add (list prefix :dir))))
        (mapc #'add (hell-bundle--walk (expand-file-name root hell-data-dir) root))))
    (sort entries (lambda (a b) (string< (car a) (car b))))))

;;; Making one ---------------------------------------------------------------

(defun hell-bundle--tar (&rest args)
  "Run tar with ARGS, or signal an error with its output."
  (unless (executable-find "tar")
    (error "tar is needed for offline bundles"))
  (pcase-let ((`(,code . ,output) (apply #'hell-process-output "tar" args)))
    (unless (zerop code)
      (error "tar failed: %s" output))))

(defun hell-bundle--platform (&optional configuration)
  "The platform a bundle is for: CONFIGURATION (`system-configuration')
without an OS release number, so macOS point releases share bundles."
  (replace-regexp-in-string "[0-9.]+\\'" "" (or configuration system-configuration)))

(defun hell-bundle--hell-commit ()
  "The commit Hell Emacs is checked out at, or nil."
  (ignore-errors
    (car (process-lines "git" "-C" hell-dir "rev-parse" "HEAD"))))

(defun hell-bundle--write-data (file data)
  "Write the Lisp DATA to FILE, readable back with `read'."
  (with-temp-file file
    (let ((print-length nil) (print-level nil) (print-escape-newlines t))
      (insert ";; -*- mode: lisp-data -*-\n")
      (prin1 data (current-buffer))
      (insert "\n"))))

(defun hell-bundle-create (out)
  "Pack what the last sync installed into the bundle OUT, and return its manifest.
Compressed as OUT's extension says (.tar.zst, .tar.gz, .tar.xz, .tar).
Written to a temporary name first, so OUT is never left half-written."
  (defvar elpaca-lock-file-functions)
  (let* ((out (expand-file-name out))
         (roots (hell-bundle--roots))
         (stage (make-temp-file "hell-bundle" t))
         (meta (expand-file-name hell-bundle--meta stage))
         (lock (expand-file-name "packages.lock.eld" meta))
         (partial (expand-file-name (concat ".partial-" (file-name-nondirectory out))
                                    (file-name-directory out)))
         manifest)
    (unwind-protect
        (progn
          (make-directory meta)
          (let ((elpaca-lock-file-functions nil)) ; every package, as `lock' does
            (elpaca-write-lock-file lock))
          (setq manifest (list :format hell-bundle-format
                               :created (format-time-string "%FT%T%z")
                               :hell (hell-bundle--hell-commit)
                               :emacs-version emacs-version
                               :platform (hell-bundle--platform)
                               :modules (mapcar (lambda (key) (list key (hell-module-get key :flags)))
                                                (hell-module-list))
                               :lock-sha256 (hell-file-sha256 lock)
                               :roots roots
                               :entries (hell-bundle--entries roots)))
          (hell-bundle--write-data (expand-file-name "manifest.eld" meta) manifest)
          ;; tar reads the data through this link; its members are data/...
          (make-symbolic-link (directory-file-name hell-data-dir) (expand-file-name "data" stage))
          (let ((names (expand-file-name "names" stage)))
            (with-temp-file names
              (dolist (name (list hell-bundle--meta
                                  (concat hell-bundle--meta "/manifest.eld")
                                  (concat hell-bundle--meta "/packages.lock.eld")))
                (insert name "\n"))
              (dolist (entry (plist-get manifest :entries))
                (insert "data/" (car entry) "\n")))
            (make-directory (file-name-directory out) t)
            (hell-bundle--tar "-c" "-a" "-f" partial "--no-recursion"
                              "-C" stage "-T" names))
          (rename-file partial out t))
      (delete-directory stage t)
      (when (file-exists-p partial)
        (delete-file partial)))
    manifest))

(defun hell-bundle-size (manifest)
  "The bytes of every file MANIFEST lists."
  (cl-loop for entry in (plist-get manifest :entries)
           when (eq (cadr entry) :file) sum (nth 2 entry)))

;;; Installing one ---------------------------------------------------------------

(defun hell-bundle--read-manifest (dir)
  "The manifest in the unpacked bundle DIR, or an error if it isn't a bundle."
  (let ((file (expand-file-name (concat hell-bundle--meta "/manifest.eld") dir)))
    (unless (file-exists-p file)
      (error "Not a Hell Emacs bundle (it has no %s/manifest.eld)" hell-bundle--meta))
    (let ((manifest (with-temp-buffer
                      (insert-file-contents file)
                      (ignore-errors (read (current-buffer))))))
      (unless (and (listp manifest) (plist-get manifest :format))
        (error "The bundle's manifest can't be read"))
      manifest)))

(defun hell-bundle--module-string (key flags)
  "KEY, a module, and FLAGS as the `hell!' block writes them."
  (format "%s%s" (hell-module-key-string key)
          (mapconcat (lambda (flag) (format " %s" flag)) flags "")))

(defun hell-bundle-check (manifest)
  "Signal an error unless the bundle MANIFEST describes can be installed here.
It must be of this format, platform and Emacs major version, and carry
every module (with its flags) this config enables."
  (unless (eql (plist-get manifest :format) hell-bundle-format)
    (error "This bundle has format %s; this Hell Emacs reads format %s"
           (plist-get manifest :format) hell-bundle-format))
  (unless (equal (plist-get manifest :platform) (hell-bundle--platform))
    (error "This bundle is for %s; this machine is %s. Make one there with `bin/hell bundle'"
           (plist-get manifest :platform) (hell-bundle--platform)))
  (let ((theirs (plist-get manifest :emacs-version)))
    (unless (equal (car (split-string theirs "\\.")) (number-to-string emacs-major-version))
      (error "This bundle was made with Emacs %s; its packages are compiled for it, not for Emacs %s"
             theirs emacs-version)))
  (let ((carried (plist-get manifest :modules))
        missing)
    (dolist (key (hell-module-list))
      (let* ((flags (hell-module-get key :flags))
             (entry (assoc key carried))
             (lacking (if entry (seq-difference flags (cadr entry)) flags)))
        (when (or (not entry) lacking)
          (push (hell-bundle--module-string key lacking) missing))))
    (when missing
      (error "The bundle wasn't made for %s, which your config enables. Make one with those modules \
\(`bin/hell bundle --modules ...') on a connected machine"
             (string-join (nreverse missing) ", ")))))

(defun hell-bundle--check-name (name)
  "Signal an error unless NAME stays inside the directory it's relative to."
  (when (or (string-empty-p name) (file-name-absolute-p name)
            (string-match-p "\\(?:\\`\\|/\\)\\.\\.?\\(?:/\\|\\'\\)" name)
            (string-match-p "//" name))
    (error "The bundle's manifest lists an unsafe file name: %S" name)))

(defun hell-bundle--names (dir &optional prefix)
  "The names of everything under DIR, relative to it, not following links.
Each name starts with PREFIX."
  (mapcan (lambda (child)
            (let ((name (concat prefix (file-name-nondirectory child))))
              (cons name (and (not (file-symlink-p child)) (file-directory-p child)
                              (hell-bundle--names child (concat name "/"))))))
          (and (file-directory-p dir)
               (directory-files dir t directory-files-no-dot-files-regexp))))

(defun hell-bundle-verify (manifest root)
  "Signal an error unless ROOT holds exactly what MANIFEST lists.
Every file must have its size and SHA-256; nothing may be missing or
extra."
  (let ((listed (make-hash-table :test #'equal))
        ;; Every file at once: a bundle holds thousands of them.
        (hashes (hell-files-sha256
                 (cl-loop for (name kind) in (plist-get manifest :entries)
                          for file = (expand-file-name name root)
                          when (and (eq kind :file) (not (file-symlink-p file))
                                    (file-regular-p file))
                          collect file)))
        bad)
    (dolist (entry (plist-get manifest :entries))
      (let* ((name (car entry))
             (file (expand-file-name name root)))
        (hell-bundle--check-name name)
        ;; Remade relative to the data directory on install: stays in it.
        (when (eq (cadr entry) :data-link)
          (hell-bundle--check-name (nth 2 entry)))
        (puthash name t listed)
        (unless (pcase (cadr entry)
                  (:dir (and (not (file-symlink-p file)) (file-directory-p file)))
                  (:file (and (not (file-symlink-p file)) (file-regular-p file)
                              (eql (file-attribute-size (file-attributes file)) (nth 2 entry))
                              (equal (gethash file hashes) (nth 3 entry))))
                  ((or :link :data-link) (file-symlink-p file)))
          (push name bad))))
    ;; The roots are what install moves into `hell-data-dir': each must be a
    ;; safe name, and one of the entries just checked.
    (dolist (root (plist-get manifest :roots))
      (hell-bundle--check-name root)
      (unless (gethash root listed)
        (error "The bundle's manifest moves %S into place, but doesn't list it" root)))
    (dolist (name (hell-bundle--names root))
      (unless (gethash name listed)
        (push (concat name " (not in the manifest)") bad)))
    (when bad
      (setq bad (nreverse bad))
      (error "The bundle is damaged or was altered: %d file%s don't match its manifest: %s%s"
             (length bad) (if (cdr bad) "s" "")
             (string-join (seq-take bad 5) ", ")
             (if (nthcdr 5 bad) ", ..." "")))))

(defun hell-bundle--delete (file)
  "Delete FILE, a file, link or directory tree, if it exists."
  (cond ((file-symlink-p file) (delete-file file))
        ((file-directory-p file) (delete-directory file t))
        ((file-exists-p file) (delete-file file))))

(defun hell-bundle--place (manifest data)
  "Move MANIFEST's roots from DATA into `hell-data-dir'.
What's there is replaced, all or nothing: if one fails, what was
replaced is put back. Then the links into the data directory are
remade for this one."
  (let (moved)                          ; (TARGET . SET-ASIDE-OR-NIL)
    (condition-case err
        (dolist (root (plist-get manifest :roots))
          (let* ((target (expand-file-name root hell-data-dir))
                 (aside (and (or (file-exists-p target) (file-symlink-p target))
                             (concat target ".hell-old"))))
            (make-directory (file-name-directory target) t)
            (when aside
              (hell-bundle--delete aside)
              (rename-file target aside))
            (push (cons target aside) moved)
            (rename-file (expand-file-name root data) target)))
      (error
       (pcase-dolist (`(,target . ,aside) moved)
         (hell-bundle--delete target)
         (when aside (rename-file aside target)))
       (signal (car err) (cdr err))))
    (pcase-dolist (`(,_ . ,aside) moved)
      (when aside (hell-bundle--delete aside))))
  (dolist (entry (plist-get manifest :entries))
    (when (eq (cadr entry) :data-link)
      (let ((link (expand-file-name (car entry) hell-data-dir)))
        (hell-bundle--delete link)
        (make-symbolic-link (expand-file-name (nth 2 entry) hell-data-dir) link)))))

(defun hell-bundle--install-lock (file)
  "Make FILE, the bundle's lock file, `hell-lock-file'.
A different lock file already there is kept, renamed .before-bundle."
  (let ((lock hell-lock-file))
    (unless (and (file-exists-p lock)
                 (equal (hell-file-sha256 lock) (hell-file-sha256 file)))
      (when (file-exists-p lock)
        (let ((kept (concat lock ".before-bundle")))
          (rename-file lock kept t)
          (hell-sync--log "Your lock file differed from the bundle's; kept it as %s"
                          (abbreviate-file-name kept))))
      (make-directory (file-name-directory lock) t)
      (copy-file file lock t))))

(defcustom hell-bundle-require-sha256 nil
  "Non-nil if `install --from-bundle' refuses a bundle without --sha256.
A bundle's manifest travels inside it, so on its own it only proves
the bundle is whole, not that it's the one `bin/hell bundle' made: the
SHA-256 that command printed, given as --sha256 on the installing
machine, does. Set it where bundles cross from an untrusted place."
  :type 'boolean
  :group 'hell)

(defun hell-bundle-check-sha256 (bundle sha256)
  "Signal an error unless the file BUNDLE's SHA-256 is SHA256.
Without SHA256: an error if `hell-bundle-require-sha256', else a
warning saying what isn't checked."
  (cond
   (sha256
    (unless (string-match-p "\\`[0-9a-fA-F]\\{64\\}\\'" sha256)
      (error "--sha256 must be 64 hexadecimal digits, as `bin/hell bundle' prints it"))
    (let ((actual (hell-file-sha256 bundle)))
      (unless (equal actual (downcase sha256))
        (error "The bundle %s has SHA-256 %s, not %s: it isn't the bundle you meant; not installed"
               (abbreviate-file-name bundle) actual (downcase sha256)))))
   (hell-bundle-require-sha256
    (error "Give the bundle's SHA-256 with --sha256 (`hell-bundle-require-sha256' is set)"))
   (t
    (hell-sync--log "  ! No --sha256: the bundle's files are checked only against its own \
manifest. Its SHA-256 is %s; compare it with the one `bin/hell bundle' printed"
                    (hell-file-sha256 bundle)))))

(defun hell-bundle-install (bundle &optional no-lock sha256)
  "Unpack BUNDLE into `hell-data-dir', after checking every file in it.
Also installs its lock file, unless NO-LOCK. With SHA256, the bundle
itself must have that SHA-256 (`hell-bundle-check-sha256').
Returns the manifest. Needs no network; the sync that follows should
run with `hell-net-offline' set."
  (let ((bundle (expand-file-name bundle)))
    (unless (file-readable-p bundle)
      (error "Can't read the bundle %s" (abbreviate-file-name bundle)))
    (hell-bundle-check-sha256 bundle sha256)
    (with-hell-sync-lock
      (make-directory hell-data-dir t)
      ;; Unpacked on the same file system, so it moves into place whole.
      (let ((stage (make-temp-file (expand-file-name ".bundle-" hell-data-dir) t)))
        (unwind-protect
            (progn
              (hell-sync--log "Unpacking %s..." (abbreviate-file-name bundle))
              ;; Owned by whoever installs, root included (in a container,
              ;; say): the builder's user means nothing here.
              (hell-bundle--tar "-x" "--no-same-owner" "-f" bundle "-C" stage)
              (let ((manifest (hell-bundle--read-manifest stage))
                    (lock (expand-file-name (concat hell-bundle--meta "/packages.lock.eld") stage))
                    (data (expand-file-name "data" stage)))
                (hell-sync--log "Bundle made %s with Emacs %s, for %s"
                                (plist-get manifest :created) (plist-get manifest :emacs-version)
                                (plist-get manifest :platform))
                (hell-bundle-check manifest)
                (hell-sync--log "Checking %d files..."
                                (cl-count :file (plist-get manifest :entries) :key #'cadr))
                (hell-bundle-verify manifest data)
                (unless (equal (ignore-errors (hell-file-sha256 lock))
                               (plist-get manifest :lock-sha256))
                  (error "The bundle is damaged or was altered: its lock file doesn't match its manifest"))
                (hell-bundle--place manifest data)
                (unless no-lock
                  (hell-bundle--install-lock lock))
                (let ((theirs (plist-get manifest :hell))
                      (ours (hell-bundle--hell-commit)))
                  (when (and theirs ours (not (equal theirs ours)))
                    (hell-sync--log "Note: the bundle was made with Hell Emacs %s, this is %s; \
if their pins differ, the sync names what's missing"
                                    (substring theirs 0 7) (substring ours 0 7))))
                (hell-sync--log "Installed %d files (%s) from the bundle (each matches its manifest)"
                                (cl-count :file (plist-get manifest :entries) :key #'cadr)
                                (file-size-human-readable (hell-bundle-size manifest)))
                manifest))
          (delete-directory stage t))))))

(hell-provide 'hell-cli 'bundle)
;;; bundle.el ends here
