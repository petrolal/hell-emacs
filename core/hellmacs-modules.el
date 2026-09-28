;;; hellmacs-modules.el --- Module system: hellmacs!, modulep!, package! -*- lexical-binding: t; -*-

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

;; Modeled on Doom Emacs' module system (`doom!', `modulep!',
;; `package!'), minus its v2 compatibility layers.
;;
;; A module is a directory, `modules/<group>/<name>/', written
;; `:group name' (e.g. `modules/completion/vertico/' is
;; `:completion vertico'). Every file in it is optional:
;;
;;   packages.el  `package!' declarations only -- what to install --
;;                and `depends-on!', the other modules this one needs
;;   autoload.el  commands and helpers other files may call
;;   init.el      runs early, before any module's config.el
;;   config.el    the module's actual configuration
;;   cli.el       extends bin/hellmacs (sync steps, extra commands)
;;   doctor.el    checks run by `bin/hellmacs doctor'
;;
;; Your `init.el' enables modules with a `hellmacs!' block:
;;
;;   (hellmacs! :ui theme
;;              :completion vertico (corfu +tab)
;;              :config default)
;;
;; `bin/hellmacs sync' (`hellmacs-sync') reads every enabled module's
;; packages.el, then yours, installs those packages, and records a
;; profile of them (see "Synced profile" below). Startup then:
;;
;;   1. activates the packages from that profile -- or, if it's missing
;;      or out of date, reads the packages.el files and installs and
;;      activates the packages through Elpaca right away
;;   2. loads each module's autoload.el and init.el, in order
;;   3. loads each module's config.el, in order
;;
;; after which `init.el' at the repo root loads your config.el.
;;
;; Modules in `hellmacs-user-dir'/modules/ take precedence over
;; Hellmacs' own, so you can override one by copying it there.

;;; Code:

(require 'use-package)
(require 'hellmacs-net)

;;; Variables --------------------------------------------------------------

(defvar hellmacs-module-load-path
  (list (expand-file-name "modules/" hellmacs-user-dir)
        hellmacs-modules-dir)
  "Directories searched for modules, highest priority first.
Each contains <group>/<name>/ module directories.")

(defvar hellmacs-modules (make-hash-table :test #'equal)
  "Enabled modules: a table of (GROUP . NAME) -> plist.
The plist holds :path, :flags, :depth and :index. Populated by
`hellmacs!'; use `hellmacs-module-list' for load order.")

(defvar hellmacs-packages nil
  "Declared packages: an alist of (NAME . PLIST), filled in by `package!'.")

(defvar hellmacs-module-dependencies nil
  "Alist: module key -> the modules it needs, each (GROUP NAME . FLAGS).
Filled in by `depends-on!' as packages.el files are read, and restored
from the synced profile otherwise.")

(defvar hellmacs-treesit-declarations) ; hellmacs-treesit.el
(declare-function hellmacs-treesit-apply "hellmacs-treesit")

(defvar hellmacs--current-module nil
  "The (GROUP . NAME) of the module whose files are being loaded.
Used by `modulep!' and `package!' to know which module they're in.")

(defvar hellmacs--initial-load-path) ; set in early-init.el

;;; Enabling modules: hellmacs! ------------------------------------------

(defun hellmacs-module-locate-path (group name)
  "Return the directory of module GROUP NAME, or nil if it doesn't exist."
  (let ((rel (format "%s/%s/" (substring (symbol-name group) 1) name)))
    (seq-some (lambda (dir)
                (let ((path (expand-file-name rel dir)))
                  (and (file-directory-p path) path)))
              hellmacs-module-load-path)))

(defun hellmacs-module-enable (group name &optional flags depth)
  "Enable module GROUP NAME with FLAGS (a list of +symbols) at DEPTH.
Modules load in ascending DEPTH (default 0), then in the order they
were enabled. Returns nil (and warns) if the module doesn't exist."
  (if-let* ((path (hellmacs-module-locate-path group name)))
      (puthash (cons group name)
               (list :path path
                     :flags flags
                     :depth (or depth 0)
                     :index (hash-table-count hellmacs-modules))
               hellmacs-modules)
    (display-warning 'hellmacs (format "Unknown module %s %s, skipped" group name))
    nil))

(defmacro hellmacs! (&rest modules)
  "Enable MODULES, in order. Use it once, in your init.el.

MODULES is a list of groups (keywords), each followed by the modules
in that group. A module is a symbol, or a list whose first element is
the module name, followed by +flags and an optional `:depth N':

  (hellmacs! :ui theme
             :editor undo
             :completion vertico (corfu +tab)
             :config (default :depth -10))

See `modulep!' for testing modules and flags from code."
  `(hellmacs--enable-modules ',modules))

(defun hellmacs--enable-modules (spec)
  "Enable every module in SPEC, the argument list of `hellmacs!'."
  (clrhash hellmacs-modules)
  (let (group)
    (dolist (item spec)
      (cond ((keywordp item)
             (setq group item))
            ((null group)
             (user-error "hellmacs!: module `%s' comes before any :group" item))
            ((symbolp item)
             (hellmacs-module-enable group item))
            ((consp item)
             (let ((name (car item)) flags depth (rest (cdr item)))
               (while rest
                 (let ((x (pop rest)))
                   (if (eq x :depth)
                       (setq depth (pop rest))
                     (push x flags))))
               (hellmacs-module-enable group name (nreverse flags) depth)))))))

(defun hellmacs-module-list ()
  "Return the keys of enabled modules, in load order."
  (let (keys)
    (maphash (lambda (k _) (push k keys)) hellmacs-modules)
    (sort keys (lambda (a b)
                 (let ((pa (gethash a hellmacs-modules))
                       (pb (gethash b hellmacs-modules)))
                   (if (= (plist-get pa :depth) (plist-get pb :depth))
                       (< (plist-get pa :index) (plist-get pb :index))
                     (< (plist-get pa :depth) (plist-get pb :depth))))))))

(defun hellmacs-module-get (key prop)
  "Return PROP of the enabled module KEY, a (GROUP . NAME) cons."
  (plist-get (gethash key hellmacs-modules) prop))

;;; Querying modules: modulep! ---------------------------------------------

(defun hellmacs-module-p (group name &optional flags)
  "Return non-nil if module GROUP NAME is enabled with all FLAGS.
A flag written -foo means +foo must NOT be enabled."
  (when-let* ((plist (gethash (cons group name) hellmacs-modules)))
    (let ((enabled (plist-get plist :flags)))
      (seq-every-p
       (lambda (flag)
         (let ((s (symbol-name flag)))
           (if (string-prefix-p "-" s)
               (not (memq (intern (concat "+" (substring s 1))) enabled))
             (memq flag enabled))))
       flags))))

(defmacro modulep! (&rest args)
  "Return non-nil if a module (and optionally its flags) is enabled.

  (modulep! :completion corfu)        ; is the module enabled?
  (modulep! :completion corfu +tab)   ; ...with the +tab flag?
  (modulep! :completion corfu -tab)   ; ...without it?

Inside a module's own files, the group and name can be left out:

  (modulep! +tab)"
  (let ((key (if (keywordp (car args))
                 (cons (pop args) (pop args))
               (or hellmacs--current-module
                   (error "modulep!: no module given, and not inside a module")))))
    `(hellmacs-module-p ',(car key) ',(cdr key) ',args)))

;;; Declaring dependencies: depends-on! -------------------------------------

(defmacro depends-on! (group name &rest flags)
  "Declare that this module needs module GROUP NAME, with FLAGS. Use it in packages.el.

  (depends-on! :tools lsp)

FLAGS are written as for `modulep!' (+flag, or -flag for \"without\").
A missing dependency is reported once, at startup, by `bin/hellmacs
sync' and by `bin/hellmacs doctor', instead of each module checking
for itself. The dependency's own packages.el is read first, so what it
declares (lsp-mode, say) comes before what this module builds on it."
  `(hellmacs-module-depend ',group ',name ',flags))

(defvar hellmacs--packages-read :none
  "Modules whose packages.el the current `hellmacs-modules-read-packages' has read.
`:none' outside of one.")

(defun hellmacs-module--read-packages (key)
  "Read module KEY's packages.el, unless this read has already."
  (unless (member key hellmacs--packages-read)
    (push key hellmacs--packages-read)
    (hellmacs-module--load key "packages.el")))

(defun hellmacs-module-depend (group name flags)
  "Record that the current module needs GROUP NAME with FLAGS. See `depends-on!'."
  (let ((key (or hellmacs--current-module
                 (error "depends-on!: not inside a module's packages.el")))
        (dep (cons group (cons name flags))))
    (let ((deps (alist-get key hellmacs-module-dependencies nil nil #'equal)))
      (unless (member dep deps)
        (setf (alist-get key hellmacs-module-dependencies nil nil #'equal)
              (append deps (list dep)))))
    (when (and (listp hellmacs--packages-read) (hellmacs-module-p group name))
      (hellmacs-module--read-packages (cons group name)))))

(defun hellmacs-module-missing-dependencies (key)
  "Return the dependencies of module KEY that aren't enabled, as (GROUP NAME . FLAGS)."
  (seq-remove (pcase-lambda (`(,group ,name . ,flags)) (hellmacs-module-p group name flags))
              (alist-get key hellmacs-module-dependencies nil nil #'equal)))

(defun hellmacs-module-dependency-string (dep)
  "DEP, a (GROUP NAME . FLAGS), as the user would write it: \":tools lsp +flag\"."
  (mapconcat (lambda (x) (format "%s" x)) dep " "))

(defun hellmacs-modules-check-dependencies ()
  "Warn about every enabled module whose dependencies aren't enabled."
  (dolist (key (hellmacs-module-list))
    (dolist (dep (hellmacs-module-missing-dependencies key))
      (display-warning
       'hellmacs
       (format "Module %s %s needs %s; add it to your hellmacs! block"
               (car key) (cdr key) (hellmacs-module-dependency-string dep))))))

;;; Declaring packages: package! -------------------------------------------

(defmacro package! (name &rest plist)
  "Declare that package NAME should be installed. Use it in packages.el.

This only records the declaration; installing happens later, all at
once. Configure the package separately, with `use-package' in a
config.el. PLIST accepts:

  :recipe PLIST   an Elpaca recipe (:host github :repo \"user/repo\" ...)
                  for packages not on (M)ELPA, or to change its source
  :pin REF        a commit, tag or branch to install
  :built-in BOOL  don't install; Emacs provides it. \\='prefer means
                  install only if this Emacs doesn't have it built in
  :disable BOOL   don't install it, and ignore every `use-package'
                  block for it (to switch off a module's package from
                  your own packages.el)
  :env ALIST      environment variables, ((\"VAR\" . \"value\") ...), set
                  while packages are built (so the package is compiled
                  with them) and again at every startup. For example,
                  lsp-mode must be compiled with LSP_USE_PLISTS=true.

A later declaration of the same package is merged over an earlier
one, so your packages.el (read last) can change a module's."
  (declare (indent defun))
  ;; A literal recipe like (:host github ...) must not be evaluated as
  ;; a function call; other values (e.g. \='prefer) are evaluated.
  (let ((recipe (plist-get plist :recipe))
        (env (plist-get plist :env)))
    (when (keywordp (car-safe recipe))
      (setq plist (plist-put (copy-sequence plist) :recipe `',recipe)))
    ;; Likewise a literal alist like (("VAR" . "value")).
    (when (consp (car-safe env))
      (setq plist (plist-put (copy-sequence plist) :env `',env))))
  `(hellmacs-package-declare ',name (list ,@plist)))

(defun hellmacs-package-declare (name plist)
  "Record PLIST for package NAME in `hellmacs-packages'. See `package!'."
  (let* ((old (alist-get name hellmacs-packages))
         (new (copy-sequence old)))
    (cl-loop for (k v) on plist by #'cddr
             do (setq new (plist-put new k v)))
    (setq new (plist-put new :modules
                         (append (plist-get old :modules)
                                 (list (or hellmacs--current-module :user)))))
    (setf (alist-get name hellmacs-packages) new)
    name))

(defun hellmacs-packages-apply-env ()
  "Set the environment variables every declared package asks for (`:env').
Disabled packages don't count. Subprocesses, like Elpaca's build
steps, inherit them."
  (pcase-dolist (`(,_name . ,plist) hellmacs-packages)
    (unless (plist-get plist :disable)
      (pcase-dolist (`(,var . ,value) (plist-get plist :env))
        (setenv var value)))))

(defun hellmacs-package-built-in-p (name)
  "Return non-nil if package NAME ships with this Emacs."
  (locate-library (symbol-name name) nil hellmacs--initial-load-path))

(defun hellmacs-package-disabled-p (name)
  "Return non-nil if package NAME was declared with `:disable'."
  (plist-get (alist-get name hellmacs-packages) :disable))

(defun hellmacs-package--order (name plist)
  "Return the Elpaca order for package NAME with `package!' PLIST, or nil.
Nil means the package shouldn't be installed."
  (let ((built-in (plist-get plist :built-in)))
    (unless (or (plist-get plist :disable)
                (eq built-in t)
                (and (eq built-in 'prefer) (hellmacs-package-built-in-p name)))
      (let ((recipe (copy-sequence (plist-get plist :recipe))))
        (when-let* ((pin (plist-get plist :pin)))
          (setq recipe (plist-put recipe :ref pin)))
        (if recipe (cons name recipe) name)))))

;; `:disable' also has to silence the package's configuration, which
;; lives in some module's `use-package' block, so the block would
;; otherwise try to load a package that was never installed.
(defun hellmacs--use-package-disabled-a (fn name &rest args)
  "Expand to nothing if package NAME was disabled with `package!'."
  (unless (hellmacs-package-disabled-p name)
    (apply fn name args)))
(advice-add 'use-package :around #'hellmacs--use-package-disabled-a)

;;; Loading ----------------------------------------------------------------

(defun hellmacs-load-user-file (name)
  "Load NAME from `hellmacs-user-dir', if it exists.
Errors are reported as warnings instead of aborting startup, so a typo
in your config leaves you with a working editor to fix it in."
  (let ((file (expand-file-name name hellmacs-user-dir)))
    (when (file-exists-p file)
      (condition-case-unless-debug err
          (load file nil 'nomessage 'nosuffix)
        (error
         (display-warning
          'hellmacs (format "Error loading %s: %s"
                            (abbreviate-file-name file) (error-message-string err))
          :error))))))

(defvar hellmacs--use-compiled nil
  "Non-nil if modules may load what `bin/hellmacs sync' compiled for them.
Set at startup: only with an up-to-date profile, and core compiled too.")

(defconst hellmacs-module--compiled-files '("init.el" "config.el")
  "Module files `bin/hellmacs sync' byte-compiles: the ones every startup loads.")

(defun hellmacs-module-compiled-file (key file)
  "Where `bin/hellmacs sync' puts module KEY's FILE compiled."
  (expand-file-name (format "modules/%s/%s/%sc" (substring (symbol-name (car key)) 1) (cdr key) file)
                    hellmacs-compiled-dir))

(defun hellmacs-module--load (key file)
  "Load FILE from module KEY's directory, if it exists.
The compiled FILE from the last sync is loaded instead when it may be
\(`hellmacs--use-compiled') and is newer than FILE, so an edited file
loads from source until the next sync. Errors warn instead of aborting
startup: one broken module should degrade Hellmacs, not brick it."
  (let* ((path (expand-file-name file (hellmacs-module-get key :path)))
         (compiled (and hellmacs--use-compiled
                        (member file hellmacs-module--compiled-files)
                        (hellmacs-module-compiled-file key file))))
    (when (and compiled (file-newer-than-file-p compiled path))
      (setq path compiled))
    (when (file-exists-p path)
      (let ((hellmacs--current-module key))
        (with-hellmacs-context 'module
          (condition-case-unless-debug err
              (load path nil 'nomessage 'nosuffix)
            (error
             (display-warning
              'hellmacs (format "Module %s %s: error in %s: %s"
                                (car key) (cdr key) file (error-message-string err))
              :error))))))))

(defun hellmacs-module-load (name)
  "Load NAME (like \"+paths\") from the directory of the module being loaded.
For a module's files to load their siblings: unlike `load-file-name',
this still points at the module when its config.el runs compiled."
  (load (expand-file-name name (if hellmacs--current-module
                                   (hellmacs-module-get hellmacs--current-module :path)
                                 (file-name-directory (or load-file-name buffer-file-name))))
        nil 'nomessage))

(defvar hellmacs-modules-override nil
  "When non-nil, a `hellmacs!' argument list enabled instead of the user's.
Your init.el still runs (for its settings). Set by `bin/hellmacs
bundle --modules', which packs another module set.")

(defun hellmacs-modules-read-config ()
  "Enable modules from the user's init.el (its `hellmacs!' block).
Without a user init.el, or without a `hellmacs!' call in it, the
defaults in static/init.example.el apply; `hellmacs-modules-override'
wins over both."
  (hellmacs--enable-modules nil)
  (hellmacs-load-user-file "init.el")
  (cond (hellmacs-modules-override
         (hellmacs--enable-modules hellmacs-modules-override))
        ((zerop (hash-table-count hellmacs-modules))
         (load (expand-file-name "static/init.example.el" hellmacs-dir) nil 'nomessage 'nosuffix)))
  ;; The proxy and CA you set there, for all of Emacs.
  (hellmacs-net-setup))

(defvar hellmacs--loaded-cli-files nil
  "cli.el files `hellmacs-modules-load-cli-files' has loaded this session.")

(defun hellmacs-modules-load-cli-files ()
  "Load every enabled module's cli.el, which extends `bin/hellmacs'.
A cli.el may add to `hellmacs-sync-functions' or define
`hellmacs-cli-COMMAND' functions (new bin/hellmacs commands). Loaded
by bin/hellmacs and `hellmacs-sync', never at a normal startup."
  (dolist (key (hellmacs-module-list))
    (let ((file (expand-file-name "cli.el" (hellmacs-module-get key :path))))
      ;; Once per session: bin/hellmacs loads them before running a
      ;; command, and `hellmacs-sync' loads them again.
      (unless (member file hellmacs--loaded-cli-files)
        (push file hellmacs--loaded-cli-files)
        (hellmacs-module--load key "cli.el")))))

(defun hellmacs-modules-read-packages ()
  "Read core/packages.el, every enabled module's packages.el, then the user's.
Fills `hellmacs-packages' and `hellmacs-module-dependencies'. A module's
dependencies (`depends-on!') have their packages.el read before its own."
  (setq hellmacs-packages nil
        hellmacs-module-dependencies nil
        hellmacs-treesit-declarations nil)
  (let ((hellmacs--current-module :core))
    (load (expand-file-name "packages.el" hellmacs-core-dir) nil 'nomessage 'nosuffix))
  (let ((hellmacs--packages-read nil))
    (dolist (key (hellmacs-module-list))
      (hellmacs-module--read-packages key)))
  (hellmacs-load-user-file "packages.el"))

(defvar hellmacs-lock-file (expand-file-name "packages.lock.eld" hellmacs-user-dir)
  "Exact commits of every installed package, written by `bin/hellmacs lock'.
When it exists, packages are installed at these commits instead of the
latest ones, so a config can be reproduced on another machine. It sits
next to your config so you can version it together. `bin/hellmacs
upgrade' rewrites it after updating.")

(defun hellmacs-modules-install-packages (&optional ignore-lock)
  "Read every packages.el, then install and activate the declared packages.
Loads Elpaca, and blocks until it has finished, so module config can
use the packages. Uses `hellmacs-lock-file' unless IGNORE-LOCK."
  (with-hellmacs-network
    (hellmacs-modules--install-packages ignore-lock))
  ;; Inside, the packages' :env only reached the fetching and building (the
  ;; environment there is a copy); this session needs it too (LSP_USE_PLISTS).
  (hellmacs-packages-apply-env))

(defun hellmacs-modules--install-packages (ignore-lock)
  "`hellmacs-modules-install-packages', inside `with-hellmacs-network'."
  (hellmacs-packages-bootstrap)
  (defvar elpaca-lock-file)
  (setq elpaca-lock-file (and (not ignore-lock)
                              (file-exists-p hellmacs-lock-file)
                              hellmacs-lock-file))
  (hellmacs-modules-read-packages)
  (hellmacs-packages-apply-env)
  (let ((rebuild (hellmacs-packages--env-changed)))
    (pcase-dolist (`(,name . ,plist) (reverse hellmacs-packages))
      (when-let* ((order (hellmacs-package--order name plist)))
        (eval `(elpaca ,order) t)))
    (hellmacs--elpaca-wait)
    ;; Already-built packages whose :env changed were compiled without
    ;; it; Elpaca doesn't notice, so rebuild them explicitly.
    (when rebuild
      (dolist (name rebuild)
        (elpaca-rebuild name))
      (elpaca-process-queues)
      (hellmacs--elpaca-wait))
    (hellmacs-packages--write-env-stamps)))

;;; Build environment stamps ---------------------------------------------------
;;
;; `package!'s :env only affects a package when it's compiled, so each
;; package's :env is recorded when it's built, and a package whose :env
;; changes since is rebuilt.

(defun hellmacs-packages--env-stamp-file (name)
  "Where the :env package NAME was last built with is recorded."
  (expand-file-name (format "build-env/%s.eld" name) hellmacs-data-dir))

(defun hellmacs-packages--recorded-env (name)
  "Return the :env package NAME was last built with, or nil."
  (let ((file (hellmacs-packages--env-stamp-file name)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (ignore-errors (read (current-buffer)))))))

(defun hellmacs-packages--env-changed ()
  "Return the installed packages whose :env differs from their last build."
  (defvar elpaca-builds-directory)
  (cl-loop for (name . plist) in hellmacs-packages
           when (and (hellmacs-package--order name plist)
                     (file-directory-p (expand-file-name (symbol-name name)
                                                         elpaca-builds-directory))
                     (not (equal (plist-get plist :env)
                                 (hellmacs-packages--recorded-env name))))
           collect name))

(defun hellmacs-packages--write-env-stamps ()
  "Record the :env every installed package was just built with."
  (pcase-dolist (`(,name . ,plist) hellmacs-packages)
    (when (hellmacs-package--order name plist)
      (let ((file (hellmacs-packages--env-stamp-file name))
            (env (plist-get plist :env)))
        (cond (env
               (make-directory (file-name-directory file) t)
               (with-temp-file file (prin1 env (current-buffer))))
              ((file-exists-p file)
               (delete-file file)))))))

(defvar hellmacs-elpaca-stall-timeout 30
  "Seconds of no progress, with only blocked packages left, before giving up.")

(defun hellmacs--elpaca-wait ()
  "Like `elpaca-wait', but give up if Elpaca stops making progress.
Elpaca can leave packages blocked forever on a dependency whose build
failed (see core/packages.el), and `elpaca-wait' then never returns.
A watchdog notices when every unfinished package has been blocked,
unchanged, for `hellmacs-elpaca-stall-timeout' seconds, and interrupts
the wait; Elpaca then marks those packages failed."
  (let* ((last nil)
         (since (float-time))
         (watchdog
          (run-with-timer
           5 5
           (lambda ()
             (let* ((statuses (mapcar (lambda (q) (elpaca<-status (cdr q))) (elpaca--queued)))
                    (pending (seq-remove (lambda (s) (memq s '(finished failed))) statuses)))
               (cond ((not (equal statuses last))
                      (setq last statuses since (float-time)))
                     ((and pending
                           (seq-every-p (lambda (s) (eq s 'blocked)) pending)
                           (> (- (float-time) since) hellmacs-elpaca-stall-timeout))
                      (display-warning
                       'hellmacs
                       (format "Elpaca stalled with %d package(s) blocked; giving up on them. \
Running the sync again usually finishes the job." (length pending)))
                      ;; Picked up by `elpaca-wait''s loop as a keyboard quit,
                      ;; which fails the unfinished packages and returns.
                      (setq quit-flag t))))))))
    (unwind-protect
        ;; Failing a package signals; callers check statuses afterwards
        ;; (see `hellmacs-sync'), which reports every failure, not just one.
        (condition-case nil (elpaca-wait)
          (elpaca-build-error nil))
      (cancel-timer watchdog))))

;;; Synced profile ---------------------------------------------------------
;;
;; `hellmacs-sync' (bin/hellmacs sync) installs every declared package,
;; then records what startup needs in a profile: the packages' build
;; directories and autoload files, in dependency order, plus loaddefs
;; generated from modules' autoload.el files. A startup that finds an
;; up-to-date profile just replays it, without loading Elpaca or reading
;; any packages.el.
;;
;; The profile is out of date when the enabled modules or their flags
;; change, when any packages.el or autoload.el involved changes, when a
;; recorded build directory disappears, or when Emacs is upgraded. Then
;; startup falls back to installing/activating live through Elpaca, and
;; warns that a sync is due.

(defun hellmacs-profile-file (name)
  "Return the path of file NAME in `hellmacs-profile-dir'."
  (expand-file-name name hellmacs-profile-dir))

(defun hellmacs-profile--modules ()
  "Describe the enabled modules for staleness checks: key, flags, path."
  (mapcar (lambda (key)
            (list key (hellmacs-module-get key :flags) (hellmacs-module-get key :path)))
          (hellmacs-module-list)))

(defun hellmacs-profile--inputs ()
  "Return the files a profile depends on, each paired with its mtime.
The mtime is nil for files that don't exist, so creating one counts
as a change too."
  (mapcar (lambda (file)
            (cons file (when-let* ((attrs (file-attributes file)))
                         (float-time (file-attribute-modification-time attrs)))))
          (cl-list* (expand-file-name "packages.el" hellmacs-core-dir)
                    (expand-file-name "packages.el" hellmacs-user-dir)
                    (cl-loop for key in (hellmacs-module-list)
                             for dir = (hellmacs-module-get key :path)
                             collect (expand-file-name "packages.el" dir)
                             collect (expand-file-name "autoload.el" dir)))))

(defun hellmacs-profile--stale-reason (profile)
  "Return why PROFILE doesn't match the current config, or nil if it does."
  (cond ((not (equal (plist-get profile :emacs-version) emacs-version))
         (format "Emacs changed from %s to %s" (plist-get profile :emacs-version) emacs-version))
        ((not (equal (plist-get profile :modules) (hellmacs-profile--modules)))
         "the enabled modules changed")
        ((when-let* ((changed (seq-difference (hellmacs-profile--inputs)
                                              (plist-get profile :inputs))))
           (format "%s changed" (abbreviate-file-name (car (car changed))))))
        ((seq-find (lambda (dir) (not (file-directory-p dir))) (plist-get profile :load-path))
         "an installed package is missing")))

(defun hellmacs-profile-read ()
  "Return the synced profile's data, or nil if it's missing or unreadable."
  (let ((file (hellmacs-profile-file "profile.eld")))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (ignore-errors (read (current-buffer)))))))

(defun hellmacs-profile-activate ()
  "Activate packages from the synced profile, if it is up to date.
Return non-nil on success. On failure, say why (unless there's no
profile at all) and return nil; the caller activates live instead."
  (let (profile reason)
    (cond ((not (file-exists-p (hellmacs-profile-file "profile.eld")))
           nil)
          ((not (setq profile (hellmacs-profile-read)))
           (display-warning 'hellmacs "The synced profile is unreadable; run `bin/hellmacs sync'.")
           nil)
          ((setq reason (hellmacs-profile--stale-reason profile))
           (display-warning
            'hellmacs
            (format "Your config changed since the last sync (%s). \
Packages were activated directly, which is slower and may install \
packages now. Run `bin/hellmacs sync' to fix." reason))
           nil)
          (t
           (setq hellmacs-packages (plist-get profile :packages)
                 hellmacs-module-dependencies (plist-get profile :dependencies)
                 hellmacs-treesit-declarations (plist-get profile :treesit))
           (hellmacs-packages-apply-env)
           (dolist (dir (reverse (plist-get profile :load-path)))
             (add-to-list 'load-path dir))
           ;; Every package's autoloads and the modules', in one compiled
           ;; file; a profile from before that loads them one by one.
           (if (file-exists-p (hellmacs-profile-file "autoloads.el"))
               (load (hellmacs-profile-file "autoloads") nil 'nomessage)
             (dolist (file (plist-get profile :autoloads))
               (load file 'noerror 'nomessage 'nosuffix))
             (load (hellmacs-profile-file "module-autoloads.el") 'noerror 'nomessage 'nosuffix))
           t))))

;;; Startup ----------------------------------------------------------------

(defun hellmacs--run-packages-ready-h ()
  "Run `hellmacs--packages-ready-hook'.
Each function's errors only warn: one broken function (an error in
`custom-file', say) mustn't keep the GC reset or `hellmacs-finalize',
which come after it, from running."
  (hellmacs-run-hooks 'hellmacs--packages-ready-hook))

(defun hellmacs-modules-startup ()
  "Activate enabled modules' packages, then load the modules.
Uses the synced profile when it is up to date; otherwise installs and
activates packages through Elpaca. See the commentary at the top of
this file for the order."
  (let ((synced (hellmacs-profile-activate)))
    (if synced
        (add-hook 'after-init-hook #'hellmacs--run-packages-ready-h 90)
      (hellmacs-modules-install-packages)
      (add-hook 'elpaca-after-init-hook #'hellmacs--run-packages-ready-h))
    (setq hellmacs--use-compiled (and synced (bound-and-true-p hellmacs--compiled-core-p)))
    (hellmacs-modules-check-dependencies)
    (hellmacs-treesit-apply)
    (let ((modules (hellmacs-module-list)))
      (dolist (key modules)
        ;; A synced profile has these as autoloads already.
        (unless synced
          (hellmacs-module--load key "autoload.el"))
        (hellmacs-module--load key "init.el"))
      (dolist (key modules)
        (hellmacs-module--load key "config.el")))))

;; Used in packages.el files, which a CLI session may read first.
(autoload 'hellmacs-treesit! "hellmacs-treesit" nil nil 'macro)

(autoload 'hellmacs-sync "hellmacs-sync"
  "Install every declared package, then write the synced profile." t)

;; JDK discovery: run by sync, read back when lsp-java loads, never at startup.
(dolist (fn '(hellmacs-jdk-release-name hellmacs-jdk-parse-release-content
              hellmacs-jdk-home-release hellmacs-jdk-home-major hellmacs-jdk-pick hellmacs-jdk-default-roots hellmacs-jdk-scan-roots hellmacs-jdk-detect
              hellmacs-jdk-write hellmacs-jdk-read hellmacs-jdk-lsp-runtimes
              hellmacs-jdk-parse-toolchains-xml hellmacs-jdk-parse-gradle-toolchain))
  (autoload fn "hellmacs-jdk"))

(provide 'hellmacs-modules)
;;; hellmacs-modules.el ends here
