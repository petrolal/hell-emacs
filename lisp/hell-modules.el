;;; hell-modules.el --- Module system: hell!, modulep!, package! -*- lexical-binding: t; -*-

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

;; Modeled on Doom Emacs' module system (`doom!', `modulep!',
;; `package!'), minus its v2 compatibility layers.
;;
;; A module is a directory, `<group>/<name>/' in a module tree (your
;; modules/, Hell Emacs' modules/, then sources/hell+/modules/: see
;; `hell-module-load-path'), written `:group name' (e.g.
;; `sources/hell+/modules/completion/vertico/' is
;; `:completion vertico'). Every file in it is optional:
;;
;;   packages.el  `package!' declarations only -- what to install --
;;                and `depends-on!', the other modules this one needs
;;   autoload.el  commands and helpers other files may call (or
;;   autoload/    several files of them, as in Doom)
;;   init.el      runs early, before any module's config.el
;;   config.el    the module's actual configuration
;;   cli.el       extends bin/hell (sync steps, extra commands)
;;   doctor.el    checks run by `bin/hell doctor'
;;
;; Your `init.el' enables modules with a `hell!' block:
;;
;;   (hell! :ui theme
;;          :completion vertico (corfu +tab)
;;          :config default)
;;
;; `bin/hell sync' (`hell-sync', lisp/cli/sync.el) reads every
;; enabled module's packages.el, then yours, installs those packages
;; through Elpaca, and generates the profile's init file
;; (lisp/hell-profiles.el), which at startup:
;;
;;   1. puts the packages on `load-path' and loads their autoloads
;;   2. loads the modules' autoloads
;;   3. loads each module's init.el, in order, then each config.el
;;
;; and then your config.el. As in Doom, startup never installs anything:
;; after changing your `hell!' block or a packages.el, sync again.
;;
;; Modules in `hell-user-dir'/modules/ take precedence over
;; Hell Emacs' own, so you can override one by copying it there.

;;; Code:

(require 'hell-lib)
(eval-and-compile (hell-require 'hell-lib 'net))
(declare-function elpaca-wait "elpaca" (&optional queue))
(declare-function elpaca-rebuild "elpaca" (package &optional interactive))
(declare-function elpaca-process-queues "elpaca" (&optional queue))
(declare-function elpaca<-status "elpaca" (e))
(declare-function elpaca--queued "elpaca" ())
(declare-function hell-packages-bootstrap "hell-packages" ())

(defvar hell-dir)           ; early-init.el
(defvar hell-core-dir)      ; early-init.el
(defvar hell-modules-dir)   ; early-init.el
(defvar hell-sources-dir)   ; early-init.el
(defvar hell-user-dir)      ; early-init.el
(defvar hell-team-dir)      ; early-init.el
(defvar hell-compiled-dir)  ; early-init.el

;;; Variables --------------------------------------------------------------

(defvar hell-module-load-path
  (append (list (expand-file-name "modules/" hell-user-dir))
          (when (and (bound-and-true-p hell-team-dir)
                     (file-directory-p (expand-file-name "modules/" hell-team-dir)))
            (list (expand-file-name "modules/" hell-team-dir)))
          (list hell-modules-dir
                (expand-file-name "hell+/modules/" hell-sources-dir)))
  "Directories searched for modules, highest priority first.
Each contains <group>/<name>/ module directories: yours, team layer's
\(if configured), Hell Emacs' own, then the sources' (the catalog), as
Doom v3's `doom-module-load-path'.")

(defvar hell-modules (make-hash-table :test #'equal)
  "Enabled modules: a table of (GROUP . NAME) -> plist.
The plist holds :path, :flags, :depth and :index. Populated by
`hell!'; use `hell-module-list' for load order.")

(defvar hell-packages nil
  "Declared packages: an alist of (NAME . PLIST), filled in by `package!'.")

(defvar hell-module-dependencies nil
  "Alist: module key -> the modules it needs, each (GROUP NAME . FLAGS).
Filled in by `depends-on!' as packages.el files are read, and restored
from the synced profile otherwise.")

(defvar hell-treesit-declarations) ; hell-treesit.el
(declare-function hell-treesit-apply "hell-treesit")

(defvar hell-unpinned-packages nil
  "Packages whose `:pin' is ignored: t for every package. See `unpin!'.")

(defvar hell-before-modules-init-hook nil
  "Run before the modules' init.el files load, at startup.")

(defvar hell-after-modules-init-hook nil
  "Run after every module's init.el has loaded, at startup.")

(defvar hell-before-modules-config-hook nil
  "Run before the modules' config.el files load, at startup.")

(defvar hell-after-modules-config-hook nil
  "Run after every module's config.el has loaded, before your config.el.")

(defvar hell--use-compiled nil
  "Non-nil if modules may load what `bin/hell sync' compiled for them.
Set at startup, by the profile's init file, when core loaded compiled.")

(defvar hell--current-module nil
  "The (GROUP . NAME) of the module whose files are being loaded.
Used by `modulep!' and `package!' to know which module they're in.")

(defvar hell--initial-load-path) ; set in early-init.el

;;; Enabling modules: hell! ------------------------------------------------

(defun hell-module-key-string (key)
  "KEY, a (GROUP . NAME) module key, as written in `hell!': \":ui theme\".
A group's own module (NAME nil, like core's `:hell') is the group alone."
  (if (cdr key) (format "%s %s" (car key) (cdr key)) (symbol-name (car key))))

(defun hell-module--rel-dir (group name)
  "Module GROUP NAME's directory, relative to a module tree: \"ui/theme/\".
A group's own module (NAME nil) is the group's directory: \"hell/\"."
  (file-name-as-directory
   (concat (substring (symbol-name group) 1) (if name (format "/%s" name) ""))))

(defun hell-module-locate-path (group name)
  "Return the directory of module GROUP NAME, or nil if it doesn't exist."
  (let ((rel (hell-module--rel-dir group name)))
    (seq-some (lambda (dir)
                (let ((path (expand-file-name rel dir)))
                  (and (file-directory-p path) path)))
              hell-module-load-path)))

(defun hell-module-metadata (path &optional key)
  "The alist in module dir PATH's .hellmodule, or its KEY; nil without one.
Doom v3's .doommodule: `name' (GROUP NAME), and optionally `depth'."
  (when (file-exists-p (expand-file-name ".hellmodule" path))
    (hell-dotfile (if key (list path 'module key) (list path 'module)))))

(defun hell-module-from-path (file)
  "The (GROUP . NAME) of the module FILE is in, from its .hellmodule; or nil."
  (when-let* ((dir (hell-dotfile-locate 'module file t))
              (name (hell-module-metadata dir 'name)))
    (cons (car name) (cadr name))))

(defun hell-file-condition (file)
  "The text of FORM if FILE begins with `;;;###if FORM', else nil."
  (with-temp-buffer
    ;; A fixed coding system: detecting one runs `auto-coding-functions',
    ;; and editorconfig's would load editorconfig at every startup.
    (let ((coding-system-for-read 'utf-8-unix))
      (insert-file-contents file nil 0 512))
    (goto-char (point-min))
    (when (re-search-forward "^;;;###if[ \t]+\\(.+\\)$" nil t)
      (match-string 1))))

(defun hell-file-active-p (file)
  "Return non-nil if FILE should be loaded.
If FILE begins with `;;;###if FORM', evaluate FORM; if nil, return nil."
  (if (and file (file-exists-p file))
      (if-let* ((text (hell-file-condition file)))
          (condition-case err
              (eval (car (read-from-string text)) t)
            (error
             ;; Skipped, as a false condition is: but say why.
             (display-warning
              'hell (format "%s isn't loaded: its `;;;###if %s' failed: %s"
                            (abbreviate-file-name file) text (error-message-string err)))
             nil))
        t)
    nil))

(defconst hell-module-removed
  '(((:ui . dashboard) . "the Altar is GNU Emacs' own startup screen (C-c h s)")
    ((:ui . modeline) . "Emacs' stock mode line shows the JVM status itself")
    ((:tools . projectile) . "Emacs' built-in project.el does it, on C-x p")
    ((:tools . eglot) . "eglot is built into Emacs; the JVM modules use lsp-mode")
    ((:ui . popup) . "Emacs places help, build and test windows itself (`display-buffer')"))
  "Modules Hell Emacs no longer has (13.7), and what to use instead.
As Doom's obsolete modules: `hell!' skips them with this reason.")

(defun hell-module-enable (group name &optional flags depth init-depth config-depth)
  "Enable module GROUP NAME with FLAGS (a list of +symbols) at DEPTH.
Supports separate INIT-DEPTH and CONFIG-DEPTH (by default DEPTH, then
the values in .hellmodule, else 0). Returns nil (and warns) if the
module doesn't exist."
  (if-let* ((path (hell-module-locate-path group name)))
      (let* ((meta-depth (hell-module-metadata path 'depth))
             (base-depth (or depth meta-depth 0))
             (i-depth (or init-depth depth (hell-module-metadata path 'init-depth) meta-depth 0))
             (c-depth (or config-depth depth (hell-module-metadata path 'config-depth) meta-depth 0)))
        (puthash (cons group name)
                 (list :path path
                       :flags flags
                       :depth base-depth
                       :init-depth i-depth
                       :config-depth c-depth
                       :index (hash-table-count hell-modules))
                 hell-modules))
    (display-warning 'hell
                     (if-let* ((why (alist-get (cons group name) hell-module-removed
                                               nil nil #'equal)))
                         (format "Module %s was removed, skipped: %s; take it out of your init.el"
                                 (hell-module-key-string (cons group name)) why)
                       (format "Unknown module %s, skipped"
                               (hell-module-key-string (cons group name)))))
    nil))

(defmacro hell! (&rest modules)
  "Enable MODULES, in order. Use it once, in your init.el.

MODULES is a list of groups (keywords), each followed by the modules
in that group. A module is a symbol, or a list whose first element is
the module name, followed by +flags and an optional `:depth N',
`:init-depth N', or `:config-depth N':

  (hell! :ui theme
         :editor undo
         :completion vertico (corfu +tab)
         :config (default :depth -10))

An empty (hell!) enables none (only core's own module loads), as
profiles/safe-mode/ does.

See `modulep!' for testing modules and flags from code."
  `(progn (setq hell--block-read t)
          (hell--enable-modules ',modules)))

(defvar hell--block-read nil
  "Non-nil once your init.el ran a `hell!' block, even an empty one.")

(defun hell--enable-modules (spec)
  "Enable every module in SPEC, the argument list of `hell!'."
  (clrhash hell-modules)
  (let (group)
    (dolist (item spec)
      (cond ((keywordp item)
             (setq group item))
            ((null group)
             (user-error "hell!: module `%s' comes before any :group" item))
            ((symbolp item)
             (hell-module-enable group item))
            ((consp item)
             (let ((name (car item)) flags depth init-depth config-depth (rest (cdr item)))
               (while rest
                 (let ((x (pop rest)))
                   (cond ((eq x :depth) (setq depth (pop rest)))
                         ((eq x :init-depth) (setq init-depth (pop rest)))
                         ((eq x :config-depth) (setq config-depth (pop rest)))
                         (t (push x flags)))))
               (hell-module-enable group name (nreverse flags) depth init-depth config-depth)))))))

(defun hell-module-list (&optional type)
  "Return the keys of enabled modules, in load order.
TYPE can be `:init' to sort by :init-depth, `:config' to sort by
:config-depth, or nil to sort by :depth."
  (let ((depth-key (pcase type
                     (:init :init-depth)
                     (:config :config-depth)
                     (_ :depth)))
        keys)
    (maphash (lambda (k _) (push k keys)) hell-modules)
    (sort keys (lambda (a b)
                 (let* ((pa (gethash a hell-modules))
                        (pb (gethash b hell-modules))
                        (da (or (plist-get pa depth-key) (plist-get pa :depth) 0))
                        (db (or (plist-get pb depth-key) (plist-get pb :depth) 0)))
                   (if (= da db)
                       (< (plist-get pa :index) (plist-get pb :index))
                     (< da db)))))))

(defun hell-module-get (key prop)
  "Return PROP of the enabled module KEY, a (GROUP . NAME) cons."
  (plist-get (gethash key hell-modules) prop))

;;; Querying modules: modulep! ---------------------------------------------

(defun hell-module-p (group name &optional flags)
  "Return non-nil if module GROUP NAME is enabled with all FLAGS.
A flag written -foo means +foo must NOT be enabled."
  (when-let* ((plist (gethash (cons group name) hell-modules)))
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
ARGS are the module's group and name, then any flags:

  (modulep! :completion corfu)        ; is the module enabled?
  (modulep! :completion corfu +tab)   ; ...with the +tab flag?
  (modulep! :completion corfu -tab)   ; ...without it?

Inside a module's own files, the group and name can be left out:

  (modulep! +tab)"
  (let ((key (if (keywordp (car args))
                 (cons (pop args) (pop args))
               (or hell--current-module
                   (error "modulep!: no module given, and not inside a module")))))
    `(hell-module-p ',(car key) ',(cdr key) ',args)))

;;; Declaring dependencies: depends-on! -------------------------------------

(defmacro depends-on! (group name &rest flags)
  "Declare that this module needs module GROUP NAME, with FLAGS.
Use it in packages.el.

  (depends-on! :tools lsp)

FLAGS are written as for `modulep!' (+flag, or -flag for \"without\").
A missing dependency is reported once, at startup, by `bin/hell
sync' and by `bin/hell doctor', instead of each module checking
for itself. The dependency's own packages.el is read first, so what it
declares (lsp-mode, say) comes before what this module builds on it."
  `(hell-module-depend ',group ',name ',flags))

(defvar hell--packages-read :none
  "Modules whose packages.el the current `hell-modules-read-packages' has read.
`:none' outside of one.")

(defun hell-module--read-packages (key)
  "Read module KEY's packages.el, unless this read has already."
  (unless (member key hell--packages-read)
    (push key hell--packages-read)
    (hell-module--load key "packages.el")))

(defun hell-module-depend (group name flags)
  "Record that current module needs GROUP NAME with FLAGS.  See `depends-on!'."
  (let ((key (or hell--current-module
                 (error "depends-on!: not inside a module's packages.el")))
        (dep (cons group (cons name flags))))
    (let ((deps (alist-get key hell-module-dependencies nil nil #'equal)))
      (unless (member dep deps)
        (setf (alist-get key hell-module-dependencies nil nil #'equal)
              (append deps (list dep)))))
    (when (and (listp hell--packages-read) (hell-module-p group name))
      (hell-module--read-packages (cons group name)))))

(defun hell-module-missing-dependencies (key)
  "Return dependencies of module KEY not enabled, as (GROUP NAME . FLAGS)."
  (seq-remove (pcase-lambda (`(,group ,name . ,flags)) (hell-module-p group name flags))
              (alist-get key hell-module-dependencies nil nil #'equal)))

(defun hell-module-dependency-string (dep)
  "DEP, a (GROUP NAME . FLAGS), formatted like \":tools lsp +flag\"."
  (mapconcat (lambda (x) (format "%s" x)) dep " "))

(defun hell-modules-check-dependencies ()
  "Warn about every enabled module whose dependencies aren't enabled."
  (dolist (key (hell-module-list))
    (dolist (dep (hell-module-missing-dependencies key))
      (display-warning
       'hell
       (format "Module %s needs %s; add it to your hell! block"
               (hell-module-key-string key) (hell-module-dependency-string dep))))))

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
  `(hell-package-declare ',name (list ,@plist)))

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
  `(hell-package-unpin ',targets))

(defun hell-package-unpin (targets)
  "Record TARGETS as unpinned. See `unpin!'."
  (dolist (target targets)
    (cond ((eq target t)
           (setq hell-unpinned-packages t))
          ((listp hell-unpinned-packages)
           (if (symbolp target)
               (cl-pushnew target hell-unpinned-packages)
             (pcase-let ((`(,group ,name) target))
               (pcase-dolist (`(,package . ,plist) hell-packages)
                 (when (seq-some (lambda (key)
                                   (and (consp key) (eq (car key) group)
                                        (or (null name) (eq (cdr key) name))))
                                 (plist-get plist :modules))
                   (cl-pushnew package hell-unpinned-packages)))))))))

(defun hell-package-unpinned-p (name)
  "Non-nil if package NAME's `:pin' is ignored (`unpin!')."
  (or (eq hell-unpinned-packages t)
      (memq name hell-unpinned-packages)))

(defun hell-package-declare (name plist)
  "Record PLIST for package NAME in `hell-packages'. See `package!'."
  (let* ((old (alist-get name hell-packages))
         (new (copy-sequence old)))
    (cl-loop for (k v) on plist by #'cddr
             do (setq new (plist-put new k v)))
    (setq new (plist-put new :modules
                         (append (plist-get old :modules)
                                 (list (or hell--current-module :user)))))
    (setf (alist-get name hell-packages) new)
    name))

(defun hell-packages-apply-env ()
  "Set the environment variables every declared package asks for (`:env').
Disabled packages don't count. Subprocesses, like Elpaca's build
steps, inherit them."
  (pcase-dolist (`(,_name . ,plist) hell-packages)
    (unless (plist-get plist :disable)
      (pcase-dolist (`(,var . ,value) (plist-get plist :env))
        (setenv var value)))))

(defun hell-package-built-in-p (name)
  "Return non-nil if package NAME ships with this Emacs."
  (locate-library (symbol-name name) nil hell--initial-load-path))

(defun hell-package-disabled-p (name)
  "Return non-nil if package NAME was declared with `:disable'."
  (plist-get (alist-get name hell-packages) :disable))

(defun hell-package--order (name plist)
  "Return the Elpaca order for package NAME with `package!' PLIST, or nil.
Nil means the package shouldn't be installed."
  (let ((built-in (plist-get plist :built-in)))
    (unless (or (plist-get plist :disable)
                (plist-get plist :ignore)
                (memq (plist-get plist :type) '(built-in virtual))
                (eq built-in t)
                (and (eq built-in 'prefer) (hell-package-built-in-p name)))
      (let ((recipe (copy-sequence (plist-get plist :recipe))))
        (when-let* ((pin (and (not (hell-package-unpinned-p name))
                              (plist-get plist :pin))))
          (setq recipe (plist-put recipe :ref pin)))
        (if recipe (cons name recipe) name)))))

;; `:disable' also has to silence the package's configuration, which
;; lives in some module's `use-package' block, so the block would
;; otherwise try to load a package that was never installed.
(defun hell--use-package-disabled-a (fn name &rest args)
  "Expand to nothing if package NAME was disabled with `package!'.
Otherwise call FN, `use-package', with NAME and ARGS."
  (unless (hell-package-disabled-p name)
    (apply fn name args)))
(with-eval-after-load 'use-package-core
  (advice-add 'use-package :around #'hell--use-package-disabled-a))

;;; Loading ----------------------------------------------------------------

(defun hell-load-user-file (name)
  "Load NAME from `hell-user-dir', if it exists.
Errors are reported as warnings instead of aborting startup, so a typo
in your config leaves you with a working editor to fix it in."
  (let ((file (expand-file-name name hell-user-dir)))
    (when (file-exists-p file)
      (condition-case-unless-debug err
          (load file nil 'nomessage 'nosuffix)
        (error
         (display-warning
          'hell (format "Error loading %s: %s"
                        (abbreviate-file-name file) (error-message-string err))
          :error))))))

(defun hell-module-compiled-files (key)
  "Module KEY's files `bin/hell sync' byte-compiles: the ones a startup loads.
Its init.el and config.el, its +NAME.el (`hell-module-load'), its
autoload files and its themes (themes/NAME-theme.el), relative to its
directory."
  (let ((dir (hell-module-get key :path)))
    (append '("init.el" "config.el")
            (mapcar (lambda (file) (file-relative-name file dir))
                    (append (file-expand-wildcards (expand-file-name "+*.el" dir))
                            (hell-module-autoload-files key)
                            (file-expand-wildcards
                             (expand-file-name "themes/*-theme.el" dir)))))))

(defun hell-module-compiled-file (key file)
  "Where `bin/hell sync' puts module KEY's FILE compiled."
  (expand-file-name (concat "modules/" (hell-module--rel-dir (car key) (cdr key)) file "c")
                    hell-compiled-dir))

(defun hell-module-file-to-load (key file)
  "The file to load module KEY's FILE from.
Its compiled copy from the last sync when that may be used
\(`hell--use-compiled') and is newer than FILE, so an edited file
loads from source until the next sync; else FILE itself."
  (let ((src (expand-file-name file (hell-module-get key :path))))
    (or (and hell--use-compiled
             (let ((compiled (hell-module-compiled-file key file)))
               (and (file-exists-p src) (file-newer-than-file-p compiled src)
                    compiled)))
        src)))

(defun hell-module--autoload-name (key file)
  "The name autoloads load module KEY's autoload FILE by.
As `hell-module-file-to-load', without its extension: an autoload
loads by a name that must take a suffix."
  (file-name-sans-extension (hell-module-file-to-load key file)))

(defun hell-module--load (key file &optional unconditional)
  "Load FILE from module KEY's directory, if it exists and is active.
From its compiled copy when it can be (`hell-module-file-to-load').
UNCONDITIONAL means sync found no `;;;###if' line in FILE: while that
sync's compiled copy is the one loaded (the source unchanged since), the
source isn't read again to look. Errors warn instead of aborting
startup: one broken module should degrade Hell Emacs, not brick it."
  (let ((src (expand-file-name file (hell-module-get key :path)))
        (path (hell-module-file-to-load key file)))
    ;; Only while the source exists and its ;;;###if condition holds
    (when (or (and unconditional (not (equal path src)))
              (hell-file-active-p src))
      (let ((hell--current-module key))
        (with-hell-context 'module
          (condition-case-unless-debug err
              (load path nil 'nomessage 'nosuffix)
            (error
             (display-warning
              'hell (format "Module %s: error in %s: %s"
                            (hell-module-key-string key) file (error-message-string err))
              :error))))))))

(defun hell-module-autoload-files (key)
  "Module KEY's autoload files: its autoload.el and autoload/*.el, as in Doom."
  (let* ((dir (hell-module-get key :path))
         (files (append (and (file-exists-p (expand-file-name "autoload.el" dir))
                             (list (expand-file-name "autoload.el" dir)))
                        (file-expand-wildcards (expand-file-name "autoload/*.el" dir)))))
    (seq-filter #'hell-file-active-p files)))

(defun hell-module-load (name)
  "Load NAME (like \"+paths\") from the directory of the module being loaded.
For a module's files to load their siblings: unlike `load-file-name',
this still points at the module when its config.el runs compiled.
Within a module, NAME loads compiled when it can (`hell-module-file-to-load')."
  (if hell--current-module
      (load (hell-module-file-to-load hell--current-module (concat name ".el"))
            nil 'nomessage 'nosuffix)
    (load (expand-file-name name (file-name-directory (or load-file-name buffer-file-name)))
          nil 'nomessage)))

(defvar hell-modules-override nil
  "When non-nil, a `hell!' argument list enabled instead of the user's.
Your init.el still runs (for its settings). Set by `bin/hell
bundle --modules', which packs another module set.")

(defun hell-modules-read-config ()
  "Enable modules from the user's init.el (its `hell!' block).
Without a user init.el, or without a `hell!' call in it, the
defaults in static/init.example.el apply; `hell-modules-override'
wins over both."
  (hell--enable-modules nil)
  (setq hell--block-read nil)
  (hell-load-user-file "init.el")
  (cond (hell-modules-override
         (hell--enable-modules hell-modules-override))
        ((not hell--block-read)
         (load (expand-file-name "static/init.example.el" hell-dir) nil 'nomessage 'nosuffix)))
  (hell-modules-enable-core)
  ;; The proxy and CA you set there, for all of Emacs.
  (hell-net-setup))

(defun hell-modules-enable-core ()
  "Enable core's own module, `:hell' (modules/hell/), always, first.
Like Doom v3's (:doom . nil): Hell Emacs' own features and packages, which
every configuration gets, whatever its `hell!' block says."
  ;; At the depth its .hellmodule gives: -100, before any other
  ;; (Doom's `:doom' is at -110).
  (hell-module-enable :hell nil))

(defvar hell--loaded-cli-files nil
  "The cli.el files `hell-modules-load-cli-files' has loaded this session.")

(defun hell-modules-load-cli-files ()
  "Load every enabled module's cli.el, which extends `bin/hell'.
A cli.el may add to `hell-sync-functions' or define
`defcli!' commands (new bin/hell commands). Loaded
by bin/hell and `hell-sync', never at a normal startup."
  (dolist (key (hell-module-list))
    (let ((file (expand-file-name "cli.el" (hell-module-get key :path))))
      ;; Once per session: bin/hell loads them before running a
      ;; command, and `hell-sync' loads them again.
      (unless (member file hell--loaded-cli-files)
        (push file hell--loaded-cli-files)
        (hell-module--load key "cli.el")))))

(defun hell-modules-read-packages ()
  "Read lisp/packages.el, module packages.el, team packages, then user's.
Fills `hell-packages' and `hell-module-dependencies'. A module's
dependencies (`depends-on!') have their packages.el read before its own."
  (setq hell-packages nil
        hell-unpinned-packages nil
        hell-module-dependencies nil
        hell-treesit-declarations nil)
  (let ((hell--current-module :core))
    (load (expand-file-name "packages.el" hell-core-dir) nil 'nomessage 'nosuffix))
  (let ((hell--packages-read nil))
    (dolist (key (hell-module-list))
      (hell-module--read-packages key)))
  (when (and (bound-and-true-p hell-team-dir)
             (file-exists-p (expand-file-name "packages.el" hell-team-dir)))
    (load (expand-file-name "packages.el" hell-team-dir) nil 'nomessage 'nosuffix))
  (hell-load-user-file "packages.el"))

(defvar hell-lock-file
  (let ((user-lock (expand-file-name "packages.lock.eld" hell-user-dir)))
    (if (or (file-exists-p user-lock) (not (bound-and-true-p hell-team-dir)))
        user-lock
      (let ((team-lock (expand-file-name "packages.lock.eld" hell-team-dir)))
        (if (file-exists-p team-lock) team-lock user-lock))))
  "Exact commits of every installed package, written by `bin/hell lock'.
When it exists, packages are installed at these commits instead of the
latest ones, so a config can be reproduced on another machine.  It sits
next to your config (or in the team layer) so you can version it
together.  `bin/hell upgrade' rewrites it after updating.")

(defvar hell-default-lock-file (expand-file-name "static/packages.lock.eld" hell-dir)
  "The commits Hell Emacs was tested with, written by `make lock'.
Sync installs from it when there's no `hell-lock-file', so a fresh install
gets the same packages as everyone else's, not whatever is newest that day.
It covers every module's packages, with every flag.")

(defun hell-lock-file-in-use ()
  "The lock file sync installs from: yours, else the default; nil if neither."
  (seq-find #'file-exists-p (list hell-lock-file hell-default-lock-file)))

(defun hell-modules-install-packages (&optional ignore-lock)
  "Read every packages.el, then install and activate the declared packages.
Loads Elpaca, and blocks until it has finished, so module config can
use the packages. Uses `hell-lock-file-in-use' unless IGNORE-LOCK."
  (with-hell-network
    (hell-modules--install-packages ignore-lock))
  ;; Inside, the packages' :env only reached the fetching and building (the
  ;; environment there is a copy); this session needs it too (LSP_USE_PLISTS).
  (hell-packages-apply-env))

(defun hell-modules--install-packages (ignore-lock)
  "`hell-modules-install-packages', inside `with-hell-network'.
Non-nil IGNORE-LOCK installs without the lock file's pins."
  (hell-packages-bootstrap)
  (defvar elpaca-lock-file)
  (setq elpaca-lock-file (and (not ignore-lock) (hell-lock-file-in-use)))
  (hell-modules-read-packages)
  (hell-packages-apply-env)
  (let ((rebuild (hell-packages--env-changed)))
    (pcase-dolist (`(,name . ,plist) (reverse hell-packages))
      (when-let* ((order (hell-package--order name plist)))
        (eval `(elpaca ,order) t)))
    (hell--elpaca-wait)
    ;; Already-built packages whose :env changed were compiled without
    ;; it; Elpaca doesn't notice, so rebuild them explicitly.
    (when rebuild
      (dolist (name rebuild)
        (elpaca-rebuild name))
      (elpaca-process-queues)
      (hell--elpaca-wait))
    (hell-packages--write-env-stamps)))

;;; Build environment stamps ---------------------------------------------------
;;
;; `package!'s :env only affects a package when it's compiled, so each
;; package's :env is recorded when it's built, and a package whose :env
;; changes since is rebuilt.

(defun hell-packages--env-stamp-file (name)
  "Where the :env package NAME was last built with is recorded."
  (expand-file-name (format "build-env/%s.eld" name) hell-data-dir))

(defun hell-packages--recorded-env (name)
  "Return the :env package NAME was last built with, or nil."
  (let ((file (hell-packages--env-stamp-file name)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (ignore-errors (read (current-buffer)))))))

(defun hell-packages--env-changed ()
  "Return the installed packages whose :env differs from their last build."
  (defvar elpaca-builds-directory)
  (cl-loop for (name . plist) in hell-packages
           when (and (hell-package--order name plist)
                     (file-directory-p (expand-file-name (symbol-name name)
                                                         elpaca-builds-directory))
                     (not (equal (plist-get plist :env)
                                 (hell-packages--recorded-env name))))
           collect name))

(defun hell-packages--write-env-stamps ()
  "Record the :env every installed package was just built with."
  (pcase-dolist (`(,name . ,plist) hell-packages)
    (when (hell-package--order name plist)
      (let ((file (hell-packages--env-stamp-file name))
            (env (plist-get plist :env)))
        (cond (env
               (make-directory (file-name-directory file) t)
               (with-temp-file file (prin1 env (current-buffer))))
              ((file-exists-p file)
               (delete-file file)))))))

(defcustom hell-elpaca-stall-timeout 30
  "Seconds of no progress, with only blocked packages left, before giving up."
  :type 'natnum
  :group 'hell)

(defun hell--elpaca-wait ()
  "Like `elpaca-wait', but give up if Elpaca stops making progress.
Elpaca can leave packages blocked forever on a dependency whose build
failed (see lisp/packages.el), and `elpaca-wait' then never returns.
A watchdog notices when every unfinished package has been blocked,
unchanged, for `hell-elpaca-stall-timeout' seconds, and interrupts
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
                           (> (- (float-time) since) hell-elpaca-stall-timeout))
                      (display-warning
                       'hell
                       (format "Elpaca stalled with %d package(s) blocked; giving up on them. \
Running the sync again usually finishes the job." (length pending)))
                      ;; Picked up by `elpaca-wait''s loop as a keyboard quit,
                      ;; which fails the unfinished packages and returns.
                      (setq quit-flag t))))))))
    (unwind-protect
        ;; Failing a package signals; callers check statuses afterwards
        ;; (see `hell-sync'), which reports every failure, not just one.
        (condition-case nil (elpaca-wait)
          (elpaca-build-error nil))
      (cancel-timer watchdog))))

;; Used in packages.el files, which a CLI session may read first.
(autoload 'hell-treesit! "hell-treesit" nil nil 'macro)

(autoload 'hell-sync (hell--part-file 'hell-cli 'sync)
  "Install every declared package, then write the synced profile." t)

;; JDK discovery: run by sync, read back when lsp-java loads, never at startup.
;; Every `;;;###autoload' function in lisp/lib/jdk.el belongs here.
(defconst hell-modules--jdk-autoloads
  '(hell-jdk-release-name hell-jdk-parse-release-content
    hell-jdk-home-release hell-jdk-home-major hell-jdk-pick hell-jdk-default-roots hell-jdk-scan-roots hell-jdk-detect
    hell-jdk-write hell-jdk-read hell-jdk-lsp-runtimes hell-jdk-java-executable
    hell-jdk-parse-toolchains-xml hell-jdk-parse-gradle-toolchain
    hell-jdk-toolchains-xml-jdks hell-jdk-build-request
    hell-jdk-gradle-installation-paths hell-jdk-gradle-provisions-p
    hell-jdk-gradle-daemon-range hell-jdk-gradle-version hell-jdk-gradle-environment)
  "The functions core autoloads from lisp/lib/jdk.el.")
(dolist (fn hell-modules--jdk-autoloads)
  (autoload fn (hell--part-file 'hell-lib 'jdk)))

;; The SBOM and license report: `bin/hell sbom' and `licenses'.
(dolist (fn '(hell-compliance-components hell-compliance-collect-licenses
              hell-compliance-license-problems hell-compliance-cyclonedx-sbom))
  (autoload fn (hell--part-file 'hell-cli 'compliance)))

;; The quality gate, `bin/hell check' and `C-c c x' / `C-c c l' (:config
;; default): lisp/cli/ isn't scanned for autoloads, so they're named here.
(autoload 'hell-check (hell--part-file 'hell-cli 'check)
  "Run the unified Static Analysis and Linting Quality Gate on TARGET." t)
(autoload 'hell-lint (hell--part-file 'hell-cli 'check)
  "Alias for `hell-check'." t)

(provide 'hell-modules)
;;; hell-modules.el ends here
