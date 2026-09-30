# Configuration & Module System

Hellmacs uses a modular architecture inspired by Doom Emacs, but modernized for pure Emacs workflows and asynchronous package management via [Elpaca](https://github.com/progfolio/elpaca).

---

## User Configuration Files

Your personal configuration lives in `~/.config/hellmacs/` (or `$HELLMACSDIR`):

```
~/.config/hellmacs/
├── init.el          # Module declarations via (hellmacs! ...)
├── packages.el      # Extra packages declared via (package! ...)
├── config.el        # Custom Elisp configuration loaded after modules
└── custom.el        # Automatically written by Emacs customize system
```

---

## Enabling and Disabling Modules (`init.el`)

The `(hellmacs! ...)` block in `~/.config/hellmacs/init.el` dictates which modules are loaded at boot. Without a block, you get the defaults (`static/init.example.el`); an empty `(hellmacs!)` loads no module but Hellmacs' own core module (`:hellmacs`: the startup screen, themed prompts), which is always on.

### Syntax
```elisp
(hellmacs! :ui
           theme              ; Hellmacs Inferno theme
           dashboard          ; The Altar startup screen
           modeline           ; Custom lightweight mode-line

           :editor
           undo               ; Persistent undo history (undo-fu-session)

           :completion
           (corfu +tab)       ; In-buffer completion popup with TAB completion
           vertico            ; Minibuffer completion (Consult + Marginalia + Orderless)

           :tools
           build              ; Gradle & Maven compilation
           debugger           ; DAP mode for JVM debugging
           lsp                ; Language Server Protocol (lsp-mode)
           magit              ; Git interface

           :lang
           (java +lombok +tree-sitter) ; Java with JDTLS, Lombok and Tree-sitter
           (kotlin +tree-sitter)       ; Kotlin with kotlin-language-server
           (clojure +tree-sitter)      ; Clojure with CIDER and clojure-lsp

           :config
           default)           ; Default keybindings & which-key
```

### Module Flags (`+flag`)
Modules support granular flags:
* `(corfu +tab)`: Enables TAB to complete when nothing is indented.
* `(java +lombok)`: Downloads and attaches Lombok javaagent to JDTLS.
* `(java +tree-sitter)`: Activates `java-ts-mode` instead of classic `java-mode`.

### New Default Modules
Your `init.el` is never rewritten, so a config made before a module existed doesn't get it. `bin/hellmacs doctor` (and `upgrade`) lists the modules on by default that your block misses, such as `:tools magit` for Git. Add the ones you want, or all of them with `bin/hellmacs config --add-defaults` (it keeps `init.el.bak`), then run `bin/hellmacs sync`. Modules you commented out are left alone.

---

## Declaring Additional Packages (`packages.el`)

To install third-party packages that are not part of Hellmacs modules, declare them in `~/.config/hellmacs/packages.el` using the `package!` macro:

```elisp
;; Install from MELPA / GNU ELPA
(package! yaml-mode)
(package! restclient)

;; Install from a specific Git repository
(package! example-pkg
  :recipe (:host github :repo "username/example-pkg"))

;; Pin a package to a specific commit
(package! another-pkg
  :pin "abcdef1234567890")

;; Disable a package included by a built-in module
(package! unwanted-pkg :disable t)
```

After modifying `init.el` or `packages.el`, always run:
```sh
bin/hellmacs sync
```
*(or press `C-c h s` inside Emacs).*

---

## Personal Elisp (`config.el`)

`~/.config/hellmacs/config.el` runs after all modules have loaded. Use standard `use-package`, `after!`, and `setq`:

```elisp
;; Customize variables
(setq display-line-numbers-type 'relative)

;; Configure packages
(after! lsp-mode
  (setq lsp-lens-enable t))

;; Custom keybindings
(keymap-global-set "C-c o" #'my-custom-command)
```

---

## Creating Private Custom Modules

You can create private modules that override or extend Hellmacs modules. Hellmacs looks for a module in your `~/.config/hellmacs/modules/` first, then in its own (`modules/`, core's; `sources/hellmacs+/modules/`, the catalog), so a module of yours with the same name replaces Hellmacs'.
1. Create a directory in `~/.config/hellmacs/modules/<category>/<name>/` (e.g. `~/.config/hellmacs/modules/lang/rust/`), or copy Hellmacs' `static/module-template/` there.
2. Add any of the following optional files:
   * `.hellmacsmodule`: its name, `"0.9.0" ((name :lang rust))`, and `(depth . N)` if it must load before (negative) or after other modules.
   * `packages.el`: Package declarations (`package! ...`).
   * `config.el`: Main configuration (`use-package ...`).
   * `autoload.el`: Functions to autoload on demand.
   * `init.el`: Early configuration run before `config.el`.
   * `doctor.el`: Health checks for `bin/hellmacs doctor`.
3. Enable `:category name` in your `init.el` and run `bin/hellmacs sync`.

---

## Corporate Networks (proxy, CA, mirrors)

Set these in `~/.config/hellmacs/init.el`, then run `bin/hellmacs sync`:

```elisp
(setq hellmacs-proxy "http://proxy.corp.example:3128")   ; nil: $HTTPS_PROXY / $HTTP_PROXY
(setq hellmacs-no-proxy '("localhost" ".corp.example"))  ; nil: $NO_PROXY
(setq hellmacs-ca-bundle "~/certs/corp-root-ca.pem")      ; your company's root CA (PEM)
(setq hellmacs-mirrors                                   ; upstream prefix -> mirror prefix
      '(("https://github.com/" . "https://git.corp.example/github/")
        ("https://repo1.maven.org/maven2/" . "https://artifactory.corp.example/maven-central/")))
```

* The proxy and the CA apply to all of Emacs. The CA is trusted on top of the system's, never instead of it.
* Mirrors apply only while Hellmacs itself fetches (`sync`, `upgrade`, package and language-server installs), to downloads and to git, Elpaca's included. Your own repositories and pushes are untouched.
* Every pinned download is still checked by SHA-256, so a mirror can't serve a different file.
* An environment proxy (`bin/hellmacs env` saves `HTTPS_PROXY`, `NO_PROXY`, ...) needs no setting.
* Git needs version 2.31 or newer for these settings.
* `bin/hellmacs doctor` shows the proxy, CA and mirrors in use and checks that each host Hellmacs fetches from can be reached through them. A TLS failure is reported as a certificate your CA bundle doesn't cover, not as a failed download. Without any of these settings, `bin/hellmacs doctor --network` runs the same checks.
* No internet at all? Make an offline bundle on a connected machine with `bin/hellmacs bundle hellmacs.tar.zst`, then run `bin/hellmacs install --from-bundle hellmacs.tar.zst` on the offline one. See [`bundle`](cli.md#bundle).

---

## Multiple Profiles

Hellmacs supports isolated configuration profiles (e.g. for work and personal setups):

```sh
# Sync and manage a specific profile
bin/hellmacs --profile work sync
bin/hellmacs --profile work doctor

# Start Emacs with a specific profile
emacs --profile work
```

Each profile maintains completely isolated configs, packages (`~/.local/share/hellmacs-work`), caches, and state directories. As in Doom v3, a directory is a profile: the config for `--profile work` is `~/.config/hellmacs-work/`, else `profiles/work/` in your config (`~/.config/hellmacs/profiles/work/`), else `profiles/work/` in Hellmacs.

Hellmacs ships one: **`safe-mode`**, its core and none of your modules or config. When something breaks Emacs, start there and add modules back one at a time:

```sh
bin/hellmacs --profile safe-mode sync
emacs --profile safe-mode
```

See [`profiles/README.md`](../profiles/README.md).
