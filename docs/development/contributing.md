# Contributing & Module Development Guide

This guide outlines how to develop, test, and contribute to **Hellmacs**, including the module system specification and core macros API.

---

## 1. Local Development Setup

To work on Hellmacs itself:
1. Clone the repository into a development directory:
   ```sh
   git clone https://github.com/petrolal/hellmacs.git ~/src/hellmacs
   ```
2. Launch a test instance of Emacs:
   ```sh
   emacs --init-directory ~/src/hellmacs
   ```
3. Or test isolated named profiles:
   ```sh
   ~/src/hellmacs/bin/hellmacs --profile dev sync
   emacs --init-directory ~/src/hellmacs --profile dev
   ```
4. When a change breaks startup, `safe-mode` (in `profiles/`) starts Hellmacs' core with no other module and none of your config:
   ```sh
   ~/src/hellmacs/bin/hellmacs --profile safe-mode sync
   ~/src/hellmacs/bin/hellmacs --profile safe-mode emacs
   ```

There is no `init.el` in the checkout: `bin/hellmacs sync` generates each profile's (`lisp/hellmacs-profiles.el`), and until it has, Emacs starts plain and says so, as Doom does. Run `sync` after changing `lisp/`, a module's list of files, its `packages.el` or its autoloads: the init file records them.

### Where code goes (Doom Emacs v3's layout)

| You're adding | Put it in |
|---|---|
| Engine code every session needs | `lisp/hellmacs-*.el` (required by `hellmacs-initialize`, or by another core file) |
| A step of the startup itself | A part of the generated init file: a function in `hellmacs-profile-generate-functions` (`lisp/hellmacs-profiles.el`) |
| A library other code calls on demand | `lisp/lib/NAME.el`, ending with `(hellmacs-provide 'hellmacs-lib 'NAME)`; load it with `(hellmacs-require 'hellmacs-lib 'NAME)` |
| Code only `bin/hellmacs` needs | `lisp/cli/NAME.el` (`hellmacs-cli` parts), or the command's own file |
| A `bin/hellmacs` command | `bin/hellmacs-NAME` (executable, `#!/usr/bin/env hellmacsscript`), defining `hellmacs-cli-NAME` |
| Something every config gets that is user-facing or needs a package (keybinding API included) | Core's own module, `modules/hellmacs/` (`autoload/` for functions other modules call) |
| An optional feature or a language | A module: `sources/hellmacs+/modules/<group>/<name>/` |
| A profile Hellmacs ships | `profiles/NAME/` |

`lisp/lib/` and `lisp/cli/` are deliberately off `load-path`: `(require 'hellmacs-jdk)` doesn't work, `(hellmacs-require 'hellmacs-lib 'jdk)` does. Wrap it in `eval-and-compile` when the file uses the part's macros (`with-hellmacs-network`), so the byte-compiler sees them.

---

## 2. Running Test Suites

Hellmacs includes an extensive ERT (Emacs Lisp Regression Testing) suite with zero external mock dependencies.

```sh
# Run the entire test suite
bin/hellmacs test

# Run a specific test selector
bin/hellmacs test test-java
bin/hellmacs test test-debugger
bin/hellmacs test test-bundle
```

Tests for the layout itself: `test-lib/layout-like-doom`, `test-modules/catalog-is-a-source`, `test-modules/every-module-has-metadata`, `test-cli/commands-in-bin-like-doom` and `test-profiles`.

### Integration & Parity Checklists

Integration scripts start Hellmacs as a batch session, then load the script:

```sh
HELLMACS_E2E_FIXTURE=maven-demo emacs --batch -l early-init.el -f hellmacs-start -l test/integration/java-e2e.el
```

* `test/integration/java-e2e.el`: End-to-end integration test validating JDTLS, compilation, debugger stepping, and hot-code replacement against sample projects.
* `test/integration/java-parity.el`: Parity runner verifying that IntelliJ/Eclipse daily capabilities function on Maven/Gradle test projects.
* `test/integration/net-e2e.el`: Validates corporate proxy, custom CA bundle, and offline bundle installations.

---

## 3. Module System Specification & API Contracts

A module is `<group>/<name>/` in a module tree: Hellmacs' catalog is `sources/hellmacs+/modules/`, core's own module is `modules/hellmacs/`, and yours go in `~/.config/hellmacs/modules/`. Each has a `.hellmacsmodule` (Doom's `.doommodule`): a version string, then `((name :group name))`, plus `(depth . N)` when it must load before or after others.

### File Contract Schema
```
sources/hellmacs+/modules/<group>/<name>/
├── .hellmacsmodule # Its name (and depth), as Doom's .doommodule
├── packages.el   # [EVALUATED AT SYNC TIME] Declarations: (package! ...), (depends-on! ...), (hellmacs-treesit! ...)
├── init.el       # [BOOT PHASE 1] Evaluated before any config.el is loaded
├── config.el     # [BOOT PHASE 2] Evaluated during interactive boot (use-package forms)
├── autoload.el   # [ON-DEMAND] Evaluated into global autoload table at sync time
├── cli.el        # [CLI EXTENSION] Extends `bin/hellmacs` subcommands
└── doctor.el     # [HEALTH CHECK] Hooks into `bin/hellmacs doctor`
```

---

## 4. Core Macros API Reference

### `(hellmacs! ...)`
Declares the enabled module set and their active flags in user's `init.el`.
```elisp
(hellmacs! :ui theme (dashboard +ascii)
           :completion (corfu +tab) vertico
           :tools lsp (debugger +dap)
           :lang (java +lombok +tree-sitter))
```

### `(modulep! ...)`
Queries module activation state and flag predicates.
* `(modulep! +FLAG)`: Tests if `+FLAG` is active in current module context.
* `(modulep! :GROUP NAME)`: Tests if module `:GROUP NAME` is active globally.
* `(modulep! :GROUP NAME +FLAG)`: Tests if flag `+FLAG` is enabled on `:GROUP NAME`.

### `(package! NAME &rest PLIST)`
Declares a package requirement inside a `packages.el` file.
* `:pin STRING`: Fixed commit hash to enforce reproducibility.
* `:recipe PLIST`: Elpaca recipe overrides.
* `:disable BOOLEAN`: Suppresses package installation and activation.
* `:built-in SYMBOL`: Indicates package availability in GNU Emacs core (`'prefer`).

### `(depends-on! :GROUP NAME &rest FLAGS)`
Declares, inside a `packages.el`, that the current module requires another module.
* Evaluated during `bin/hellmacs sync` and `bin/hellmacs doctor`. Shared dependencies (like `:tools lsp`) are declared once.

### `(hellmacs-treesit! :grammars GRAMMARS :remap REMAP)`
Declares Tree-sitter grammars and mode remappings under `+tree-sitter`.
* `GRAMMARS`: `((LANGUAGE URL LABEL COMMIT [DIRECTORY]) ...)`
* `REMAP`: `((MODE . TS-MODE) ...)`, added to `major-mode-remap-alist` once grammars are built.

### Buffer-Local Hooks for `:lang` Modules
Core and `:tools` modules never hardcode language names; `:lang` modules configure:
* `hellmacs-reload-function`: Called on `C-c h r` (Crucible) — hot-swap for Java, REPL reload for Clojure.
* `hellmacs-forge-test-class-function` / `hellmacs-forge-test-method-function`: Resolves test context at point for `hellmacs-forge-test-at-point`.
* `(hellmacs-lsp-status-register SERVER :label ...)`: Language server status indicators.

---

## 5. Precedence & Override Rules

1. **User Module Override**: a module at `~/.config/hellmacs/modules/<group>/<name>/` takes precedence over Hellmacs' own (`modules/`, then `sources/hellmacs+/modules/`).
2. **Evaluation Order (Sync)**: `lisp/packages.el` $\rightarrow$ Module `packages.el` (core's `:hellmacs` first, then in `hellmacs!` order) $\rightarrow$ User `packages.el`.
3. **Execution Order (Boot)**: `lisp/` $\rightarrow$ Module `init.el` $\rightarrow$ Module `config.el` $\rightarrow$ User `config.el`.

---

## 6. Creating a New Module Step-by-Step

1. Copy the template from `static/module-template/` into `sources/hellmacs+/modules/<category>/<name>/`, and set the name in its `.hellmacsmodule`:
   ```sh
   cp -r static/module-template sources/hellmacs+/modules/lang/scala
   ```
2. Populate `packages.el`, `config.el`, `autoload.el`, and `doctor.el`. Find other modules with `hellmacs-module-locate-path`, and load your module's own files with `(hellmacs-module-load "+paths")`, never by path.
3. Register the module in `static/init.example.el` and add unit tests in `test/`.
4. Run `bin/hellmacs sync` and verify with `bin/hellmacs test` and `bin/hellmacs doctor`.
