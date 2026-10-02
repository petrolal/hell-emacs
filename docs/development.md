# Developing Hell Emacs

How Hell Emacs is built, where code goes, and how to change it. The rules
every change follows, and what to work on next, are in the
[roadmap](roadmap.md#rules); read them first.

---

## Why Hell Emacs

Enterprise JVM teams live in IntelliJ IDEA, Eclipse or VS Code: heavy on
memory, slow to start, and different on every desk. Emacs distributions
that modernized Emacs (Doom, Spacemacs) did it by turning it into Vim,
which shuts out the people who have used GNU Emacs for decades. And stock
Emacs needs a lot of fragile setup before JDTLS, Lombok, debugging and hot
swap work on a multi-module Gradle build.

Hell Emacs is the answer to both: **Doom Emacs' architecture, stock GNU Emacs
keys, and IntelliJ IDEA Ultimate's JVM features**, pinned and reproducible
enough for a bank's security team, starting in under 0.12s.

---

## Architecture

Hell Emacs is laid out and works as Doom Emacs v3 (`doomemacs/core`):

| Doom v3 | Hell Emacs | What it holds |
|---|---|---|
| `early-init.el` | `early-init.el` | Directories, GC and UI tuning, startup hacks; loads core and calls `hell-initialize` |
| *(no root `init.el`)* | *(none)* | `sync` generates each profile's init file; `.gitignore` keeps a root one out |
| `lisp/doom.el` | `lisp/hell-core.el` | The heart: lifecycle hooks, GC, directories, `hell-initialize`, `hell-start`, `hell-startup` |
| `lisp/doom-emacs.el` | `lisp/hell-emacs.el` | Stock-Emacs defaults and the entry point (overrides Emacs' init-file loader) |
| `lisp/doom-lib.el` | `lisp/hell-lib.el` | Macros (`after!`, `add-hook!`, `defadvice!`), `hell-require`, dotfiles |
| `lisp/doom-modules.el` | `lisp/hell-modules.el` | `hell!`, `modulep!`, `package!`, `unpin!`, module paths and metadata |
| `lisp/doom-packages.el`, `-elpaca.el` | `lisp/hell-packages.el`, `-elpaca.el` | use-package settings; Elpaca, loaded only by sync |
| `lisp/doom-profiles.el` | `lisp/hell-profiles.el` | The generated init file, from `init.d/` parts |
| `lisp/doom-cli.el` | `lisp/hell-cli.el` | The command dispatcher and shared helpers |
| `lisp/lib/`, `lisp/cli/` | `lisp/lib/` (`jdk`, `net`, `lsp-status`), `lisp/cli/` (`sync`, `bundle`, `compliance`, `config`, `verify`) | Off `load-path`: `(hell-require 'hell-lib 'net)` |
| — | `lisp/hell-treesit.el` | Pinned tree-sitter grammars (`hell-treesit!`) |
| `modules/doom/` (`:doom`) | `modules/hell/` (`:hell`) | Core's own module, always on, first: gcmh, the Altar, themed UX, the `C-c` leader API |
| `sources/doom+/modules/` | `sources/hell+/modules/` | The module catalog (a submodule in Doom, in the repo here) |
| `.doom`, `.doommodule` | `.hell-emacs`, `.hellmodule` | A version string, then an alist (`name`, `depth`) |
| `bin/doom`, `bin/doom-COMMAND`, `doomscript`, `doom.sh` | `bin/hell`, `bin/hell-COMMAND`, `hellscript`, `hell.sh` | The CLI |
| `profiles/` | `profiles/` | Shipped profiles (`safe-mode`); a directory is a profile |

Not taken from Doom, on purpose: straight.el (Elpaca), evil and `:doom
compat`, the `SPC` leader, Org docs. See the [roadmap](roadmap.md#doom-v3-parity)
for the full comparison and the open parity items.

### Startup

```
early-init.el      directories, GC off, stock UI chrome, startup hacks
  └ lisp/hell-core.el  (byte-compiled when the last sync compiled it)
    └ hell-initialize   core libraries; interactively hell-emacs.el,
                            whose entry point replaces Emacs' init-file loading
      └ hell-start      loads <profile>/init.MAJOR.MINOR.elc, then
        └ hell-startup  runs hell-startup-functions by depth:
             5  profile data, packages on load-path
            10  core's autoloads
            20  your init.el (settings), the network setup   (at load time)
            30  packages' :env                               (at load time)
            60  lisp/lib/ and the modules' autoloads
            70  packages' autoloads (one compiled file), Info dirs
            80  every module's init.el, then every config.el, then your config.el
after-init         custom.el, GC back to 16MB (gcmh collects when idle),
                   hell-after-init-hook
```

`sync` writes those parts into `<profile>/init.d/`
(`hell-profile-generate-functions`), joins them into
`init.MAJOR.MINOR.el` and byte-compiles it. **Everything startup needs is
decided at sync time**: which modules are on (`hell-modules` is baked
in), where each package is, what to autoload. Startup reads no
`packages.el`, checks nothing and installs nothing; without an init file it
warns and leaves plain Emacs (`hell-nosync-error`). Batch sessions
start the same way:

```sh
emacs --batch -l early-init.el -f hell-start -l SCRIPT.el
```

`sync` also byte-compiles core (all of `lisp/`) and each enabled module's
`init.el` and `config.el` into `<profile>/compiled/`. Compiled core is used
only while no `lisp/**/*.el` is newer than its stamp; a compiled module
file only while it's newer than its source.

### Directories

| | Where | Defined in |
|---|---|---|
| Hell Emacs | the checkout (`hell-dir`) | `early-init.el` |
| Your config | `~/.config/hell-emacs/` (`hell-user-dir`; `$HELLDIR`) | `early-init.el` |
| Data | `~/.local/share/hell-emacs/` (`hell-data-dir`): Elpaca, servers, `profiles/NAME/` | `early-init.el` |
| Cache | `~/.cache/hell-emacs/` (`hell-cache-dir`): native-comp, caches | `early-init.el` |
| State | `~/.local/state/hell-emacs/` (`hell-state-dir`, `hell-state-file`) | `early-init.el` |

A profile `NAME` gets `hell-emacs-NAME` in each. Never write to `~/.emacs.d`
or `$HOME`; `user-emacs-directory` points at the cache.

---

## Modules

A module is `<group>/<name>/` in a module tree, written `:group name`.
Trees are searched in order (`hell-module-load-path`): your
`~/.config/hell-emacs/modules/`, Hell Emacs' `modules/` (core's own), then
`sources/hell+/modules/` (the catalog). Yours wins over Hell Emacs' of
the same name. Find a module with `hell-module-locate-path`, a file's
module with `hell-module-from-path`; never hard-code a path.

Every file is optional:

| File | When | What |
|---|---|---|
| `.hellmodule` | always | `"0.9.0" ((name :group name) (depth . N))`; every shipped module has one |
| `packages.el` | read at sync | `package!`, `depends-on!`, `hell-treesit!` under `+tree-sitter` |
| `autoload.el`, `autoload/*.el` | autoloaded at startup | Commands and helpers others call (`;;;###autoload`) |
| `init.el` | startup, before any `config.el` | Early settings |
| `config.el` | startup | The configuration (`use-package`) |
| `cli.el` | `bin/hell` only | Sync steps (`hell-sync-functions`), commands (`hell-cli-NAME`) |
| `doctor.el` | `bin/hell doctor` | Checks: `hell-doctor-ok`, `-info`, `-warn`, `-error` (a leading `:topic 'jdk` links a warning or error to that entry of the guide's "What doctor's messages mean"), `-executable`, `-pinned` |
| `+paths.el` | loaded by `config.el` and `cli.el` | A language server's paths and pins (`hell-component!`) |
| `+NAME.el` | loaded with `(hell-module-load "+NAME")` | Splitting a big config |

### The API

```elisp
(hell! :lang (java +lombok) :tools lsp)   ; user init.el: enable modules
(modulep! +lombok)                            ; in a module: its own flag
(modulep! :tools lsp)                         ; another module
(modulep! :lang java +spring)                 ; another module's flag (-flag: without)

(package! NAME :recipe (...) :pin "REF" :built-in 'prefer
               :disable t :ignore t :type 'virtual :env (("VAR" . "v")))
(disable-packages! a b)
(unpin! pkg (:lang java) t)                   ; user packages.el
(depends-on! :tools lsp)                      ; packages.el: needs that module
(hell-treesit! :grammars ((java URL LABEL COMMIT)) :remap ((java-mode . java-ts-mode)))
(hell-component! :name ... :version ... :license "EPL-2.0" :url ... :sha256 ... :path ...)

(hell-leader-def "x" "group" "x y" '("label" . command))   ; C-c x y
(hell-localleader-def '(java-mode java-ts-mode)          ; C-c l b, in those modes
  "b" '("build" . command))
(after! lsp-mode ...) (add-hook! java-mode #'fn) (defadvice! ...)
(hell-require 'hell-lib 'jdk)         ; a lisp/lib/ part
```

`:lang` modules plug into shared features through buffer-local variables,
so core and `:tools` never name a language: `hell-reload-function`
(`C-c h r`), `hell-forge-test-class-function` and
`-test-method-function` and `-test-run-function` (running tests, on
`C-c l t` once `hell-forge-setup-build-h` has run), and
`(hell-lsp-status-register SERVER ...)` (the mode line and messages).

Useful hooks: `hell-first-input-hook`, `-first-file-hook`,
`-first-buffer-hook` (defer work until needed),
`hell-{before,after}-modules-{init,config}-hook`,
`hell-after-init-hook`, `hell-sync-functions`.

### A new module

1. `cp -r static/module-template sources/hell+/modules/lang/NAME`, and
   name it in its `.hellmodule`.
2. Fill in `packages.el`, `config.el`, and what else it needs. A language
   server gets a pinned installer in `cli.el` (registered with
   `hell-lsp-pin-installer`, so lsp-mode never downloads its own), its
   pin declared with `hell-component!` in `+paths.el`, and a check in
   `doctor.el`. The language's own commands go on the localleader
   (`hell-localleader-def`, `C-c l`); what every language shares
   (rename, format, code actions) is already on `C-c c`. Never a
   single-key or modal binding, and never a stock key rebound.
3. Add it to `static/init.example.el`, the single list of default modules
   (commented out if it's off by default).
4. Sync in throwaway directories, try it, run `doctor` (below).

---

## Where code goes

| You're adding | Put it in |
|---|---|
| Engine code every session needs | `lisp/hell-*.el` |
| A step of the startup | A part in `hell-profile-generate-functions` (`lisp/hell-profiles.el`) |
| A library called on demand | `lisp/lib/NAME.el`, ending with `(hell-provide 'hell-lib 'NAME)` |
| Code only the CLI needs | `lisp/cli/NAME.el`, or the command's own file |
| A command | `bin/hell-NAME` (executable, `#!/usr/bin/env hellscript`), defining `hell-cli-NAME` |
| Something every config gets, user-facing or needing a package | Core's own module, `modules/hell/` |
| An optional feature or a language | A module in `sources/hell+/modules/<group>/<name>/` |
| A theme | Its module: `sources/hell+/modules/ui/theme/themes/` |

Code must stay byte-compilable: in module files load siblings with
`(hell-module-load "+paths")` and find the module's directory with
`(hell-module-get hell--current-module :path)`, never
`load-file-name` (it points into the profile when compiled); wrap
`load-path` changes a top-level `require` needs in `eval-and-compile`; in
core, `defvar` every special variable a file binds. A file that expands a
third-party macro that may not be loaded yet (like `lisp/hell-elpaca.el`)
must be `no-byte-compile`.

Downloads go through `hell-sync-download-verified` (pinned by SHA-256)
inside `with-hell-network`; packages only through `package!`, never
`package-install`.

---

## Working on Hell Emacs

### Development Environments & Workflows

When developing Hell Emacs itself, adding new modules, or testing configurations, you should **never use symlinks** (e.g. symlinking `~/.config/hell-emacs` to your repository or vice-versa). Symlinks often cause unexpected canonical path resolutions, break relative path lookups, trigger duplicate file warnings, and pollute git tracking.

Instead, Hell Emacs natively provides **three clean development workflows**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Workflow 1: In-Tree Root Configuration                                 │
│ ∙ Real `init.el`, `config.el`, `packages.el` at repository root        │
│ ∙ Automatically detected by `early-init.el`                             │
│ ∙ Zero git noise: root `/*.el` (except `early-init.el`) is .gitignored  │
│ ∙ Run: `bin/hell sync`, `bin/hell doctor`, `bin/hell emacs` │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────────────────┐
│ Workflow 2: Named & In-Tree Profiles                                    │
│ ∙ Completely isolated configs, packages, caches, history, and state    │
│ ∙ In-tree profiles: `profiles/NAME/` (e.g. `profiles/dev/`)            │
│ ∙ XDG profiles: `~/.config/hell-emacs-NAME/`                              │
│ ∙ Create: `bin/hell profile create dev --in-tree`                   │
│ ∙ Run: `bin/hell -p dev sync` / `bin/hell -p dev emacs`         │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────────────────┐
│ Workflow 3: Ephemeral Sandbox Mode                                      │
│ ∙ 100% clean, throwaway temporary directory in `/tmp/`                  │
│ ∙ Perfect for debugging clean installs and reproducible testing        │
│ ∙ Run: `bin/hell emacs --sandbox`                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

#### Workflow 1: In-Tree Root Configuration (Fastest Local Development)

This is the recommended workflow when developing Hell Emacs or testing new features directly in your cloned repository checkout.

1. **Place your configuration files at the root of the repository**:
   ```sh
   cp static/init.example.el init.el
   cp static/config.example.el config.el
   cp static/packages.example.el packages.el
   ```
2. **How it works**:
   - When you run `bin/hell` or start Emacs pointing to the repo (`emacs --init-directory ~/hell-emacs`), `early-init.el` checks if a real `init.el` exists at the root of the checkout (`hell-dir`).
   - If present, `hell-user-dir` automatically resolves to the repository root instead of `~/.config/hell-emacs/`.
   - Hell Emacs' `.gitignore` explicitly ignores `/*.el` (except `early-init.el`), keeping your `git status` completely clean without uncommitted changes.
3. **Daily workflow**:
   ```sh
   bin/hell sync          # sync packages and compile modules
   bin/hell doctor        # verify configuration health
   bin/hell emacs         # launch Hell Emacs
   ```

---

#### Workflow 2: Named & In-Tree Profiles (Isolated Environments)

Named profiles let you run completely isolated instances of Hell Emacs side-by-side with separate package trees, caches, native-comp outputs, bookmarks, and undo histories.

1. **Creating a Profile**:
   - **In-Tree Profile** (inside repo under `profiles/NAME/`):
     ```sh
     bin/hell profile create dev --in-tree
     ```
   - **XDG Named Profile** (in `~/.config/hell-emacs-NAME/`):
     ```sh
     bin/hell profile create dev
     ```
2. **Managing and Inspecting Profiles**:
   ```sh
   bin/hell profile list          # list all profiles, sync state, and paths
   bin/hell profile path dev      # print resolved config path
   bin/hell profile sync dev      # sync specific profile
   bin/hell profile sync --all    # sync all discovered profiles
   bin/hell profile delete dev -! # delete profile and associated data
   ```
3. **Running a Profile**:
   ```sh
   bin/hell -p dev sync
   bin/hell -p dev doctor
   bin/hell -p dev emacs          # (or: emacs --profile dev)
   ```
4. **Data Isolation**:
   | Profile Component | Path for profile `NAME` |
   |---|---|
   | Configuration | `profiles/NAME/` (in-tree) or `~/.config/hell-emacs-NAME/` |
   | Installed Packages | `~/.local/share/hell-emacs-NAME/` |
   | Cache & Native Comp | `~/.cache/hell-emacs-NAME/` |
   | State & History | `~/.local/state/hell-emacs-NAME/` |

---

#### Workflow 3: Ephemeral Sandbox Mode

For testing fresh installations, verifying isolated behaviors, or diagnosing configuration issues without touching any existing profile:

```sh
bin/hell emacs --sandbox
```

This allocates an isolated temporary directory in `/tmp/hell-sandbox.XXXXXX`, runs the session, and automatically wipes all temporary state upon exiting.

---

### Verifying Changes

Hell Emacs has strict standards for reproducibility and performance:

1. **Verify Health**:
   ```sh
   bin/hell doctor
   ```
2. **Verify Checksums & Lock Integrity**:
   ```sh
   bin/hell verify
   ```
3. **Verify Licenses & SBOM**:
   ```sh
   bin/hell licenses
   bin/hell sbom
   ```

A full sync of the default modules downloads the language servers and
takes minutes the first time. After changing core or a module, sync again
before measuring startup: otherwise you're running the last sync's files.
CI (`.github/workflows/ci.yml`) installs Hell Emacs and runs `doctor`,
`licenses` and `sbom` on Emacs 29.1 and 30.1 for every push.

**Commits** follow Conventional Commits (`feat:`, `fix:`, `docs:`,
`refactor:`, `chore:`), as `.hell-emacs` says. Every source file carries the
GPL-3.0-or-later header with the `petrolal` copyright.

**Releasing** (maintainers):

1. Move `[Unreleased]` in `CHANGELOG.md` under the new version and date,
   with the Emacs versions and platforms it supports.
2. Set `hell-version` (`lisp/hell-lib.el`) to it.
3. `bin/hell doctor` passes and CI is green.
4. Tag it, signed: `git tag -s vX.Y.Z -m "Hell Emacs X.Y.Z"`, and push the tag.
5. Set `hell-version` on `main` to the next version.

---

## The identity

Hell Emacs looks and talks like itself; these don't change.

- **The palette** (`hell-inferno`):

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
- **The words:** the Altar (GNU Emacs' startup screen, themed), the Forge (projects, stock `C-x p`),
  the Crucible (hot swap and REPL reload, `C-c h r`), the Reaper (GC,
  `C-c h c`); `[FORGE IGNITED]`, `[DAEMON READY]`, `[BYTECODE PURGATORY]`,
  `[DAEMON BANISHED]`, `[TEST DAMNATION]`.
- **The banner and logos** in `assets/`.
- **Neutral mode** for workplaces that ask: `hell-ux-enable nil`,
  `hell-splash-enable nil`, another `hell-theme`. Only ever opt-in.
