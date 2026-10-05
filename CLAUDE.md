# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Hell Emacs is a GNU Emacs distribution for JVM development (Java, Kotlin, Clojure, Groovy) that mirrors **Doom Emacs v3's architecture** (`lisp/hell-*.el` ↔ `lisp/doom-*.el`, `bin/hell` ↔ `bin/doom`, `.hellmodule` ↔ `.doommodule`) while keeping **stock GNU Emacs keys** (no Evil/modal). `docs/development.md` is the authoritative developer guide; read it before non-trivial changes.

## Commands

Engine checks (`Makefile`) run Emacs in batch exactly as `bin/hell` does, with `HELLDIR` and all XDG dirs redirected into `.make-tmp/`, so the user's real config is never touched:

```sh
make compile    # byte-compile lisp/ + tests; any warning is an error (CI gate)
make test       # run the ERT suite in test/*-test.el (CI gate)
make checkdoc   # docstring style, advisory only
make lock       # regenerate static/packages.lock.eld (slow, needs network)
make clean      # remove .make-tmp/
```

Run a single ERT test (same env as `make test`; pass the test name or a regexp as the selector):

```sh
HELLDIR=$PWD/.make-tmp/config XDG_CONFIG_HOME=$PWD/.make-tmp/xdg/config \
XDG_DATA_HOME=$PWD/.make-tmp/xdg/data XDG_CACHE_HOME=$PWD/.make-tmp/xdg/cache \
XDG_STATE_HOME=$PWD/.make-tmp/xdg/state \
emacs -Q --batch -l early-init.el --eval "(require 'hell-cli)" -L test -l test/hell-test.el \
  --eval '(ert-run-tests-batch-and-exit "TEST-NAME-REGEXP")'
```

CI (`.github/workflows/ci.yml`) runs `make compile`, `make test`, `make checkdoc` on Emacs 29.1, 30.1 and snapshot. Code must work on Emacs 29.1.

Full-distribution checks (need a synced config; first sync downloads language servers and takes minutes): `bin/hell sync`, `bin/hell doctor`, `bin/hell check` (lint), `bin/hell verify`, `bin/hell licenses`, `bin/hell sbom`. `bin/hell emacs --sandbox` runs a throwaway install in `/tmp`. For local dev, prefer root-level `init.el`/`config.el`/`packages.el` copied from `static/*.example.el` (gitignored, auto-detected by `early-init.el`) or `bin/hell profile create dev --in-tree`; never symlink the config dir.

## Architecture

**Startup is decided at sync time.** `bin/hell sync` reads every enabled module's `packages.el`, installs packages (Elpaca, loaded only by sync), and writes parts into `<profile>/init.d/` via `hell-profile-generate-functions` (`lisp/hell-profiles.el`), which are joined into `init.MAJOR.MINOR.el` and byte-compiled. At runtime, `early-init.el` → `lisp/hell-core.el` → `hell-initialize` → `hell-start` (loads that generated file) → `hell-startup` runs `hell-startup-functions` by depth. Startup reads no `packages.el` and installs nothing; without a generated init file it warns and falls back to plain Emacs. Consequence: after changing core or a module, **re-sync before testing real behavior or measuring startup**.

**Core (`lisp/`):** `hell-core.el` (lifecycle, GC, dirs), `hell-emacs.el` (stock defaults; replaces Emacs' init-file loader), `hell-lib.el` (macros `after!`, `add-hook!`, `defadvice!`, `hell-require`; holds `hell-version`), `hell-modules.el` (`hell!`, `modulep!`, `package!`), `hell-cli.el` (CLI dispatcher). `lisp/lib/*.el` and `lisp/cli/*.el` are off `load-path` and loaded on demand with `(hell-require 'hell-lib 'NAME)`; lib files end with `(hell-provide 'hell-lib 'NAME)`. `lisp/hell-elpaca.el` is never byte-compiled.

**CLI:** `bin/hell` dispatches to one file per command, `bin/hell-NAME` (`#!/usr/bin/env hellscript`, defines `hell-cli-NAME`). Modules can add sync steps (`hell-sync-functions`) and commands via their `cli.el`.

**Modules:** `<group>/<name>/`, written `:group name`. Search order (`hell-module-load-path`): user `modules/` → `modules/` (core's always-on `:hell` module) → `sources/hell+/modules/` (the catalog). Per-module files (all optional): `.hellmodule` (version + metadata alist), `packages.el` (sync only), `autoload.el`/`autoload/`, `init.el`, `config.el`, `cli.el` (CLI only), `doctor.el` (`hell-doctor-*` checks), `+paths.el` (language-server pins via `hell-component!`), `+NAME.el` (loaded with `(hell-module-load "+NAME")`). New modules start from `static/module-template` and must be added to `static/init.example.el`, the single list of default modules. `:lang` modules integrate via buffer-local hooks (`hell-reload-function`, `hell-forge-test-*-function`, `hell-lsp-status-register`) so core and `:tools` never name a language.

## Rules that aren't obvious

- **Byte-compilable everywhere:** in module files never use `load-file-name` (it points into the profile once compiled) — use `(hell-module-get hell--current-module :path)` and `hell-module-load`; locate modules with `hell-module-locate-path`/`hell-module-from-path`, never hard-coded paths. Wrap `load-path` changes needed by top-level `require` in `eval-and-compile`; in core, `defvar` every special variable a file binds.
- **Reproducibility:** packages only via `package!` (never `package-install`); downloads only via `hell-sync-download-verified` (SHA-256 pinned) inside `with-hell-network`. Language servers get a pinned installer registered with `hell-lsp-pin-installer` so lsp-mode never self-downloads.
- **Keys:** never rebind stock keys, never single-key/modal bindings. Hell commands live under `C-c h`; per-language commands on the localleader `C-c l` (`hell-localleader-def`); shared code actions on `C-c c`. Leader keys via `hell-leader-def`.
- **Directories:** never write to `~/.emacs.d` or `$HOME`; use `hell-data-dir`, `hell-cache-dir`, `hell-state-dir` (`user-emacs-directory` points at the cache).
- **Style:** one space after sentence-ending periods in docstrings/comments (`sentence-end-double-space nil`), no tabs. Every source file carries the GPL-3.0-or-later header with the `petrolal` copyright (copy from an existing file).
- **Commits:** Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`), per `.hell-emacs`.
- **Branding:** the `hell-inferno` palette and themed vocabulary (the Altar, the Forge, the Crucible, `[FORGE IGNITED]`, …) are fixed identity; neutral mode (`hell-ux-enable nil`, `hell-splash-enable nil`) is opt-in only.
