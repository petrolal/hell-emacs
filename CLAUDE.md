# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hell Emacs is an Emacs distribution (Emacs 29.1+, pure Elisp, `lexical-binding: t`) for JVM development (Java first; Kotlin, Clojure, Groovy follow). Its layout, module system, CLI and startup mirror **Doom Emacs v3** (`doomemacs/core`): `hell!`/`modulep!`/`package!`, `lisp/`, `bin/hell-COMMAND`, a generated per-profile init file. It keeps **stock GNU Emacs keybindings** and uses Elpaca instead of straight.el. When unsure where something goes or how it should work, do what Doom does, unless a rule below says otherwise.

Read before changing anything:
- `docs/roadmap.md` → "Rules" (the non-negotiables) and "Open work, in order" (what to do next).
- `docs/development.md`: architecture table (Doom file ↔ Hell Emacs file), startup sequence, module file roles and API, "Where code goes", how to check a change, releasing.
- `docs/guide.md` (users), `docs/jvm.md` (JVM features), `docs/cli.md`, `docs/keybindings.md`, `profiles/README.md`.

## Commands

Everything goes through `bin/hell` (sh wrapper → `emacs --batch` → `hell-cli-main` in `lisp/hell-cli.el`). Each command is its own file `bin/hell-COMMAND` defining `hell-cli-COMMAND`. Global options come before the command. `$EMACS` picks the Emacs binary.

```sh
bin/hell sync                 # install packages, build grammars, byte-compile, generate the profile init file
bin/hell doctor               # health checks (core + each enabled module's doctor.el)
bin/hell -p dev sync          # -p/--profile, --helldir, -D, -! go before the command
bin/hell -p safe-mode sync    # core only, for bisecting a broken config
bin/hell emacs                # run this checkout interactively
bin/hell licenses | sbom      # read every hell-component! / grammar :license pin
```

**There are no tests, and none should be added** (removed 2026-09-30). A change is checked by syncing and starting Emacs against throwaway XDG directories, never the real config:

```sh
T=$(mktemp -d)
export XDG_CONFIG_HOME=$T/config XDG_DATA_HOME=$T/data \
       XDG_CACHE_HOME=$T/cache XDG_STATE_HOME=$T/state HELLDIR=$T/config/hell-emacs
bin/hell install --no-env     # creates the config, syncs, runs doctor
bin/hell emacs                # *Messages* shows "Hell Emacs ready in N.NNs"
```

A full sync downloads language servers and takes minutes: run it in the background. CI (`.github/workflows/ci.yml`) runs install, `doctor`, `licenses`, `sbom` on Emacs 29.1 and 30.1.

## Architecture: the parts that bite

- **Everything startup needs is decided at sync time.** `early-init.el` loads `lisp/hell-core.el` → `hell-initialize` → `hell-start` loads `<profile>/init.MAJOR.MINOR.elc`, built by `lisp/hell-profiles.el` from numbered parts in `<profile>/init.d/` (05 load-path, 10 core autoloads, 20 user `init.el` + network, 30 `:env`, 60 lib/module autoloads, 70 package autoloads, 80 module `init.el`s then `config.el`s then user `config.el`). Startup never reads `packages.el` or installs anything. After changing a `hell!` block, a `packages.el`, an autoload file, core, or a module: **sync again**, or you are running stale compiled files.
- **There is no root `init.el`** (gitignored on purpose); `early-init.el` is the only root `.el`.
- **`lisp/lib/` and `lisp/cli/` are off `load-path`.** Load with `(hell-require 'hell-lib 'net)` / `(hell-require 'hell-cli 'sync)` (inside `eval-and-compile` when you need their macros, e.g. `with-hell-network`); end such files with `(hell-provide 'hell-lib 'NAME)`. Plain `(require 'hell-jdk)` doesn't work.
- **Module trees**, searched in order: user `modules/`, `modules/hell/` (core's own module `:hell`, always on, depth -100: gcmh, the Altar splash, themed UX, the `C-c` leader API `hell-leader-def` in `autoload/keybinds.el`), then `sources/hell+/modules/<group>/<name>/` (the catalog). Never hard-code a module path: use `hell-module-locate-path` / `hell-module-from-path`.
- **Default modules** come from `static/init.example.el`, the single source: register new modules there. New modules start from `static/module-template/`.
- **Code must stay byte-compilable** (sync compiles core and module files into `<profile>/compiled/`): load module siblings with `(hell-module-load "+paths")` and get the module dir with `(hell-module-get hell--current-module :path)`, never `load-file-name`; wrap `load-path` changes needed by a top-level `require` in `eval-and-compile`; `defvar` special variables bound in core; files expanding a not-yet-loaded third-party macro (e.g. `lisp/hell-elpaca.el`) are `no-byte-compile`.
- **Languages plug in via buffer-local variables** so core and `:tools` never name a language: `hell-reload-function`, `hell-forge-test-class-function` / `-test-method-function`, `hell-lsp-status-register`.

## Rules (from `docs/roadmap.md`)

- **Stock Emacs keys.** No Evil, no `SPC` leader, no modal or single-key hijacks, no IntelliJ keymap. Hell Emacs keys live under `C-c` in Doom's non-evil groups (`C-c h` Hell Emacs' own, `C-c c` code, `C-c t` toggles, ...; `hell-leader-def`), and a mode's own commands on the `C-c l` localleader (`hell-localleader-def`); packages improve default commands instead of adding keys, and keys a package takes from stock Emacs are given back; `TAB` indents; `C-h` untouched. The deliberate departures (as-you-type completion, `delete-selection-mode`, `electric-pair-mode`) are listed in docs/keybindings.md.
- **`doctor` messages link to docs.** Every `hell-doctor-warn` / `-error` in core and the modules starts with `:topic 'NAME`, matching a `#### Doctor: NAME` entry in docs/guide.md's "What doctor's messages mean"; a new message needs one.
- **The identity is fixed:** `hell-inferno` theme and palette, banner/logos, the Altar, themed messages (`[FORGE IGNITED]` …). `hell-ux-enable nil` is the neutral opt-out.
- **Built-ins first** (`project.el`, flymake, treesit, `compile`, …); third-party only where the JVM workflow needs it.
- **Pinned and reproducible.** Packages only via `package!` in a `packages.el` (never `package-install`). Every download goes through `hell-sync-download-verified` (SHA-256) inside `with-hell-network`, is declared with `hell-component!` in the module's `+paths.el`, and grammars carry a `:license`. Language servers get a pinned installer in the module's `cli.el` registered with `hell-lsp-pin-installer`. Nothing installs mid-session.
- **XDG only**: never `~/.emacs.d` or `$HOME`; use `hell-data-dir`, `hell-cache-dir`, `hell-state-file`, etc. No telemetry.
- **Startup under 0.12s** for a synced profile; keep work lazy (autoloads, `after!`, `hell-first-*-hook`).
- Every source file carries the GPL-3.0-or-later header with the `petrolal` copyright.
- Commits use Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).

## Work tracking

Take the next unchecked item in `docs/roadmap.md` → "Open work, in order". When done and verified (throwaway sync, `doctor` passes, startup within budget if touched), tick it as `- [x] Thing (YYYY-MM-DD: what was done, how it was checked)`; partial work is `- [/]`. Add new work to the roadmap before starting it. Code comments cite roadmap item numbers ("12.7", "Phase 16").
