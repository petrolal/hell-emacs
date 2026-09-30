# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hellmacs is an Emacs distribution (Emacs 29.1+, pure Emacs Lisp with `lexical-binding: t`) aimed at JVM development (Java, Kotlin, Clojure, Groovy). Its module system and directory layout follow Doom Emacs v3 (`hellmacs!`, `modulep!`, `package!`; `lisp/`, module sources, `bin/hellmacs-COMMAND`, generated profile init), but it keeps stock GNU Emacs keybindings. Elpaca is the package manager.

## Commands

All commands go through `bin/hellmacs`, a thin sh wrapper that runs `emacs --batch` with `early-init.el` and dispatches to `hellmacs-cli-main` in `lisp/hellmacs-cli.el`. Each command is its own Elisp file, `bin/hellmacs-COMMAND` (Doom v3's `bin/doom-COMMAND`), loaded when it runs (`hellmacs-cli-load`); with `bin/` on `PATH` it also runs directly through `bin/hellmacsscript`. A new command goes in a new `bin/hellmacs-NAME` defining `hellmacs-cli-NAME` (or in a module's `cli.el`). Set `$EMACS` to use a different Emacs binary.

```sh
bin/hellmacs test                 # run all ERT unit tests (test/test-*.el)
bin/hellmacs test 'test-java/'    # run only the tests whose names match this regexp
bin/hellmacs test 'test-build/commands'   # a single test
bin/hellmacs doctor               # health checks (core + every enabled module's doctor.el)
bin/hellmacs sync                 # install packages, build tree-sitter grammars, rewrite profile
bin/hellmacs --profile dev sync   # --profile NAME must come first
bin/hellmacs --profile safe-mode sync   # profiles/safe-mode: core only, for bisecting a broken config
emacs --init-directory .          # run this checkout interactively
```

- The argument to `test` is an ERT selector **regexp matched against test names**, not file names. Tests are named `test-<file>/<case>`.
- `bin/hellmacs test` points every `XDG_*_HOME` and `HELLMACSDIR` at a throwaway temp dir, so unit tests never touch the real config and don't need a synced profile.
- The integration scripts in `test/integration/` (`*-e2e.el`, `*-parity.el`, `startup-bench.el`) are **not** run by `bin/hellmacs test`. They need a synced profile with the relevant modules enabled, real language servers/JDKs, and sometimes network access. Each file's header gives its exact invocation, e.g.:
  ```sh
  HELLMACS_E2E_FIXTURE=maven-demo emacs --batch -l early-init.el -f hellmacs-start -l test/integration/java-e2e.el
  ```
  Fixture projects live in `test/fixtures/`.
- In those scripts, give checks that depend on another (a running server, a first good build) `:needs NAME` in `e2e-check`, so they're reported `SKIP (needs …)` at once instead of each waiting out its time; end with `(e2e-finish)`. `HELLMACS_E2E_DEADLINE` (seconds; 30 minutes by default) caps a whole run. They take minutes: run them in the background, never as a blocking step.

The project rules (`docs/development/vision-and-rules.md`) require running `bin/hellmacs test` and `bin/hellmacs doctor` after any change to the core engine or to modules.

## Architecture

Hellmacs follows Doom Emacs v3's layout (`doomemacs/core`, Phase 16 in `docs/roadmap.md`). Know where things go before adding a file.

### Layout
- `early-init.el`: the only `.el` at the root. There is **no root `init.el`** (`.gitignore` keeps it so).
- `lisp/`: the engine (Doom's `lisp/`). `hellmacs.el` is the heart (lifecycle, GC, dirs), `hellmacs-emacs.el` the stock-Emacs defaults, `hellmacs-lib.el` the macros (`after!`, `add-hook!`, `hellmacs-require`, `hellmacs-dotfile`), `hellmacs-modules.el` the module system, `hellmacs-packages.el`/`-elpaca.el`/`-sync.el` packages, `hellmacs-keybinds.el` the `C-c` leader, `hellmacs-treesit.el` grammars, `hellmacs-profiles.el` the generated init file, `hellmacs-start.el` the startup sequence, `hellmacs-cli.el` the CLI dispatcher, `packages.el` (empty, as Doom's).
  - `lisp/lib/` (library: `jdk`, `net`, `lsp-status`) and `lisp/cli/` (the CLI's parts: `bundle`, `compliance`, `config`, `verify`) are **not** on `load-path`, as in Doom. Load them with `(hellmacs-require 'hellmacs-lib 'net)` / `(hellmacs-require 'hellmacs-cli 'verify)` (Doom's `doom-require`; wrap in `eval-and-compile` when a file needs their macros, e.g. `with-hellmacs-network`), and end each such file with `(hellmacs-provide 'hellmacs-lib 'NAME)`. `(require 'hellmacs-jdk)` and the like don't work.
- `modules/hellmacs/`: core's own module, `(:hellmacs . nil)` (Doom's `:doom`), always on, first (depth -100, from its `.hellmacsmodule`): core's packages (compat, gcmh), gcmh's setup, the Altar (`+splash.el`), themed UX (`+ux.el`). Anything user-facing or package-backed that every config gets goes here, not in `lisp/`.
- `sources/hellmacs+/modules/<group>/<name>/`: the module catalog, a module source (Doom's `sources/doom+`, in-tree here). Every other module lives here.
- `bin/`: `hellmacs` (sh dispatcher), one Elisp file per command `bin/hellmacs-COMMAND` (Doom's `bin/doom-COMMAND`), and `hellmacsscript` (Doom's `doomscript`).
- `profiles/`: profiles Hellmacs ships (`safe-mode`). A directory is a profile (implicit profiles).
- `.hellmacs` (the project) and each module's `.hellmacsmodule` (`name`, optional `depth`): Doom's dotfile format, a version string then an alist, read with `hellmacs-dotfile`.
- `static/` (starter templates, `module-template/`), `themes/`, `test/`, `docs/`.

### Boot sequence
- `early-init.el`: GC tuning, XDG directory remapping (defines `hellmacs-dir`, `hellmacs-core-dir` = `lisp/`, `hellmacs-modules-dir`, `hellmacs-sources-dir`, and the data/cache/state dirs; a profile's config dir via `hellmacs--user-dir`), and suppression of UI chrome. `bin/hellmacs` also loads it. Last, it hands Emacs the init file (`hellmacs-init-file`, through an advice on `startup--load-user-init-file`, as Doom v3 does): the profile's generated `<profile>/init.el(c)` while it's current, else `lisp/hellmacs-start.el` from source. Batch sessions start with `emacs --batch -l early-init.el -f hellmacs-start`.
- `sync` generates `<profile>/init.el` (`lisp/hellmacs-profiles.el`, numbered parts: 05 puts the compiled core on `load-path`, 10 is `lisp/hellmacs-start.el`'s forms) and byte-compiles it, so the startup sequence is written once, in `lisp/hellmacs-start.el`.
- `lisp/hellmacs-start.el` only orchestrates, with no configuration of its own. Its header documents the fixed load order: `hellmacs-lib` → `hellmacs` → `hellmacs-emacs` → `hellmacs-packages` → `hellmacs-keybinds` → `hellmacs-modules` → treesit → user `init.el` (the `hellmacs!` block) → package activation → each module's `autoload.el` + `init.el` (core's `:hellmacs` first) → each module's `config.el` → user `config.el` → `custom-file`.
- Package activation reads a static **profile** written by `bin/hellmacs sync`. If the profile is missing or stale, startup reads every `packages.el` and falls back to a live Elpaca install (`lisp/hellmacs-sync.el`, `lisp/hellmacs-elpaca.el`).
- `sync` also byte-compiles core (all of `lisp/`, subdirectories included) and each enabled module's `init.el`/`config.el` into `<profile>/compiled/` (`hellmacs-compiled-dir`), and merges all autoloads into one compiled `autoloads.el`. Startup uses compiled core only if no `lisp/**/*.el` is newer than its stamp (all or nothing), and a compiled module file only if it's newer than its source. So code must stay compilable: in module files load siblings with `(hellmacs-module-load "+paths")`, never via `load-file-name` (it points into the profile when compiled); wrap `load-path` changes that a top-level `require` needs in `eval-and-compile`; and in core, `defvar` any special variable a file binds. A file that expands a third-party macro that may not be loaded yet (like `lisp/hellmacs-elpaca.el`'s `elpaca`) must be `no-byte-compile`: compiled, the macro's expansion calls that package's internals before it's loaded. After changing core or a module, run `bin/hellmacs sync` before measuring startup or running the integration scripts, or you're testing the source fallback.

### Modules (`lisp/hellmacs-modules.el`)
A module is `<group>/<name>/` in a module tree, written `:group name`. Trees are searched in order (`hellmacs-module-load-path`, Doom v3's `doom-module-load-path`): your `$HELLMACS_USER_DIR/modules/`, then Hellmacs' `modules/` (core's own), then `sources/hellmacs+/modules/` (the catalog). Find a module with `hellmacs-module-locate-path`, a file's module with `hellmacs-module-from-path`; never hard-code a module's path. Every file in a module is optional:
- `.hellmacsmodule`: `"0.9.0"` then `((name :group name))`, plus `(depth . N)` to load before (negative) or after other modules. Every module Hellmacs ships has one (`test-modules/every-module-has-metadata`).
- `packages.el`: declarations only, read at sync time (and by `doctor`); the synced profile keeps what startup needs from them. That means `(package! ...)`, `(depends-on! :tools lsp)` for modules this one needs, and `(hellmacs-treesit! :grammars ... :remap ...)` under `+tree-sitter` for pinned grammars and mode remaps. Don't hand-write "needs module X" warnings or tree-sitter remap/doctor code in other files.
- `autoload.el`: commands and helpers that other files may call.
- `init.el`: runs before any module's `config.el`.
- `config.el`: the actual configuration, usually `use-package` forms.
- `cli.el`: extends `bin/hellmacs`, for example by adding to `hellmacs-sync-functions` or adding commands.
- `doctor.el`: checks run by `bin/hellmacs doctor`.
- `+paths.el` (lang modules): language-server and workspace locations. Both `config.el` and `cli.el` load it, so batch and interactive sessions agree on paths.

User modules in `$HELLMACS_USER_DIR/modules/` fully override Hellmacs' modules with the same name. The user directory is resolved in this order: `$HELLMACSDIR` → `~/.config/hellmacs/` → `~/.hellmacs.d/`; for `--profile NAME`: `~/.config/hellmacs-NAME/` → `~/.config/hellmacs/profiles/NAME/` → Hellmacs' `profiles/NAME/`. Use `(modulep! +flag)` and `(modulep! :group name +flag)` to gate code on module flags. When the user `init.el` has no `hellmacs!` block, the default module set comes from `static/init.example.el` (an empty `(hellmacs!)` means no modules, as in `safe-mode`). That makes it the single source of defaults: register new modules there.

Some larger UI implementations live next to their module directories rather than inside them, and the module's `config.el` requires them. Examples are `sources/hellmacs+/modules/ui/hellmacs-modeline.el` and `sources/hellmacs+/modules/ui/hellmacs-dashboard.el`. New modules start from `static/module-template/` (copied into `sources/hellmacs+/modules/<group>/<name>/`, with its `.hellmacsmodule` renamed).

## Project rules

- **Stock Emacs keybindings only.** Never add Evil/modal bindings or single-key hijacks. Hellmacs bindings go under `C-c`, mainly the `C-c h` leader via `hellmacs-leader-def`. Leave built-in help (`C-h …`) untouched.
- **XDG isolation.** Never hardcode `~/.emacs.d` or write state to `$HOME`. Use `hellmacs-data-dir`, `hellmacs-cache-dir`, `hellmacs-state-file`, and related helpers.
- **Packages** are declared only with `package!` in a `packages.el`. Never call `package-install` or `straight-use-package`.
- **Network:** anything Hellmacs downloads goes through `hellmacs-sync-download-verified` (pinned by SHA-256), and any fetching code runs inside `with-hellmacs-network` (`lisp/lib/net.el`), so the user's proxy, CA and mirrors apply. A module's language server gets a pinned installer in its `cli.el`, registered with `hellmacs-lsp-pin-installer` so lsp-mode never falls back to its own. Declare every pinned download with `hellmacs-component!` in the module's `+paths.el`, next to its pin (name, version, SPDX license, URL, SHA-256, install path), and give every grammar a `:license`: `bin/hellmacs sbom` and `licenses` read them, and `test-compliance` fails on a pin that isn't declared.
- **Built-ins first.** Prefer `project.el`, `treesit`, `compile`, and similar built-ins. Add a third-party package only when it's needed.
- **Startup budget is under 0.12s.** Keep work lazy (autoloads, `after!`, hooks). `test/integration/startup-bench.el` measures startup time.
- **Strict TDD (Test-Driven Development).** Always write tests first for any new phase, feature, or fix before implementing the production code. Tests must call the target functions/features directly (RED). Then write minimal code to make tests pass (GREEN), refactor, and verify (`bin/hellmacs test` and `bin/hellmacs doctor`).
- Every source file carries the GPL-3.0-or-later header with the `petrolal` copyright. Preserve it and add it to new files.

## Docs

`docs/development/` contains the engineering specifications: `vision-and-rules.md`, `architecture.md`, and `contributing.md`. `docs/roadmap.md` tracks phases; code comments often refer to them ("Phase 6.2", "Phase 9 spec"). Finished roadmap items before Phase 16 keep the paths they were written with (`core/`, `modules/<group>/`, root `init.el`): map them to `lisp/`, `sources/hellmacs+/modules/<group>/` and `lisp/hellmacs-start.el`. Some docs describe planned features, so check the code before relying on them. `profiles/README.md` explains profiles.

`docs/development/work-order.md` is the ordered checklist of remaining roadmap work. Take the next unchecked item from it. When an item is done and verified, tick it there and in `docs/roadmap.md`, with the date and a short note.

