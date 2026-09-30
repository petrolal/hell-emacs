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
;; A module is a directory, `<group>/<name>/' in a module tree (your
;; modules/, Hellmacs' modules/, then sources/hellmacs+/modules/: see
;; `hellmacs-module-load-path'), written `:group name' (e.g.
;; `sources/hellmacs+/modules/completion/vertico/' is
;; `:completion vertico'). Every file in it is optional:
;;
;;   packages.el  `package!' declarations only -- what to install --
;;                and `depends-on!', the other modules this one needs
;;   autoload.el  commands and helpers other files may call (or
;;   autoload/    several files of them, as in Doom)
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
;; `bin/hellmacs sync' (`hellmacs-sync', lisp/cli/sync.el) reads every
;; enabled module's packages.el, then yours, installs those packages
;; through Elpaca, and generates the profile's init file
;; (lisp/hellmacs-profiles.el), which at startup:
;;
;;   1. puts the packages on `load-path' and loads their autoloads
;;   2. loads the modules' autoloads
;;   3. loads each module's init.el, in order, then each config.el
;;
;; and then your config.el. As in Doom, startup never installs anything:
;; after changing your `hellmacs!' block or a packages.el, sync again.
;;
;; Modules in `hellmacs-user-dir'/modules/ take precedence over
;; Hellmacs' own, so you can override one by copying it there.

;;; Code:

(require 'use-package)
(require 'hellmacs-lib)
(eval-and-compile (hellmacs-require 'hellmacs-lib 'net))

;;; Variables --------------------------------------------------------------

(defvar hellmacs-module-load-path
  (list (expand-file-name "modules/" hellmacs-user-dir)
        hellmacs-modules-dir
        (expand-file-name "hellmacs+/modules/" hellmacs-sources-dir))
  "Directories searched for modules, highest priority first.
Each contains <group>/<name>/ module directories: yours, Hellmacs' own
(core's module), then the sources' (the catalog), as Doom v3's
`doom-module-load-path'.")

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

(defvar hellmacs-unpinned-packages nil
  "Packages whose `:pin' is ignored: `t' for every package. See `unpin!'.")

(defvar hellmacs-before-modules-init-hook nil
  "Run before the modules' init.el files load, at startup.")

(defvar hellmacs-after-modules-init-hook nil
  "Run after every module's init.el has loaded, at startup.")

(defvar hellmacs-before-modules-config-hook nil
  "Run before the modules' config.el files load, at startup.")

(defvar hellmacs-after-modules-config-hook nil
  "Run after every module's config.el has loaded, before your config.el.")

(defvar hellmacs--use-compiled nil
  "Non-nil if modules may load what `bin/hellmacs sync' compiled for them.
Set at startup, by the profile's init file, when core loaded compiled.")

(defvar hellmacs--current-module nil
  "The (GROUP . NAME) of the module whose files are being loaded.
Used by `modulep!' and `package!' to know which module they're in.")

(defvar hellmacs--initial-load-path) ; set in early-init.el

;;; Enabling modules: hellmacs! ------------------------------------------

(defun hellmacs-module-key-string (key)
  "KEY, a (GROUP . NAME) module key, as written in `hellmacs!': \":ui theme\".
A group's own module (NAME nil, like core's `:hellmacs') is the group alone."
  (if (cdr key) (format "%s %s" (car key) (cdr key)) (symbol-name (car key))))

(defun hellmacs-module--rel-dir (group name)
  "Module GROUP NAME's directory, relative to a module tree: \"ui/theme/\".
A group's own module (NAME nil) is the group's directory: \"hellmacs/\"."
  (file-name-as-directory
   (concat (substring (symbol-name group) 1) (if name (format "/%s" name) ""))))

(defun hellmacs-module-locate-path (group name)
  "Return the directory of module GROUP NAME, or nil if it doesn't exist."
  (let ((rel (hellmacs-module--rel-dir group name)))
    (seq-some (lambda (dir)
                (let ((path (expand-file-name rel dir)))
                  (and (file-directory-p path) path)))
              hellmacs-module-load-path)))

(defun hellmacs-module-metadata (path &optional key)
  "The alist in module directory PATH's .hellmacsmodule, or its KEY; nil without one.
Doom v3's .doommodule: `name' (GROUP NAME), and optionally `depth'."
  (when (file-exists-p (expand-file-name ".hellmacsmodule" path))
    (hellmacs-dotfile (if key (list path 'module key) (list path 'module)))))

(defun hellmacs-module-from-path (file)
  "The (GROUP . NAME) of the module FILE is in, from its .hellmacsmodule; or nil."
  (when-let* ((dir (hellmacs-dotfile-locate 'module file t))
              (name (hellmacs-module-metadata dir 'name)))
    (cons (car name) (cadr name))))

(defun hellmacs-file-active-p (file)
  "Return non-nil if FILE should be loaded.
If FILE begins with `;;;###if FORM', evaluate FORM; if nil, return nil."
  (if (and file (file-exists-p file))
      (with-temp-buffer
        (insert-file-contents file nil 0 512)
        (goto-char (point-min))
        (if (re-search-forward "^;;;###if[ \t]+\\(.+\\)$" nil t)
            (let ((form (condition-case nil (read (match-string 1)) (error nil))))
              (condition-case nil (eval form t) (error nil)))
          t))
    nil))

(defun hellmacs-module-enable (group name &optional flags depth init-depth config-depth)
  "Enable module GROUP NAME with FLAGS (a list of +symbols) at DEPTH.
Supports separate INIT-DEPTH and CONFIG-DEPTH (by default DEPTH, then
the values in .hellmacsmodule, else 0). Returns nil (and warns) if the
module doesn't exist."
  (if-let* ((path (hellmacs-module-locate-path group name)))
      (let* ((meta-depth (hellmacs-module-metadata path 'depth))
             (base-depth (or depth meta-depth 0))
             (i-depth (or init-depth depth (hellmacs-module-metadata path 'init-depth) meta-depth 0))
             (c-depth (or config-depth depth (hellmacs-module-metadata path 'config-depth) meta-depth 0)))
        (puthash (cons group name)
                 (list :path path
                       :flags flags
                       :depth base-depth
                       :init-depth i-depth
                       :config-depth c-depth
                       :index (hash-table-count hellmacs-modules))
                 hellmacs-modules))
    (display-warning 'hellmacs (format "Unknown module %s, skipped"
                                       (hellmacs-module-key-string (cons group name))))
    nil))

(defmacro hellmacs! (&rest modules)
  "Enable MODULES, in order. Use it once, in your init.el.

MODULES is a list of groups (keywords), each followed by the modules
in that group. A module is a symbol, or a list whose first element is
the module name, followed by +flags and an optional `:depth N',
`:init-depth N', or `:config-depth N':

  (hellmacs! :ui theme
             :editor undo
             :completion vertico (corfu +tab)
             :config (default :depth -10))

An empty (hellmacs!) enables none (only core's own module loads), as
profiles/safe-mode/ does.

See `modulep!' for testing modules and flags from code."
  `(progn (setq hellmacs--block-read t)
          (hellmacs--enable-modules ',modules)))

(defvar hellmacs--block-read nil
  "Non-nil once your init.el ran a `hellmacs!' block, even an empty one.")

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
             (let ((name (car item)) flags depth init-depth config-depth (rest (cdr item)))
               (while rest
                 (let ((x (pop rest)))
                   (cond ((eq x :depth) (setq depth (pop rest)))
                         ((eq x :init-depth) (setq init-depth (pop rest)))
                         ((eq x :config-depth) (setq config-depth (pop rest)))
                         (t (push x flags)))))
               (hellmacs-module-enable group name (nreverse flags) depth init-depth config-depth)))))))

(defun hellmacs-module-list (&optional type)
  "Return the keys of enabled modules, in load order.
TYPE can be `:init' to sort by :init-depth, `:config' to sort by
:config-depth, or nil to sort by :depth."
  (let ((depth-key (pcase type
                     (:init :init-depth)
                     (:config :config-depth)
                     (_ :depth)))
        keys)
    (maphash (lambda (k _) (push k keys)) hellmacs-modules)
    (sort keys (lambda (a b)
                 (let* ((pa (gethash a hellmacs-modules))
                        (pb (gethash b hellmacs-modules))
                        (da (or (plist-get pa depth-key) (plist-get pa :depth) 0))
                        (db (or (plist-get pb depth-key) (plist-get pb :depth) 0)))
                   (if (= da db)
                       (< (plist-get pa :index) (plist-get pb :index))
                     (< da db)))))))

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
       (format "Module %s needs %s; add it to your hellmacs! block"
               (hellmacs-module-key-string key) (hellmacs-module-dependency-string dep))))))

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
  :ignore FORM    don't install it, if FORM is non-nil, but keep its
                  configuration (you installed it some other way)
  :type TYPE      \\='built-in (as :built-in t), \\='virtual (not a real
                  package: never installed), or nil, a normal package
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

(defmacro disable-packages! (&rest packages)
  "Disable PACKAGES: as `(package! NAME :disable t)' for each. See `package!'."
  `(progn ,@(mapcar (lambda (name) `(package! ,name :disable t)) packages)))

(defmacro unpin! (&rest targets)
  "Install TARGETS at their latest version, ignoring their `:pin'.
Use it in your packages.el. Each target is a package name, a module
written (GROUP NAME) or (GROUP) -- every package that module or group
declares -- or t, for every package.

  (unpin! lsp-mode)
  (unpin! (:lang java) (:tools))
  (unpin! t)"
  `(hellmacs-package-unpin ',targets))

(defun hellmacs-package-unpin (targets)
  "Record TARGETS as unpinned. See `unpin!'."
  (dolist (target targets)
    (cond ((eq target t)
           (setq hellmacs-unpinned-packages t))
          ((listp hellmacs-unpinned-packages)
           (if (symbolp target)
               (cl-pushnew target hellmacs-unpinned-packages)
             (pcase-let ((`(,group ,name) target))
               (pcase-dolist (`(,package . ,plist) hellmacs-packages)
                 (when (seq-some (lambda (key)
                                   (and (consp key) (eq (car key) group)
                                        (or (null name) (eq (cdr key) name))))
                                 (plist-get plist :modules))
                   (cl-pushnew package hellmacs-unpinned-packages)))))))))

(defun hellmacs-package-unpinned-p (name)
  "Non-nil if package NAME's `:pin' is ignored (`unpin!')."
  (or (eq hellmacs-unpinned-packages t)
      (memq name hellmacs-unpinned-packages)))

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
                (plist-get plist :ignore)
                (memq (plist-get plist :type) '(built-in virtual))
                (eq built-in t)
                (and (eq built-in 'prefer) (hellmacs-package-built-in-p name)))
      (let ((recipe (copy-sequence (plist-get plist :recipe))))
        (when-let* ((pin (and (not (hellmacs-package-unpinned-p name))
                              (plist-get plist :pin))))
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

(defconst hellmacs-module--compiled-files '("init.el" "config.el")
  "Module files `bin/hellmacs sync' byte-compiles: the ones every startup loads.")

(defun hellmacs-module-compiled-file (key file)
  "Where `bin/hellmacs sync' puts module KEY's FILE compiled."
  (expand-file-name (concat "modules/" (hellmacs-module--rel-dir (car key) (cdr key)) file "c")
                    hellmacs-compiled-dir))

(defun hellmacs-module--load (key file)
  "Load FILE from module KEY's directory, if it exists and is active.
The compiled FILE from the last sync is loaded instead when it may be
\(`hellmacs--use-compiled') and is newer than FILE, so an edited file
loads from source until the next sync. Errors warn instead of aborting
startup: one broken module should degrade Hellmacs, not brick it."
  (let* ((src (expand-file-name file (hellmacs-module-get key :path)))
         (path src)
         (compiled (and hellmacs--use-compiled
                        (member file hellmacs-module--compiled-files)
                        (hellmacs-module-compiled-file key file))))
    ;; Only while the source exists and its ;;;###if condition holds
    (when (and (file-exists-p src) (hellmacs-file-active-p src))
      (when (and compiled (file-exists-p compiled) (file-newer-than-file-p compiled src))
        (setq path compiled))
      (let ((hellmacs--current-module key))
        (with-hellmacs-context 'module
          (condition-case-unless-debug err
              (load path nil 'nomessage 'nosuffix)
            (error
             (display-warning
              'hellmacs (format "Module %s: error in %s: %s"
                                (hellmacs-module-key-string key) file (error-message-string err))
              :error))))))))

(defun hellmacs-module-autoload-files (key)
  "Module KEY's autoload files: its autoload.el and autoload/*.el, as in Doom."
  (let* ((dir (hellmacs-module-get key :path))
         (files (append (and (file-exists-p (expand-file-name "autoload.el" dir))
                             (list (expand-file-name "autoload.el" dir)))
                        (file-expand-wildcards (expand-file-name "autoload/*.el" dir)))))
    (seq-filter #'hellmacs-file-active-p files)))

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
  (setq hellmacs--block-read nil)
  (hellmacs-load-user-file "init.el")
  (cond (hellmacs-modules-override
         (hellmacs--enable-modules hellmacs-modules-override))
        ((not hellmacs--block-read)
         (load (expand-file-name "static/init.example.el" hellmacs-dir) nil 'nomessage 'nosuffix)))
  (hellmacs-modules-enable-core)
  ;; The proxy and CA you set there, for all of Emacs.
  (hellmacs-net-setup))

(defun hellmacs-modules-enable-core ()
  "Enable core's own module, `:hellmacs' (modules/hellmacs/), always, first.
Like Doom v3's (:doom . nil): Hellmacs' own features and packages, which
every configuration gets, whatever its `hellmacs!' block says."
  ;; At the depth its .hellmacsmodule gives: -100, before any other
  ;; (Doom's `:doom' is at -110).
  (hellmacs-module-enable :hellmacs nil))

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
  "Read lisp/packages.el, every enabled module's packages.el, then the user's.
Fills `hellmacs-packages' and `hellmacs-module-dependencies'. A module's
dependencies (`depends-on!') have their packages.el read before its own."
  (setq hellmacs-packages nil
        hellmacs-unpinned-packages nil
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
failed (see lisp/packages.el), and `elpaca-wait' then never returns.
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

;; Used in packages.el files, which a CLI session may read first.
(autoload 'hellmacs-treesit! "hellmacs-treesit" nil nil 'macro)

(autoload 'hellmacs-sync (hellmacs--part-file 'hellmacs-cli 'sync)
  "Install every declared package, then write the synced profile." t)

;; JDK discovery: run by sync, read back when lsp-java loads, never at startup.
;; Every `;;;###autoload' function in lisp/lib/jdk.el belongs here.
(defconst hellmacs-modules--jdk-autoloads
  '(hellmacs-jdk-release-name hellmacs-jdk-parse-release-content
    hellmacs-jdk-home-release hellmacs-jdk-home-major hellmacs-jdk-pick hellmacs-jdk-default-roots hellmacs-jdk-scan-roots hellmacs-jdk-detect
    hellmacs-jdk-write hellmacs-jdk-read hellmacs-jdk-lsp-runtimes hellmacs-jdk-java-executable
    hellmacs-jdk-parse-toolchains-xml hellmacs-jdk-parse-gradle-toolchain
    hellmacs-jdk-toolchains-xml-jdks hellmacs-jdk-build-request
    hellmacs-jdk-gradle-installation-paths hellmacs-jdk-gradle-provisions-p
    hellmacs-jdk-gradle-daemon-range hellmacs-jdk-gradle-version hellmacs-jdk-gradle-environment)
  "The functions core autoloads from lisp/lib/jdk.el.")
(dolist (fn hellmacs-modules--jdk-autoloads)
  (autoload fn (hellmacs--part-file 'hellmacs-lib 'jdk)))

;; The SBOM and license report: `bin/hellmacs sbom' and `licenses'.
(dolist (fn '(hellmacs-compliance-components hellmacs-compliance-collect-licenses
              hellmacs-compliance-license-problems hellmacs-compliance-cyclonedx-sbom))
  (autoload fn (hellmacs--part-file 'hellmacs-cli 'compliance)))

(provide 'hellmacs-modules)
;;; hellmacs-modules.el ends here
