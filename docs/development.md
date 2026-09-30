# Developing Hellmacs

How Hellmacs is built, where code goes, and how to change it. The rules
every change follows, and what to work on next, are in the
[roadmap](roadmap.md#rules); read them first.

---

## Why Hellmacs

Enterprise JVM teams live in IntelliJ IDEA, Eclipse or VS Code: heavy on
memory, slow to start, and different on every desk. Emacs distributions
that modernized Emacs (Doom, Spacemacs) did it by turning it into Vim,
which shuts out the people who have used GNU Emacs for decades. And stock
Emacs needs a lot of fragile setup before JDTLS, Lombok, debugging and hot
swap work on a multi-module Gradle build.

Hellmacs is the answer to both: **Doom Emacs' architecture, stock GNU Emacs
keys, and IntelliJ IDEA Ultimate's JVM features**, pinned and reproducible
enough for a bank's security team, starting in under 0.12s.

---

## Architecture

Hellmacs is laid out and works as Doom Emacs v3 (`doomemacs/core`):

| Doom v3 | Hellmacs | What it holds |
|---|---|---|
| `early-init.el` | `early-init.el` | Directories, GC and UI tuning, startup hacks; loads core and calls `hellmacs-initialize` |
| *(no root `init.el`)* | *(none)* | `sync` generates each profile's init file; `.gitignore` keeps a root one out |
| `lisp/doom.el` | `lisp/hellmacs.el` | The heart: lifecycle hooks, GC, directories, `hellmacs-initialize`, `hellmacs-start`, `hellmacs-startup` |
| `lisp/doom-emacs.el` | `lisp/hellmacs-emacs.el` | Stock-Emacs defaults and the entry point (overrides Emacs' init-file loader) |
| `lisp/doom-lib.el` | `lisp/hellmacs-lib.el` | Macros (`after!`, `add-hook!`, `defadvice!`), `hellmacs-require`, dotfiles |
| `lisp/doom-modules.el` | `lisp/hellmacs-modules.el` | `hellmacs!`, `modulep!`, `package!`, `unpin!`, module paths and metadata |
| `lisp/doom-packages.el`, `-elpaca.el` | `lisp/hellmacs-packages.el`, `-elpaca.el` | use-package settings; Elpaca, loaded only by sync |
| `lisp/doom-profiles.el` | `lisp/hellmacs-profiles.el` | The generated init file, from `init.d/` parts |
| `lisp/doom-cli.el` | `lisp/hellmacs-cli.el` | The command dispatcher and shared helpers |
| `lisp/lib/`, `lisp/cli/` | `lisp/lib/` (`jdk`, `net`, `lsp-status`), `lisp/cli/` (`sync`, `bundle`, `compliance`, `config`, `verify`) | Off `load-path`: `(hellmacs-require 'hellmacs-lib 'net)` |
| — | `lisp/hellmacs-treesit.el` | Pinned tree-sitter grammars (`hellmacs-treesit!`) |
| `modules/doom/` (`:doom`) | `modules/hellmacs/` (`:hellmacs`) | Core's own module, always on, first: gcmh, the Altar, themed UX, the `C-c` leader API |
| `sources/doom+/modules/` | `sources/hellmacs+/modules/` | The module catalog (a submodule in Doom, in the repo here) |
| `.doom`, `.doommodule` | `.hellmacs`, `.hellmacsmodule` | A version string, then an alist (`name`, `depth`) |
| `bin/doom`, `bin/doom-COMMAND`, `doomscript`, `doom.sh` | `bin/hellmacs`, `bin/hellmacs-COMMAND`, `hellmacsscript`, `hellmacs.sh` | The CLI |
| `profiles/` | `profiles/` | Shipped profiles (`safe-mode`); a directory is a profile |

Not taken from Doom, on purpose: straight.el (Elpaca), evil and `:doom
compat`, the `SPC` leader, Org docs. See the [roadmap](roadmap.md#doom-v3-parity)
for the full comparison and the open parity items.

### Startup

```
early-init.el      directories, GC off, UI chrome off, startup hacks
  └ lisp/hellmacs.el  (byte-compiled when the last sync compiled it)
    └ hellmacs-initialize   core libraries; interactively hellmacs-emacs.el,
                            whose entry point replaces Emacs' init-file loading
      └ hellmacs-start      loads <profile>/init.MAJOR.MINOR.elc, then
        └ hellmacs-startup  runs hellmacs-startup-functions by depth:
             5  profile data, packages on load-path
            10  core's autoloads
            20  your init.el (settings), the network setup   (at load time)
            30  packages' :env                               (at load time)
            60  lisp/lib/ and the modules' autoloads
            70  packages' autoloads (one compiled file), Info dirs
            80  every module's init.el, then every config.el, then your config.el
after-init         custom.el, GC back to 16MB (gcmh collects when idle),
                   hellmacs-after-init-hook
```

`sync` writes those parts into `<profile>/init.d/`
(`hellmacs-profile-generate-functions`), joins them into
`init.MAJOR.MINOR.el` and byte-compiles it. **Everything startup needs is
decided at sync time**: which modules are on (`hellmacs-modules` is baked
in), where each package is, what to autoload. Startup reads no
`packages.el`, checks nothing and installs nothing; without an init file it
warns and leaves plain Emacs (`hellmacs-nosync-error`). Batch sessions
start the same way:

```sh
emacs --batch -l early-init.el -f hellmacs-start -l SCRIPT.el
```

`sync` also byte-compiles core (all of `lisp/`) and each enabled module's
`init.el` and `config.el` into `<profile>/compiled/`. Compiled core is used
only while no `lisp/**/*.el` is newer than its stamp; a compiled module
file only while it's newer than its source.

### Directories

| | Where | Defined in |
|---|---|---|
| Hellmacs | the checkout (`hellmacs-dir`) | `early-init.el` |
| Your config | `~/.config/hellmacs/` (`hellmacs-user-dir`; `$HELLMACSDIR`) | `early-init.el` |
| Data | `~/.local/share/hellmacs/` (`hellmacs-data-dir`): Elpaca, servers, `profiles/NAME/` | `early-init.el` |
| Cache | `~/.cache/hellmacs/` (`hellmacs-cache-dir`): native-comp, caches | `early-init.el` |
| State | `~/.local/state/hellmacs/` (`hellmacs-state-dir`, `hellmacs-state-file`) | `early-init.el` |

A profile `NAME` gets `hellmacs-NAME` in each. Never write to `~/.emacs.d`
or `$HOME`; `user-emacs-directory` points at the cache.

---

## Modules

A module is `<group>/<name>/` in a module tree, written `:group name`.
Trees are searched in order (`hellmacs-module-load-path`): your
`~/.config/hellmacs/modules/`, Hellmacs' `modules/` (core's own), then
`sources/hellmacs+/modules/` (the catalog). Yours wins over Hellmacs' of
the same name. Find a module with `hellmacs-module-locate-path`, a file's
module with `hellmacs-module-from-path`; never hard-code a path.

Every file is optional:

| File | When | What |
|---|---|---|
| `.hellmacsmodule` | always | `"0.9.0" ((name :group name) (depth . N))`; every shipped module has one |
| `packages.el` | read at sync | `package!`, `depends-on!`, `hellmacs-treesit!` under `+tree-sitter` |
| `autoload.el`, `autoload/*.el` | autoloaded at startup | Commands and helpers others call (`;;;###autoload`) |
| `init.el` | startup, before any `config.el` | Early settings |
| `config.el` | startup | The configuration (`use-package`) |
| `cli.el` | `bin/hellmacs` only | Sync steps (`hellmacs-sync-functions`), commands (`hellmacs-cli-NAME`) |
| `doctor.el` | `bin/hellmacs doctor` | Checks: `hellmacs-doctor-ok`, `-info`, `-warn`, `-error` (a leading `:topic 'jdk` links a warning or error to that entry of the guide's "What doctor's messages mean"), `-executable`, `-pinned` |
| `+paths.el` | loaded by `config.el` and `cli.el` | A language server's paths and pins (`hellmacs-component!`) |
| `+NAME.el` | loaded with `(hellmacs-module-load "+NAME")` | Splitting a big config |

### The API

```elisp
(hellmacs! :lang (java +lombok) :tools lsp)   ; user init.el: enable modules
(modulep! +lombok)                            ; in a module: its own flag
(modulep! :tools lsp)                         ; another module
(modulep! :lang java +spring)                 ; another module's flag (-flag: without)

(package! NAME :recipe (...) :pin "REF" :built-in 'prefer
               :disable t :ignore t :type 'virtual :env (("VAR" . "v")))
(disable-packages! a b)
(unpin! pkg (:lang java) t)                   ; user packages.el
(depends-on! :tools lsp)                      ; packages.el: needs that module
(hellmacs-treesit! :grammars ((java URL LABEL COMMIT)) :remap ((java-mode . java-ts-mode)))
(hellmacs-component! :name ... :version ... :license "EPL-2.0" :url ... :sha256 ... :path ...)

(hellmacs-leader-def "x" "group" "x y" '("label" . command))   ; C-c x y
(hellmacs-localleader-def '(java-mode java-ts-mode)          ; C-c l b, in those modes
  "b" '("build" . command))
(after! lsp-mode ...) (add-hook! java-mode #'fn) (defadvice! ...)
(hellmacs-require 'hellmacs-lib 'jdk)         ; a lisp/lib/ part
```

`:lang` modules plug into shared features through buffer-local variables,
so core and `:tools` never name a language: `hellmacs-reload-function`
(`C-c h r`), `hellmacs-forge-test-class-function` and
`-test-method-function` and `-test-run-function` (running tests, on
`C-c l t` once `hellmacs-forge-setup-build-h` has run), and
`(hellmacs-lsp-status-register SERVER ...)` (the modeline and messages).

Useful hooks: `hellmacs-first-input-hook`, `-first-file-hook`,
`-first-buffer-hook` (defer work until needed),
`hellmacs-{before,after}-modules-{init,config}-hook`,
`hellmacs-after-init-hook`, `hellmacs-sync-functions`.

### A new module

1. `cp -r static/module-template sources/hellmacs+/modules/lang/NAME`, and
   name it in its `.hellmacsmodule`.
2. Fill in `packages.el`, `config.el`, and what else it needs. A language
   server gets a pinned installer in `cli.el` (registered with
   `hellmacs-lsp-pin-installer`, so lsp-mode never downloads its own), its
   pin declared with `hellmacs-component!` in `+paths.el`, and a check in
   `doctor.el`. The language's own commands go on the localleader
   (`hellmacs-localleader-def`, `C-c l`); what every language shares
   (rename, format, code actions) is already on `C-c c`. Never a
   single-key or modal binding, and never a stock key rebound.
3. Add it to `static/init.example.el`, the single list of default modules
   (commented out if it's off by default).
4. Sync in throwaway directories, try it, run `doctor` (below).

---

## Where code goes

| You're adding | Put it in |
|---|---|
| Engine code every session needs | `lisp/hellmacs-*.el` |
| A step of the startup | A part in `hellmacs-profile-generate-functions` (`lisp/hellmacs-profiles.el`) |
| A library called on demand | `lisp/lib/NAME.el`, ending with `(hellmacs-provide 'hellmacs-lib 'NAME)` |
| Code only the CLI needs | `lisp/cli/NAME.el`, or the command's own file |
| A command | `bin/hellmacs-NAME` (executable, `#!/usr/bin/env hellmacsscript`), defining `hellmacs-cli-NAME` |
| Something every config gets, user-facing or needing a package | Core's own module, `modules/hellmacs/` |
| An optional feature or a language | A module in `sources/hellmacs+/modules/<group>/<name>/` |
| A theme | Its module: `sources/hellmacs+/modules/ui/theme/themes/` |

Code must stay byte-compilable: in module files load siblings with
`(hellmacs-module-load "+paths")` and find the module's directory with
`(hellmacs-module-get hellmacs--current-module :path)`, never
`load-file-name` (it points into the profile when compiled); wrap
`load-path` changes a top-level `require` needs in `eval-and-compile`; in
core, `defvar` every special variable a file binds. A file that expands a
third-party macro that may not be loaded yet (like `lisp/hellmacs-elpaca.el`)
must be `no-byte-compile`.

Downloads go through `hellmacs-sync-download-verified` (pinned by SHA-256)
inside `with-hellmacs-network`; packages only through `package!`, never
`package-install`.

---

## Working on Hellmacs

```sh
git clone https://github.com/petrolal/hellmacs.git ~/src/hellmacs
~/src/hellmacs/bin/hellmacs -p dev sync       # a profile of its own
~/src/hellmacs/bin/hellmacs -p dev emacs
```

**Checking a change.** Hellmacs has no test suites. Sync against throwaway
directories so your own config is never touched, try the change, run
`doctor`:

```sh
T=$(mktemp -d)
export XDG_CONFIG_HOME=$T/config XDG_DATA_HOME=$T/data \
       XDG_CACHE_HOME=$T/cache XDG_STATE_HOME=$T/state HELLMACSDIR=$T/config/hellmacs
bin/hellmacs install --no-env     # creates the config, syncs, runs doctor
bin/hellmacs emacs                # try it; *Messages* says the startup time
```

A full sync of the default modules downloads the language servers and
takes minutes the first time. After changing core or a module, sync again
before measuring startup: otherwise you're running the last sync's files.
CI (`.github/workflows/ci.yml`) installs Hellmacs and runs `doctor`,
`licenses` and `sbom` on Emacs 29.1 and 30.1 for every push.

**Commits** follow Conventional Commits (`feat:`, `fix:`, `docs:`,
`refactor:`, `chore:`), as `.hellmacs` says. Every source file carries the
GPL-3.0-or-later header with the `petrolal` copyright.

**Releasing** (maintainers):

1. Move `[Unreleased]` in `CHANGELOG.md` under the new version and date,
   with the Emacs versions and platforms it supports.
2. Set `hellmacs-version` (`lisp/hellmacs-lib.el`) to it.
3. `bin/hellmacs doctor` passes and CI is green.
4. Tag it, signed: `git tag -s vX.Y.Z -m "Hellmacs X.Y.Z"`, and push the tag.
5. Set `hellmacs-version` on `main` to the next version.

---

## The identity

Hellmacs looks and talks like itself; these don't change.

- **The palette** (`hellmacs-inferno`):

  | Token | Colour | Used for |
  |---|---|---|
  | `bg-main` | `#16171d` | Background |
  | `bg-alt` | `#1c1e24` | Mode-line, popups, current line |
  | `fg-main` | `#bbc2cf` | Text |
  | `inferno-crimson` | `#ff6c6b` | Headers, errors, cursor |
  | `ember-amber` | `#da8548` | Warnings, subheadings, keywords |
  | `reap-gold` | `#ecbe7b` | Accents, functions, shortcuts |
  | `forge-gray` | `#5b6268` | Borders, fringes, inactive line numbers |
  | `venom-green` | `#98be65` | Success, strings, added lines |
  | `forge-gray-hi` | `#868f96` | Comments, doc strings, dimmed text |

  Every text colour is at least 4.5:1 against its background.
- **The words:** the Altar (the dashboard), the Forge (projects, `C-c h f`),
  the Crucible (hot swap and REPL reload, `C-c h r`), the Reaper (GC,
  `C-c h c`); `[FORGE IGNITED]`, `[DAEMON READY]`, `[BYTECODE PURGATORY]`,
  `[DAEMON BANISHED]`, `[TEST DAMNATION]`.
- **The banner and logos** in `assets/`.
- **Neutral mode** for workplaces that ask: `hellmacs-ux-enable nil`,
  `hellmacs-splash-enable nil`, another `hellmacs-theme`. Only ever opt-in.
