# System Architecture & Design System

This document details the software architecture, code organization (Doom Emacs v3's layout), boot lifecycle, directory resolution rules, and aesthetic design system of **Hellmacs**.

---

## 1. High-Level Architecture

Hellmacs is structured into four distinct layers:

```
+-------------------------------------------------------------------------+
|                              USER CONFIG                                |
|          ~/.config/hellmacs/ (init.el, packages.el, config.el)          |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                             MODULE SYSTEM                               |
|  modules/hellmacs/ (core's own), sources/hellmacs+/modules/<group>/     |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                             CORE ENGINE                                 |
|  early-init.el, lisp/ (hellmacs.el, lib/, cli/), profile's init file   |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                         BASE RUNTIME & CLI                              |
|    Emacs 29+ (Native Comp) + bin/hellmacs, bin/hellmacs-COMMAND         |
+-------------------------------------------------------------------------+
```

---

## 2. Code Organization (Doom Emacs v3's layout)

Since Phase 16, Hellmacs is laid out as Doom Emacs v3 (`doomemacs/core`),
so anyone who knows Doom finds their way:

| Doom v3 | Hellmacs | What it holds |
|---|---|---|
| `early-init.el` | `early-init.el` | Boot, XDG directories, startup hacks; loads core and calls `hellmacs-initialize` |
| *(no root `init.el`)* | *(none)* | `sync` generates each profile's `init.MAJOR.MINOR.el`; `.gitignore` keeps a root one out |
| `lisp/doom.el` | `lisp/hellmacs.el` | The heart: lifecycle hooks, GC, directories, `hellmacs-initialize`/`-start`/`-startup` |
| `lisp/doom-emacs.el` | `lisp/hellmacs-emacs.el` | Stock Emacs, with saner defaults, and the entry point (the init file loader's override) |
| `lisp/doom-lib.el` | `lisp/hellmacs-lib.el` | Macros (`after!`, `add-hook!`), `hellmacs-require`, `hellmacs-dotfile` |
| `lisp/doom-modules.el` | `lisp/hellmacs-modules.el` | `hellmacs!`, `modulep!`, `package!`, module load path and metadata |
| `lisp/doom-profiles.el` | `lisp/hellmacs-profiles.el` | The profile's generated init file: `init.d/` parts on `hellmacs-startup-functions` |
| `lisp/doom-cli.el` | `lisp/hellmacs-cli.el` | The command dispatcher and the helpers commands share |
| `lisp/lib/*.el` | `lisp/lib/` (`jdk`, `net`, `lsp-status`) | The library, off `load-path`: `(hellmacs-require 'hellmacs-lib 'net)` |
| `lisp/cli/*.el` | `lisp/cli/` (`sync`, `bundle`, `compliance`, `config`, `verify`) | The CLI's parts: `(hellmacs-require 'hellmacs-cli 'verify)` |
| `modules/doom/` (`:doom`) | `modules/hellmacs/` (`:hellmacs`) | Core's own module, always on, first: core's packages, gcmh, the Altar, themed UX, the `C-c` leader API (`autoload/keybinds.el`) |
| `sources/doom+/modules/` | `sources/hellmacs+/modules/` | The module catalog (a submodule in Doom, in-tree here) |
| `.doom`, `.doommodule` | `.hellmacs`, `.hellmacsmodule` | Metadata: a version string, then an alist (`name`, `depth`) |
| `bin/doom`, `bin/doom-COMMAND`, `bin/doomscript`, `bin/doom.sh` | `bin/hellmacs`, `bin/hellmacs-COMMAND`, `bin/hellmacsscript`, `bin/hellmacs.sh` | The CLI: a dispatcher (global options, aliases, `$HELLMACSPATH`), one file per command, a script runner, and a bash launcher |
| `profiles/` (`safe-mode`) | `profiles/` (`safe-mode`) | Profiles shipped; a directory is a profile |

**Modules are found** in this order (`hellmacs-module-load-path`, Doom's
`doom-module-load-path`): your `~/.config/hellmacs/modules/`, then
`modules/`, then `sources/hellmacs+/modules/`. A module's depth comes from
its `.hellmacsmodule` unless your `hellmacs!` block gives one.

**Not taken from Doom:** straight.el (Elpaca: Doom's own `lisp/doom-elpaca.el`
says it replaces straight next), evil and the `:doom compat` module, the
shell/Lisp polyglot `bin/doom` and its `defcli!` framework (a sh dispatcher
and plain `hellmacs-cli-NAME` functions instead), explicit `profiles.el`
profiles (directory profiles only), the catalog as a git submodule, Windows'
`doom.ps1`, org-format docs, and the `SPC` leader: the keybinding policy is
unchanged. **Added to Doom's:** the generated init file is byte-compiled (and
core and modules with it), for the startup budget.

---

## 3. Directory Resolution & XDG Compliance

Hellmacs strictly isolates user configurations, installed packages, caches, and session state:

```
Hellmacs' installation (e.g. ~/.config/emacs), laid out as Doom v3's
  ├── early-init.el     # boot; loads core (hellmacs-initialize)
  ├── .hellmacs         # the project (Doom's .doom)
  ├── bin/              # hellmacs (dispatch), hellmacs-COMMAND, hellmacsscript, hellmacs.sh
  ├── lisp/             # the engine; lib/ and cli/ load with hellmacs-require
  ├── modules/hellmacs/ # core's own module, :hellmacs
  ├── sources/hellmacs+/modules/  # the module catalog
  ├── profiles/         # shipped profiles (safe-mode)
  └── static/

Modules are found in this order (`hellmacs-module-load-path`): your
modules/, then modules/, then sources/hellmacs+/modules/.

$HELLMACS_USER_DIR (User Configuration: ~/.config/hellmacs/ or $HELLMACSDIR)
  ├── init.el          # Module declarations (hellmacs! ...)
  ├── packages.el      # Extra packages (package! ...)
  ├── config.el        # Custom post-load Elisp
  ├── custom.el        # Emacs customize output
  ├── packages.lock.eld# Lockfile generated by `bin/hellmacs lock`
  └── modules/         # Private custom modules (override core modules)

XDG Storage Layout:
  Data  ($XDG_DATA_HOME/hellmacs/):  Installed packages (Elpaca); profiles/default/: profile.eld,
                                      init.d/ (the parts), the generated init.MAJOR.MINOR.el(c),
                                      autoloads.el(c), compiled/ (core and modules)
  Cache ($XDG_CACHE_HOME/hellmacs/): Native compilation eln-cache, package caches
  State ($XDG_STATE_HOME/hellmacs/): Undo history, recentf, bookmarks, dap-breakpoints
```

---

## 4. Boot Lifecycle & Speed Optimization

Hellmacs achieves **~0.05s startup time** through a two-phase initialization model with static compiled profiles:

```mermaid
sequenceDiagram
    autonumber
    participant Host as OS / Shell
    participant EI as early-init.el
    participant IN as profile init file (generated by sync)
    participant CR as lisp/hellmacs.el
    participant MD as modules/
    participant UC as user config.el

    Host->>EI: emacs invocation
    EI->>EI: GC tuning (collection off during boot)
    EI->>EI: Inhibit UI chrome (tool-bar, menu-bar, scroll-bar), hide mode-line and messages
    EI->>EI: Remap XDG directories
    EI->>CR: Load core (compiled if current); hellmacs-initialize
    CR->>CR: Entry point replaces Emacs' init file loading (lisp/hellmacs-emacs.el)
    CR->>IN: hellmacs-start: load init.MAJOR.MINOR.elc (none: warn, plain Emacs)
    IN->>IN: Part 20: user init.el settings; part 30: packages' :env
    IN->>CR: hellmacs-startup: run hellmacs-startup-functions
    CR->>IN: 5: packages on load-path; 60: modules' autoloads; 70: packages' autoloads
    IN->>MD: 80: every module's init.el (core's :hellmacs first), then every config.el
    IN->>UC: Load ~/.config/hellmacs/config.el
    CR->>CR: after-init: custom-file, GC threshold back to 16MB (gcmh collects when idle)
```

1. **Pre-Frame (`early-init.el`)**:
   * Disables GUI chrome before frame creation, and hides the mode-line and messages until the init file has loaded.
   * Sets temporary 1GB GC allocation threshold to avoid boot-time collections.
   * Remaps cache, state, and data paths to XDG directories.
   * Loads core and calls `hellmacs-initialize`, as Doom's calls `doom-initialize`.
2. **The profile's init file**: as in Doom v3 there is no root `init.el`. `bin/hellmacs sync` writes `<profile>/init.MAJOR.MINOR.el` from the parts in `init.d/` (`lisp/hellmacs-profiles.el`) and compiles it; the entry point in `lisp/hellmacs-emacs.el` loads it (`hellmacs-start`). Batch sessions: `emacs --batch -l early-init.el -f hellmacs-start`.
   * Everything was decided at sync time: the enabled modules, the packages' paths, every autoload. Startup reads no `packages.el`, checks nothing for staleness, and never installs: after a config change, `bin/hellmacs sync` (`doctor` notices a stale profile).
   * `hellmacs-startup` runs `hellmacs-startup-functions` by depth: 5 data, 60 modules' autoloads, 70 packages' autoloads, 80 modules (`init.el` $\rightarrow$ `config.el`) $\rightarrow$ user `config.el`.
   * Restores GC threshold to 16MB managed by GCMH during idle.

---

## 5. The Design System: *Inferno* Aesthetic

Hellmacs features a thematic design language inspired by dark metal, brimstone, and industrial computing:

### Palette Specification (`hellmacs-inferno-theme.el`)
* **Background (Charcoal)**: `#16171d` / `#1b1c24`
* **Foreground (Bone White)**: `#bbc2cf`
* **Accent Primary (Inferno Crimson)**: `#ff6c6b`
* **Accent Secondary (Ember Amber)**: `#da8548`
* **Accent Tertiary (Reap Gold)**: `#ecbe7b`
* **Success / Ready (Venom Green)**: `#98be65`
* **Selection / Highlight**: `#22242f`

### Themed UX Terminology
* **The Altar (`*hellmacs*`)**: Startup dashboard with ASCII logo and startup benchmarks.
* **The Forge**: Project indexing and file discovery (`C-c h f`).
* **The Crucible**: Hot-code bytecode replacement and REPL injection (`C-c h r`).
* **The Reaper**: Instant GC memory collection (`C-c h c`).
* **Daemon State Indicators**:
  * `[FORGE IGNITED]`: Language server process spawned.
  * `[DAEMON READY]`: Indexing finished; workspace operational.
  * `[BYTECODE PURGATORY]`: Build or project import failure.
  * `[DAEMON BANISHED]`: Language server process exited.
  * `[TEST DAMNATION]`: Unit test assertions failed.

### Corporate Neutrality Toggle
For strict enterprise environments requiring standard terminology and appearance:
```elisp
;; In ~/.config/hellmacs/init.el:
(setq hellmacs-ux-enable nil)        ; Standard echo area messages & quit dialog
(setq hellmacs-splash-enable nil)    ; Start on blank *scratch* buffer
(setq hellmacs-theme 'modus-vivendi) ; Standard GNU Modus theme
```
