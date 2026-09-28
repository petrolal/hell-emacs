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

### Integration & Parity Checklists
* `test/integration/java-e2e.el`: End-to-end integration test validating JDTLS, compilation, debugger stepping, and hot-code replacement against sample projects.
* `test/integration/java-parity.el`: Parity runner verifying that IntelliJ/Eclipse daily capabilities function on Maven/Gradle test projects.
* `test/integration/net-e2e.el`: Validates corporate proxy, custom CA bundle, and offline bundle installations.

---

## 3. Module System Specification & API Contracts

A module is declared at `modules/<group>/<name>/` (or `~/.config/hellmacs/modules/<group>/<name>/`).

### File Contract Schema
```
modules/<group>/<name>/
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

1. **User Module Override**: A module at `~/.config/hellmacs/modules/<group>/<name>/` takes precedence over `modules/<group>/<name>/`.
2. **Evaluation Order (Sync)**: `core/packages.el` $\rightarrow$ Module `packages.el` (in `hellmacs!` order) $\rightarrow$ User `packages.el`.
3. **Execution Order (Boot)**: `core/` $\rightarrow$ Module `init.el` $\rightarrow$ Module `config.el` $\rightarrow$ User `config.el`.

---

## 6. Creating a New Module Step-by-Step

1. Copy the template from `static/module-template/` into `modules/<category>/<name>/`:
   ```sh
   cp -r static/module-template modules/lang/scala
   ```
2. Populate `packages.el`, `config.el`, `autoload.el`, and `doctor.el`.
3. Register the module in `static/init.example.el` and add unit tests in `test/`.
4. Run `bin/hellmacs sync` and verify with `bin/hellmacs test` and `bin/hellmacs doctor`.
