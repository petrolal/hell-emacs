;;; <group>/<name>/config.el -*- lexical-binding: t; -*-

;; SCAFFOLD for a new module. Copy this directory to
;; sources/hellmacs+/modules/<group>/<name>/ (or $HELLMACSDIR/modules/<group>/<name>/ for
;; a private one), then enable it in your init.el:
;;
;;   (hellmacs! ... :<group> <name> ...)
;;
;; A module can have any of these files, all optional:
;;   packages.el  `package!' declarations (what to install)
;;   autoload.el  commands/helpers other files may call (or autoload/*.el)
;;   init.el      runs before any module's config.el
;;   config.el    this file: the actual configuration
;;
;; Conventions every module follows:
;;
;;   - A comment at the top saying what the module does, which leader
;;     group (if any) it owns, and what its flags do. See
;;     sources/hellmacs+/modules/completion/corfu/config.el for a real example.
;;   - Install with `package!' in packages.el; configure with
;;     `use-package' here. Blocks are deferred by default (see
;;     `use-package-always-defer'), so load lazily via
;;     `:hook'/`:bind'/`:commands', or `:demand t' only when genuinely
;;     needed immediately (e.g. `vertico', so the first minibuffer uses
;;     it). Never load a package just by mentioning it.
;;   - Test flags with `(modulep! +flag)'; other modules with
;;     `(modulep! :group name)'.
;;   - Keybindings follow Emacs conventions (see "Rules"
;;     in docs/roadmap.md): never rebind a default key to something
;;     else, and nothing modal or vi-like (no single-key commands
;;     outside special buffers). Improve a default command with
;;     `[remap ...]' in `:bind', add a `C-c' leader binding with
;;     `hellmacs-leader-def', or put a mode's own commands on the
;;     `C-c l' localleader with `hellmacs-localleader-def'.
;;   - Leader groups belong to exactly one module -- the one that owns
;;     that feature. Don't duplicate a binding across modules; layer
;;     onto the owning module's group instead.

(use-package example-package
  :init
  ;; Settings read *before* the package loads (safe to set unconditionally,
  ;; cheap, no side effects on Emacs internals).
  (setq example-package-some-option t)
  ;; A leader binding (`C-c x x'). The command is autoloaded, so
  ;; pressing the key loads the package.
  (hellmacs-leader-def
    "x"   "example"
    "x x" '("example command" . example-package-command))
  :hook
  ;; Load lazily, the first time `some-mode' turns on.
  (some-mode . example-package-mode)
  :bind
  ;; Make a default key smarter instead of adding a new one.
  ([remap some-builtin-command] . example-package-better-command)
  :config
  ;; Runs once, after the package actually loads. Settings here may
  ;; depend on the package's own internals (faces, keymaps, etc.).
  (example-package-setup))

(when (modulep! +extra)
  (use-package example-extra
    :after example-package))
