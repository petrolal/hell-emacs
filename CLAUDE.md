# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hellmacs is an Emacs distribution (Emacs 29.1+, pure Elisp, `lexical-binding: t`) for JVM development (Java first; Kotlin, Clojure, Groovy follow). Its layout, module system, CLI and startup mirror **Doom Emacs v3** (`doomemacs/core`): `hellmacs!`/`modulep!`/`package!`, `lisp/`, `bin/hellmacs-COMMAND`, a generated per-profile init file. It keeps **stock GNU Emacs keybindings** and uses Elpaca instead of straight.el. When unsure where something goes or how it should work, do what Doom does, unless a rule below says otherwise.

Read before changing anything:
- `docs/roadmap.md` → "Rules" (the non-negotiables) and "Open work, in order" (what to do next).
- `docs/development.md`: architecture table (Doom file ↔ Hellmacs file), startup sequence, module file roles and API, "Where code goes", how to check a change, releasing.
- `docs/guide.md` (users), `docs/jvm.md` (JVM features), `docs/cli.md`, `docs/keybindings.md`, `profiles/README.md`.

## Commands

Everything goes through `bin/hellmacs` (sh wrapper → `emacs --batch` → `hellmacs-cli-main` in `lisp/hellmacs-cli.el`). Each command is its own file `bin/hellmacs-COMMAND` defining `hellmacs-cli-COMMAND`. Global options come before the command. `$EMACS` picks the Emacs binary.

```sh
bin/hellmacs sync                 # install packages, build grammars, byte-compile, generate the profile init file
bin/hellmacs doctor               # health checks (core + each enabled module's doctor.el)
bin/hellmacs -p dev sync          # -p/--profile, --hellmacsdir, -D, -! go before the command
bin/hellmacs -p safe-mode sync    # core only, for bisecting a broken config
bin/hellmacs emacs                # run this checkout interactively
bin/hellmacs licenses | sbom      # read every hellmacs-component! / grammar :license pin
```

**There are no tests, and none should be added** (removed 2026-09-30). A change is checked by syncing and starting Emacs against throwaway XDG directories, never the real config:

```sh
T=$(mktemp -d)
export XDG_CONFIG_HOME=$T/config XDG_DATA_HOME=$T/data \
       XDG_CACHE_HOME=$T/cache XDG_STATE_HOME=$T/state HELLMACSDIR=$T/config/hellmacs
bin/hellmacs install --no-env     # creates the config, syncs, runs doctor
bin/hellmacs emacs                # *Messages* shows "Hellmacs ready in N.NNs"
```

A full sync downloads language servers and takes minutes: run it in the background. CI (`.github/workflows/ci.yml`) runs install, `doctor`, `licenses`, `sbom` on Emacs 29.1 and 30.1.

## Architecture: the parts that bite

- **Everything startup needs is decided at sync time.** `early-init.el` loads `lisp/hellmacs.el` → `hellmacs-initialize` → `hellmacs-start` loads `<profile>/init.MAJOR.MINOR.elc`, built by `lisp/hellmacs-profiles.el` from numbered parts in `<profile>/init.d/` (05 load-path, 10 core autoloads, 20 user `init.el` + network, 30 `:env`, 60 lib/module autoloads, 70 package autoloads, 80 module `init.el`s then `config.el`s then user `config.el`). Startup never reads `packages.el` or installs anything. After changing a `hellmacs!` block, a `packages.el`, an autoload file, core, or a module: **sync again**, or you are running stale compiled files.
- **There is no root `init.el`** (gitignored on purpose); `early-init.el` is the only root `.el`.
- **`lisp/lib/` and `lisp/cli/` are off `load-path`.** Load with `(hellmacs-require 'hellmacs-lib 'net)` / `(hellmacs-require 'hellmacs-cli 'sync)` (inside `eval-and-compile` when you need their macros, e.g. `with-hellmacs-network`); end such files with `(hellmacs-provide 'hellmacs-lib 'NAME)`. Plain `(require 'hellmacs-jdk)` doesn't work.
- **Module trees**, searched in order: user `modules/`, `modules/hellmacs/` (core's own module `:hellmacs`, always on, depth -100: gcmh, the Altar splash, themed UX, the `C-c` leader API `hellmacs-leader-def` in `autoload/keybinds.el`), then `sources/hellmacs+/modules/<group>/<name>/` (the catalog). Never hard-code a module path: use `hellmacs-module-locate-path` / `hellmacs-module-from-path`.
- **Default modules** come from `static/init.example.el`, the single source: register new modules there. New modules start from `static/module-template/`.
- **Code must stay byte-compilable** (sync compiles core and module files into `<profile>/compiled/`): load module siblings with `(hellmacs-module-load "+paths")` and get the module dir with `(hellmacs-module-get hellmacs--current-module :path)`, never `load-file-name`; wrap `load-path` changes needed by a top-level `require` in `eval-and-compile`; `defvar` special variables bound in core; files expanding a not-yet-loaded third-party macro (e.g. `lisp/hellmacs-elpaca.el`) are `no-byte-compile`.
- **Languages plug in via buffer-local variables** so core and `:tools` never name a language: `hellmacs-reload-function`, `hellmacs-forge-test-class-function` / `-test-method-function`, `hellmacs-lsp-status-register`.

## Rules (from `docs/roadmap.md`)

- **Stock Emacs keys.** No Evil, no `SPC` leader, no modal or single-key hijacks, no IntelliJ keymap. Hellmacs keys live under `C-c` (`C-c h` is Hellmacs' own); packages improve default commands instead of adding keys; `TAB` indents; `C-h` untouched.
- **The identity is fixed:** `hellmacs-inferno` theme and palette, banner/logos, the Altar, themed messages (`[FORGE IGNITED]` …). `hellmacs-ux-enable nil` is the neutral opt-out.
- **Built-ins first** (`project.el`, flymake, treesit, `compile`, …); third-party only where the JVM workflow needs it.
- **Pinned and reproducible.** Packages only via `package!` in a `packages.el` (never `package-install`). Every download goes through `hellmacs-sync-download-verified` (SHA-256) inside `with-hellmacs-network`, is declared with `hellmacs-component!` in the module's `+paths.el`, and grammars carry a `:license`. Language servers get a pinned installer in the module's `cli.el` registered with `hellmacs-lsp-pin-installer`. Nothing installs mid-session.
- **XDG only**: never `~/.emacs.d` or `$HOME`; use `hellmacs-data-dir`, `hellmacs-cache-dir`, `hellmacs-state-file`, etc. No telemetry.
- **Startup under 0.12s** for a synced profile; keep work lazy (autoloads, `after!`, `hellmacs-first-*-hook`).
- Every source file carries the GPL-3.0-or-later header with the `petrolal` copyright.
- Commits use Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).

## Work tracking

Take the next unchecked item in `docs/roadmap.md` → "Open work, in order". When done and verified (throwaway sync, `doctor` passes, startup within budget if touched), tick it as `- [x] Thing (YYYY-MM-DD: what was done, how it was checked)`; partial work is `- [/]`. Add new work to the roadmap before starting it. Code comments cite roadmap item numbers ("12.7", "Phase 16").
