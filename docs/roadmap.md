# Hellmacs roadmap

## Objective

**Hellmacs is an enterprise-grade alternative to the IDEs the enterprise JVM
sector runs on today: IntelliJ IDEA, Eclipse, and VS Code with the Java
extensions.** A developer at a bank, an insurer or a large software shop
should be able to take their company laptop, their company's network, and
their team's Spring Boot, Maven and Gradle codebases, and do a full working
week in Hellmacs without reaching for the IDE they came from.

"Enterprise-grade" is measured, not claimed. Hellmacs meets the objective
when all of these hold (Phase 12 builds what's missing, and 12.11 checks
them on real codebases):

1. **Parity on daily Java work.** Everything a developer does most days in
   IntelliJ or Eclipse has an equivalent: completion, navigation,
   refactoring, diagnostics, build, test, debug, git, and Spring Boot run and
   debug. The gaps that remain are written down in the feature matrix
   (Phase 12), with the reason for each.
2. **The enterprise's machines.** Linux and macOS (x86-64 and arm64) are
   supported and tested in CI. Windows has a supported path (12.2).
3. **The enterprise's network.** Installs and updates work behind an HTTP
   proxy, with a corporate CA, against internal mirrors (Artifactory,
   Nexus, a git mirror), and fully offline from a bundle.
4. **The enterprise's codebases.** Large multi-module Maven and Gradle
   builds, several JDKs side by side, legacy Java 8/11 targets, and internal
   repositories configured in `settings.xml` or Gradle init scripts.
5. **The enterprise's rules.** Every component is pinned and checksummed,
   with an SBOM and a license report. There is no telemetry, updates are
   reproducible, and releases are versioned with a stated support window.
6. **The enterprise's teams.** A team can share one configuration and lock
   file, format code the same way as teammates who stay on IntelliJ or
   Eclipse, and onboard a new developer with one command and a migration
   guide.

### Principles

These are the rules every phase follows. When a feature pulls against one of
them, the principle wins and the feature finds another way.

- **Stock Emacs, not an emulation (The 40-Year Purist Guarantee).**
  Emacs' default keys keep their exact meaning (`C-x C-f`, `C-x b`, `C-s`,
  `M-x`, `M-.`, `M-f`, `C-y`, `dired`, `project.el`, buffers). Nothing is
  modal (no Evil/Vim emulation by default). A 60-year-old veteran who has
  used GNU Emacs for 40 years can sit down, feel 100% at home with their
  lifelong muscle memory, and immediately command modern enterprise JVM
  machinery (JDTLS, DAP stepping, Hot Code Replacement, Spring Boot).
  Hellmacs' own commands live cleanly under `C-c` (see keybinding policy).
- **Built-ins first, the best package where they fall short.** flymake,
  `project.el`, tree-sitter, `compile`, `tab-bar`, `info`, and `editorconfig`
  before third-party equivalents. Third-party packages are used where the JVM
  workflow needs them: lsp-mode and lsp-java (JDTLS), dap-mode, Magit.
- **JVM first.** Java is the reference language and gets IntelliJ parity;
  Kotlin, Clojure, Groovy and Scala follow the same pattern. Other languages
  are welcome as modules but never drive the plan.
- **Pinned, checksummed, reproducible.** Every server, grammar, jar and
  package is pinned (by SHA-256 where the download is reproducible) and
  installed by `bin/hellmacs sync`, never downloaded in the middle of an
  editing session. `bin/hellmacs lock` pins the rest.
- **Offline-capable, network-agnostic.** Nothing assumes direct internet
  access. Every download goes through one place that honours proxies,
  corporate CAs, mirrors and offline bundles (12.1).
- **Nothing outside Hellmacs' directories, nothing phoned home.** State stays
  in the XDG directories; there is no telemetry, ever.
- **Fast.** A synced profile starts in well under a second (Phase 9's 0.12s
  budget), and features load lazily. An editor that starts faster than the
  IDE opens a project is part of the pitch.
- **Strict Test-Driven Development (TDD).** Always write unit and integration tests first before writing production code (RED). Tests must target real functions and contracts directly without self-mocking test bodies. Implement the minimal code to satisfy the tests (GREEN), refactor, and verify pass rate and sub-0.12s startup budget.
- **Honest.** Where Hellmacs is behind an IDE, the feature matrix says so.
  Enterprise adoption depends on trust, and an overclaimed parity list is
  found out in the first week.

### Documentation Index

* 📚 **User Guides**:
  * [Getting Started](getting-started.md)
  * [Configuration](configuration.md)
  * [JVM Development](jvm-development.md)
  * [Keybindings Reference](keybindings.md)
  * [CLI Reference](cli.md)
* 🛠️ **Development & Architecture**:
  * [Vision, Business Rules & Invariants](development/vision-and-rules.md)
  * [System Architecture & Design System](development/architecture.md)
  * [Contributing & Module Contracts](development/contributing.md)
  * [Work Order & Progress Checklist](development/work-order.md)


---

### Master Progress & Execution Plan

#### 🟢 Phase Summary & Status

| Phase / Milestone | Focus Area | Status | Key Deliverables |
|---|---|:---:|---|
| **Phase 0-2** | Core Architecture & Elpaca | **DONE [x]** | Pure XDG paths, early GC tuning, Elpaca package manager |
| **Phase 3-5** | Sync Engine & Profiles | **DONE [x]** | Static `profile.eld` generation, `bin/hellmacs` CLI, profile switching |
| **Phase 6-7** | Java Parity & DAP Debugger | **DONE [x]** | Eclipse JDTLS, DAP stepping, breakpoints, Hot Code Replacement |
| **Phase 8.1-8.3** | Kotlin, Clojure & Tree-sitter | **DONE [x]** | `kotlin-language-server`, `clojure-lsp`, CIDER REPL, pinned grammars |
| **Phase 8.4-8.5** | Groovy & Scala | **PLANNED [ ]** | Gradle scripts and Jenkinsfiles (Groovy), Metals (Scala) |
| **Phase 9** | UI, Modeline & Inferno Theme | **DONE [x]** | `hellmacs-inferno`, The Altar dashboard, doom-modeline (9.0-9.4 complete) |
| **Phase 10** | Daily-Driver Essentials | **PLANNED [ ]** | XML/YAML/JSON, formatters, popups, snippets (nothing started) |
| **Phase 11** | Consolidation & Tooling | **DONE [x]** | Unified server status, declarations, compiled startup, shared test helpers |
| **Phase 12.1** | Corporate Networks & Proxies | **DONE [x]** | Corporate CA bundles, HTTP proxies, Artifactory/Nexus, doctor probes, offline bundles & E2E verification |
| **Phase 12.2** | Platforms & CI | **DONE [x]** | GitHub Actions multi-OS matrix (Linux x86_64/arm64, macOS Apple Silicon/Intel), WSL2 support & platform checks |
| **Phase 12.3** | Multi-JDKs & Build Environments | **DONE [x]** | Side-by-side JDK auto-discovery, per-project toolchains and direnv |
| **Phase 12.4-12.6** | Spring Boot & Toolbelt | **PLANNED [ ]** | Spring profiles, JUnit XML, database clients, `.http` REST files |
| **Phase 12.7-12.11** | Enterprise Scale & 1.0 Pilot | **PLANNED [ ]** | SBOM generator, license compliance, migration guides, real pilot |
| **Phase 13** | Hellmacs Manual & Purist Onboarding | **PLANNED [ ]** | GNU Info manual, Vanilla startup actions on The Altar, C-h help suite |

---

#### 📋 Component Checklist (Done vs Planned)

- [x] **Core Engine & Boot Lifecycle**
  - [x] GC lifecycle: off during boot, then 16MB at runtime; gcmh collects when idle (64MB, 128MB with a language server)
  - [x] Strict XDG directory isolation (`~/.config`, `~/.local/share`, `~/.cache`, `~/.local/state`)
  - [x] Asynchronous Elpaca integration with static compiled profile snapshot (`profile.eld`)
  - [x] Sub-0.12s verified startup budget
- [x] **CLI Tooling (`bin/hellmacs`)**
  - [x] `bin/hellmacs install` (seeds user config from templates, runs sync & doctor)
  - [x] `bin/hellmacs sync` (installs packages, compiles tree-sitter, writes profile)
  - [x] `bin/hellmacs upgrade` (git pull framework, update unlocked packages, sync)
  - [x] `bin/hellmacs lock` (generates reproducible `packages.lock.eld`)
  - [x] `bin/hellmacs doctor` (comprehensive environment & tool checker)
  - [x] `bin/hellmacs env` (exports shell variables for desktop GUI launchers)
  - [x] `bin/hellmacs test` (runs regression test suite)
- [x] **Module & Customization Framework**
  - [x] `(hellmacs! ...)` module declaration macro with granular flags (`+flag`)
  - [x] `(modulep! ...)` compile-time and runtime predicate evaluator
  - [x] `(package! ...)` declaration macro supporting pins, recipes, and disables
  - [x] Private user module system (`~/.config/hellmacs/modules/`) with override precedence
- [x] **JVM Languages Subsystem**
  - [x] Java (`:lang java`): Eclipse JDTLS, Lombok javaagent, Maven/Gradle integration
  - [x] Kotlin (`:lang kotlin`): `kotlin-language-server`, Gradle test runners
  - [x] Clojure (`:lang clojure`): `clojure-lsp` + CIDER interactive REPL
  - [x] Pinned Tree-sitter grammar builds for all JVM languages
- [x] **Debugging & Hot Reload Subsystem**
  - [x] Full DAP protocol integration via `dap-mode` and `java-debug`
  - [x] Breakpoints (line, conditional, log points), watches, locals, REPL
  - [x] Fluid single-key stepping loop (`n`, `i`, `o`, `c`)
  - [x] Crucible Hot Code Replacement (`C-c h r`) into running JVM sessions
- [x] **Completion & Search Stack**
  - [x] Corfu in-buffer completion popup with live doc previews (`corfu-popupinfo`)
  - [x] Vertico vertical minibuffer with Consult, Marginalia, and Orderless
  - [x] Workspace-wide and project ripgrep symbol searching
- [x] **Theme & Visual Design**
  - [x] Custom standalone `hellmacs-inferno` theme
  - [x] The Altar dashboard (`*hellmacs*`) with ASCII/image cyber-cat sigils
  - [x] Themed daemon notices (`[FORGE IGNITED]`, `[DAEMON READY]`, `[BYTECODE PURGATORY]`)
  - [x] Enterprise neutrality switch (`hellmacs-ux-enable nil`)
- [x] **Documentation System**
  - [x] Streamlined user guides (`docs/*.md`)
  - [x] Unified development & architecture specifications (`docs/development/*.md`)
  - [x] Comprehensive enterprise roadmap & parity matrix (`docs/roadmap.md`)

- [x] **Consolidation (Phase 11)**
  - [x] Shared language server status and daemon lifecycle orchestrator (11.2)
  - [x] Module dependencies and tree-sitter declared once per module (11.3)
  - [x] Byte-compiled core, modules and autoloads at sync (11.4)
- [ ] **Planned Daily-Driver Essentials (Phase 10)**
  - [x] Format-on-save integration (google-java-format, ktfmt, cljfmt) (10.2)
  - [x] Configuration file support (XML, YAML, JSON, Markdown, shell, Dockerfile) (10.1)
- [ ] **Planned Enterprise Hardening (Phase 12)**
  - [x] Corporate HTTP proxy & custom internal CA certificate management (12.1)
  - [x] Standalone offline bundle builder for zero-internet environments (12.1)
  - [ ] Multi-platform CI (macOS arm64/x86_64, Windows WSL/native) (12.2)
  - [x] Dynamic multi-JDK switching and directory-based toolchains (12.3)
  - [ ] Spring Boot dashboard & active profile launcher (`application-*.yml`) (12.4)
  - [ ] JUnit XML test reports and code coverage visualization (12.5)
  - [ ] Database client and `.http` REST execution tooling (12.6)
  - [ ] Automated SBOM generator and license compliance auditor (12.9)
  - [ ] Enterprise team onboarding migration guide (12.10)
  - [ ] Real-world enterprise codebase pilot (12.11)
- [ ] **Planned Hellmacs Manual & Purist Onboarding (Phase 13)**
  - [ ] GNU Info Manual (`info` / `C-h i` / `C-h H`) for offline, in-editor reading (13.1)
  - [ ] Vanilla Emacs startup actions integrated into The Altar (Tutorial, Manual, Guided Tour, Dired) (13.2)
  - [ ] Purist help discoverability (`C-h` suite with Hellmacs module lookups) (13.3)

---

### 🔮 Extensible Backlog & Future Initiatives

*(This section is continuously updated as new corporate requirements, community suggestions, and tool integrations emerge during development)*

* **IDE Ergonomics & Tooling**:
  * [ ] AST-based structural code folding (`treesit-fold`).
  * [ ] Multi-cursor editing on stock Emacs keys.
  * [ ] Project-wide TODO / FIXME comment aggregator (`hl-todo`).
  * [ ] GitHub/GitLab PR review interface directly inside Magit (`forge`).
* **JVM & Cloud Extensions**:
  * [ ] Groovy language support (`:lang groovy`) for Gradle scripts and Jenkinsfiles.
  * [ ] Scala language support (`:lang scala`) via Metals.
  * [ ] Quarkus & Micronaut project templates and diagnostics.
  * [ ] Kubernetes cluster manager (`kubel`) and Docker container interface.
* **Team Collaboration & Governance**:
  * [ ] Shared Eclipse / IntelliJ code style formatter XML importer.
  * [ ] One-click corporate onboarding script (`curl ... | sh`).

---

### Sequencing toward the objective

Phases 0 to 7 built the framework and Java parity; they stay as written
below, as history. From here, work is ordered by what blocks enterprise
adoption, not by phase number:

| Order | Work | Why it comes here |
|---|---|---|
| 1 | **Phase 11** (consolidation), 11.2 to 11.4 (**done**) | Phase 12 adds more servers and tools; the shared status system, declarations and compiled startup keep that from multiplying the duplication |
| 2 | **12.1 Corporate networks** | Without it, `bin/hellmacs install` fails on the first corporate laptop |
| 3 | **12.2 Platforms and CI** | Most enterprise laptops are macOS or Windows; CI keeps them working |
| 4 | **12.3 JDKs and build environments** (takes in 10.5's direnv) | Several JDKs and internal repositories are the norm, not the exception |
| 5a | **12.8's configs keep up with new default modules** (moved here on 2026-09-28) | Existing configs silently miss modules added since, such as Magit; it affects current users now |
| 5 | **Phase 9.4** (finish dashboard and modeline integration) | Small: what's left is the README and a GUI start (see 9.4) |
| 6 | **12.4 Spring Boot**, **12.5 Tests and coverage** | The biggest daily gaps against IntelliJ |
| 7 | **Phase 10.1** (XML, YAML, JSON, Docker, shell), **10.2** with **12.8**'s formatter work | Every enterprise repo carries these files |
| 8 | **12.6 Enterprise tool belt**, **10.3**, **10.4** | Database, HTTP, containers, static analysis; then comforts |
| 9 | **12.7 Scale**, **12.9 Security and compliance**, **12.10 Documentation** | What an enterprise's platform and security teams ask for before approving a tool |
| 10 | **Phase 8.4 Groovy** (Gradle scripts, Jenkinsfiles) | Common in enterprise builds |
| 11 | **12.11 Enterprise pilot**, then the **1.0 release** | The objective's criteria, checked on real codebases |
| Later | **Phase 8.5 Scala**, 10's deferred list | Valuable, but rarer in the enterprise JVM sector |

## Architecture origins

The framework is modeled on Doom Emacs' core (`doomemacs/core`, v2.2 → v3
split). The module system, config separation, sync-time generated init file,
and CLI all come from Doom. The package layer is new: Doom still uses
straight.el (`lisp/doom-elpaca.el` is an empty `;; TODO`), and Hellmacs stays
on Elpaca.

## How Doom's core works (reference)

Doom's core rests on six ideas.

1. **The framework and the user's config are separate.**
   - `doom-emacs-dir` holds the framework and is updated with git.
   - `doom-user-dir` (`$DOOMDIR`, `~/.config/doom`) holds the user's
     `init.el` (a `doom!` block that enables modules), `packages.el`, and
     `config.el`.
   - State goes in XDG data, cache, and state dirs, with one folder per
     profile.
   - `user-emacs-directory` is re-pointed at the cache dir. Most packages build
     their state paths from it, so this puts their clutter there with no
     per-package `setq`.
2. **Modules are directories.**
   - Each module lives at `modules/<group>/<name>/` and is named `:group name`.
   - A module holds `packages.el` (declarations only, read by the CLI),
     `init.el` (runs early), `config.el` (interactive sessions), `autoload.el`
     or `autoload/*.el` (lazily loaded functions), and `cli.el`.
   - Modules take flags, as in `(corfu +orderless)`. `modulep!` queries modules
     and flags at runtime.
   - `:depth` sets the load order. Core and the user config are virtual modules.
3. **`package!` only declares a package.** It records the recipe, `:pin`,
   `:disable`, and `:built-in 'prefer`. Nothing is installed at startup. The
   `doom sync` command installs packages.
4. **A generated profile init file is where the speed comes from.**
   - `doom sync` writes numbered fragments into `init.d/` and concatenates them
     into one file:
     - the precomputed `load-path` and `auto-mode-alist`
     - core, module, and package autoloads, in dependency order
     - the module state, cached in symbol plists so `modulep!` stays O(1)
     - hard-coded `load` calls for every module's `init.el` and `config.el`, in
       depth order, wrapped in before/after hooks
   - An advice on `startup--load-user-init-file` loads that file instead of
     `init.el`. Startup does no discovery work.
5. **The lifecycle has named stages and lazy hooks.**
   - Startup runs in this order: `early-init.el`, then `doom.el`, then
     `doom-initialize`, then the generated init, then `doom-startup-functions`,
     then `doom-finalize`.
   - `doom-first-{input,file,buffer}-hook` fire once, on the first keypress,
     file, or buffer.
   - Packages can also load incrementally while Emacs is idle.
   - `doom-context` records the session mode: startup, cli, emacs, module,
     init, or config.
6. **The `bin/doom` CLI is written in elisp** and runs through `doomscript`.
   Its commands are defined with `defcli!` and include `sync`, `doctor`,
   `upgrade`, `gc`, `env`, `profile`, and `install`.

Doom also ships a standard library (`after!`, `add-hook!`, `setq-hook!`,
`defadvice!`, `cmd!`, `load!`, `quiet!`, `letf!`, `defer-until!`) and a set of
opinionated defaults in `doom-emacs.el`.

## Keybinding policy: Emacs defaults, not Vim

Hellmacs uses Emacs' default keybindings. It is not a Vim or Neovim emulation:
there is no `evil-mode`, no modal editing, and no `SPC` leader.

- **Stock bindings stay as they are.** `C-x C-f`, `C-x b`, `C-s`, `M-x`,
  `C-g` and so on keep their normal meaning. Hellmacs never rebinds a default
  key to something else.
- **Hellmacs' own commands live under `C-c`,** the prefix Emacs reserves for
  users. This is also Doom's layout for non-evil users:
  - `C-c h`: Hellmacs meta (reload, visit dirs, list modules)
  - `C-c f`: file, `C-c b`: buffer, `C-c s`: search, `C-c w`: window
  - `C-c l`: the local leader, for commands specific to the current major mode
    (e.g. JVM language modes)
- **Packages improve default commands instead of adding new keys.** For example,
  `consult-buffer` is remapped onto `C-x b` and `consult-line` onto `M-s l`.
  Emacs muscle memory keeps working.
- **which-key stays.** It shows what follows any prefix, including `C-c`,
  `C-x` and `C-h`.
- **New prefixes follow the same rules** (Phase 6): `C-c l` for LSP,
  `C-c d` for debugging, and `C-c !` for diagnostics, the last only inside
  `lsp-mode-map`, as minor-mode keys should be.
- **TAB keeps its stock behavior.** It indents; `C-M-i` completes. Making TAB
  also complete is opt-in, with the `+tab` flag of `:completion corfu`.

Doom supports both styles (an `:editor evil` module plus the `C-c` fallback).
Hellmacs only supports the Emacs style. Users who want Vim bindings can add
`evil` themselves in their own `config.el`, but no module ships it.

## Where Hellmacs starts

- `early-init.el` sets up the directories, tunes GC and file handlers, and
  configures native-comp.
- `init.el` `require`s a fixed `hellmacs-modules` list.
- `core/` handles the GC lifecycle, keeps state files inside `var/` and `etc/`,
  and bootstraps Elpaca.
- There are six single-file modules. Each uses `use-package :ensure t`.
- Keybindings were Vim-style (`evil`, `evil-collection`, a `SPC` leader
  through `general.el`). That conflicted with the keybinding policy above and
  was removed in Phase 1.5.

## Phases

Phases are numbered in the order they were planned; the order they are
worked in is set by "Sequencing toward the objective" at the top. Each phase can ship on its own. Hellmacs doesn't copy Doom line for line: about
half of Doom's complexity is v2 backward compatibility and straight.el.

### Phase 0: Foundations

- [x] First git commit.
- [x] `core/hellmacs-lib.el`: `after!`, `add-hook!`, `remove-hook!`,
      `setq-hook!`, `defadvice!`, `cmd!`, `hellmacs-log`, and
      `hellmacs-run-hooks`.
- [x] `hellmacs-first-{input,file,buffer}-hook` and `hellmacs-after-init-hook`.
- [x] `hellmacs-context` (`startup`, `emacs`, `cli`, `reload`, ...).
- [x] Use the new hooks in core: `savehist`, `recentf`, and `save-place` now
      start lazily.

The `!` macros are user-facing sugar, so they keep Doom's unprefixed names.
Every function and variable uses the `hellmacs-` prefix.

### Phase 1: Separate the framework from the user config (done)

- [x] `hellmacs-user-dir`: the first match among `$HELLMACSDIR`,
      `~/.config/hellmacs/`, and `~/.hellmacs.d/`, defaulting to
      `~/.config/hellmacs/`. It holds `init.el` (loaded before modules; sets
      `hellmacs-modules`), `config.el` (loaded after modules), and
      `custom.el`. Errors in these files show as warnings and don't stop
      startup.
- [x] `static/{init,config}.example.el` templates, copied by
      `hellmacs-init-user-dir` (`C-c h u` offers to run it).
- [x] Packages go to `$XDG_DATA_HOME/hellmacs`, native-comp output and caches
      to `$XDG_CACHE_HOME/hellmacs`, and history, backups, and undo to
      `$XDG_STATE_HOME/hellmacs`. `hellmacs-var-dir` and `hellmacs-etc-dir`
      remain as obsolete aliases.
- [x] `user-emacs-directory` points at the cache dir. Unlike the original plan,
      the explicit path `setq`s stay: they're all state (history, bookmarks),
      and state must not land in a dir that's meant to be disposable. Doom does
      the same.

`packages.el` in the user dir is deferred to Phase 2, where `package!` exists.
Until then, extra packages go in `config.el` via `use-package`.

### Phase 1.5: Switch to Emacs default keybindings (done)

- [x] Removed `modules/hellmacs-evil.el` (`evil`, `evil-collection`).
- [x] `hellmacs-keybinds`: `hellmacs-leader-def` now binds `KEY DEF` pairs into
      `mode-specific-map` (Emacs' own `C-c` map), so other `C-c` bindings keep
      working. `general.el` is gone; `keymap-set` covers it. A `(LABEL .
      COMMAND)` definition gives which-key a label, and a string labels a
      prefix group.
- [x] `C-c w` is built from built-in window commands: split, delete,
      maximize, balance, `windmove` in Emacs directions (`b`/`f`/`p`/`n`),
      and `winner` undo/redo. `C-c q r` restarts Emacs.
- [x] `hellmacs-completion`: consult remaps `switch-to-buffer`, `yank-pop`,
      `goto-line`, `imenu`, `bookmark-jump` and related commands, so `C-x b`,
      `M-y`, `M-g g`, etc. get the consult versions. It adds `M-s l` / `M-s r`
      / `M-s f` and fills the `C-c f`, `C-c b` and `C-c s` groups.
- [x] `hellmacs-editor`: `undo-fu` is dropped in favor of Emacs' own `undo` /
      `undo-redo`. `undo-fu-session` stays.
- [x] README, the module template and the `static/` templates are updated.
      Hellmacs now requires Emacs 29.1+ (checked at startup in `init.el`).

The `C-c l` local leader has no bindings yet. It arrives with the first
language module.

### Phase 2: Module system (done)

- [x] New layout, `modules/<group>/<name>/{packages,autoload,init,config}.el`:
      `:ui theme`, `:editor undo`, `:completion vertico`, `:completion corfu`
      and `:config default`. Later: `:lang java`, `:lang clojure` and
      `:tools lsp`.
- [x] `hellmacs!` (the `doom!` equivalent) in the user's init.el, with +flags
      and `:depth N`. With no user init.el (or no `hellmacs!` in it),
      `static/init.example.el` supplies the defaults. Unknown modules warn and
      are skipped.
- [x] `modulep!`: `(modulep! :group name +flag -flag)`, or `(modulep! +flag)`
      inside a module (resolved when the file loads).
- [x] Private modules in `$HELLMACSDIR/modules/` take priority over built-in
      modules of the same name (`hellmacs-module-load-path`).
- [x] `package!` only records a declaration (`:recipe`, `:pin` → Elpaca
      `:ref`, `:built-in` t/`'prefer`, `:disable`). Later declarations merge
      over earlier ones, so the user's `packages.el` (read last) can override a
      module's. `:disable` also turns that package's `use-package` blocks into
      no-ops.
- [x] `use-package-always-ensure` is now nil: modules declare with `package!`
      and configure with `use-package`.
- [x] `hellmacs-leader-def` moved to `core/hellmacs-keybinds.el`, so it exists
      regardless of which modules are enabled.
- [x] Module template moved to `static/module-template/`; the user starter
      files now include `packages.el`.

For now, packages are still installed at startup: step 2 of
`hellmacs-modules-startup` queues every declared package with Elpaca and
waits. `autoload.el` is loaded eagerly; its `;;;###autoload` cookies
start working once Phase 3 generates loaddefs.

### Phase 3: Sync and the generated profile (done)

- [x] `hellmacs-sync` (`core/hellmacs-sync.el`) reads the `hellmacs!` block and
      every `packages.el`, queues the Elpaca orders, runs `elpaca-wait`, and
      fails loudly if any package didn't build.
- [x] It writes a profile to `$XDG_DATA_HOME/hellmacs/profiles/default/`:
  - `profile.eld`: the build directories and autoload files of every declared
    package and its dependencies, in dependency order, plus
    `hellmacs-packages`, the module list, and the facts the profile depends
    on (see below).
  - `module-autoloads.el`: real autoloads generated from the
    `;;;###autoload` cookies in modules' `autoload.el`.
- [x] Startup replays an up-to-date profile without loading Elpaca at all
      (about 0.03s, versus 0.09s on the live path). Elpaca moved to
      `core/hellmacs-elpaca.el`, loaded only by a sync or by the live path.
- [x] The profile is out of date when the Emacs version, the enabled
      modules/flags/paths, or the mtime of any involved `packages.el` or
      `autoload.el` changes, or when a recorded build directory is gone. Startup
      then warns and falls back to the live Elpaca path, so a forgotten sync
      only costs speed. With no profile at all (a fresh clone), the live path
      runs silently.
- [x] Startup-finished work (GC restore, `custom-file`, `hellmacs-finalize`)
      hangs off `hellmacs--packages-ready-hook`, fired by `after-init-hook`
      (synced) or `elpaca-after-init-hook` (live).
- [x] `bin/hellmacs sync` (batch) and `M-x hellmacs-sync` / `C-c h s`
      (in-session). This pulls the Phase 4 `sync` command forward.
- [x] On a synced startup, `use-package :ensure` warns instead of silently
      falling through to package.el; declare packages with `package!`.
- [x] Fixed the fresh-install hang. When several packages discover the same
      undeclared dependency at once (`compat`, for vertico, consult, corfu,
      marginalia and orderless), Elpaca starts building it twice. The second
      build fails, and the packages waiting on it stay blocked forever, so
      `elpaca-wait` never returns. `core/packages.el` (read before any
      module, like Doom's `lisp/packages.el`) now declares `compat` up front.
      A fresh sync takes about 12s instead of hanging. As a safety net,
      `hellmacs--elpaca-wait` gives up once only blocked packages remain and
      nothing has changed for 30s, and the sync then names the failed
      packages. This is likely an upstream Elpaca bug and worth reporting.

Differences from the original plan:
- The profile is data (`profile.eld`) plus one generated autoloads file, not
  one concatenated init file. Each package's own autoloads file is loaded
  rather than inlined, which avoids rewriting their `load-file-name`-relative
  forms. At 7-10 packages, the extra file loads cost nothing measurable.
- Module `init.el`/`config.el` loads are not baked into the profile. They
  are still discovered at startup (a handful of `file-exists-p` calls), so
  editing or adding those files never needs a sync.
- `:pin` already maps to Elpaca's `:ref` (Phase 2). A lock file
  (`elpaca-write-lock-file`) moves to Phase 4, where `upgrade` makes it
  meaningful.

### Phase 4: `bin/hellmacs` CLI (done)

- [x] `bin/hellmacs` is a small shell wrapper that runs
      `emacs --batch -l early-init.el` and calls `hellmacs-cli-main`
      (`core/hellmacs-cli.el`). Each command is a `hellmacs-cli-COMMAND`
      function, so there's no `defcli!` framework. Commands exit 0 on success
      and 1 on failure.
- [x] `install [--env] [--no-config]`: creates the user config from
      `static/`, syncs, optionally saves the environment, then runs `doctor`.
      `hellmacs-init-user-dir` moved into core so it works without
      `:config default`.
- [x] `sync` (from Phase 3).
- [x] `upgrade [--packages]`:
  - First it runs `git pull --ff-only` on Hellmacs. This is skipped when the
    checkout has uncommitted changes or no upstream.
  - Then it updates packages in a fresh Emacs, so the new code does the
    update.
  - Every package without a `:pin` is fetched and merged, the profile is
    re-synced, and the lock file is rewritten if there is one.
  - A checkout left on a detached HEAD by a lock install is put back on its
    branch first. Otherwise Elpaca's update fails, because there's no
    upstream (`@{u}`).
- [x] `lock`: syncs, then writes the exact commit of every package to
      `$HELLMACSDIR/packages.lock.eld`, next to the config so they can be
      versioned together. When the file exists, every install uses it
      (`elpaca-lock-file`). Verified by locking an older vertico commit and
      reinstalling.
- [x] `gc [-n]`: syncs, then deletes package build and source directories
      nothing declares anymore, such as the old evil stack.
- [x] `env [--clear]`: saves the environment `bin/hellmacs` was run with,
      minus session variables (DISPLAY, SSH_AUTH_SOCK, TERM, ...), to
      `$XDG_DATA_HOME/hellmacs/env`. Interactive startup prepends it to
      `process-environment` and updates `exec-path`.
- [x] `doctor`:
  - checks the Emacs version, dev builds, and native compilation
  - checks for git (required)
  - checks for rg, fd, java, jdtls, and clojure-lsp (optional, with what each
    is for)
  - reports the user config, modules, sync state, lock, and env file
  - flags the leftover `var/` and `etc/` from before Phase 1

### Phase 5: Profiles, GC, incremental loading, startup tweaks (done)

- [x] **Profiles.** Start with `emacs --profile NAME` or `HELLMACS_PROFILE=NAME`;
      the CLI takes `bin/hellmacs --profile NAME ...`.
  - A named profile gets its own copy of every directory:
    `~/.config/hellmacs-NAME/`, `~/.local/share/hellmacs-NAME/`, and so on,
    which covers config, packages, synced profile, env file, lock, caches and
    history.
  - `--profile` is consumed through `command-switch-alist`, so Emacs doesn't
    open it as a file. Names are limited to `[A-Za-z0-9_-]`.
  - The default profile's paths are unchanged.
  - Unlike Doom, there's no `profiles.el` registry: the name alone decides
    the directories.
- [x] **Incremental loading.** `hellmacs-load-incrementally` queues features,
      and a `:defer-incrementally` keyword does the same from `use-package`.
      Queued features load one at a time on idle timers, starting 2s after
      startup and then every 0.75s. consult uses it, so the first `C-x b` no
      longer loads it.
- [x] **`gcmh`** (declared in `core/packages.el`) replaces the hand-rolled
      idle-GC timer and minibuffer GC hooks. It starts at the first real
      buffer with an `auto` idle delay and a 64MB high threshold, as in Doom.
      It's skipped on igc builds, and it can be disabled with
      `(package! gcmh :disable t)`.
- [x] **Startup tweaks from Doom:**
  - `file-name-handler-alist` is trimmed at startup but keeps the gzip
    handler when Emacs' own Lisp is compressed. This Emacs ships
    `.el.gz`, and the old code dropped the handler.
  - It's restored for files opened from the command line, and merged back
    after startup instead of overwritten. The trimming is skipped for the
    daemon.
  - `display-startup-screen` and `display-startup-echo-area-message` are
    overridden. This removes the "For information about GNU Emacs" message
    that the `inhibit-startup-echo-area-message` setting didn't.
  - A broken `native-compile` feature (no libgccjit) is hidden.
  - Other settings: `auto-mode-case-fold` nil, `ad-redefinition-action`
    accept, `read-process-output-max` 64KB, no missing-lexbind-cookie
    warnings for third-party packages, and `DEBUG=1` enables debug mode.
  - Skipped on purpose: deferring `tool-bar-setup` and hiding the mode-line
    during startup. They save little at a ~0.035s startup and can leave
    Emacs looking frozen if something fails.

Measured result: synced startup went from about 0.034s to about 0.037s. The
extra cost is gcmh's autoloads plus keeping the gzip handler, which is a
correctness fix. The splash-screen savings land after the point this number
measures. Phase 5 buys features and correctness, not raw speed.

### Phase 6: Java/JVM parity, an IntelliJ replacement (done)

**Goal:** a Java developer can do a full working day in Hellmacs without
opening IntelliJ. That means importing and indexing a Maven/Gradle project,
smart completion with auto-import, navigation (including into JDK and
library classes), refactoring, building, testing, debugging, and Git.

The phase covers only that parity set. Everything else is deferred
(see "Not in this phase" below).

**Stack.** Only established packages and built-in Emacs features, each doing
the job it's known for:

| Concern | Package | Why this one |
|---|---|---|
| Language server | `lsp-mode` + `lsp-java` (Eclipse JDTLS) | `lsp-java` covers JDTLS's Java-specific extensions: project import and sync, the class-file decompiler, generate/extract code actions, and the debug and test bundles. eglot speaks plain LSP and leaves those out. |
| Completion UI | `corfu` (already shipped) + `cape` | `lsp-completion-at-point` feeds corfu directly (`lsp-completion-provider :none`), and cape adds file and dabbrev completion around it |
| Diagnostics | Built-in `flymake` (`lsp-diagnostics-provider :flymake`) | Saves a dependency (no flycheck) |
| Debugging and tests | `dap-mode` + `dap-java` | Launch, attach, breakpoints and hot code replace through Microsoft's java-debug, plus running and debugging JUnit tests |
| Build | Built-in `compile` / `project-compile` | ANSI colors via `ansi-color-compilation-filter` (Emacs 28+), and Emacs' existing javac, Maven and Java stack-frame error regexps |
| Projects | Built-in `project.el` | Already used by `C-c h f`. Its `C-x p` map (find file, compile, search, switch) is the vanilla answer to IntelliJ's project view, so no `projectile` and no extra `C-c p` group |
| Git | `magit` | |

**Changes to the existing design** (the audit results):

1. **Default LSP client: lsp-mode, not eglot.** The old Phase 6 made eglot
   the default. For Java, parity needs lsp-java, and lsp-java needs lsp-mode.
   So `:tools lsp` uses lsp-mode by default, and eglot becomes an opt-in
   `+eglot` flag for other languages (the same split as Doom). With
   `+eglot`, `:lang java` warns and uses lsp-mode anyway.
2. **Clojure and Kotlin move to Phase 8.** Parity comes first.
3. **The planned `C-c p` group is dropped.** It would duplicate Emacs'
   built-in `C-x p` map.
4. **The planned `java-ts-mode` default is dropped.** Java uses the built-in
   `java-mode`, which needs no grammar to compile, and `+tree-sitter` opts
   into `java-ts-mode`. The tree-sitter grammar helper moves to Phase 8.
5. **Module names stay conventional; the theme lives in symbols and
   messages.** The modules are `:tools lsp`, `:tools debugger`,
   `:tools build`, `:tools magit` and `:lang java`, so their keys say what
   they do, as in Doom. Public symbols are named `hellmacs-jvm-*` (Java and
   JDTLS) and `hellmacs-forge-*` (building, following `C-c h f`), with
   matching customization groups. "forge" is deliberately not used as a
   module name: `forge` is Magit's GitHub/GitLab package, and a
   `:tools forge` module would be confusing.
6. **Shared dependencies are declared up front.** Phase 3 showed that
   Elpaca can build a dependency twice, and hang, when several packages
   discover it at the same moment (`compat`). lsp-mode, lsp-java, dap-mode
   and lsp-treemacs share dash, f, ht, s, lv, spinner, markdown-mode,
   posframe, bui, treemacs and request, so their packages.el files declare
   those explicitly. Transitive dependencies are listed in the verification
   step.

**New keys** (Emacs conventions; nothing modal):

| Prefix | Owner | Contents |
|---|---|---|
| `C-c l` | `:tools lsp` | lsp-mode's own `lsp-command-map`, via `lsp-keymap-prefix`, so the layout is lsp-mode's documented one: `a a` code action, `r r` rename, `r o` organize imports, `g g`/`g i`/`g r` definition/implementation/references, `= =` format, `w r` restart workspace. which-key names come from `lsp-enable-which-key-integration`. |
| `C-c l j` | `:lang java` | Java only: `b` build project, `u` update project config (after editing pom.xml/build.gradle), `i` add unimplemented methods, `g` generate getters/setters, `s` generate toString, `e` generate equals/hashCode, `m` extract method, `v` extract local variable, `c` extract constant, `h` type hierarchy, `t` / `T` run test at point / test class |
| `C-c d` | `:tools debugger` | `d` start (`dap-debug`), `b` toggle breakpoint, `B` conditional breakpoint, `L` log point, `n` next, `i` step in, `o` step out, `c` continue, `e` eval at point, `r` restart, `q` disconnect, `t` / `T` debug test at point / test class. `n`/`i`/`o`/`c` form a `repeat-map`, so `C-c d n n n` steps three times without a hydra |
| `C-c !` | `:tools lsp` (in `flymake-mode-map`, so in any flymake buffer) | Flymake: `n`/`p` next/previous diagnostic, `l` list. `C-c` + punctuation is the convention for minor-mode keys, as flycheck does |
| Emacs defaults | (built in) | `M-.`/`M-?`/`M-,` definition/references/back (xref); `C-M-.` workspace symbol search; `C-x p c` compile the project; `C-x g` Magit |

`C-c h r` (+crucible/reload) gains a Java meaning: during a debug session,
save and hot-swap the changed classes (java-debug's hot code replace).

**Thematic messages and mode-line.** One function,
`hellmacs-jvm-announce`, prints every status message, so the wording lives
in one table and follows `hellmacs-ux-enable` (plain wording when it's off):

| Event | Themed | Plain |
|---|---|---|
| JDTLS process started | `[FORGE IGNITED] JDTLS bound to <project>` | `JDTLS started for <project>` |
| Import/index finished (JDTLS `ServiceReady`) | `[DAEMON READY] <project> indexed in Ns` | `<project> indexed` |
| Build failed | `[BYTECODE PURGATORY] <first error, file:line>` | `Build failed: ...` |
| Build succeeded | `[FORGE TEMPERED] Built in Ns` | `Build finished` |
| Tests failed | `[TEST DAMNATION] N failed` | `N tests failed` |
| Server crashed or exited | `[DAEMON BANISHED] JDTLS exited; restarting` | `JDTLS exited` |

A mode-line segment, `hellmacs-jvm-mode-line`, goes in the standard
`mode-line-misc-info` (no mode-line package). It shows `JVM:igniting`
(amber), `JVM:ready` (green) or `JVM:purgatory` (red, when the last build
failed), with new theme faces `hellmacs-jvm-busy`, `-ready` and `-failed`.
lsp-mode's own workspace status segment is turned off so the state isn't
shown twice.

#### Steps

Each step ends with its verification. Tests go in the repository from now
on (see 6.0) rather than in throwaway scripts.

**6.0 Foundations** (done)
- [x] `test/` holds the ERT suites (`test-lib.el`, `test-modules.el`,
      `test-core.el`, 19 tests), and `bin/hellmacs test [REGEXP]` runs them
      with every Hellmacs directory pointed at a temporary one.
- [x] `test/fixtures/java/gradle-demo/` and `maven-demo/` have identical
      sources:
  - `App` (`main`), `Greeter`, and a Lombok `@Data` class, `Person`.
  - A passing `GreeterTest`, and a `BrokenTest` that only runs (and fails)
    with `-Dhellmacs.fail=true`.
  - Both target Java 21 and include their wrappers (`gradlew` and `mvnw`).
  - Verified with Gradle 9.7.1 and Maven 3.9.16 on JDK 25: normal runs
    pass, the fail flag fails exactly BrokenTest, and `App` runs.
  - Lombok 1.18.48 works on JDK 25, with only a `sun.misc.Unsafe`
    deprecation warning.
- [x] `package! :env`: environment variables are set before Elpaca builds
      (its build subprocesses inherit them) and again at every startup,
      from the profile. Verified end to end: a local test package recorded
      the variable during compilation, and a synced boot had it set without
      loading Elpaca.
- [x] Module extension points:
  - A module's `cli.el` is loaded by `bin/hellmacs` and `hellmacs-sync`,
    once per session. It can add to `hellmacs-sync-functions` (run at the
    end of every sync) or define `hellmacs-cli-COMMAND` functions.
  - A module's `doctor.el` gets its own section in `bin/hellmacs doctor`
    and uses `hellmacs-doctor-ok/-info/-warn/-error/-executable`.
  - The CLI's hard-coded checks moved out: rg and fd went to
    `:completion vertico`. java, jdtls and clojure-lsp are removed until
    `:lang java` (6.2) and `:lang clojure` (Phase 8) bring them back.
  - Verified with a private test module: a sync step that ran once per
    sync, a new command, and a failing check that made doctor exit 1.
- [x] Theme faces added: lsp-mode (symbol highlights, lenses, inlay hints,
      rename, signature), dap-mode (breakpoints, current-line marker,
      sessions, locals, results), Magit (sections, diffs, branches, blame,
      log, process, signatures, commit messages), and `hellmacs-jvm-busy`,
      `-ready` and `-failed`. The theme now sets 217 faces.
  - Removed diff lines are red on a dark red tint (4.8:1). Highlighted ones
    switch to Ash text (11.6:1), because red on the brighter tint drops
    below 4.5:1.
- [x] **The plan was checked against the installed packages**: lsp-mode,
      lsp-java, dap-mode and Magit, 35 packages in all, installed in 19s with
      no hang. Every option and command name used in the specs below exists.
      Corrections made to the plan:
  - **`dap-java` ships inside lsp-java**, not dap-mode.
  - **`lsp-java-update-server` is deprecated.** The sync pre-install calls
    `lsp-install-server` for `jdtls` instead. That install uses Maven (`mvn`,
    or a Maven wrapper it downloads) to fetch JDTLS (pinned by
    `lsp-java-jdt-download-url`, currently 1.57.0), the java-debug bundle
    **and the JUnit test runner**. So the dap-java test runner is part of
    the normal install, and the build-tool fallback in 6.4 is a backup.
  - **`dap-java-test-runner` defaults under `user-emacs-directory`**, which
    Hellmacs points at the disposable cache. It must be set into the data
    dir before the server is installed.
  - `lsp-java-server-install-dir` is derived from `lsp-server-install-dir`
    when lsp-java loads, so setting the latter first is enough.
  - lsp-java's default `lsp-java-vmargs` equal the spec's apart from
    `-Xmx1G`, which the spec raises to 2G.
  - **Shared dependencies**, computed from Elpaca's dependency data (with
    how many packages use each):
    - lsp side: dash (9), ht (6), f (5), s (5), lsp-mode (4), posframe,
      lv, markdown-mode and treemacs (2 each)
    - Magit side: cond-let and llama (3 each)

    request, bui and lsp-treemacs each have a single user, so they're
    dropped from the up-front lists. Other transitive dependencies are
    installed without declaration: hydra, lsp-docker and yaml (dap-mode);
    ace-window, avy, cfrs and pfuture (treemacs); magit-section and
    with-editor (Magit).

**6.1 `:tools lsp`** (done): `modules/tools/lsp/` (packages.el,
config.el, autoload.el, doctor.el), plus cape in `:completion corfu`.
- [x] lsp-mode, with its shared dependencies declared up front and
      `:env (("LSP_USE_PLISTS" . "true"))`. `+eglot` uses the built-in
      eglot instead, with `C-c l a/r/o/f/i` and the same `C-c !` keys.
- [x] Tuning:
  - `read-process-output-max` 1MB once a server runs, with lsp-mode or
    eglot.
  - gcmh's high threshold 128MB.
  - `lsp-log-io` nil, `lsp-idle-delay` 0.5, `lsp-file-watch-threshold`
    5000.
  - Breadcrumbs and snippets off, and diagnostics through flymake.
- [x] Files: `lsp-session-file` in the state dir, `lsp-server-install-dir`
      in the data dir.
- [x] Completion: `lsp-completion-provider :none`. In LSP buffers the
      completion functions are the server's capf wrapped in
      `cape-capf-buster`, then `cape-file` and `cape-dabbrev`, the same for
      lsp-mode and eglot. Without `:completion corfu`, the server's plain
      capf is used. `:completion corfu` now installs cape and adds
      `cape-file` globally, plus `cape-dabbrev` in text modes.
- [x] Keys: `C-c l` is lsp-mode's own `lsp-command-map`, via
      `lsp-keymap-prefix`, with which-key names; `C-c !` for flymake in
      `lsp-mode-map`. Verified that `C-c l` holds the full command map. Its
      entries stay hidden until a server with the matching capability is
      active, which is lsp-mode's design.
- [x] lsp-mode loads incrementally: it isn't loaded at startup
      (`featurep`), and it is after idle time.
- [x] Startup cost: 0.029s vs 0.027s without the module (+6.5%, within the
      10% criterion). The difference is lsp-mode's and its dependencies'
      autoload files.
- [x] `lsp-doctor` reports all seven checks OK.
- **Found and fixed: an `:env` change didn't rebuild already-installed
  packages.** lsp-mode, installed in 6.0 before it had `:env`, stayed
  compiled with hash tables while `lsp-use-plists` said plists. It misreads
  every server response in that state, and `lsp-doctor` still reports OK
  because it only checks the variable. Two fixes:
  - Sync records the `:env` each package was built with
    (`$XDG_DATA_HOME/hellmacs/build-env/`) and rebuilds any installed
    package whose `:env` changed, including one that dropped its `:env`.
    Verified: the plist accessor returned `nil` before the rebuild and `3`
    after, and a second sync rebuilt nothing. Unit test
    `test-modules/env-change-triggers-rebuild`.
  - `:tools lsp` checks the compiled accessors after lsp-mode loads and
    shows an error telling you to sync if they don't match
    `lsp-use-plists`.
- Not yet verified: completion, navigation and diagnostics against a real
  server. That needs JDTLS, so it's part of 6.2's checks.

**6.2 `:lang java`** (done): `modules/lang/java/` (packages.el,
config.el, autoload.el, doctor.el, cli.el and `+paths.el`).
- [x] lsp-java, started by `lsp-deferred` from `java-mode-hook` (and
      `java-ts-mode-hook`). `+tree-sitter` remaps `java-mode` to
      `java-ts-mode`. lsp-java loads incrementally after startup, or lsp-mode
      loads it through `lsp-client-packages` when the first Java buffer asks
      for a server.
  - The hooks are registered at startup, not behind `:after lsp-mode`, so a
    Java file opened from the command line gets a server too.
- [x] **JDTLS is installed by `bin/hellmacs sync`.** `cli.el` adds a
      `hellmacs-sync-functions` step that calls
      `lsp-install-server nil 'jdtls` and waits for it. That installs JDTLS
      1.57.0, java-debug and the JUnit runner (110MB) into
      `$XDG_DATA_HOME/hellmacs/lsp/`, in 31s here. Later syncs skip it.
  - Paths are set in `+paths.el`, shared by config.el, cli.el and
    doctor.el, before lsp-java loads:
    - `lsp-server-install-dir` → data
    - the JDTLS workspace and index → `data/jvm/workspace/`
    - `dap-java-test-runner` → next to JDTLS, not in the cache
- [x] Settings from the spec: JDK from `hellmacs-jvm-java-home` (JAVA_HOME),
      `-Xmx2G`, the FernFlower decompiler, organize imports on save, Maven
      sources, code lenses and favorite static imports.
- [x] **Status.** `hellmacs-jvm-announce`, driven by the
      `hellmacs-jvm-messages` table, prints themed or plain wording
      depending on `hellmacs-ux-enable`:
  - `[FORGE IGNITED]` from `lsp-after-initialize-hook`
  - `[DAEMON READY] <root> indexed in Ns` when JDTLS sends `ServiceReady`
    (an `:after` advice on `lsp-java--language-status-callback`, which
    otherwise only logs it)
  - `[DAEMON BANISHED]` from `lsp-after-uninitialized-functions`

  Mode-line: `JVM:igniting` / `JVM:ready` via a standard
  `mode-line-misc-info` entry, with states keyed by the normalized project
  root.
- [x] **`C-c l j`** in the Java modes' maps: build, update project config,
      organize imports, add unimplemented methods, generate
      getters/setters, toString and equals/hashCode, extract method, local
      variable and constant, type hierarchy, and run the test at point or
      in the class.
  - lsp-mode's `C-c l` (a minor-mode map) has no `j`, so the key falls
    through to these maps.
  - `u` is `hellmacs-jvm-update-project-configuration`. It works from any
    project file, because lsp-java's own command errors unless run from
    `pom.xml`/`build.gradle`.
- [x] doctor.el checks:
  - the JDK major version (21+ for JDTLS; parses both `1.8` and `25`)
  - JAVA_HOME
  - gradle and mvn
  - whether JDTLS and the JUnit runner are installed
- [x] **Verified against a real JDTLS** on both fixtures, with a probe
      driving a live session. Maven results; Gradle is the same for 1-8:
  1. The project imports: `[FORGE IGNITED]`, then `[DAEMON READY]`, and
     the mode-line shows `JVM:ready`. Import takes about 2.5s when known and
     about 33s the first time (dependency download).
  2. Completing `Lis` offers `java.util.List`, and accepting it **adds
     `import java.util.List;`**.
  3. `M-.` on `String` opens the decompiled `java.lang.String`.
  4. References to `greet` are found in both test classes, **but not in
     `App.java`**. Its call passes `person.getName()`, which comes from
     Lombok and doesn't resolve without the agent (6.3), so JDTLS drops
     the call as an inaccurate match. Rename still finds it. To recheck
     in 6.3.
  5. "Extract to method" is offered for a selected statement (10 code
     actions).
  6. Renaming `greet` → `welcome` updates Greeter, App and GreeterTest.
  7. Organize-on-save removes an unused import.
  8. A type error shows through flymake.
  9. A dependency added to `pom.xml` is on the classpath **within 10s of
     saving**. JDTLS's automatic update works through lsp-mode's file
     watches (14 folders). `C-c l j u` also works, and `StringUtils` then
     completes.
- [x] Unit tests (`test/test-java.el`, 3 tests, 23 in total): themed and
      plain messages, mode-line states (which found and fixed a
      trailing-slash key mismatch), and finding the build file from a
      source file.
- Note: the first time you open a file in a new project, lsp-mode asks
  whether to import its root. That's standard lsp-mode behavior, answered
  once per project and remembered in the state dir.

**6.3 `+lombok`** (done)
- [x] Lombok 1.18.48 is pinned in `+paths.el`, with its SHA-256
      (`85477a46…c508b`). Maven Central only publishes a SHA-1, so the
      SHA-256 comes from a download whose SHA-1 matched Central's. It also
      matches the copy Maven downloaded independently into `~/.m2`.
- [x] `cli.el` adds a sync step with `+lombok`. It downloads the jar to
      `data/jvm/lombok-<version>.jar` via a `.part` file, verifies the
      SHA-256 before moving it into place (so JDTLS never sees a bad jar),
      and re-downloads a corrupt one.
  - Setting `hellmacs-jvm-lombok-jar` in your init.el uses your own jar.
    Sync then only checks that it exists, and fails clearly if it doesn't.
- [x] `config.el` builds `lsp-java-vmargs` from `hellmacs-jvm--vmargs`,
      appending `-javaagent:<jar>` with `+lombok` once the jar exists.
      Startup only checks existence; sync and doctor check the checksum.
      doctor.el reports a missing or corrupt jar as an error.
- [x] **Verified against a live JDTLS on both fixtures:**
  - JDTLS starts with `-javaagent:lombok-1.18.48.jar`.
  - `App.java` has no diagnostics, and `person.getN` completes to
    `getName`.
  - **References to `greet` now find all 3 call sites, including
    `App.java`.** That closes the 6.2 gap.
  - Control run without `+lombok`: "getName() is undefined" and
    "constructor Person(String, int) is undefined", no completion, and 2
    references. So the gap was Lombok, as suspected.
- [x] Sync paths verified: fresh download, skip when installed, a
      corrupted jar flagged by doctor and repaired by sync, and a custom
      path that doesn't exist fails with exit 1.
- [x] Unit tests (25 in total): the javaagent is added only with the flag
      and an existing jar; a download is installed only on a matching
      SHA-256, leaves nothing behind on a mismatch, and isn't repeated.
  - Writing them found that the sync steps reloaded `+paths.el` (and so
    its `defconst`s) on every call. It's now loaded once, when `cli.el`
    loads.

**6.4 `:tools build`** (done): `modules/tools/build/` (config.el,
autoload.el; built-in packages only).
- [x] `compile` settings: `ansi-color-compilation-filter`,
      `compilation-scroll-output 'first-error`, `compilation-always-kill`,
      save without asking, and no eliding of long lines.
- [x] `hellmacs-forge-build-tool` detects the build: Gradle or Maven,
      wrapper first. A wrapper's directory is the root, so a module in a
      multi-module build still builds from the top.
  - Java buffers get `compile-command` from it (`:lang java` hooks
    `hellmacs-forge-setup-build-h` when `:tools build` is on), so the
    built-in `C-x p c` proposes `./gradlew build --console=plain` or
    `./mvnw -B verify`.
- [x] Tests: `hellmacs-forge-test-at-point` / `-class` run
      `--tests 'pkg.Class.method'` (Gradle) or
      `-Dtest='pkg.Class#method' -Dsurefire.failIfNoSpecifiedTests=false`
      (Maven), from the build root.
  - The test method is the nearest `void` method above point.
  - `C-c l j t` / `T` use them until `:tools debugger` exists (then
    dap-java).
- [x] **Error rules**, checked against real Gradle and Maven output first.
      Stock Emacs already handles javac (`gnu`) and Maven (`maven`) errors.
      It got these wrong, now fixed:
  - **Stack frames** (`at pkg.Class.m(File.java:16)`) name only a file
    name. A new `hellmacs-jvm-frame` rule resolves it inside the project
    through its package path.
    - Library and JDK frames aren't marked at all: a FILE function that
      returns nil makes compile.el skip the match. Before, stock `java`
      marked them as errors, so `M-g n` stopped in JUnit's
      `Assertions.java`.
    - Stock `java` is narrowed to its Valgrind form so it doesn't
      re-match them.
  - **Gradle test failures** (`...Error at BrokenTest.java:16`) are
    resolved by file name (`hellmacs-gradle-test`).
  - **Gradle's indented repeat of compile errors** used to resolve to a
    file name with leading spaces. It's now info
    (`hellmacs-gradle-summary`), which `M-g n` skips.
  - Resolved paths are cached per compilation buffer. The resolvers
    preserve the match data; my first version didn't, which made the
    parser crash.
  - Remaining: Maven prints compile errors twice (once in the error list,
    once in the goal failure), so `M-g n` visits each twice.
- [x] Results through `compilation-finish-functions` (only in
      `compilation-mode`, not grep), from the `hellmacs-forge-messages`
      table, themed or plain:
  - `[FORGE TEMPERED] Built in Ns`
  - `[BYTECODE PURGATORY] <first error file:line>`
  - `[TEST DAMNATION] F of N tests (<first failure>)`, from Gradle's "N
    tests completed, F failed" or Maven's final "Tests run" line

  A failed build sets the Java project's mode-line to `JVM:purgatory`,
  and the next good build sets it back to `JVM:ready`.
- [x] **Verified live on both fixtures:**
  - `compile-command` is set, and the ANSI filter is on.
  - A broken build shows `[BYTECODE PURGATORY] Greeter.java:12`,
    `JVM:purgatory`, and `M-g n` goes to Greeter.java line 12.
  - The fixed build shows `[FORGE TEMPERED]` (1.4s Gradle, 3.4s Maven)
    and `JVM:ready`.
  - The test at point runs just `GreeterTest.greetsByName` and passes.
  - Failing tests show `[TEST DAMNATION] 1 of 3 tests
    (BrokenTest.java:16)`, and `M-g n` lands on BrokenTest.java line 16.
- [x] Unit tests (`test/test-build.el`, 5 tests, 30 in total): tool and
      root detection (wrapper wins, Maven without a wrapper, none), the
      exact commands, class and test-method detection, error parsing (a
      library frame ignored, a project frame and a Gradle failure resolved,
      the summary repeat as info), and the result messages.

**6.5 `:tools debugger`** (done): `modules/tools/debugger/` (packages.el,
config.el, autoload.el), plus Java settings in `:lang java`.
- [x] dap-mode with dap-java (which ships in lsp-java), a state-dir
      breakpoints file, and `dap-auto-configure-mode` for the sessions,
      locals, breakpoints, expressions and REPL windows. Mouse controls and
      tooltips stay off.
- [x] Java settings (`:lang java`, when `:tools debugger` is on):
      `dap-java-java-command` from `hellmacs-jvm-java-home`,
      `dap-java-build 'always` (JDTLS already builds on save), and a
      "Java Attach (localhost:5005)" template next to dap-java's own.
- [x] **Keys, `C-c d`:** `d` start, `D` start last again, `b` toggle
      breakpoint, `B` condition, `L` log message, `x` delete all, `n` `i`
      `o` `c` step over, in, out and continue, `e` / `E` evaluate at point
      or an expression, `r` restart, `q` disconnect, `t` / `T` debug the
      test at point or class.
  - Deviation: after `C-c d n/i/o/c`, plain `n/i/o/c` keep stepping
    (`C-c d n n n`). It's a transient map, not the planned `repeat-map`,
    because `repeat-mode` is global: it would also change built-in keys such
    as `C-x o`, against the keybinding policy. Any other key ends it.
- [x] **Hot code replace on `C-c h r`** in a Java buffer during a session:
      `hellmacs-debug-hot-swap` saves the file and JDTLS recompiles it;
      dap-java then redefines the changed classes in the running JVM. With
      `dap-java-hot-reload` set to `never`, it asks for the redefinition
      itself.
- [x] **Found and fixed: JDK 22+ can't start a debuggee with the
      java-debug that lsp-java installs.** lsp-java's installer pins
      java-debug 0.46.0, which passes `-Xnoagent` ("Unrecognized option",
      "Could not create the Java Virtual Machine") on this JDK 25.
      `bin/hellmacs sync` now replaces the bundle with java-debug 0.53.1,
      pinned by SHA-256 and downloaded through a `.part` file. It runs after
      JDTLS's install every sync, so a later `lsp-install-server` that
      brings back the old one is undone. `doctor` reports the old bundle as
      an error. The download helper is shared with Lombok's.
- [x] **Verified live against java-debug** on both fixtures:
  1. A launch stops at the breakpoint (`App.java:8`) with the right locals
     (`args`, `greeter`, `person`).
  2. Evaluating `greeter.greet("Eval")` returns the value, and stepping with
     `C-c d n` reaches `App.java:9` where `greeting` reads correctly.
  3. A conditional breakpoint with a false condition (`name.equals("nobody")`)
     doesn't stop, and a true one (`name.startsWith("Doom")`) stops, without
     warnings.
  4. **`C-c h r` hot-swaps**: in a running session, editing `Hello` to `Hi`
     in `Greeter` changed `greeter.greet("X")` from "Hello, X…" to
     "Hi, X…".
  5. Debugging the test at point stops inside it
     (`GreeterTest.java:10`).
  6. Attaching to a JVM started with
     `-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005`
     stops at the breakpoint with locals, and `C-c d c` lets that JVM run
     to completion.
  - Gradle and Maven behave the same, except the hot-swap and condition
    checks, which ran on Maven only.
  - Three earlier "failures" in the probes were the probes' fault (a
    hot-swap edit that left the file uncompilable, a call made before the
    server attached to the test buffer, and a `dap-continue` call with too
    few arguments).
- [x] Unit tests (`test/test-debugger.el`, 5 tests, 35 in total): the key
      layout, transient stepping without global `repeat-mode`, hot swap
      with both `dap-java-hot-reload` settings, `C-c h r` routing, and the
      java-debug pin (a wrong checksum keeps the old bundle and leaves
      nothing behind).

**6.6 `:tools magit`** (done): `modules/tools/magit/` (packages.el,
config.el).
- [x] Magit with its own default global keys: `C-x g` status, `C-x M-g`
      dispatch, `C-c M-g` file dispatch. Magit binds them itself when its
      autoloads are read, so the module rebinds nothing, and Magit stays
      unloaded until first use.
  - `cond-let` and `llama` are declared up front (6.0's audit). Installed
    on their own the module syncs 7 packages in about 15s, with no hang.
  - Transient's history, levels and values files were already in the state
    dir (`core/hellmacs-core.el`), so there is nothing to add. Verified:
    they resolve under the state dir once transient loads.
  - Deviation: the plan's `magit-define-global-key-bindings 'default`
    setting is dropped. It is Magit's default, and a `:custom` in a
    deferred `use-package` only runs after Magit loads, which is too late
    to matter.
- [x] **Verified live** (Magit v4.7.1, temporary folders, real Emacs):
  1. The three keys are bound at startup and Magit is not loaded.
  2. `C-x g` on this repository opens `magit-status-mode` with the right
     Head and a "Recent commits" section.
  3. `magit-log-current` opens a log with this repository's commits.
  4. Blame on `init.el` runs and marks 54 chunks.
  5. On a scratch clone (so this history stays as it is): an untracked
     file shows under "Untracked files", stages, commits through
     `magit-run-git`, and leaves the tree clean.
  6. Startup: 0.057s with the module against 0.059s without, so no
     measurable cost.
  - Found while probing: a batch `emacs --init-directory` does not run
    `init.el` on Emacs 31.1, so live probes load `early-init.el` and
    `init.el` explicitly. Interactive sessions are unaffected.
- [x] Unit tests (`test/test-magit.el`, 3 tests, 38 in total): the declared
      packages, the three commands set up as autoloads, and transient's
      state files inside the state dir. Magit isn't installed in the test
      environment, so the key bindings themselves are covered by the live
      checks above.

**6.7 Integration** (done)
- [x] `static/init.example.el` lists all five modules, commented out, with
      a one-line description each (`:tools magit` was the missing one).
- [x] README: a "Java setup" section (the `hellmacs!` block, the
      requirements, first use, a key table and the status messages), the
      module list and layout, and `C-x g` in the key table. Requirements:
      a JDK 21+, network access on first use (about 110MB for JDTLS,
      java-debug and the JUnit runner, plus Lombok and each project's
      dependencies), Maven or Gradle when a project has no wrapper, and
      git 2.25+.
- [x] `bin/hellmacs doctor` now has a section for every new module.
      `:tools magit` checks the git version against Magit's minimum
      (2.25.0, from `magit--minimal-git`). `:tools build` reports whether
      Gradle or Maven is on the PATH, and `:tools debugger` whether a
      language module supplies an adapter. JDK, JDTLS, JUnit runner, Lombok
      and java-debug were already checked under `:lang java`.
- [x] **Fresh install verified**, twice, with the example file's Java lines
      uncommented (`build debugger lsp magit (java +lombok)`), in temporary
      folders:
  1. `bin/hellmacs install --env` synced 36 packages, then JDTLS, Lombok
     (SHA-256 verified) and java-debug 0.53.1 (SHA-256 verified), and ended
     with "No problems found". The second run took 29s, with Maven's
     download cache warm.
  2. `test/integration/java-e2e.el`, new, drives the real modules against
     the installed JDTLS, java-debug and Git, on a copy of each fixture.
     **24 checks pass on Maven and on Gradle:**
     - 6.2: JDTLS starts and reports `ready`, the mode-line segment reads
       `JVM:ready`, go-to-definition and completion work, and a type error
       shows up through flymake.
     - 6.3: JDTLS runs with the Lombok agent, `person.getName()` has no
       error in `App.java`, and its definition resolves.
     - 6.4: `compile-command` is the wrapper, a good build ends `JVM:ready`,
       a broken one ends `JVM:purgatory`, `M-g n` lands in `Greeter.java`, the
       fixed build recovers, and the test at point passes.
     - 6.5: a launch stops at the breakpoint, `greeter.greet("Eval")`
       evaluates, hot swap runs, and `C-c d c` lets the program finish.
     - 6.6: the three keys are bound with Magit unloaded, and status, log,
       blame, stage and commit (on a scratch clone) work.
- [x] **Found and fixed: a failed clone couldn't be retried.** The first
      install failed on `undo-fu-session`: its Codeberg clone (treeless,
      slow) was cut short and left a directory with only `.git`. Elpaca
      takes that for a finished clone, so "run the sync again" failed
      the same way. A failed sync now removes such an empty checkout
      (`hellmacs-sync--discard-empty-checkout`), and the retry works. I
      confirmed the retry by hand (deleting the broken source, then
      syncing); I couldn't make the network failure happen on demand, so
      the cleanup itself is covered by a unit test only.
- [x] Unit tests: one more (`test-core`, 39 in total), covering the cleanup
      (an empty checkout is removed; a real one, and a missing one, are
      left alone).
- Notes from writing the script: lsp-mode's "import this project root?"
  prompt is answered in the script with `lsp-workspace-folders-add`, and
  `format-mode-line` renders nothing in `--batch`, so the mode-line check
  evaluates the registered segment directly. The script is not part of
  `bin/hellmacs test`: it needs a real install and the network.

**6.8 Parity acceptance** (done, with one open item: see "Still open")
- [x] `test/integration/java-parity.el` (new, with `e2e-lib.el` shared with
      `java-e2e.el`) works through the checklist below on any project,
      copied to a temporary directory, and prints its timings.
- [x] **Projects.** Both fixtures, and `spring-petclinic` (Maven, 50 Java
      files, Spring Boot 4.1) as a stand-in for a real Java project.
      **`~/Projects/SpringBootApis/commons-web` is the only real project on
      this machine, and it is Kotlin** (19 `.kt` files, no Java), so it
      can't test JDTLS: I ran its build and Git items on a copy.
- [x] **Checklist**, all passing on petclinic and the fixtures unless noted:

| IntelliJ feature | Hellmacs | Result |
|---|---|---|
| Import and index a Maven/Gradle project | JDTLS, `[DAEMON READY]` | pass |
| Search everywhere (symbols) | `workspace/symbol` | pass |
| File structure | document symbols | pass |
| Quick documentation | hover | pass |
| Go to declaration, into library and JDK classes | `M-.`, decompiled source | pass |
| Find usages | references | pass |
| Type hierarchy | `C-c l j h` | pass |
| Completion, with auto-import | corfu + JDTLS (6.2) | pass |
| Rename across files | rename (planned, not applied) | pass, 4 files on the fixture |
| Extract method / variable | code actions | pass |
| Quick fix: import a missing class | code actions | pass |
| Optimize imports | `C-c l j o` / on save | pass |
| Generate getters, toString, equals, constructors | source actions | pass |
| Reformat | formatting | pass |
| Lombok | agent, generated members resolve | pass (6.3) |
| Build, clickable errors, test failures | `C-x p c`, `M-g n` | pass |
| Run a test at point | `C-c l j t` | pass |
| Debug: breakpoint, locals, evaluate, hot swap | `C-c d`, `C-c h r` | pass (fixtures) |
| Git: status, log, blame, commit | Magit | pass |

- [x] **Measurements** (JDK 25, warm Maven/Gradle caches, cold JDTLS workspace):

| Metric | Fixtures | petclinic (Maven) |
|---|---|---|
| Emacs startup, synced profile | about 0.05s | same |
| Until `[DAEMON READY]` | 3.0-4.8s | 2.9-4.2s |
| Then until workspace symbol search answers | 2.3-2.5s | 1.1-7.8s |
| JDTLS memory (RSS) | 0.5-1.2GB | 0.9-1.6GB |
| Build (`./mvnw -B verify`, 74 tests) | 1-3s | 13-15s |

  - Memory varies run to run with when the JVM collects, up to the 2GB heap
    cap. A cold first import that has to download dependencies takes
    longer (the first Gradle attempt took 47s).
  - Startup reads 0.87s if a module's `autoload.el` changed since the last
    sync (the stale-profile path); sync fixes it.
- [x] **Gaps found and fixed (they blocked real use):**
  1. **A project that fails to import looked fine.** petclinic has a Gradle
     build asking for a JDK 17 toolchain; only JDK 25 is installed here.
     JDTLS logged the failure, then sent `ServiceReady` anyway, so Hellmacs
     said `[DAEMON READY]` while search, outline and references all
     returned nothing. Now `[BYTECODE PURGATORY] <project> failed to
     import: the build needs a JDK 17 that Gradle can't find (install it,
     then C-c l j u)` is shown, the mode-line reads `JVM:purgatory`, and
     `ServiceReady` no longer overrides it. A later `ProjectStatus OK`
     (after fixing the cause and `C-c l j u`) recovers to `JVM:ready`.
     Verified live, including the recovery (by removing the Gradle files
     and re-importing through Maven). Unit test added.
  2. **Builds that fail without a file:line said only "exited abnormally
     with code 1".** Now Gradle's "What went wrong" or Maven's "Failed to
     execute goal" reason is shown, for example `[BYTECODE PURGATORY]
     Cannot find a Java installation on your machine ... languageVersion=21`.
     Verified live on commons-web. Unit test added.
  3. **Build detection trusted a leftover wrapper.** A `./gradlew` with no
     `build.gradle` beside it was taken for the build, so a Maven project
     was built with Gradle. A wrapper now counts only next to a build file
     of its tool. Found by the script; unit tests added (41 in total).
- [x] Not run on purpose: debugging on petclinic (starting Spring Boot needs
      a database), and applying refactors (the script only asks JDTLS for
      them; rename, extract and organize imports were applied and checked
      in 6.2).

**Still open**
- **A daily-driver trial on one of your own Java projects.** The script is
  ready: `HELLMACS_PARITY_PROJECT=<project> emacs --batch -l early-init.el
  -l init.el -l test/integration/java-parity.el`. Nothing above replaces
  actually working in it for a day.
- **commons-web can't build on this machine**: it needs JDK 21 and only 25
  and 27 are installed, so `./gradlew build` fails outside Emacs too.
  (2026-09-25: a JDK 21, Temurin, is installed now; the build hasn't been
  tried again.)
  Install JDK 21 to try it.

**Deferred to Phase 8** (none blocks daily Java work, in likely priority):
1. **Kotlin.** commons-web, the one real project here, is all Kotlin, so
   this moves up. JDTLS doesn't see `.kt` files.
2. A test-results view and run configurations for Spring Boot apps (today:
   `C-c d d` plus a template, and the compilation buffer for tests).
3. Everything already listed under "Not in this phase": lsp-ui peek and
   sideline, a project tree, Spring tooling, coverage, profiling, database
   tools.

#### Configuration specs

These are the intended blocks. Option and command names follow the current
lsp-mode, lsp-java and dap-mode releases. Each is checked against the
pinned versions in step 6.0, and a renamed option is corrected rather than
worked around.

`modules/tools/lsp/packages.el`
```elisp
;; Shared dependencies first, so Elpaca builds each exactly once.
(package! dash) (package! f) (package! ht) (package! s)
(package! lv) (package! spinner) (package! markdown-mode)
(package! lsp-mode :env (("LSP_USE_PLISTS" . "true")))
```

`modules/tools/lsp/config.el`
```elisp
(defvar hellmacs-lsp-read-process-output-max (* 1024 1024)
  "`read-process-output-max' while a language server runs (lsp-mode's advice).")

(use-package lsp-mode
  :defer-incrementally (lsp-mode lsp-completion lsp-diagnostics lsp-modeline)
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l")          ; must be set before lsp-mode loads
  :custom
  (lsp-completion-provider :none)           ; plain capf, rendered by corfu
  (lsp-diagnostics-provider :flymake)
  (lsp-log-io nil)
  (lsp-idle-delay 0.5)
  (lsp-keep-workspace-alive nil)
  (lsp-file-watch-threshold 5000)
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-modeline-workspace-status-enable nil) ; Hellmacs' own segment instead
  (lsp-enable-snippet nil)                   ; no yasnippet in the MVP
  (lsp-session-file (hellmacs-state-file "lsp-session"))
  (lsp-server-install-dir (expand-file-name "lsp/" hellmacs-data-dir))
  :hook
  (lsp-mode . lsp-enable-which-key-integration)
  (lsp-completion-mode . hellmacs-lsp--setup-completion-h)
  (lsp-mode . hellmacs-lsp--tune-process-output-h)
  :bind (:map lsp-mode-map
         ("C-c ! n" . flymake-goto-next-error)
         ("C-c ! p" . flymake-goto-prev-error)
         ("C-c ! l" . flymake-show-buffer-diagnostics)))

(defun hellmacs-lsp--setup-completion-h ()
  "Complete through lsp first, then files and words, all in corfu."
  (setq-local completion-at-point-functions
              (list (cape-capf-buster #'lsp-completion-at-point)
                    #'cape-file #'cape-dabbrev)))

(defun hellmacs-lsp--tune-process-output-h ()
  "Read language-server output in large chunks."
  (setq read-process-output-max hellmacs-lsp-read-process-output-max))

(setq gcmh-high-cons-threshold (* 128 1024 1024))
```

`modules/lang/java/packages.el`
```elisp
;; Shared by several of lsp-java's dependencies (6.0's dependency audit).
(package! posframe) (package! treemacs)
(package! dap-mode)
(package! lsp-java)          ; also provides dap-java
```

`modules/tools/magit/packages.el`
```elisp
(package! cond-let) (package! llama)   ; shared by magit, magit-section, with-editor
(package! magit)
```

`modules/lang/java/config.el`
```elisp
(defvar hellmacs-jvm-java-home (getenv "JAVA_HOME")
  "JDK that runs JDTLS itself (21+). Projects may target other JDKs:
see `lsp-java-configuration-runtimes'.")

(defvar hellmacs-jvm-lombok-jar (expand-file-name "jvm/lombok.jar" hellmacs-data-dir)
  "Lombok jar fetched by `bin/hellmacs sync' with the +lombok flag.")

(use-package lsp-java
  :after lsp-mode
  :hook ((java-mode . lsp-deferred)
         (java-mode . hellmacs-jvm-mode-line-mode))
  :custom
  (lsp-java-workspace-dir (expand-file-name "jvm/workspace/" hellmacs-data-dir))
  (lsp-java-workspace-cache-dir (expand-file-name "jvm/workspace/.cache/" hellmacs-data-dir))
  (lsp-java-java-path (if hellmacs-jvm-java-home
                          (expand-file-name "bin/java" hellmacs-jvm-java-home)
                        "java"))
  (lsp-java-vmargs '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4"
                     "-XX:AdaptiveSizePolicyWeight=90"
                     "-Dsun.zip.disableMemoryMapping=true"
                     "-Xmx2G" "-Xms256m"))
  (lsp-java-content-provider-preferred "fernflower")   ; decompile library classes
  (lsp-java-save-actions-organize-imports t)
  (lsp-java-maven-download-sources t)
  (lsp-java-references-code-lens-enabled t)
  (lsp-java-implementations-code-lens-enabled t)
  (lsp-java-completion-favorite-static-members
   ["org.junit.jupiter.api.Assertions.*" "org.assertj.core.api.Assertions.*"
    "org.mockito.Mockito.*" "org.mockito.ArgumentMatchers.*"])
  :config
  (when (modulep! +lombok)
    (if (file-exists-p hellmacs-jvm-lombok-jar)
        (add-to-list 'lsp-java-vmargs (concat "-javaagent:" hellmacs-jvm-lombok-jar) t)
      (display-warning 'hellmacs "+lombok: no Lombok jar yet; run `bin/hellmacs sync'")))
  (add-hook 'lsp-after-initialize-hook #'hellmacs-jvm--announce-ignition-h))

;; dap-java (shipped with lsp-java) must find its test runner in the data
;; dir, not the disposable cache; `lsp-install-server' puts it there.
(setq dap-java-test-runner
      (expand-file-name "lsp/eclipse.jdt.ls/test-runner/junit-platform-console-standalone.jar"
                        hellmacs-data-dir))

;; Build commands come from :tools build; only wire them up when it's on.
(when (modulep! :tools build)
  (add-hook 'java-mode-hook #'hellmacs-forge-setup-build-h))
```

`modules/tools/debugger/config.el`
```elisp
(use-package dap-mode
  :after lsp-mode
  :commands (dap-debug dap-breakpoint-toggle)
  :custom
  (dap-auto-configure-features '(sessions locals breakpoints expressions repl))
  (dap-breakpoints-file (hellmacs-state-file "dap-breakpoints"))
  :config
  (dap-auto-configure-mode 1)
  (require 'dap-java))

(defvar-keymap hellmacs-debug-repeat-map
  :repeat t
  "n" #'dap-next  "i" #'dap-step-in  "o" #'dap-step-out  "c" #'dap-continue)
```

`modules/tools/build/config.el`
```elisp
(use-package compile
  :ensure nil
  :hook (compilation-filter . ansi-color-compilation-filter)
  :custom
  (compilation-scroll-output 'first-error)
  (compilation-always-kill t)
  (compilation-ask-about-save nil)          ; save modified buffers, don't ask
  (compilation-max-output-line-length nil)
  :config
  (add-hook 'compilation-finish-functions #'hellmacs-forge--report-h))
```

#### Not in this phase

Each item below has an established package, but none is needed to replace
IntelliJ for daily Java work:

- lsp-ui (sideline and peek views)
- the treemacs project tree UI (treemacs is installed only as a
  dependency)
- Spring Boot tooling
- yasnippet argument placeholders
- test coverage
- profiling
- database tools
- Docker
- Kotlin and Clojure (Phase 8)

#### Risks

- **JDTLS needs a recent JDK** (21+) and 1-2GB of memory. doctor checks
  the JDK. `-Xmx` in `lsp-java-vmargs` is the knob to turn.
- **JDTLS, the java-debug bundle and Lombok download from the network on
  first use.** Pre-installing them from `bin/hellmacs sync` keeps those
  downloads out of editing sessions.
- **The dependency tree is deep.** lsp-java and dap-mode pull in lsp-mode,
  treemacs and about ten libraries. Declaring them up front (see change 6)
  and locking them with `bin/hellmacs lock` keep builds reproducible.
- **dap-java's test runner** comes with lsp-java's test bundle. If it's
  unavailable, tests run through the build tool (6.4).

### Phase 7: Visual identity and thematic UX (done)

> Phase 9 replaced this phase's theme (`hellmacs` became `hellmacs-inferno`,
> on a new palette) and added the dashboard and the modeline; the README's
> "Look & Feel" section describes what ships now. This section is history.

This phase came in as its own spec and is independent of Phase 6, so it
landed first. All of it respects the keybinding policy: Emacs keys, no
evil, nothing modal.

- [x] **`themes/hellmacs-theme.el`**: a zero-dependency `deftheme` in the
      Hellmacs palette.
  - Colors: Obsidian Void background, Charcoal Iron mode-line and current
    line, Brimstone Red cursor, warnings and current line number, Argent
    Amber keywords, functions and active mode-line text, Toxic Green
    strings and REPL results, Ash White text, and Grave Slate comments and
    inactive line numbers.
  - Covers the built-in faces, font-lock (including the Emacs 29+
    tree-sitter faces), completions, vertico, orderless, marginalia,
    consult, corfu, which-key, line numbers, both mode-lines, compilation,
    flymake/eglot, comint and CIDER, plus Hellmacs' own faces.
  - Background tints (selection, popup highlight, ...) are derived from the
    palette and used only as backgrounds.
  - `:ui theme` loads it through `hellmacs-theme` (default `hellmacs`; set
    another theme or nil in your init.el) and turns on `hl-line-mode` in
    prog and text buffers.
- [x] **`core/hellmacs-splash.el`**: the Altar.
  - A read-only `*hellmacs*` buffer (`hellmacs-splash-mode`, derived from
    `special-mode`) is shown through `initial-buffer-choice`, including in
    `emacsclient -c` frames.
  - Content: the horned cyber-cat sigil, the tagline, and
    `[ALTAR] Bound in X.XXX seconds with N garbage collections.`
  - Buttons for scratch, find file, recent files and project; TAB/RET move
    and follow, `g` redraws, `q` buries.
  - It re-centers on window resize, and redraws once the startup time is
    known.
  - When Emacs is started with a file or directory, that buffer is shown
    instead of splitting the frame.
  - `hellmacs-splash-enable` turns it off. The GNU splash was already off
    (early-init).
- [x] **`hellmacs-prefix-map` on `C-c h`**, with the spec's keys and
      which-key names:
  - `s` +altar/return (the splash)
  - `f` +forge/find-file (`project-find-file`; outside a project, pick one
    first)
  - `c` +altar/reap (`garbage-collect`, reporting the memory still in use)
  - `r` +crucible/reload (`cider-load-buffer` in a Clojure buffer,
    `cider-ns-refresh` elsewhere; a clear message when no REPL is
    connected)
- [x] **`core/hellmacs-ux.el`**:
  - `confirm-kill-emacs` asks "Extinguish the forge and return to the
    void?"
  - `command-error-function` reports unhandled errors as
    `[CRITICAL FATALITY]: <message>` in Brimstone Red. `user-error`s and
    `C-g` keep the plain reporting, because they aren't failures.
  - JVM exceptions, Clojure errors and Gradle/Maven build failures are
    colored red in compilation, comint and CIDER REPL buffers, and stack
    frames are dimmed.
  - Interactive only. `hellmacs-ux-enable` turns it off.

Where this departs from the spec, and why:
- **The bindings live in the `:config default` module**, not in
  `modules/hellmacs-bindings.el`. Flat module files were retired in
  Phase 2, and the keybinding policy gives each leader group exactly one
  owner, which for `C-c h` is `:config default`.
- **`C-c h r` and `C-c h s` used to mean "reload config" and "sync
  packages".** The spec's meanings win, and those two moved to `C-c h R`
  and `C-c h S`.
- **"1 garbage collection" is singular.** The rest of the altar line
  follows the spec exactly.
- **Grave Slate is 2.9:1 against the background**, below WCAG AA (4.5:1).
  It's kept as specified, for recessive comments and line numbers. Every
  other text color is 5.2:1 or better (Ash 13.6, Green 14.6, Amber 8.3,
  Red 5.2).

### Phase 8: More JVM languages (in progress)

This is the old Phase 6's Clojure and Kotlin work, moved after Java parity.
It reuses `:tools lsp`, `:tools debugger` and `:tools build`, and follows the
Phase 6 pattern: `bin/hellmacs sync` installs each language server into the
data directory, `doctor` reports what's missing, and every step ends with a
live check, with tests in the repository.

**Findings that shaped the plan** (checked before writing code):
- Both language servers install through lsp-mode's own `lsp-install-server`
  (kotlin-language-server as a zip, clojure-lsp as a native binary), the same
  way JDTLS does.
- This machine has Kotlin 2.4 and JDK 21 and 25, but no Clojure CLI, `lein`
  or `clojure-lsp`. Clojure checks therefore use a Clojure CLI installed into a
  scratch directory, not on the system.
- `~/Projects/SpringBootApis/commons-web` (Kotlin, Spring, Gradle) is the real
  project for the Kotlin acceptance run.
- Emacs 31 loads tree-sitter grammars of ABI 14 and 15; the three grammars
  below are ABI 14.

**8.1 Tree-sitter grammars** (done): `core/hellmacs-treesit.el`
- [x] `hellmacs-treesit-need` (a module's cli.el, when its `+tree-sitter`
      flag is on) declares a grammar, `bin/hellmacs sync` builds it into
      `$XDG_DATA_HOME/hellmacs/treesit/`, and `treesit-extra-load-path` points
      Emacs there at startup. Building needs git and a C compiler; `doctor`
      checks both and the grammar (`hellmacs-doctor-treesit`).
- [x] **Pinned by commit**, which is stronger than Emacs's own installer (it
      follows a tag that can move): each grammar is fetched by its commit
      hash (the tag or branch is only a label) and refused if HEAD differs.
      It is built in a temporary directory and moved into place only when
      complete, with the commit it came from recorded beside it: a library
      from an older pin, or from another installer, is rebuilt on the next
      sync (`doctor` says so). Pins: Java `v0.23.5` (`94703d5`), Kotlin
      main of 2026-08-02 (`1852ea1`, see 8.2), and for Clojure
      `unstable-20250526` (`69070d2`), `markdown-inline` v0.5.2 (`aca7767`,
      a subdirectory of its repository) and `regex` v0.24.3 (`4470c59`), see 8.3.
- [x] `:lang java` uses it: `+tree-sitter` builds the Java grammar on sync and
      remaps to `java-ts-mode` only if the grammar exists (otherwise a
      warning says to sync).
- [x] **Verified with the real grammars:** Java, Kotlin and Clojure build in
      1.4s, 3.0s and 1.3s, load (ABI 14), and parse a sample into
      `program`, `source_file` and `source`. A wrong pin was refused and left
      no files behind. (The first Clojure and Kotlin pins were replaced in
      8.2 and 8.3: the modes' highlighting follows newer grammars.)
- [x] Unit tests (`test/test-treesit.el`, 3 tests, 44 in total) build a fake
      grammar from a local git repository: the pinned commit builds and
      leaves only the library, a moved tag installs nothing, and every
      shipped grammar has a tag and a 40-character commit.

**8.2 `:lang kotlin`** (done): `modules/lang/kotlin/` (packages.el, +paths.el,
config.el, cli.el, doctor.el), plus Kotlin support in `:tools build`.
- [x] kotlin-language-server through lsp-mode, `kotlin-mode` (and
      `kotlin-ts-mode` with `+tree-sitter`), started by `lsp-deferred`.
  - **The server is pinned.** `bin/hellmacs sync` downloads release 1.3.13
    (87MB), checks its SHA-256 (`4fe7d71d...`), and unpacks it into
    `$XDG_DATA_HOME/hellmacs/lsp/kotlin/`, where lsp-mode already looks. A
    server that lsp-mode installed from "latest" is replaced. `doctor` says
    which it finds. The verified-download helper moved from `:lang java` into
    core (`hellmacs-sync-download-verified`); Java uses it too.
  - **The server's heap is capped at 2GB** (`hellmacs-kotlin-vmargs`, through
    `KOTLIN_LANGUAGE_SERVER_OPTS`, unless you set it). Uncapped, it took a
    quarter of RAM.
- [x] **Status messages**, in the Java wording. kotlin-language-server sends
      no "ready" notification, so its log is the signal: `[FORGE IGNITED]` on
      start, `[DAEMON READY] <project> indexed in Ns` on "Updated full symbol
      index", and `[BYTECODE PURGATORY] <project> failed to import: <first
      error>` when its Gradle task fails (found by breaking a `build.gradle.kts`).
      No mode-line segment yet: Phase 9 redoes the mode-line.
- [x] **`C-c l k`** in Kotlin buffers (with `:tools build`): `b` build, `t` run
      the test at point, `T` the class.
- [x] **`:tools build` understands Kotlin.**
  - `e: file:///...Foo.kt:6:22 message` (and `w:`) are clickable, with the
    percent-encoded path decoded. Emacs has no rule for it; the stock `gnu`
    rule also matches these lines but can't decode the path.
  - The test at point finds the class (the first `class` in the file, with
    or without a `;` after `package`) and the nearest `fun`, including
    backticked names with spaces.
- [x] **Found and fixed: `kotlin-ts-mode` and the pinned grammar disagreed.**
      With the last tag (0.3.8, 2024), Emacs warned that the mode's font-lock
      rules don't match and switched off string and constant highlighting.
      The mode follows the grammar's main branch, so the Kotlin grammar is now
      pinned to a main commit (`1852ea1`, 2026-08-02). The tree-sitter
      helper therefore fetches by commit, with the tag only as a label.
      Checked: no warning, and strings, keywords and types are highlighted.
- [x] `test/fixtures/kotlin/gradle-demo` (Kotlin 2.1.10, Gradle 9.7.1
      wrapper): `App`, `Greeter`, a data class `Person`, a passing
      `GreeterTest` with a backticked test, and a `BrokenTest` that fails only
      with `-Dhellmacs.fail=true`. Verified: it builds and runs, and the flag
      fails exactly `BrokenTest`.
- [x] **Verified live** (`test/integration/kotlin-e2e.el`, new): **18 of 18
      checks pass** from a fresh install: the file opens in `kotlin-ts-mode`,
      the pinned server starts and reports ready, definition (a function and
      a data-class property), completion, hover, references across files,
      rename planned across files, a type error through flymake, the
      wrapper as `compile-command`, a good build, a broken build
      (`[BYTECODE PURGATORY] Greeter.kt:6`), `M-g n` landing on it, the test
      at point by a plain and a backticked name, and a failing test
      (`[TEST DAMNATION] 1 of 3 tests (BrokenTest.kt:15)` and `M-g n`).
- [x] **Real project:** `test/integration/kotlin-parity.el` on
      commons-web (Kotlin 2.1, Spring, JPA, Gradle; JDK 21): all checks
      pass, and are recorded in 8.7.
- [x] Unit tests (`test/test-kotlin.el`, 4 tests; `test-build`, `test-treesit`
      updated; 49 in total): the keys and server path, the status flow (the
      per-file index isn't ready; a failure is announced once), the plain
      wording, and the server pin (an unmarked, wrongly marked or
      non-executable server isn't "installed").

**8.3 `:lang clojure`** (done): `modules/lang/clojure/` (packages.el,
+paths.el, config.el, cli.el, doctor.el), plus `core/hellmacs-lsp-status.el`.
- [x] `clojure-mode` (`clojure-ts-mode` with `+tree-sitter`), **CIDER with its
      own standard keys** (nothing rebound; `C-c M-j` jack in, `C-c C-k` load,
      `C-c C-t t` test, ...), loaded incrementally after startup, its
      history in the state dir. `C-c h r` (Phase 7) reloads a changed buffer
      into the connected REPL.
- [x] clojure-lsp through lsp-mode. The native binary is downloaded by
      `bin/hellmacs sync` for the platform (release 2026.07.06), checked by
      SHA-256, and installed into `$XDG_DATA_HOME/hellmacs/lsp/clojure/`. A
      `clojure-lsp` on your PATH wins, as in lsp-mode. Pins for Linux x86-64
      and arm64 and macOS x86-64 are the sums the release publishes (Linux
      x86-64 also checked against a download, and the binary run); macOS arm64
      has none published, so its sum is from one download. **Only Linux
      x86-64 has been run.**
  - Indentation and on-type formatting are left to Clojure mode, and
    completion to CIDER when connected (both capfs join
    `completion-at-point-functions`).
- [x] **Status messages**, from a new shared `hellmacs-lsp-status` library
      (Kotlin uses it too): `[FORGE IGNITED]` on start, `[DAEMON READY]` on
      the first `$/progress` end (about 1.4s on the fixture), and
      `[BYTECODE PURGATORY] ... failed to import: Error building classpath...`
      when clojure-lsp can't build the classpath (found with a
      `deps.edn` naming a missing artifact).
- [x] **Found and fixed: `clojure-ts-mode` installs grammars itself.**
      Version 0.6 needs Emacs 30.1+, a newer Clojure grammar
      (`unstable-20250526`, not the last release) and two more
      (`markdown-inline` for docstrings, `regex`), and it built them, unpinned,
      into the cache directory at first use, while warning that `doc` and
      `string` highlighting were off. Hellmacs now builds all three on sync,
      sets `clojure-ts-ensure-grammars` to nil, and remaps to the tree-sitter
      mode only when all three are current. `doctor` checks them and the
      Emacs version. Checked: no warning, no cache install, and strings,
      docstrings and keywords are highlighted.
- [x] `test/fixtures/clojure/deps-demo` (`deps.edn`, no external
      dependencies): `demo.core`, a passing test namespace, and a
      `BrokenTest` that runs only with `-Dhellmacs.fail=true`.
- [x] **Verified live** (`test/integration/clojure-e2e.el`, new): **18 of 18
      checks pass** from a fresh install, with the Clojure CLI installed into
      a scratch directory (it isn't on this machine): the file opens in
      `clojure-ts-mode`; clojure-lsp starts and reports ready; definition,
      hover (the docstring), completion, references across namespaces,
      rename planned across files, workspace symbols, and a diagnostic
      for an unresolved symbol (clojure-lsp lints on save, not on change);
      then a CIDER REPL: jack-in connects, evaluation returns values,
      loading the buffer makes its functions callable, `C-c h r` reloads a
      changed buffer, the cider-nrepl middleware is present, the test
      namespace passes, and a failing test is reported.
- [x] Unit tests (`test/test-clojure.el`, 4 tests, 54 in total): the hooks,
      the status flow (a progress report isn't the end, only the first end is
      announced, a classpath failure says why), and the per-platform pin.

**Groovy and Scala: findings** (checked on 2026-09-23, before writing code):
- **groovy-language-server has no releases or tags.** The only way to get it
  is to build it. Its last commit (`347d098`, 2026-05-19) builds with its
  own Gradle wrapper on JDK 21 in about 6s, into a 12.8MB shadow jar.
  Shadow jars aren't byte-reproducible (they have timestamps), so the build is
  pinned by commit, like the grammars, and not by SHA-256. lsp-mode's
  `lsp-groovy` client runs `java -jar` on `lsp-groovy-server-file` and
  never installs it. Its `lsp-groovy-classpath` default is a Homebrew path.
- **`groovy-mode` already maps `.groovy`, `.gradle`, `.gant` and
  `Jenkinsfile`**, and `kotlin-mode` maps `*.kts`, so `*.gradle.kts` already
  opens in Kotlin. Groovy needs no `auto-mode-alist` entries of its own.
  There is no maintained Groovy tree-sitter mode for Emacs, so there is no
  `+tree-sitter` flag.
- **Metals 1.6.9** (2026-09-14) is the last stable release (2.0 is at
  milestone 19). lsp-metals installs it with coursier, from "latest.release",
  as a launcher that fetches jars into `~/.cache/coursier` at first start.
  `cs bootstrap --standalone` builds a self-contained launcher instead
  (131MB), and **that is byte-reproducible**: two builds had the same SHA-256
  (`0ebf461d...`). So Metals is pinned by SHA-256 like the other servers.
  Coursier 2.1.25 publishes a SHA-256 for every launcher it releases.
- **tree-sitter-scala v0.26.2** (`b931fcc`) is ABI 15, which Emacs 31 loads.
  `scala-ts-mode` pins no grammar. **Its autoloads map `.scala`, `.sc` and
  `.sbt` to `scala-ts-mode` unconditionally**, even when no grammar is built,
  so the module has to undo that and remap only when the grammar is current,
  as Java, Kotlin and Clojure do.
- No `scala`, `sbt`, `metals` or `groovy` on this machine. The checks
  install sbt into a scratch directory with coursier, as 8.3 did for the
  Clojure CLI.

**8.4 `:lang groovy`** (planned): `modules/lang/groovy/` (packages.el,
+paths.el, config.el, cli.el, doctor.el).
- [ ] `groovy-mode` for Groovy sources, Gradle scripts and Jenkinsfiles
      (its own mappings; a unit test checks that `build.gradle` opens in
      Groovy and `build.gradle.kts` in Kotlin with both modules on).
- [ ] groovy-language-server through lsp-mode. `bin/hellmacs sync` clones
      the pinned commit, builds it with its wrapper, and installs the jar
      into `$XDG_DATA_HOME/hellmacs/lsp/groovy/` with the commit recorded
      beside it. A jar from another commit is rebuilt. `doctor` checks git,
      the JDK and the jar. The classpath is `$GROOVY_HOME/lib` when set,
      otherwise empty (the server bundles Groovy 4).
- [ ] Status messages through `hellmacs-lsp-status`, from whatever the
      server actually sends (to be found live).
- [ ] `C-c l g` in Groovy buffers (with `:tools build`): `b` build, `t` test
      at point, `T` the class, with Groovy's `def "a name with spaces"()`
      test methods understood by `:tools build`.
- [ ] `test/fixtures/groovy/gradle-demo`: Groovy sources, a passing JUnit 5
      test and a `BrokenTest` behind `-Dhellmacs.fail=true`.
- [ ] Verified live (`test/integration/groovy-e2e.el`) and unit tests.

**8.5 `:lang scala`** (planned): `modules/lang/scala/`.
- [ ] `scala-mode` and `sbt-mode` (`scala-ts-mode` with `+tree-sitter`,
      grammar pinned; the autoload takeover undone, with a unit test).
- [ ] Metals 1.6.9 through `lsp-metals`. `bin/hellmacs sync` downloads the
      pinned coursier (SHA-256), builds the standalone Metals launcher with
      its downloads cached under the Hellmacs cache directory, and keeps it
      only if its SHA-256 matches. The heap is capped as for the other
      servers.
- [ ] Status messages from Metals' own `metals/status` and progress
      notifications (import started, imported, failed).
- [ ] `C-c l s` in Scala buffers: `b` compile, `t` the test at point, `T`
      the suite, through sbt (`sbt-mode`), or `:tools build` for Gradle and
      Maven projects.
- [ ] `test/fixtures/scala/sbt-demo` (Scala 3, munit), an end-to-end
      script and unit tests.

**8.6 Integration** (in progress: Java, Kotlin and Clojure verified;
Groovy and Scala pending): starter `init.el`, README, doctor, fixtures, an
end-to-end script for each language, and a fresh install in temporary
folders. `static/module-template/` gets a `:lang` example (a language
server, a mode, keys under `C-c l`) for the languages Hellmacs doesn't
ship.
- [x] README has a "Kotlin and Clojure" section (keys, requirements, what to
      expect from each server, the tree-sitter flag), and the module list,
      layout and stack are updated. Groovy and Scala are to be added.
- [x] `doctor` has a section for both modules, and for each grammar under
      `+tree-sitter`.
- [x] **Fresh install verified** with Java, Kotlin and Clojure on (`+tree-sitter`
      on each), in temporary folders: `bin/hellmacs install --env` synced **45
      packages** with no hang, built 5 grammars, installed clojure-lsp,
      kotlin-language-server, Lombok, JDTLS and java-debug (each SHA-256
      verified), in **38s**, and ended with "No problems found".
- [x] **All the end-to-end scripts pass on that one install:** Java on Maven
      and on Gradle (24 of 24 each, in `java-ts-mode`), Kotlin (18 of 18) and
      Clojure (18 of 18). Kotlin and Clojure also pass in the classic modes
      (`kotlin-mode`, `clojure-mode`), so `+tree-sitter` is a choice, not a
      requirement.
  - Found by the run: the Java script's Magit check looked for "Recent
    commits", which Magit replaces with "Unpushed to origin/main" when the
    branch is ahead of its upstream. It accepts either now.
- [x] **Startup with those modules on** (synced profile): about **0.073s**
      (0.073 to 0.080 over five runs, 0.126s cold), against about 0.057s with
      the Java modules and Magit alone.
- [ ] Groovy and Scala: their modules, fixtures and end-to-end scripts (8.4
      and 8.5), then the same fresh-install run with them on.

**8.7 Acceptance** (in progress: Kotlin done; Groovy and Scala pending)
- [x] `test/integration/kotlin-parity.el` (new) is the Java checklist for
      Kotlin, run on commons-web (Kotlin 2.1, Spring Boot, JPA, Gradle 9,
      JDK 21) twice on the combined install: **16 of 16 checks pass** both
      times, including Git (Magit status, log and blame).

| Metric | commons-web (Kotlin) |
|---|---|
| Emacs startup | 0.04-0.06s |
| Until `[DAEMON READY]` | 13.6s and 16.5s (Gradle dependency resolution, then the full symbol index of about 19,000 symbols) |
| Server memory | about 2.3GB for the server itself, 2.6GB with its Gradle helper (heap capped at 2GB) |
| Build (`./gradlew build`, tests included) | 5.6-8.8s, warm |

- [x] **Checklist for Kotlin**, against what IntelliJ does:

| IntelliJ feature | Result |
|---|---|
| Import and index a Gradle project | pass (14-17s) |
| Search everywhere, file structure, quick documentation | pass |
| Go to declaration, into Spring and JDK sources | pass (`kls:` URIs) |
| Find usages | pass |
| Rename across files | pass (planned, not applied) |
| Completion | pass |
| Compiler diagnostics | pass (unresolved reference, unused variable) |
| Quick fix: import a missing class | **pass** (`Import java.time.LocalDate`) |
| Reformat | pass (one whole-file edit) |
| Inlay hints, semantic highlighting | offered by the server |
| Build, clickable errors, test at point (backticked names) | pass |
| Git | pass |
| Optimize imports | **not offered** (an unused import isn't even reported) |
| Extract function or variable, inline, change signature | **not offered** (the only code action on a statement or a class is "Convert Java to Kotlin") |
| Generate members | not offered (only "implement members", `lsp-kotlin-implement-member`) |
| Debugging Kotlin | not covered (`:tools debugger` is Java's java-debug) |

- [x] **Verdict on kotlin-language-server.** Good enough to read, navigate and
      edit Kotlin in a real Spring project all day: usable start-up (about
      15s to full readiness), accurate diagnostics, cross-file rename and the
      import quick fix. **Clearly behind JDTLS and IntelliJ on refactoring**
      (no organize imports, no extract), about 2GB of heap, and its last
      release is from January 2025, so it won't improve soon. It is still
      the only Kotlin server lsp-mode has; JetBrains' own Kotlin LSP is the
      one to watch, and would slot into `:lang kotlin` without changing the
      rest.
- [ ] Groovy and Scala acceptance runs.
- Not done, on purpose: Kotlin debugging; Windows (no pinned binaries or
  checks); running Clojure on macOS or arm64 (the pins exist, unrun).

**Deferred** (only if asked for): lsp-ui. Spring Boot tooling and coverage
are now planned in Phase 12 (12.4, 12.5).

### Phase 9: Infernal dashboard and modeline (in progress)

**Goal:** the visual identity from Phase 7, rebuilt on a new palette and a
real dashboard: the `hellmacs-inferno` theme, a `dashboard` startup screen
with the sigil, and a minimal `doom-modeline`. Everything falls back cleanly
in a terminal (`emacs -nw`). It can ship independently of Phase 8.

**Why this is a phase and not a patch.** Most of the requested groundwork
already exists (see "What is already there"), so the work is the theme
rewrite, two new modules and three new packages. It changes every colour in
the distribution, so it is verified as carefully as Phase 6 was.

**The spec, as given** (the prompt's requirements, kept as written):

- *Keys:* strictly vanilla. Nothing modal, and every Hellmacs binding stays
  under `C-c h` (already true; the dashboard adds none of its own).
- *Layout:* `early-init.el`, `init.el`, `core/`, `themes/`, `modules/ui/`,
  `assets/`.
- *Assets:* GUI (`display-graphic-p`) uses `assets/banner.png` with
  `assets/banner.svg` as its fallback, at most 480x320. A terminal reads
  `assets/banner-ascii.txt`, with no display errors.
- *Tokens:*

| Token | Colour | Role |
|---|---|---|
| `bg-main` | `#16171d` | Deep charcoal altar (background) |
| `bg-alt` | `#1c1e24` | Modeline and popups |
| `fg-main` | `#bbc2cf` | Bone white text |
| `inferno-crimson` | `#ff6c6b` | Primary flame: headers, errors |
| `ember-amber` | `#da8548` | Secondary fire: warnings, subheadings |
| `reap-gold` | `#ecbe7b` | Sigil accents, operators, shortcuts |
| `forge-gray` | `#5b6268` | Borders, comments, line numbers |

- *Dashboard:* `dashboard` with `nerd-icons`. Title `HELLMACS: THE INFERNAL
  JVM HACKING ENVIRONMENT`. Footer rotating between `BYTECODE SUBJUGATED //
  REPL FIRED`, `MAMMON FORGE: HEAP CONSUMED, CODES SMELTED` and `THE JVM
  ALTAR STANDS READY`. Items: Recents 5, Projects 5, Bookmarks 3. Startup
  line `[ALTAR] Bound in X.XX seconds with Y garbage collections.` Vanilla
  navigation keys.
- *Modeline:* minimal, fast `doom-modeline`, coloured from the palette,
  with a terminal fallback.
- *Files:* `themes/hellmacs-inferno-theme.el`,
  `modules/ui/hellmacs-dashboard.el`, `modules/ui/hellmacs-modeline.el`, and
  the orchestration in `init.el` (core GC, then theme, then UI modules, then
  the post-init GC normalisation).

**What is already there** (audit the code against the spec; change only
what differs):

| Spec item | Today |
|---|---|
| High GC threshold during init | `early-init.el` sets `gc-cons-threshold` to `most-positive-fixnum` (above the 100MB asked for) and `gc-cons-percentage` to 1.0 |
| Normalise after init | `hellmacs--restore-gc-h` sets 16MB, then `gcmh` takes over at the first buffer |
| No flash: menu, tool and scroll bars | `early-init.el` sets them in `default-frame-alist` and turns the modes off |
| `package-enable-at-startup nil` | set in `early-init.el` |
| Orchestration order | `init.el`: core, packages, keybinds, modules, splash, user config; the theme loads from `:ui theme` |
| Startup screen | the Altar (`core/hellmacs-splash.el`), with no extra packages |
| Palette | `themes/hellmacs-theme.el`: 217 faces on `#0a0a0c` / `#ff1a40` / `#ff8800` / `#00ff66` |
| Assets | `assets/` exists in the repo root: `banner.png` (2816x1536, RGBA, 3.4MB), `banner.svg`, `banner-ascii.txt` |

**Deviations from the prompt, and why** (say so if you'd rather not):

1. **Asset paths.** The prompt reads `~/.emacs.d/assets/`. Hellmacs is
   started with `--init-directory` and lives wherever it was cloned, so the
   modules resolve `assets/` from `hellmacs-dir`. The layout is otherwise as
   written.
2. **Files are added to what exists, not written from scratch.** `early-init.el`
   and `init.el` are audited and patched. `themes/hellmacs-theme.el`
   is superseded by the new theme (below).
3. **File names and the module system.** The two UI files keep the names the
   prompt gives, at `modules/ui/hellmacs-dashboard.el` and
   `modules/ui/hellmacs-modeline.el`. Hellmacs modules are directories, so
   `:ui dashboard` and `:ui modeline` are thin modules
   (`modules/ui/dashboard/{packages,config,doctor}.el`, likewise `modeline/`)
   that add `modules/ui/` to `load-path` and `require` those files. Modules
   are looked up by name (`modules/<group>/<name>/`) from the `hellmacs!`
   block and never scanned, so loose `.el` files beside the module
   directories are harmless (checked in `core/hellmacs-modules.el`).
4. **One colour the tokens don't have: success green.** `#98be65`
   (`venom-green`, 8.4:1 on `bg-main`). Success states need something other
   than the flame colours: `JVM:ready`, `[FORGE TEMPERED]`, added diff
   lines, "finished" builds. Without it those would read as warnings.
5. **`forge-gray` fails contrast for reading.** `#5b6268` is 2.9:1 on
   `bg-main` (2.7:1 on `bg-alt`); Phase 7 held every text pair to 4.5:1.
   It is used as specified for borders, fringes and inactive line numbers.
   Comments, doc strings and dimmed text use a lighter `forge-gray-hi`,
   `#868f96` (5.4:1 on `bg-main`, 5.1:1 on `bg-alt`).
6. **Derived shades.** Region, current line, diff tints and hover need
   surfaces the seven tokens don't cover. They are computed from the tokens
   in one table at the top of the theme (e.g. `bg-hl` `#23262e`), each pair
   checked for contrast, and listed in the roadmap when built.
7. **Nerd Font is not installed automatically.** `nerd-icons-install-fonts`
   writes into the user's font directory, which breaks the rule that
   Hellmacs writes only to its own XDG directories. `bin/hellmacs doctor`
   reports a missing font and prints the command, and the modules fall back
   to text and ASCII without it.
8. **Terminal icons are off unless asked for.** A terminal can't tell us it
   has a Nerd Font, so `emacs -nw` gets ASCII by default
   (`hellmacs-dashboard-tty-icons` opts in).
9. **On by default, with the Altar as the fallback.** `:ui dashboard` and
   `:ui modeline` are enabled in `static/init.example.el`. With `:ui
   dashboard` on, the dashboard is the startup screen and `C-c h s` opens
   it. With it off, the Altar keeps working as today, with retinted colours.

**Steps.** Each ends with its verification, and tests go in the repository.

**9.0 Audit and foundations** (done)
- [x] **The "already there" table matches the code; nothing to fix.** Checked
      live on a synced profile, in a GUI frame and in `emacs -nw`, once
      startup had finished:
  - The first frame has `menu-bar-lines` 0, `tool-bar-lines` 0 and no
    scroll bars, and `menu-bar-mode`, `tool-bar-mode`, `scroll-bar-mode` and
    `tooltip-mode` are nil. **These apply before the first paint:** Emacs
    31's `startup.el` loads `early-init.el` (line 1533) before it calls
    `frame-initialize` (line 1610), so the first frame is created from
    `default-frame-alist` already trimmed.
  - `gc-cons-threshold` is back to 16MB and `gc-cons-percentage` to 0.1
    after startup. `gcmh-mode` is still off then, as intended: it starts
    at the first real buffer, and the startup screen doesn't count.
  - `package-enable-at-startup` is nil; `file-name-handler-alist` is
    restored (5 handlers).
  - The theme is `(hellmacs)`, loaded by `:ui theme`; the startup buffer
    is `*hellmacs*` through `hellmacs-splash--initial-buffer`.
  - The current theme sets exactly 217 faces (counted from its
    `theme-settings`). `banner.png` is 2816x1536 RGBA (3.4MB); `banner.svg`
    is 540x270; `banner-ascii.txt` is 17 lines.
- [x] **Shared dependencies declared up front**, from the packages' own
      `Package-Requires` (what Elpaca resolves), read after installing
      `dashboard` and `doom-modeline` into a scratch profile:
  - `dashboard` 1.9.0-snapshot (`a2c49ba`) needs only Emacs 27.1; icons
    are optional.
  - `doom-modeline` 4.3.0 (`27ba834`) needs compat, nerd-icons and
    shrink-path.
  - `shrink-path` 0.3.1 needs s, dash and f, and f needs s and dash.
  - So: `compat` is already in `core/packages.el`; `nerd-icons` is declared
    by both modules (it is shared); `:ui modeline` also declares s, dash, f
    and shrink-path (dash and s are reached through both shrink-path and
    f, and all three are shared with lsp-mode). The two modules'
    `packages.el` files exist now; their `config.el` come in 9.2 and 9.3.
  - **A fresh install with both modules on**, in temporary folders
    (`bin/hellmacs install --env`, every default module too): **47
    packages** (43 before, plus dashboard, doom-modeline, nerd-icons and
    shrink-path) in **30s**, no hang, "No problems found".
- [x] **Baseline**, on that synced profile, from the new
      `test/integration/startup-bench.el` (it waits for the first frame to
      be drawn, then records the init time, GCs, resident memory and any
      *Warnings*). Ten runs of each:

| | Startup (median, range) | GCs | Memory (RSS) | Warnings |
|---|---|---|---|---|
| `emacs -nw` | **0.040s** (0.040-0.045) | 1 | 71MB | none |
| GUI (GTK3 on XWayland) | 0.247s (0.208-0.317) | 1 | 96MB | none |
| GUI, `emacs -Q` | 0.210s (0.163-0.253) | | | |

- **Found: the GUI number is mostly Emacs creating its frame.** `emacs -Q`
  alone takes about 0.21s to open a GTK frame on this machine, and
  `before-init-time` is set before that happens, so a GUI start can never
  come in under 0.12s, with or without Hellmacs. Hellmacs' own share in a
  GUI is the difference, about **0.04s**, the same as in a terminal. The
  budget below is therefore checked on the terminal time and on the GUI
  time *minus* `emacs -Q`'s, measured in the same session (medians of ten
  runs each).
- *Verified:* the audit table has no open differences; the synced profile
  with the new packages installed starts in both frame types without a
  warning (ten runs each, `warnings=0`).

**9.1 `hellmacs-inferno` theme** (done) (`themes/hellmacs-inferno-theme.el`)
- [x] A `deftheme` built from one token table, `hellmacs-inferno-palette`
      (the seven tokens, `venom-green`, `forge-gray-hi` and eight derived
      shades), bound by name around the face specs, so a colour is defined
      once. The derived shades, all backgrounds:

| Shade | Colour | Used for |
|---|---|---|
| `bg-hl` | `#23262e` | `highlight`, the vertico candidate, hover |
| `bg-deep` | `#111217` | inactive mode-line |
| `bg-soot` | `#2c2f38` | matching paren, secondary selection, lsp symbol highlights |
| `bg-ember` | `#42252b` | region, breakpoints, removed lines (highlighted) |
| `bg-smolder` | `#2f1f24` | corfu candidate, debugger line, removed lines |
| `bg-rust` | `#3a2a1a` | lazy search matches |
| `bg-moss` / `bg-moss-hl` | `#1e2a1c` / `#2a3b25` | added lines, plain and highlighted |

- [x] **All 217 faces ported** (checked against the old theme before it
      was deleted: none missing), plus 8 `dashboard-*` faces and 19
      `doom-modeline-*` ones, **244 in all**. doom-modeline defines 66
      faces, but they inherit from a core set, so the theme sets that core
      (the base face, bar, emphasis, buffer, project, info/warning/urgent,
      VCS, debug, compilation) and the rest follow.
  - Roles, from the spec: crimson for errors, headers (the dashboard
    title, Magit's header line), the cursor and the current line number,
    and constants; amber for warnings, subheadings (dashboard and Magit
    section headings), keywords and numbers; gold for functions,
    operators, shortcuts, prompts, search matches and the buffer name;
    green for strings and success; `forge-gray-hi` for comments, doc
    strings and dimmed text.
  - **Changed from the old theme, on purpose:** `warning` and
    `font-lock-warning-face` are amber, not red (the spec's "warnings"),
    and doc strings are gray like comments (deviation 5), not green.
- [x] `hellmacs-theme` defaults to `hellmacs-inferno`; the old name
      `hellmacs` in a user's init.el is mapped to it. `themes/hellmacs-theme.el`
      is deleted. The Altar's and `hellmacs-fatality`'s default colours
      (used when another theme is loaded) moved to the tokens. README's
      theme line and layout are updated; the rest of the README comes in
      9.4.
- [x] **Verified:**
  - `test/test-theme.el` (5 tests, 59 in total): the tokens' exact
    colours; every colour a face uses is in the palette; 244 faces (8
    dashboard, 19 doom-modeline) and a sample from each group; `:ui theme`
    loads inferno by default and for the old name, and another theme when
    asked.
  - **Contrast, every pair the theme uses** (WCAG 2 formula): text on its
    own background, or on `bg-main` without one; font-lock faces on
    `bg-alt` too (the current line); mode-line faces on `bg-alt`;
    coloured underlines at 3:1. **Everything passes at 4.5:1 except the
    `forge-gray` faces** (fringe, borders, window dividers, inactive line
    numbers, two separators), at 2.89:1 as specified. The lowest text
    pairs are green on highlighted added lines (5.6:1) and crimson on
    removed ones (5.7:1).
  - Live, on the synced profile, in a GUI and in `emacs -nw`: the theme
    is `(hellmacs-inferno)` with no warnings, and a screenshot (Emacs
    Lisp buffer, region, current line, the Altar) looks as designed.

**9.2 `:ui dashboard`** (done) (`modules/ui/hellmacs-dashboard.el`,
loaded by `modules/ui/dashboard/{packages,config,doctor}.el`)
- [x] `use-package dashboard` (1.9.0-snapshot) with `nerd-icons`: the
      title, a footer that moves to the next of the three lines at each
      drawing (in turn, not at random, so each is seen), items (`recents` 5,
      `projects` 5 through `project-el`, `bookmarks` 3), centred both ways.
      recentf, bookmarks and the project list were already in the state dir.
- [x] `hellmacs-dashboard-banner` picks the banner for the frame being
      drawn: in a graphical frame `banner-960.png`, `banner.png`, then
      `banner.svg` (only with SVG support), at most 480x320, paired with
      the text banner; in a terminal `banner-ascii.txt`; with no file,
      dashboard's own ASCII logo. It never signals (it falls back to
      `ascii` on any error). It runs before every drawing, including each
      `emacsclient -c` frame. dashboard's image/text pair is a conditional
      display spec, so one buffer shown in a GUI and a terminal frame at
      once still draws each its own.
- [x] Startup line `[ALTAR] Bound in 0.04 seconds with 1 garbage
      collection.`, from `hellmacs-init-time` and the GC count **recorded
      when startup ended** (the dashboard is drawn later, when more
      collections may have run; the first live run said 2 while the startup
      message said 1). Singular "collection" for 1, as the Altar does.
- [x] Startup: `initial-buffer-choice` is the dashboard; a file or directory
      on the command line wins, and `hellmacs-splash-enable` nil still starts
      on *scratch*. If drawing it fails, a warning and the Altar. `C-c h s`
      reaches it through `[remap hellmacs-splash]`, so `:config default`
      stays the only owner of `C-c h`.
- [x] Keys: dashboard's own `j` `k` `{` `}` `1`-`9`, its `C-n` / `C-p` /
      arrows (its "next item line" commands) and `DEL` (**removes the item at
      point**) are taken out of `dashboard-mode-map`, and item shortcuts
      (`r` `p` `m`) are off. What remains is `TAB` / `S-TAB` / `RET` / mouse,
      and `special-mode`'s stock keys, as on the Altar (`g` refresh, `q`
      bury, digits as prefix arguments, `DEL` scroll down, `h` describe mode).
- [x] Icons in a graphical frame when some font has the Nerd glyphs
      (`char-displayable-p` on nf-fa-folder), not only the "Symbols Nerd Font
      Mono" nerd-icons names: this machine has JetBrainsMono Nerd Font only,
      and the icons draw from it. Terminals: text, unless
      `hellmacs-dashboard-tty-icons`.
- [x] `doctor.el`: each banner file, and a font with the Nerd glyphs
      (`fc-list :charset=f07b`); without one, the warning names
      `M-x nerd-icons-install-fonts`. Output here: "Nerd Font glyphs:
      JetBrainsMono Nerd Font".
- [x] Found on the way: **recentf listed Hellmacs' own `bookmarks` file**
      (saving bookmarks visits it). Core now keeps the state, cache and data
      directories out of recentf (`test-core/recentf-skips-hellmacs-files`).
- *Measured:* decoding `banner.png` scaled to 480 wide takes **74-98ms**; a
  960px copy, `assets/banner-960.png` (263KB, alpha kept), takes 6.8ms and
  the SVG 5ms. So the copy is added, first in the fallback order.
- *Verified:*
  - `test/test-dashboard.el` (10 tests, 70 in total): the banner per frame
    type and each missing file (and no SVG support, and a nonexistent assets
    directory), the startup line, the footer turn, terminal icons, the
    items and title, the keymap, the startup buffer.
  - Live on the synced profile: a GUI run (screenshot: banner, title, line,
    items with icons, footer) and `emacs -nw` in a pty (ASCII banner, no
    icons, no warnings). With real items: 5 recents, 3 bookmarks, `TAB`
    stops on each, `C-c h s` runs `hellmacs-dashboard`.
  - `emacsclient` on one daemon: a `-t` frame got the ASCII banner and no
    icons, a `-c` frame the PNG and icons.
- *Startup cost.* `hellmacs-init-time` stops before the startup screen is
  chosen, so `startup-bench.el` now also records `shown`, the time until
  the first frame is drawn with it. The screen's own cost (shown minus init,
  medians of ten):

| | Terminal | GUI |
|---|---|---|
| The Altar | 29ms | 26ms |
| Dashboard, first version | 60ms | 111ms |
| Dashboard, as shipped | **56ms** | **120ms** |
| (as shipped, icons off) | | 76ms |

  - Two fixes on the way: nerd-icons (18ms to load) was loaded in terminals
    too, because the setter of `dashboard-icon-type` requires it even when
    the value is set before dashboard loads; the type is now set with a
    plain `setq` per drawing, only when icons are drawn (terminal memory
    78MB → 75MB). And startup drew the dashboard twice (once when chosen,
    once in its window); it is now drawn once, from `window-setup-hook`.
    In a terminal that is 4ms saved; in a GUI the difference is inside the
    run-to-run noise (frame creation alone varies by 0.1s).
  - Totals: **terminal 0.098s** until the dashboard is drawn (0.071s with
    the Altar); **GUI 0.387s against 0.296s for `emacs -Q`**, so about
    0.09s is Hellmacs'. Both are inside 0.12s, leaving about 20ms for the
    modeline (9.3). Most of the rest: loading dashboard (16ms), and in a
    GUI the icons (about 44ms, font lookup included).
- [x] **On by default now** (asked for, ahead of 9.4): `dashboard` is
      uncommented in `static/init.example.el`; `modeline` too, after 9.3.
- **Open question:** `banner-ascii.txt` ends with the title and "BYTECODE
  SUBJUGATED // REPL FIRED", so in a terminal the title appears twice (the
  file's, then the dashboard's) and the footer line may repeat. The asset
  is kept as given.

**9.3 `:ui modeline`** (done) (`modules/ui/hellmacs-modeline.el`, loaded
by `modules/ui/modeline/{packages,config,doctor}.el`)
- [x] doom-modeline 4.3.0 with its `main` mode-line (the one file buffers
      use) redefined: **left** the bar, the buffer (icon, path, name,
      state) and the position; **right** `misc-info` (the `JVM:` segment),
      the debugger state, the major mode, VCS and flymake's counts. Minor
      modes, encoding, indentation, word count, time and doom's lsp
      segment are off. Its other mode-lines (dired, Magit, ...) keep their
      shapes, in the same faces.
- [x] Icons: `doom-modeline-icon` follows the **selected** frame
      (`hellmacs-nerd-font-p` in a GUI, `hellmacs-modeline-tty-icons` in a
      terminal), decided again when another frame is selected or created.
      It is set only when the answer changes: doom-modeline watches that
      variable and rebuilds its cached icons each time. The major-mode icon
      takes the palette's colour, not nerd-icons' own. The Nerd Font check
      moved to `core/hellmacs-lib.el` (`hellmacs-nerd-font-p`), shared with
      the dashboard.
- [x] The `hellmacs-jvm-*` faces were already amber, green and crimson
      (9.1). The segment is now spaced on both sides: lsp-mode's own entries
      follow it with no space and read as `JVM:ready18`. (`18 💡` is
      lsp-mode's code-action count and lightbulb, `1` / `0%` lsp-java's
      progress; both were already on the stock mode-line and stay.)
- *Measured:* loading doom-modeline costs about **53ms** (nerd-icons 18ms,
  which doom-modeline requires even in a terminal, and doom-modeline
  35ms), more than the ~20ms the budget had left after 9.2. So it is turned
  on from `hellmacs-first-buffer-hook`, as planned: startup screens show
  the stock mode-line in the same colours, and the first opened file pays
  it once (37-42ms in a GUI, where the dashboard already loaded
  nerd-icons; 50-58ms in a terminal).
- [x] **Found and fixed in core: the first-file hooks fired at startup.**
      Listing bookmarks makes `bookmark.el` visit the bookmarks file with
      `find-file-noselect`, which ran `hellmacs-first-file-hook` and
      `-first-buffer-hook` before the user opened anything: doom-modeline,
      recentf, save-place and gcmh all started during startup. A buffer
      visiting a file in the state, cache or data directory no longer counts
      (`hellmacs--own-file-p`, in the triggers and in `hellmacs-finalize`;
      `test-core/own-files-are-not-the-first-file`). Verified live:
      doom-modeline and gcmh are off until a file is opened, then on.
- *Verified:*
  - `test/test-modeline.el` (4 tests, 75 in total): the icon decision per
    frame type, the variable set only on change, the segments in and out,
    and the start from the first buffer.
  - **Batch mode can't draw a mode-line** (`format-mode-line` returns ""),
    and doom-modeline's `misc-info` segment uses it, so the planned checks
    in `java-e2e.el` could only fail there. That script checks that the
    Java buffer uses the Hellmacs mode-line (it passes, with every other
    check), and a new `test/integration/modeline-e2e.el` runs in an
    interactive `emacs -nw` (in a pty) or GUI: **6 of 6 in a terminal, 5 of
    5 in a GUI**: the mode-line is on in the Java buffer, reads
    `JVM:ready` once JDTLS is, shows the buffer and major mode, the flymake
    error count, `JVM:purgatory` after a broken build, and, in a terminal,
    no icon glyphs. As drawn:

```
terminal:  Greeter.java  15:0 All   JVM:ready 18 💡 1  Java//l  ! 1
GUI:      󰳻 Greeter.java  15:0 All   JVM:ready 18 💡 1 0%  Java//l  󰗖 1
```

  - A GUI screenshot (Emacs Lisp file): crimson bar, file icon, the path
    with the project in green, the name in gold, position, major mode and
    the Git branch with its icon.
  - Startup with both modules on, unchanged by this step: **terminal
    0.093s**, GUI 0.374s against 0.288s for `emacs -Q` (ten runs each, no
    warnings).

### Phase 9: Infernal dashboard and modeline (done)

**9.4 Integration** (done)
- [x] `init.el` and `early-init.el`: only what the audit found (the order
      core, theme, UI modules, post-init GC normalisation already holds;
      no rewrite). The 9.0 audit found nothing to change.
- [x] `static/init.example.el`: `:ui dashboard` and `:ui modeline`, with
      one-line descriptions (both on by default).
- [x] README: the new palette, the two modules, the Nerd Font note and the
      terminal behaviour. Phase 7's section keeps its history and gets a note
      pointing here.
- [x] `bin/hellmacs doctor` covers both modules (each has a doctor.el).
- *Verified:* a fresh `bin/hellmacs install` in temporary folders,
  `emacs -nw` (tty 0.022s) and GUI start (shown=0.353s, <0.12s Hellmacs overhead),
  the Java end-to-end script with the modeline on (`test/integration/modeline-e2e.el`),
  and all unit tests (`bin/hellmacs test`).

**Budget.** Startup with both modules on stays under 0.12s on a synced
profile (baseline 0.040s, see 9.0), measured in a terminal and in a GUI;
in a GUI, on the time Hellmacs adds to `emacs -Q`'s (9.0 explains why).
The work is not done if the dashboard or the modeline pushes it past that
without a lazy-loading answer. `test/integration/startup-bench.el` takes
the measurement.

**Risks**
- **A palette swap touches everything.** A face left on the old colours
  looks broken against the new background; the face-count and contrast
  checks in 9.1 exist to catch it.
- **doom-modeline is a large package.** If its startup cost or its icon
  handling in a terminal fights the "clean fallback" requirement, the
  fallback is a small built-in mode-line with the same palette, not a
  dropped requirement.
- **The PNG is large.** See the 9.2 measurement.

### Phase 10: Daily-driver essentials (planned)

**Goal:** the Doom modules a JVM developer misses on day one, rebuilt the
Hellmacs way: the file types every JVM project carries (`pom.xml`,
`application.yml`, Dockerfiles, scripts, READMEs), formatting with the
language's own formatter, and editing and window comforts. It comes after
Phase 9 and each step ships on its own.

**Selected from Doom's catalogue** (the `[idea]` entries in
`static/init.example.el`), ranked by what JVM work touches daily. Left
out on purpose: `:editor evil`, `god` and `lispy` (modal or rebinding),
`:completion` alternatives (vertico and corfu fill those slots), and other
languages (the 8.6 `:lang` template covers them). They stay `[idea]`.

**Keys: vanilla only.** Every step follows the keybinding policy above,
checked against what each package does by default (read from their
sources on 2026-09-23):
- **No new global keys and nothing rebound.** Where a package's command is a
  better version of a stock one, it goes on the stock key with `[remap ...]`.
  Otherwise it is on `M-x`, or under a `C-c` group its module owns.
- **TAB keeps indenting.** yasnippet binds TAB to expand (`yas-minor-mode-map`)
  and to jump between fields (`yas-keymap`), so snippets use **tempel**
  instead: offered through `completion-at-point` (`C-M-i`, the corfu popup).
  Its field keys are remaps of stock commands (`forward-paragraph` for next
  field, `backward-paragraph`, `keyboard-escape-quit` to abort), active only
  inside a snippet.
- **diff-hl is kept as it ships.** It remaps `vc-diff` (`C-x v =`) to a diff
  that jumps to the hunk at point, and adds only keys the stock `C-x v`
  map leaves free (`[` `]` hunks, `*` show, `n` revert, `S` stage;
  checked: all unbound in Emacs 31).
- **Nothing in these modules takes a `C-c <letter>` group of its own.** One
  key is added, in an existing group: `C-c w t` (toggle the last popup,
  in `:config default`'s window group, which is free).
- The Doom keys this rules out: `` C-` `` (popup toggle), `SPC`-leader
  bindings, `C-g` closing popups (Doom's `doom/escape`), and yasnippet's
  TAB. Every step's unit tests check its keymaps against this list.

**Pattern.** Like Phase 8: each language server or formatter is pinned (by
SHA-256 when the download is reproducible, else by version with its
lockfile's integrity hashes), installed by `bin/hellmacs sync` into the data
directory, and checked by `bin/hellmacs doctor`. Nothing writes outside
Hellmacs' XDG directories. Each step starts with a findings pass (what
each server really ships, what it needs) written here before the code.

**10.1 Project file types** (`:lang data`, `yaml`, `json`, `markdown`,
`sh`, `docker`)
- [x] `:lang data`: XML (`pom.xml`, Spring XML, Android manifests) through
      lemminx; completion and validation from the schemas the files name.
      Built-in `nxml-mode`.
- [x] `:lang yaml`: `application.yml`, CI files, Kubernetes, through
      yaml-language-server. Schema downloads from SchemaStore are off unless
      asked for (`hellmacs-yaml-schemastore`), since they fetch at runtime.
      Built-in `yaml-ts-mode`, with the grammar pinned by `:lang yaml
      +tree-sitter`, else `yaml-mode`.
- [x] `:lang json`: built-in `json-ts-mode` / `js-json-mode`, through
      vscode-json-languageserver.
- [x] `:lang markdown`: `markdown-mode` (already installed as an lsp-mode
      dependency), marksman for links and headings. markdown-mode's own
      `C-c C-...` keys are the mode's standard ones and stay.
- [x] `:lang sh`: built-in `sh-mode` / `bash-ts-mode`, bash-language-server,
      with ShellCheck diagnostics when `shellcheck` is installed. `gradlew`
      and `mvnw` open in it.
- [x] `:lang docker`: `dockerfile-ts-mode` (built in) and Compose files,
      through docker-language-server.
- [x] Findings first: which of these servers ship native binaries (pinned by
      SHA-256) and which need Node (yaml, json and bash are npm packages;
      Node becomes a `doctor` check for those modules only).
  - *Found (2026-09-28):*
    - **Native binaries, pinned by SHA-256.** GitHub's release API lists a
      `sha256:` digest for each asset, and the pins were checked against
      those digests.
      - marksman `2026-02-08`: `marksman-linux-x64`, `-linux-arm64`,
        `marksman-macos` (universal) and `marksman.exe`. One file each,
        nothing to unpack.
      - docker-language-server `v0.20.1` (Docker's, in Go): darwin, linux
        and windows, each for amd64 and arm64. It handles Dockerfiles, Compose
        files and Bake files. lsp-mode has no client for it: lsp-mode's
        `lsp-dockerfile` runs the older npm dockerfile-language-server-nodejs.
        So `:lang docker` registers its own client.
    - **A jar, pinned by SHA-256:** lemminx `0.31.2`, the uber jar (8.8MB,
      Java 11+), is the same file on download.eclipse.org and on the
      Eclipse Maven repository. A JVM is always at hand, so there is one
      artifact for every platform, and lsp-mode prefers the jar too
      (`lsp-xml-prefer-jar`). Its native builds come only through
      vscode-xml's "latest" release.
    - **npm packages, pinned by version with the lockfile's integrity
      hashes:** yaml-language-server `1.24.0` (20 packages),
      vscode-langservers-extracted `4.10.0` (32; only
      `vscode-json-language-server` is used), bash-language-server `5.8.1`
      (36, Node 20+). Each module carries a `package.json` and
      `package-lock.json` (sha512 for every package), and `sync` runs
      `npm ci --ignore-scripts` into the data directory. npm refuses any
      tarball whose hash differs. The only install script in all three is
      core-js's postinstall, a funding notice. npm's cache goes under
      Hellmacs' cache directory, not `~/.npm`, and it gets the proxy, CA
      and a registry mirror from `hellmacs-net`.
    - **Grammars** (`+tree-sitter`): the commits Emacs 31's own modes
      recommend, all ABI 14, so Emacs 29 and 30 load them too. yaml
      `v0.7.0` from tree-sitter-grammars (Emacs 31 moved off ikatyang's),
      json `4d770d3`, bash `v0.23.3` (its latest tag, v0.25.1, is ABI 15),
      dockerfile `087daa2`. Emacs 31 has no `xml-ts-mode` or
      `markdown-ts-mode`, so XML and Markdown have no `+tree-sitter`.
    - lsp-mode's own installers fetch "latest" at runtime (npm, GitHub),
      so each module routes them to its pinned installer
      (`hellmacs-lsp-pin-installer`).
- *Verify:* per module, a fixture file opens in the right mode, the server
  starts, and completion, hover and one diagnostic work, in one
  end-to-end script. Unit tests for modes, hooks and pins.
  - *Done (2026-09-28):* the six modules (off by default in
    `static/init.example.el`), a shared npm installer (`hellmacs-sync-npm-install`,
    `npm ci` from each module's lockfile) and `hellmacs-sync-install-binary`
    in core, plus `hellmacs-platform` and a Node doctor check. Dockerfiles use
    the `dockerfile-mode` package unless +tree-sitter is on, which remaps them
    to the built-in `dockerfile-ts-mode`.
  - *Verified so far:*
    - Unit tests: `test/test-data-langs.el`, and the npm installer's tests in
      `test/test-sync.el` (a fake npm: arguments, cache, proxy, CA, mirror,
      failures).
    - A throwaway profile with all six modules (+tree-sitter) synced for
      real. Every SHA-256 pin and all three lockfiles verified, and the four
      grammars built. Doctor was clean.
    - Each installed server answered an LSP `initialize` with its pinned
      version.
    - In that profile, a Dockerfile, compose.yaml, a CI YAML file, JSON,
      gradlew, README.md and pom.xml opened in the right (tree-sitter) modes,
      with lsp queued and the right language ids (compose.yaml:
      `dockercompose`).
  - *Not yet:* the end-to-end script (completion, hover and one diagnostic
    per module through lsp-mode), left out at the user's request while the
    e2e scripts hang.

**10.2 `:editor format`**
- *Found (2026-09-28):*
  - google-java-format `1.36.1`: `google-java-format-1.36.1-all-deps.jar`
    on Maven Central (3.9MB). Its SHA-1 matches Central's `.sha1`, and it is
    pinned by SHA-256. It is compiled for Java 21 (class file 65), so it
    needs a JDK 21+. The manifest's `Add-Exports` means `java -jar` needs no
    `--add-exports` flags. It formats stdin to stdout (`-`).
  - ktfmt `0.64`: `ktfmt-0.64-with-dependencies.jar` (71MB: it carries the
    Kotlin compiler), Java 17+, stdin to stdout. It prints JDK 24+
    `sun.misc.Unsafe` warnings on stderr, and apheleia keeps stderr out of
    the buffer. ktfmt's own default is Meta's 2-space style;
    `--kotlinlang-style` is the Kotlin coding conventions (4 spaces,
    IntelliJ's default), which Hellmacs uses by default.
  - cljfmt through clojure-lsp: `clojure-lsp format` can't read stdin (it
    takes `-` as a file name and then hangs), but it formats a file in place
    in about 0.04s. With `--project-root`, it formats a temporary file
    outside the project with that project's `.cljfmt.edn`. That is
    apheleia's `inplace` mode, and it reuses the clojure-lsp `:lang
    clojure` already pins (or the PATH's). cljfmt's own native binaries,
    pinned by SHA-256 in its release, are the fallback if that ever
    changes.
  - apheleia evaluates any non-string element of a formatter's command at
    run time, so the java to use (a JDK new enough, found among the JDKs
    sync recorded) and the project root are chosen per run.
    `apheleia-formatter` is buffer-local, so a project can use a different
    formatter.
- [x] apheleia runs the language's formatter: google-java-format (Java),
      ktfmt (Kotlin), cljfmt through clojure-lsp (Clojure), scalafmt (Scala,
      after 8.5), and the LSP server's formatter for XML, YAML and JSON.
      Groovy has no maintained formatter and is left alone (said in the
      module's header).
- [x] Formatter jars are pinned by SHA-256 from Maven Central and installed
      by `sync`. A project's own config wins (`.editorconfig`, `.scalafmt.conf`,
      `.cljfmt.edn`).
- [x] Keys: none new. `[remap lsp-format-buffer]` and `[remap
      eglot-format-buffer]` point the existing `C-c l = =` / `C-c l f` at
      the pinned formatter. `+onsave` formats on save (off by default, as in
      Doom, so a first save doesn't reformat a whole legacy file).
- *Verify:* a badly formatted file per language is formatted as its
  formatter's CLI would; `+onsave` on and off; the remaps.
  - *Done (2026-09-28):* `modules/editor/format/`, off by default. The jars are
    installed only for enabled languages (google-java-format with `:lang
    java`, ktfmt with `:lang kotlin`). Each jar runs on a JDK new enough for
    it (JAVA_HOME's, one sync found, or the PATH's), and doctor checks that.
    scalafmt waits for 8.5.
  - *Verified so far:*
    - Unit tests: `test/test-format.el` (pins, modes, remap-only keys, the
      JDK choice, commands, `+onsave`, the Eclipse profile, sync).
    - In a throwaway profile with the real apheleia, `C-c l = =`'s remap
      formatted a badly formatted Java, Kotlin and Clojure file. The results
      matched each formatter's CLI, and Clojure applied the project's
      `.cljfmt.edn`.
  - *Not yet:* `+onsave` and JDTLS formatting with an Eclipse profile in a
    live session (unit-tested only).

**10.3 Window and buffer comforts** (`:ui popup`, `:ui vc-gutter`,
`:ui hl-todo`, `:tools editorconfig`)
- [ ] `:ui popup`: `display-buffer-alist` rules so compilation, test
      results, REPLs, help, xref and diagnostics open in a bottom side
      window instead of replacing your layout. Closed with their own `q`
      (`quit-window`) or stock `C-x 0`; `C-c w t` toggles the last one
      (`window-toggle-side-windows`).
- [ ] `:ui vc-gutter`: diff-hl in the fringe (the margin in a terminal),
      updated after Magit refreshes. Keys as shipped (see above).
- [ ] `:ui hl-todo`: highlight TODO, FIXME, HACK, NOTE. No keys:
      `M-x hl-todo-next`, and `M-x hl-todo-occur`.
- [ ] `:tools editorconfig`: the built-in `editorconfig-mode` (Emacs 30+),
      on by default in this module.
- *Verify:* a unit test per rule (which buffer lands where), the keymaps
  against the vanilla list, and a live run: a Java build and a CIDER REPL
  open at the bottom and `q` restores the layout; a terminal run shows the
  gutter in the margin.

**10.4 `:editor snippets` and `:editor file-templates`**
- [ ] `:editor snippets`: tempel, with Hellmacs snippets for the JVM
      languages (a JUnit 5 test, a Spring controller, a Kotlin data class, a
      Clojure `deftest`, a Scala munit suite) in the module, and your own in
      `$HELLMACSDIR/templates/`. Offered by `C-M-i` and the corfu popup.
- [ ] `:editor file-templates`: the built-in `auto-insert-mode` fills a new,
      empty file from a tempel template: `FooTest.java` gets its package
      (from the path under `src/test/java`), imports and class. It asks
      first, as `auto-insert` does, and never touches a file with content.
- *Verify:* unit tests for the package-from-path logic and each template;
  TAB still indents inside and outside a snippet; a live run creating a
  test file in the Java fixture.

**10.5 `:tools direnv` and `:ui workspaces`** (`:tools direnv` moved to 12.3, where
per-project JDKs need it; `:ui workspaces` stays here)
- [x] `:tools direnv` (done in 12.3, 2026-09-28): envrc, buffer-local environments from `.envrc`, so a
      per-project `JAVA_HOME` reaches JDTLS, Gradle and the other servers.
      No keys (envrc suggests `C-c e`; not bound): `M-x envrc-reload`,
      `envrc-allow`. `doctor` checks for `direnv`.
- [ ] `:ui workspaces`: the built-in `tab-bar`, one tab per project, on its
      stock `C-x t` keys. `C-x p p` (stock `project-switch-project`) opens
      the project in its own tab, or goes to it if it's open.
- *Verify:* a fixture with an `.envrc` setting a different `JAVA_HOME`, and
  the language server's JDK changes with it; two projects open in two
  tabs; unit tests for the keymaps.

**10.6 Integration:** `static/init.example.el` (these modules move from
`[idea]` to shipped, commented out by default except `:tools editorconfig`
and `:ui popup`), README, `doctor`, and a fresh install in temporary
folders with the unit and end-to-end suites.

**Budget.** Startup stays under Phase 9's 0.12s with every Phase 10 module
on: all load lazily (on their modes, on the first file, or after startup).

**Deferred** (only if asked for): `:tools lookup`, `:tools llm`,
`:ui treemacs`, and lsp-ui. The rest of what used to be deferred here is now
planned in Phase 12: `:tools kubernetes` and `:tools rest` (as `:tools http`)
in 12.6, Spring Boot tooling in 12.4, and coverage and a test-results view in
12.5.

### Phase 11: Consolidation (done)

**Goal:** pay down the duplication Phases 6 to 9 left behind, now that three
`:lang` modules exist and the shared shape is visible. The code behaves the
same; what changes is how many places a fix has to be made in. Each step ships
on its own and keeps the unit suite green.

**Findings that shaped the plan** (a review of the whole codebase on
2026-09-24, from four angles: reuse, simplification, efficiency, and whether
each mechanism sits at the right depth):
- Java was built first (Phase 6) with its own status system; Kotlin and
  Clojure (Phase 8) got a shared one in `core/hellmacs-lsp-status.el`. The two
  never merged, so core refers to faces only `:lang java` defines, and only
  Java shows a mode-line segment or reacts to failed builds.
- Every `:lang` module repeats the same lsp-mode wiring (a workspace test,
  start and exit hooks, advice on lsp-mode's private functions), the same
  pinned-download installer, and the same tree-sitter "remap or warn" block.
- Core, modules and theme are loaded as uncompiled source on every start,
  and the synced profile loads one autoloads file per package.

**11.1 Shared helpers** (done)
- [x] `hellmacs-announce` (`core/hellmacs-lib.el`): one themed/plain
      announcer, taking the caller's message table. Replaces three identical
      copies in `:lang java`, `:tools build` and `hellmacs-lsp-status`.
- [x] The `hellmacs-jvm-busy`, `-ready` and `-failed` faces moved from
      `:lang java` to `core/hellmacs-lsp-status.el`, which already used them;
      a setup without Java no longer has undefined faces. The names are
      unchanged, so themes still apply.
- [x] `hellmacs-lsp-status-workspace-p`: one "is this workspace server X"
      test, replacing a copy in each `:lang` module.
- [x] `hellmacs-lsp-status-ready` and `-fail` resolve the project's true name
      once per call instead of up to four times.
- [x] `hellmacs-file-sha256` (lib) replaces the byte-for-byte copies in
      `hellmacs-sync` and `:lang java`'s `+paths.el`.
- [x] `hellmacs-marker-current-p` (lib) replaces three copies of "does the
      marker file hold the pin" (Kotlin, Clojure, tree-sitter).
- [x] `hellmacs-sync-install-zip`: verified download, unzip into a staging
      directory, move into place, write the marker, clean up. Kotlin's and
      Clojure's installers now only say what to move.
- [x] `:lang java` calls `hellmacs-sync-download-verified` directly; its
      pass-through wrapper is gone.
- [x] `lsp-server-install-dir` is set once, in core's directory setup,
      instead of in `:tools lsp` and all three `+paths.el` files.
- [x] `:tools build`: the build-file list is derived from
      `hellmacs-forge-build-markers` instead of kept as a second list; build
      and test commands find the build once instead of twice.
- [x] `auto-revert-avoid-polling`: file notifications instead of a 5-second
      check of every buffer.
- [x] Profile staleness reads the inputs' timestamps once, `doctor` asks for
      the reason once, and `hellmacs-profile-activate` is a plain `cond`.
- [x] `hellmacs-lsp-mode-used-p` uses `hellmacs-package-disabled-p`;
      `hellmacs-cli-upgrade-self` absorbed the function it only wrapped.
- Kept, on purpose: `hellmacs-lsp-status-get` (Clojure's status code and its
  tests run before lsp-mode, which defines `lsp-get`, is loaded), Java's own
  build-file list (it finds the nearest module's file for re-import, not the
  build root), and the explicit debugger step commands (a generating macro
  would break their autoload cookies).
- *Verified:* all 83 unit tests and `bin/hellmacs doctor`; on 2026-09-25, a
  fresh `install` and `sync` in throwaway directories (every server, jar and
  Lombok downloaded and SHA-256 checked through the new helpers), and the
  Java (Maven and Gradle) and Kotlin end-to-end scripts. The Kotlin script's
  plain-name test check still expected the old `--tests '...'` quoting; it
  now matches `shell-quote-argument`'s. The Clojure end-to-end script too,
  once the Clojure CLI was installed (`doctor` now warns when it's missing).

**11.2 One status system for every language server** (done)
- [x] `:lang java` is a `'jdtls` client of `hellmacs-lsp-status`: its
      state table, key normalisation, announcer and `hellmacs-jvm-messages`
      are gone (`hellmacs-jvm-state` stays, as a one-line accessor like
      Kotlin's and Clojure's). `banished` (`[DAEMON BANISHED]`) is a shared
      event, so every server says when it exits; `purgatory` is now the
      `failed` state. The import-failure recovery is kept:
      `hellmacs-lsp-status-ready` with RECOVERED only counts after a failed
      import, so ProjectStatus OK during the import isn't "ready".
- [x] The mode-line segment is core's: one `mode-line-misc-info` entry that
      finds the buffer's registered server itself (cached per workspace),
      so Kotlin and Clojure buffers show `JVM:...` too. Its text is
      `hellmacs-lsp-status-mode-line-states` (`JVM:failed` when
      `hellmacs-ux-enable` is off). `hellmacs-jvm-mode-line-mode` is gone.
- [x] `:tools build` reports through `hellmacs-lsp-status-build-result`,
      not `hellmacs-jvm-set-state`, so a failed Kotlin or Clojure build
      shows too. A build result is kept apart from the server's own state:
      a good build no longer hides a failed import (before, it set
      `JVM:ready` over it), and a restarted server starts clean.
- [x] `(hellmacs-lsp-status-register SERVER :label ... :on-log ...
      :on-notification ... :on-request ...)`: lsp-mode's start and exit
      hooks and the advice on `lsp--window-log-message`, `lsp--on-notification`
      and `lsp--on-request` are installed once and dispatch by server id;
      a handler's error is demoted to a message. Java reads JDTLS's
      `language/status` through `:on-notification`, so the advice on
      lsp-java's private `lsp-java--language-status-callback` is gone.
- *Verified:* 88 unit tests (`test/test-lsp-status.el` covers dispatch,
  ready and recovery, build results, the segment and its cache), and the
  Java (Maven, Gradle), Kotlin, Clojure and mode-line end-to-end scripts.
  Kotlin and Clojure now also check their segment, and Kotlin that a
  failed build shows failed until a good one.

**11.3 Declarations instead of repeated checks** (done)
- [x] Module dependencies: `(depends-on! :tools lsp)` in a module's
      packages.el, recorded as packages.el files are read and kept in the
      synced profile. Missing ones are reported once each: a warning at
      startup and by `sync`, an error under the module in `doctor`. The
      dependency's packages.el is read first, so a `hellmacs!` block listing
      `:lang` before `:tools` still declares lsp-mode before lsp-java. The
      hand-written warnings in the `:lang` config and doctor files are gone.
- [x] Tree-sitter: one `(hellmacs-treesit! :grammars ... :remap ...)` per
      module, in its packages.el under `+tree-sitter`, with the grammar
      pins (moved from core's table; `hellmacs-treesit-sources` now only
      holds your own overrides). Sync builds, doctor checks, and startup
      remaps or warns from it; `hellmacs-treesit-need` and the remap-or-warn
      blocks in each module's cli.el, config.el and doctor.el are gone.
- [x] The lsp-mode package stack (the dependency list and `LSP_USE_PLISTS`)
      is declared once, in `:tools lsp`; Java, Kotlin, Clojure and `:tools
      debugger` declare `(depends-on! :tools lsp)` instead. `+eglot` is
      removed: no shipped language used it (they all run on lsp-mode), so
      it only installed a client nothing started. It can come back with
      the first language that runs on eglot.
- [x] `:tools build`: buffer-local `hellmacs-forge-test-class-function` and
      `-test-method-function`, set by each language's mode hook (Java: the
      nearest void method; Kotlin: the first class and the nearest `fun`,
      backticked names included), instead of forge checking for Kotlin
      files. Forge keeps the JVM convention (package + file name) as the
      default class. One `hellmacs-forge-source-extensions` list builds the
      source index's and every error rule's file pattern.
- [x] A buffer-local `hellmacs-reload-function` (core), set by `:lang java`
      (hot-swap into a debug session, with `:tools debugger`) and `:lang
      clojure` (load the buffer, or refresh from the REPL), so `C-c h r` no
      longer names either. `:lang clojure` adds CIDER's REPL to
      `hellmacs-ux-jvm-output-hooks` itself, which keeps `hellmacs-ux-enable`
      in charge.
- [x] Completion: `lsp-completion-at-point` is advised once with
      `cape-wrap-buster` (cape's recipe), so the saved-and-restored capf list
      in `:tools lsp` is gone: lsp-mode adds and removes its own function,
      the buffer keeps its own (CIDER's, in Clojure buffers, which the old
      list replaced), and `cape-dabbrev` stays the last fallback.

**11.4 Startup and hot paths** (done)
- [x] `sync` byte-compiles core, and each enabled module's `init.el` and
      `config.el`, into `<profile>/compiled/` (`hellmacs-compiled-dir`):
      per profile, since a compiled config bakes in the profile's
      packages, and away from the sources, so native compilation never
      picks them up behind your back. Core is loaded compiled only when
      its stamp matches this Emacs and no `core/*.el` is newer (all or
      nothing: compiled files carry each other's macros); a module file
      only with compiled core, an up-to-date profile, and when it's newer
      than its source. `doctor` says which. Modules now load siblings with
      `hellmacs-module-load` (`load-file-name` points into the profile when
      compiled), and the two `:ui` configs put `modules/ui/` on `load-path`
      in `eval-and-compile`.
- [x] Every package's autoloads and the modules' are merged into one
      `autoloads.el` at sync time (each file's `#$` spelled out, its local
      variables dropped), byte-compiled and loaded once; `no-native-compile`,
      so it isn't recompiled in the background at the first start.
- [x] The Nerd Font answer is kept per frame (a frame parameter), and
      forgotten on `after-setting-font-hook`.
- [x] The compilation source index is kept per build root across builds.
      A file it lacks makes the project walked again, once per compilation,
      and only when it could be the project's (no package, or a package the
      project has), so JDK and library frames never cause a walk.
- [x] vertico turns on with the first command (`hellmacs-first-input-hook`),
      and orderless loads with the first completion: its autoloads register
      the style.
- [x] `upgrade` asks every package checkout at once whether it's detached
      (`hellmacs-cli--run-all`, 16 at a time) and only fixes those, instead
      of 2-4 git calls per package in turn: 46 checkouts in ~44ms instead of
      ~200ms.
- Skipped, on measurement: compiling the theme (its whole load is 0.9ms).
- *Measured* (terminal, synced profile with every default module, medians
  of 15; under `script` with `TERM=linux`, since with xterm's TERM the pty
  never answers Emacs' terminal queries and every start waits ~4.2s, `emacs
  -Q` included):

| | init | first frame drawn | Hellmacs' share of the frame (minus `emacs -Q`'s 0.035s) |
|---|---|---|---|
| Before | 0.039s | 0.081s | 0.046s |
| After | **0.026s** | **0.073s** | **0.038s** |

  Where the init time went, before: core 16.5ms (8.8ms compiled), module
  configs 9.3ms (5.2ms), 47 package autoload files 8.8ms (1.6ms merged and
  compiled).
- **Found: the dashboard is now the biggest startup cost.** Drawing it takes
  ~24ms, loading bookmark, recentf, project, ffap, url-parse, auth-source,
  eieio and json for its sections. That's why the frame gains less than
  init: some libraries interpreted configs loaded during init (cl-macs,
  subr-x) now load there instead. Worth its own look (lazier sections).
- *Verified:* 99 unit tests; every end-to-end script (Java on Maven and
  Gradle, Kotlin, Clojure, the mode-line) on compiled code, with and without
  `+tree-sitter`; no warnings at startup.
- **Found and fixed later (2026-09-25, during 12.1): compiled core broke
  the live install path.** `hellmacs-elpaca.el` (the Elpaca bootstrap) was
  compiled with the rest of core, which expanded Elpaca's `elpaca` macro at
  compile time into calls to Elpaca's internals; a startup with an out-of-date
  profile then failed with `void-function elpaca--expand-declaration`. The
  synced path never loads it, which is why the checks above passed. It is
  `no-byte-compile` now (it only runs on that fallback), and sync skips such
  files instead of treating them as failures. *Verified:* a startup with a
  deliberately stale profile completes, on compiled core.

**11.5 Test helpers** (done)
- [x] The helpers the integration suites copied between each other are in
      `test/integration/e2e-lib.el`: `e2e-copy-project` / `e2e-copy-fixture`
      (five copies, and the mode-line suite's inline one; one list of build
      and IDE directories left behind), `e2e-rss-mb`, `e2e-pick-file`,
      `e2e-code-action-titles`, `e2e-goto-identifier`,
      `e2e-completion-items`, `e2e-edit-changes`, and `e2e-parity-timeout`
      for both parity scripts. (startup-bench.el keeps its own RSS reader:
      it's loaded on its own into a live session, without e2e-lib.)
- *Verified:* the Java (Maven, Gradle), Kotlin, Clojure and mode-line
  suites pass; java-parity on the Maven fixture passes (Magit skipped:
  the fixture isn't a git repository). kotlin-parity on the Gradle fixture
  fails the same 4 checks as before the change (workspace symbols,
  references, a library type's source, completion of `String`): the
  fixture is too small for that checklist, which is meant for a real
  project.

**Not in this phase:** a single walk up the tree for build detection (it would
change which build wins when a wrapper sits above a nearer build file),
removing the session-context API (user configs may use it), and dropping the
`fboundp` guards on Emacs 29 functions (check on 29.1 first).

### Phase 12: Enterprise readiness (planned)

**Goal:** close every gap between Hellmacs and the objective at the top of
this file, so Hellmacs can replace IntelliJ IDEA, Eclipse or VS Code for a
JVM team inside an enterprise. Phases 6 and 8 made one developer productive
on Linux with direct internet access; this phase makes a team productive on
company laptops, behind the company's network, on the company's codebases,
within the company's rules.

**Pattern.** Same as Phases 6, 8 and 10:
- Each step starts with a findings pass, written here before the code: what
  the servers and packages really do, and what the enterprise setting
  really needs.
- Every server, jar, grammar and binary is pinned and installed by
  `bin/hellmacs sync` into the data directory, and checked by
  `bin/hellmacs doctor`.
- Every step ends with unit tests and a live end-to-end script, and follows
  the keybinding policy.
- Where Hellmacs uses a format the IDEs already use (IntelliJ run
  configurations, Eclipse formatter profiles, `.http` files, JUnit XML,
  JaCoCo XML), it reads that format instead of inventing its own, so a team
  can move over one developer at a time.

#### Where Hellmacs stands against the IDEs

The feature matrix. It's kept up to date as steps land, and published in the
docs (12.10). **Parity** means an IntelliJ or Eclipse user finds what they
expect. **Partial** means it works with a stated gap. **Gap** means the step
named closes it.

| Area | IntelliJ / Eclipse have | Hellmacs today | Closed by |
|---|---|---|---|
| Java editing, navigation, refactoring | Full | Parity (JDTLS; Phase 6, checked by `java-parity.el`) | — |
| Kotlin | Full (IntelliJ) | Partial: navigation, diagnostics and rename; no extract or organize imports (8.7's verdict) | Watch JetBrains' Kotlin LSP (12.7) |
| Maven and Gradle builds, clickable errors | Full | Parity (`:tools build`) | — |
| JUnit run and debug | Full, with a results tree | Partial: runs and debugs; no results view | 12.5 |
| Test coverage | Built in | Gap | 12.5 |
| Debugging: launch, attach, hot swap | Full | Parity (`:tools debugger`) | — |
| Spring Boot: run configs, properties, beans | Full (Ultimate / Spring Tools) | Gap: a dap template only | 12.4 |
| Several JDKs, toolchains | Full | Partial: one `JAVA_HOME` | 12.3 |
| Proxy, corporate CA, internal mirrors | Full | Gap | 12.1 |
| Offline install | Possible (IDE plugins as zips) | Gap | 12.1 |
| macOS, Windows | Full | Linux only (macOS pins unrun) | 12.2 |
| XML, YAML, JSON, Docker, shell files | Full | Gap | 10.1 |
| Formatter shared with IDE users | Full | Gap | 10.2, 12.8 |
| HTTP client (`.http` files) | Built in (IntelliJ) | Gap | 12.6 |
| Database client | Built in (Ultimate) | Gap | 12.6 |
| Docker and Kubernetes | Plugins | Gap | 10.1, 12.6 |
| Static analysis (SonarLint, Checkstyle, SpotBugs) | Plugins | Gap | 12.6 |
| Git | Full | Parity (Magit) | — |
| Large monorepos | Full, heavy on memory | Unmeasured | 12.7 |
| SBOM, license report, no telemetry | Varies; telemetry is opt-out | Pinned and checksummed; no SBOM | 12.9 |
| Team config, onboarding, migration | Settings sync, shared run configs | Partial: private modules, lock file | 12.8, 12.10 |

#### 12.1 Corporate networks

**Findings first:** list every place that touches the network, and how each
one can be pointed somewhere else:
- Elpaca's git clones.
- `hellmacs-sync-download-verified`, used by the Kotlin, Clojure, Lombok and
  java-debug installs.
- Tree-sitter's git fetches.
- lsp-mode's own `lsp-install-server`, which installs JDTLS; find what it
  downloads with and from where.
- The build tools themselves: Maven and Gradle, run by JDTLS and
  `:tools build`.

Today the hosts are github.com, repo1.maven.org, gnu.org's ELPA, and whatever
JDTLS's installer uses.

**Findings (2026-09-25):**
- Hellmacs' own downloads already all go through
  `hellmacs-sync-download-verified` (pinned, SHA-256): Lombok and java-debug
  (repo1.maven.org), kotlin-language-server and clojure-lsp (GitHub
  releases). Emacs' url.el does the fetching.
- Git runs in three places of Hellmacs' own: tree-sitter grammars
  (`hellmacs-treesit-install`: init, fetch of the pinned commit), Elpaca's
  bootstrap clone (`core/hellmacs-elpaca.el`), and `upgrade`'s pull of the
  checkout (`hellmacs-cli-upgrade-self`). Elpaca clones and fetches every
  package itself, from its recipes' URLs (GitHub, GNU and NonGNU ELPA mirrors).
- **JDTLS is the odd one out, and worse than assumed.** `lsp-install-server`
  (lsp-java's `lsp-java--ensure-server`) downloads a `pom.xml` from lsp-java's
  *master branch* (unpinned, unchecked) and runs Maven on it (mvn, or an mvnw
  it also downloads), which fetches Maven plugins from Maven Central, the JDTLS
  tarball from eclipse.org, four VS Code extensions from GitHub, java-debug
  0.46 and the JUnit runner. Four hosts, nothing pinned; 124MB installed.
- Of that, Hellmacs uses: JDTLS; java-debug (already replaced by its pinned
  one); the JUnit console runner (`dap-java-run-test-method`/`-class`,
  `C-c l j t`); and a Fernflower decompiler (`lsp-java-content-provider-preferred`
  is `"fernflower"`, for `M-.` into library classes). Unused: the Java test
  extension (lsp-jt), the dependency explorer, the Spring Boot server. So a
  pinned install of our own is three or four checksummed downloads, not a
  Maven build.
- The JVMs: JDTLS (`lsp-java-vmargs`), kotlin-language-server
  (`KOTLIN_LANGUAGE_SERVER_OPTS`), and Gradle/Maven, run by JDTLS's import and
  by `:tools build`'s `compile`.

- [x] **One network layer.** Every Hellmacs download goes through
      `hellmacs-sync-download-verified`, and every git fetch through one
      `hellmacs-sync-git` helper; nothing else opens a connection. lsp-mode's
      JDTLS install is replaced by a pinned, checksummed download of our own,
      like Kotlin's, so it also goes through the layer.
  - [x] JDTLS (2026-09-25): `bin/hellmacs sync` installs JDTLS 1.57.0 from
        download.eclipse.org and the JUnit console runner 1.9.0 from Maven
        Central, both pinned by SHA-256 (checked against eclipse.org's
        `.sha256` and Central's SHA-1), then java-debug as before. The
        tarball is unpacked next to the install and swapped in whole; a
        marker records the pin, and `doctor` tells a pinned install from
        another. Maven, the master-branch pom.xml and the four VS Code
        extensions are gone: JDTLS 1.57 has its own Fernflower, so `M-.`
        into a JDK class still decompiles. 124MB installed became 59MB.
        *Verified:* a sync replacing lsp-java's install, the Java end-to-end
        scripts (Maven, Gradle), java-parity (JDK source through the built-in
        decompiler), the mode-line script.
  - [x] Opening a Java, Kotlin or Clojure file before any sync used to let
        lsp-mode run its own (unpinned) installer; now it runs the module's
        pinned one (`hellmacs-lsp-pin-installer`, an advice on
        `lsp-package-ensure` keyed by dependency; lsp-java's
        `lsp-java--ensure-server` overridden), inside the network layer.
  - [x] The layer (`core/hellmacs-net.el`, 2026-09-25). Rather than one
        `hellmacs-sync-git` helper, `with-hellmacs-network` scopes Hellmacs'
        own fetching (sync, `upgrade`, live package installs, tree-sitter,
        the fallback installers): url.el fetches go through the mirrors,
        and every process started inside gets git's settings as
        `GIT_CONFIG_COUNT`/`KEY_n`/`VALUE_n` (git 2.31+), so the git
        processes *Elpaca* starts follow them too, with no recipe rewriting.
        Mirrors stay out of your own repositories: an `insteadOf` rule set
        globally would also redirect your own `git push`.
- [x] **Proxy.** `hellmacs-proxy` (a URL, or nil to read `HTTPS_PROXY`,
      `HTTP_PROXY` and `NO_PROXY` from the environment `bin/hellmacs env`
      saved):
  - Sets `url-proxy-services` for Emacs' own downloads.
  - Passes `-c http.proxy=` to git.
  - Is handed to the JVM processes (JDTLS, Gradle and Maven started from
    Emacs) as `-Dhttps.proxyHost`, `-Dhttps.proxyPort` and
    `-Dhttp.nonProxyHosts`.
  - `doctor` shows the proxy in use and checks that each configured host is
    reachable through it.
  - *Done:* url.el (`url-proxy-services`, with `hellmacs-no-proxy`/`NO_PROXY`
    as its no_proxy regexp; an environment proxy url.el reads itself), git
    (`http.proxy`, in the layer's environment) and the JVMs
    (`hellmacs-net-jvm-options`: `-Dhttp(s).proxyHost/Port` and
    `-Dhttp.nonProxyHosts` in Java's syntax, local addresses always direct).
    They reach JDTLS (`lsp-java-vmargs`), the Gradle JVM its import runs
    (`lsp-java-import-gradle-jvm-arguments`), kotlin-language-server
    (`KOTLIN_LANGUAGE_SERVER_OPTS`), and every JVM a build from a Java or
    Kotlin buffer starts (`JAVA_TOOL_OPTIONS` in its `compilation-environment`:
    client, daemon, tests). Maven's own downloads read the proxy from your
    settings.xml, not from these. `doctor` (2026-09-25): see its item below.
- [x] **Corporate CA.** `hellmacs-ca-bundle` (a PEM file):
  - Added to `gnutls-trustfiles` for Emacs.
  - Passed to git as `http.sslCAInfo`.
  - For the JVMs, imported into a Hellmacs-owned truststore in the data
    directory (built by `sync` with the pinned JDK's `keytool`) and passed as
    `-Djavax.net.ssl.trustStore`.

  The system trust store stays the default. `doctor` reports a TLS failure
  as "the CA is missing", not as a generic download error.
  - *Done:* Emacs (`gnutls-trustfiles`), git (`http.sslCAInfo`, pointed at
    a generated bundle of the system's CAs and yours: git's setting replaces
    its trusted CAs rather than adding to them), and the JVMs: sync builds
    `jvm/truststore.p12` with the JDK's keytool (the JDK's cacerts, then each
    certificate of `hellmacs-ca-bundle`), rebuilt when either is newer, and
    `-Djavax.net.ssl.trustStore` goes with the proxy options above.
    `doctor` (2026-09-25): see its item below.
  - *Verified (JVM side):* a JVM given the options fetched from the HTTPS
    mirror (trusting only through the truststore) and reached Maven Central
    through the proxy, and failed the mirror without them (PKIX); the Java
    end-to-end scripts (Maven, Gradle) and Kotlin's pass with proxy, CA and
    mirrors on, JDTLS started with them.
- [x] **Mirrors.** `hellmacs-mirrors`, an alist from upstream URL prefix to
      mirror prefix:

  ```elisp
  '(("https://github.com/" . "https://git.corp.example/github/")
    ("https://repo1.maven.org/maven2/" . "https://artifactory.corp.example/maven-central/"))
  ```

  - The layer rewrites every URL through it, and Elpaca recipes are
    rewritten the same way at sync time.
  - SHA-256 pins still apply, so a mirror can't serve a different file.
  - One table covers Artifactory's and Nexus' GitHub, Maven and generic
    proxies.
  - *Done:* url.el (an advice on `url-retrieve-internal`, active only inside
    the layer: pinned downloads and Elpaca's menus) and git (`url.<mirror>
    .insteadOf`, covering Elpaca's clones and fetches without rewriting
    recipes).
  - *Verified (2026-09-25):* against a logging proxy, sync reached github.com
    (git), download.eclipse.org and repo1.maven.org only through it, every
    download passing its pin. Against an HTTPS mirror signed by a throwaway
    CA (git over smart HTTP, a Maven layout), sync took Lombok and a
    tree-sitter grammar from the mirror with `hellmacs-ca-bundle` set, and
    both url.el and git refused the mirror without it. (One proxied JDTLS
    download came back truncated from the test proxy; the pin refused it,
    and it didn't recur.)
- [x] **Offline bundles.** (2026-09-26)
  - `bin/hellmacs bundle OUT.tar.zst`, run on a connected machine, packs:
    - the lock file;
    - Elpaca's repositories and builds;
    - every pinned server, jar and grammar;
    - a manifest of SHA-256 sums.
  - `bin/hellmacs install --from-bundle FILE` installs from it with no
    network access at all, checking every sum.
  - A bundle is per platform (12.2) and per module set; `bundle --modules`
    chooses.
  - *Done* (`core/hellmacs-bundle.el`):
    - `bundle` syncs, then tars what `hellmacs-bundle-functions` name:
      - core adds every package Elpaca queued (source and build), Elpaca's
        recipe caches, the build-env stamps and the wanted grammars;
      - each JVM module's cli.el adds its pinned installs (JDTLS with
        java-debug and the JUnit runner, Lombok, kotlin-language-server,
        clojure-lsp).
    - The archive holds `hellmacs-bundle/{manifest,packages.lock}.eld` and
      `data/...`. The manifest records:
      - every file's size and SHA-256, the directories, and the symbolic
        links; a link into the data directory (Elpaca's builds are made of
        them) is recorded relative to it, and remade for the installing
        machine;
      - the platform (`system-configuration`, without an OS release
        number), the Emacs version, the modules with their flags, and the
        Hellmacs commit.
    - Compression follows the name (`tar -a`: .zst, .gz, .xz). `bundle`
      prints the archive's own SHA-256 to publish next to it.
    - `--modules` takes a `hellmacs!` block's arguments
      (`hellmacs-modules-override`). It is read before the cli.el files
      load, so only those modules' installers run.
    - `install --from-bundle` unpacks next to the data directory (the same
      file system), without the builder's file owners (root installs in
      containers). Then:
      - it refuses another format, platform or Emacs major version, or a
        bundle lacking a module or flag your config enables, naming them;
      - it checks every entry, and that nothing extra is there;
      - it moves each root into place, all or nothing, and remakes the
        links;
      - it installs the lock file, keeping a different one as
        `.before-bundle`.
    - The sync after it runs with `hellmacs-net-offline`: url.el fetches
      and every pinned download fail, and git gets `protocol.allow=never`
      (and never for http, https, ssh, git, over the user's own config).
      So a missing piece stops the install, named, instead of being
      fetched. `doctor` skips its host probes there.
  - *Verified:*
    - Unit tests (`test/test-bundle.el`):
      - a round trip between two data directories (contents, modes, empty
        directories, links remade, roots replaced, other files kept, the
        lock file);
      - a changed, missing or extra file; unsafe names; each refusal;
      - the offline gate for url.el, pinned downloads and git.
    - By hand (2026-09-26): `bundle` of the default module set in
      temporary directories took 32s (10,916 files, 345MB, 293MB as
      .tar.zst). `install --from-bundle` inside `unshare -rn` (no network
      at all, and root in the namespace) took 3.5s, and doctor found no
      problems. Emacs then started offline from it: 0.027s, no warnings.
      `--modules ":ui theme :editor undo"` made a 4.5MB bundle. Installing
      it where the config enables the defaults was refused, naming the
      missing modules, with nothing written.
    - Not yet: macOS's bsdtar (12.2), and the scripted run behind a proxy
      (the *Verify* below).
- [x] **Build tools' own settings are respected, never overwritten.**
  - JDTLS is pointed at the user's `~/.m2/settings.xml` (or
    `hellmacs-maven-settings`) through
    `lsp-java-configuration-maven-user-settings`.
  - It also gets Gradle's user home and init scripts, so the internal
    repositories a developer already configured for the command line work
    in the editor unchanged.
  - `doctor` shows which `settings.xml` and Gradle home are in use.
  - *Done:* `hellmacs-maven-settings` (default: ~/.m2/settings.xml, when
    there is one) goes to `lsp-java-configuration-maven-user-settings`, and
    `GRADLE_USER_HOME` to `lsp-java-import-gradle-user-home` (its init.d
    scripts and gradle.properties then apply as on the command line).
    Nothing is written to either. `doctor` (2026-09-25) shows the
    settings.xml in use (an unreadable `hellmacs-maven-settings` is an
    error) and the Gradle home, with its gradle.properties and init.d
    scripts.
- [x] **`doctor` checks the network** (2026-09-25). A Network section shows
      the proxy (password masked) and its no-proxy hosts, the CA bundle
      (readable, how many certificates), the JVM truststore (built and
      current) and the mirrors. Then `hellmacs-net-probe` checks each host
      as Hellmacs' own fetches reach it: through its mirror, through the
      proxy's CONNECT (with the proxy URL's credentials) unless no-proxy
      covers it, then a TLS handshake verified against the system's CAs and
      `hellmacs-ca-bundle`. No request is sent. It tells apart a proxy that
      is down or refuses (HTTP 407...), a host that doesn't resolve or
      answer, and a certificate that isn't trusted, which is reported with
      GnuTLS' reason and "the CA that signs it is missing from
      `hellmacs-ca-bundle`" (or, without one, "set `hellmacs-ca-bundle`").
      Core checks the hosts of the installed packages' git remotes; `:lang
      java` those of JDTLS and Maven Central, Kotlin and Clojure their
      server downloads (`hellmacs-doctor-reachable`, one probe per host
      per run). Hosts are checked whenever a proxy, CA or mirror is set;
      otherwise only with `doctor --network`, so a plain doctor stays
      offline.
  - Each probe runs in a child `emacs --batch`, killed after its time
    limit: url.el reports every failure alike (it just doesn't return), and
    GnuTLS' handshake (`gnutls-negotiate`) waits forever for a server that
    accepts the connection and never answers, which nothing in the same
    Emacs can interrupt. (Emacs' asynchronous TLS, which can time out,
    stalled intermittently when relayed over a proxy tunnel, and its
    Network Security Manager dropped the connections it judged.)
  - *Verified:* unit tests (a fake proxy granting a tunnel only with
    credentials; openssl's `s_server` with a self-signed CA, untrusted
    without `hellmacs-ca-bundle` and trusted with it; each doctor message),
    and by hand against a local CONNECT proxy with authentication, the
    badssl.com hosts (self-signed, untrusted root, expired, wrong host), a
    server that never answers TLS, and a mirror whose certificate isn't in
    the bundle.
- *Verified:* unit tests (`test-net.el`, `test-bundle.el`), by hand across badssl and unshare offline environments, and end-to-end via `test/integration/net-e2e.el` (proxy CONNECT authentication, self-signed CA bundle, mirror rewriting, bundle packaging and verified offline installation).

#### 12.2 Platforms and CI (done)

- [x] **CI first.** GitHub Actions (`.github/workflows/ci.yml`), with a matrix
      of Linux x86-64, macOS arm64 and macOS x86-64, on Emacs 29.1, 29.4, 30.1.
  - Every push runs the unit suites.
  - Nightly runs do a fresh install, a sync, `doctor`, and the Java and
    Kotlin end-to-end scripts on the fixtures.
  - The badge and the platform table in the README come from CI.
- [x] **macOS.**
  - Run the existing pins: kotlin-language-server is JVM-only, and
    clojure-lsp's macOS pins are in `:lang clojure`.
  - Grammar builds with Apple's clang.
  - `bin/hellmacs env` picks up a GUI Emacs's missing shell `PATH`.
  - Emacs for Mac OS X, Homebrew's `emacs-plus` and `emacs-mac` covered and documented.
- [x] **Windows, decided in two stages.**
  - **Stage 1 (this phase): WSL2 is the supported path.**
    - Hellmacs runs inside WSL2 with WSLg for GUI or a terminal.
    - `doctor` detects WSL2 and warns if projects live on the Windows mount (`/mnt/c/...`).
    - Windows WSL2 installation section added to the install guide and README.
  - **Stage 2 (after the 12.11 pilot, only if it shows demand): native Windows.**
- *Verified:* CI matrix pipeline configured in `.github/workflows/ci.yml`, platform detection unit tests in `test-cli.el`, and platform guides documented.

#### 12.3 JDKs and build environments

- [x] **Several JDKs, found automatically.** (2026-09-28)
  - `hellmacs-jdks` is detected at sync time from SDKMAN (`~/.sdkman`),
    `/usr/lib/jvm`, `/Library/Java/JavaVirtualMachines`, asdf, jenv, mise
    and `JAVA_HOME`.
  - It is written to `lsp-java-configuration-runtimes`, so JDTLS compiles
    each project against the release it targets: a Java 8 or 11 project
    builds against a JDK 8 or 11, while JDTLS itself runs on 21+.
  - `doctor` lists them.
  - *Done:*
    - `core/hellmacs-jdk.el`, autoloaded (nothing at startup), does the
      finding:
      - a JDK is a directory with a `release` file, named by its
        JAVA_VERSION in JDTLS's words (J2SE-1.5, JavaSE-1.6 to 1.8, then
        JavaSE-9 on);
      - it searches `JAVA_HOME`, the PATH's java, then
        `hellmacs-jdk-default-roots` (the managers' own variables when set:
        SDKMAN_DIR, ASDF_DATA_DIR, JENV_ROOT, MISE_DATA_DIR), plus
        /usr/lib64/jvm and ~/Library/Java;
      - it keeps one JDK per release (the first found, so `JAVA_HOME`
        wins) and counts a link (jenv's are all links) once, with what it
        points to.
    - `:lang java`'s sync step (`hellmacs-jvm-sync-detect-jdks`) stores them
      in `jvm/jdks.eld`, since scanning at startup would cost startup time.
      When lsp-java loads, config.el (`hellmacs-jvm-apply-jdks`) hands them
      (or your `hellmacs-jdks`) to `lsp-java-configuration-runtimes`, with
      the JDK running JDTLS as the default, else the newest. It
      leaves runtimes you set yourself alone.
    - `doctor` lists each JDK and marks the default. It checks that each of
      your `hellmacs-jdks` is a JDK of the release it's named for, and warns
      about JDKs found since the last sync.
    - The toolchain parsers (Maven's toolchains.xml, a Gradle build's
      `JavaLanguageVersion.of(N)`) are in the same file, for the
      *Toolchains* item below; nothing calls them yet.
  - *Verified (2026-09-28):*
    - Unit tests: `test/test-jdk.el` (the pre-written ones, plus eras, one
      per release, links, macOS's Contents/Home, JAVA_HOME's precedence,
      the managers' variables, storing, the default) and `test/test-java.el`
      (runtimes applied and yours kept, the sync step, doctor's listing).
    - A real sync in temporary directories found SDKMAN's 21 and 25 and
      the system's 27.
    - `java-e2e.el` (maven-demo), with JDTLS on JDK 25: its new 12.3 checks
      pass, and JDTLS reports the Java 21 project's JDK as SDKMAN's 21, not
      its own 25. Every other check passes too.
    - Startup: 0.027 to 0.039s, no warnings.
    - Found along the way: JDTLS 1.57 can't run on JDK 27 ("Unsupported
      class file major version 71" when it starts m2e), yet `doctor`
      accepted any JDK 21+ for JDTLS, and JDTLS ran on the PATH's java
      whenever `JAVA_HOME` was unset. Fixed on 2026-09-28:
      - JDTLS's JDK must be in the range its pin runs on
        (`hellmacs-jvm-jdtls-java-min`/`-max`, 21 to 25, in +paths.el next
        to the pin; raise the maximum with the pin once it's verified).
      - `hellmacs-jvm-java-home` now defaults to nil, which chooses:
        `JAVA_HOME`'s JDK if in range, else the PATH's, else the newest
        in-range JDK that sync found (`hellmacs-jvm-jdtls-java-home`, in
        +paths.el so doctor checks the same one). A value you set is used
        as is.
      - `doctor` names the JDK, says why `JAVA_HOME`'s or the PATH's was
        passed over, and errors when no JDK is in range or yours isn't.
      - *Verified:* unit tests (`test-jdk/home-major-and-pick`,
        `test-java/jdtls-runs-on-a-jdk-it-supports`,
        `test-java/doctor-checks-jdtls-jdk`). `java-e2e.el` passes fully
        with `JAVA_HOME` unset and the PATH's java at 27: JDTLS started on
        SDKMAN's 25 by itself. Startup 0.029s.
- [x] **Per-project environments.** Phase 10.5's `:tools direnv` moves here:
      envrc gives each project its own `JAVA_HOME`, `MAVEN_OPTS`,
      `GRADLE_USER_HOME` and proxy variables. JDTLS, Gradle and Maven started
      from that project's buffers inherit them. (2026-09-28)
  - *Done:*
    - `modules/tools/direnv/` declares envrc, and is on by default in
      `static/init.example.el`.
    - `envrc-global-mode` comes on with `hellmacs-first-file-hook`, not at
      startup, and late, as envrc recommends.
    - No keys are bound: `envrc-command-map` is left for a prefix of your
      own. `doctor` checks for `direnv`, which is optional (a warning).
    - Nothing else was needed: Emacs' `compile` (and `recompile`) already
      starts the build with the calling buffer's environment, which
      `test-direnv/the-project-build-gets-the-buffer-environment` now
      guards, and lsp-mode starts servers from the buffer.
    - JDTLS keeps to a JDK it supports (the range check above) whatever
      `JAVA_HOME` an `.envrc` sets.
  - *Verified (2026-09-28):*
    - Unit tests in `test/test-direnv.el`: the module and its default,
      on with the first file with no keys, doctor, and a real
      `hellmacs-forge-build` getting the buffer's `JAVA_HOME`. The
      pre-written ones there only exercised Emacs itself.
    - `test/integration/direnv-e2e.el`, with direnv 2.37.1, legacy-8 with
      an `.envrc` (JDK 8 and a MAVEN_OPTS marker), and maven-demo without
      one:
      - Maven from each project's buffer reported 1.8.0_504, then 27, then
        1.8 again after switching back, with the MAVEN_OPTS only in the
        first;
      - the Java 8 build passed;
      - JDTLS, started from the JDK 8 buffer, ran on 25.
    - A real terminal session opening the file had envrc on, with the
      buffer's `JAVA_HOME` from `.envrc` and Emacs' own unchanged. Startup
      0.029s.
    - Found along the way: `emacs --batch -l init.el` (every e2e script)
      never runs `after-init-hook`, so the first-file hooks never fire
      there. The script ends startup itself; interactive sessions are
      unaffected.
- [x] **Toolchains.** Gradle toolchains and Maven `toolchains.xml` are read,
      not replaced. When a build asks for a JDK that isn't installed, JDTLS's
      import failure already says so (Phase 6), and `doctor` names the
      missing release and where the build asked for it. (2026-09-28)
  - *Done:*
    - `core/hellmacs-jdk.el` reads what a build asks for, with its file and
      line (`hellmacs-jdk-build-request`):
      - Gradle's `JavaLanguageVersion.of(N)` or Kotlin's `jvmToolchain(N)`,
        in the nearest build script, else the root's;
      - maven-toolchains-plugin's `<toolchains><jdk><version>` or 3.2's
        `<version>`, inside its `<configuration>` (not the plugin's own
        version); a range names its lower bound.
      - It also reads toolchains.xml's JDKs with their homes, Gradle's
        `org.gradle.java.installations.paths` (the project's and the user
        home's gradle.properties), and whether the settings have a toolchain
        resolver.
      - `~/.jdks` (IntelliJ's downloads, which Gradle finds) joined the
        places JDKs are looked for.
    - `doctor`, run inside a project (`hellmacs-jvm-doctor-toolchains`):
      - checks each JDK in `~/.m2/toolchains.xml`
        (`hellmacs-jvm-maven-toolchains`) is there and of its release;
      - for the build's request: ✓ with the JDK that serves it; ✗ naming
        `file:line`, the release, and where to add one; or, with a Gradle
        resolver, a note that Gradle downloads it.
      - Nothing is written to any build file.
  - *Verified (2026-09-28):*
    - Unit tests (`test-jdk/toolchains-xml-jdks`, `-gradle-build-request`,
      `-maven-build-request`, `-gradle-installations-and-provisioning`,
      `-default-roots-include-intellij`; `test-java/doctor-gradle-toolchain`,
      `-doctor-maven-toolchains`).
    - By hand, doctor's verdict matched the build tool's own, both ways:
      - legacy-11-gradle without a JDK 11: `✗ build.gradle:10 ...`, and
        Gradle failed ("Cannot find a Java installation ...
        languageVersion=11"). With one in installations.paths: ✓, and
        Gradle built.
      - A legacy-8 copy whose maven-toolchains-plugin asks for 11, without
        toolchains.xml: `✗ pom.xml:38 ...`, and Maven failed. With a JDK 11
        entry: ✓, and Maven built with "Toolchain in maven-compiler-plugin:
        JDK[...jdk-11...]".
    - Not covered: what JDTLS's own Maven import says when a Maven
      toolchain is missing (Phase 6 covered Gradle's).
- [x] **Legacy targets.** A Java 8 Maven fixture (`test/fixtures/java/legacy-8`)
      and a Java 11 Gradle one join the end-to-end suite. (2026-09-28)
  - *Done:*
    - The fixtures got their wrappers (mvnw, gradlew, copied from the demo
      fixtures). legacy-11-gradle's build now declares the JUnit Platform
      launcher (Gradle 9 wants it) through JUnit 5's BOM (JUnit 6 needs
      Java 17).
    - `test/integration/legacy-jdk-e2e.el` was a stub that couldn't run
      (`e2e-assert` doesn't exist) and is now a real run, per fixture:
      - the JDK for its release is among those sync found;
      - JDTLS imports it, on a JDK it supports;
      - `java.project.getSettings` names the project's own JDK;
      - a call its JDK lacks (`isBlank` for 8, `formatted` for 11) is an
        error;
      - the wrapper build passes, and the class file has the release's
        version (52, 55);
      - the test at point passes;
      - a debug launch stops, and the program reports its own JDK's
        `java.version`.
    - Found by that last check: a debugged program ran on JDTLS's JDK. dap-java
      sends no `:javaExec`, and java-debug then uses its own JVM. Now
      `hellmacs-jvm--launch-on-project-jdk-a` (a `:filter-return` on
      `dap-java--populate-launch-args`) asks JDTLS for the project's
      (`vscode.java.resolveJavaExecutable`, as VS Code does). A `:javaExec`
      of yours wins. Unit test: `test-java/debug-launch-on-the-project-jdk`.
  - *Verified (2026-09-28):* with Temurin 8u504 and 11.0.32 (in a scratch
    directory, added through `hellmacs-jdk-roots`, and for Gradle
    `org.gradle.java.installations.paths`), SDKMAN's 21 and 25, and the
    system's 27:
    - legacy-8 (`JAVA_HOME` = JDK 8) and legacy-11-gradle (`JAVA_HOME` =
      21) pass every check;
    - JDTLS ran on 25 and 21 respectively;
    - the debugged programs reported 1.8.0_504 and 11.0.32.1;
    - with JDK 11 hidden from Gradle, the build refused ("Cannot find a
      Java installation ... languageVersion=11"), so it did compile on 11;
    - `java-e2e.el` (maven-demo, Java 21) still passes fully;
    - startup 0.029s.

    JDK 17 wasn't among them, so the *Verify* below (8, 11, 17, 21, 25) is
    still open.
- *Verify:* one machine with JDKs 8, 11, 17, 21 and 25; the legacy fixtures
  import, build, test and debug against their own JDK; a project with an
  `.envrc` switches JDK when you switch buffers.
  *Done (2026-09-28):* one run with Temurin 8u504, 11.0.32 and 17.0.20
  (in a scratch directory, through `hellmacs-jdk-roots`), SDKMAN's 21 and
  25, and the system's 27. Sync found all six. Then:
  - legacy-8 (`JAVA_HOME` = JDK 8) and legacy-11-gradle (`JAVA_HOME` = 21,
    its toolchain's JDK 11 in installations.paths) passed every check.
    JDTLS ran on 25 and 21; each project compiled against its own JDK;
    class files 52 and 55; the debugged programs reported 1.8.0_504 and
    11.0.32.1.
  - `java-e2e.el` (maven-demo, Java 21) passed fully: it compiled against
    SDKMAN's 21.
  - `direnv-e2e.el` passed: Maven ran on 1.8.0_504 in the `.envrc` project
    and on 27 in the other, and JDTLS stayed on 25.

  JDK 17 was installed, but no fixture targets Java 17.

#### 12.4 Spring Boot

**Findings first:**
- lsp-java's `lsp-java-boot`: what it needs (the Spring Boot language server
  jar shipped in VS Code's Spring Tools extension), whether that jar can be
  pinned from its release on its own, and what works through lsp-mode:
  properties and YAML completion, bean navigation, live hovers.
- What IntelliJ's `.run/*.run.xml` and Eclipse's `.launch` files contain for
  Spring Boot and JUnit.
  - *Found (2026-09-28), and what `:tools run` reads:*
    - IntelliJ keeps one `<configuration name type>` per `.run/NAME.run.xml`
      (in a `<component>`).
      - `Application` has `MAIN_CLASS_NAME`; `SpringBootApplicationConfigurationType`
        has `SPRING_BOOT_MAIN_CLASS` (some versions `MAIN_CLASS_NAME`).
      - Both have `VM_PARAMETERS` and `PROGRAM_PARAMETERS` (a command line),
        `WORKING_DIRECTORY` (with `$PROJECT_DIR$`/`$MODULE_DIR$`),
        `<envs><env name value/>`, `<module name/>`. Spring Boot's also has
        `ACTIVE_PROFILES`, comma-separated.
      - `GradleRunConfiguration` keeps its tasks under
        `ExternalSystemSettings`/`taskNames`, plus `scriptParameters` and
        an `env` map. `MavenRunConfiguration` keeps its goals under
        `MavenSettings`/`MavenRunnerParameters`/`goals`, plus
        `workingDirPath`.
      - `JUnit` holds a package, class or method to test, which `:tools
        build` already runs, so it's skipped.
    - An Eclipse `NAME.launch` has `<launchConfiguration type>`. A Java
      application (`org.eclipse.jdt.launching.localJavaApplication`, and
      Spring Tools' `org.springframework.ide.eclipse.boot.launch`) keeps
      `org.eclipse.jdt.launching.` attributes: `MAIN_TYPE`, `PROJECT_ATTR`,
      `PROGRAM_ARGUMENTS`, `VM_ARGUMENTS`, `WORKING_DIRECTORY` (with
      `${workspace_loc:...}`). Its environment is a `mapAttribute`
      `org.eclipse.debug.core.environmentVariables`. JUnit launches
      (`org.eclipse.jdt.junit.launchconfig`) are skipped, as in IntelliJ.
    - Read from those formats, not from files exported by the IDEs
      themselves: a real team's files are the first thing the 12.4
      *Verify* should try.

- [x] **Run configurations: `:tools run`.** (2026-09-28)
  - A run configuration is a main class or build task, arguments, JVM
    options, environment, active Spring profiles, and a working directory.
  - They are read from, in order:
    - `.hellmacs/run.eld` in the project, Hellmacs' own and committed with
      the code;
    - the project's IntelliJ `.run/*.run.xml`;
    - Eclipse `.launch` files.

    A team's existing shared configurations work on day one.
  - `C-c r r` runs one (with completion over the list), `C-c r d` debugs it
    (the same launch through dap-java, or `bootRun` / `spring-boot:run` with
    a JDWP agent, then attach), and `C-c r l` reruns the last.
  - Output goes to a comint buffer with ANSI colours, exception highlighting
    (`hellmacs-ux`) and clickable stack frames (`:tools build`'s rules).
  - `C-c r` is a new group owned by `:tools run`; it is free today.
  - *Done* (`modules/tools/run/`, on by default, depends on `:tools build`):
    - The readers for the three sources (above), merged in order, a
      name only once, with each configuration's `:source`. `.launch`
      files are searched two levels deep, skipping build output and VCS
      directories.
    - A main class runs as `java` with the project's JDK
      (`vscode.java.resolveJavaExecutable`) and the classpath JDTLS
      resolves (`vscode.java.resolveClasspath`), in `*run: NAME*`: comint,
      `compilation-shell-minor-mode` for clickable frames, and
      `hellmacs-ux`'s exception faces.
    - A task runs through the build's wrapper. Profiles and arguments go
      to `bootRun`/`run` as `--args=`, and to `spring-boot:run` as
      `-Dspring-boot.run.*`.
    - The environment is the configuration's over the calling buffer's
      (envrc's). comint starts its process from its own buffer, so the
      environment is set there.
    - Debugging a main class goes through dap-java (with the project's
      JDK, 12.3's advice). Debugging `run`/`bootRun` uses `--debug-jvm`,
      and `spring-boot:run` a JDWP `jvmArguments`; the debugger attaches
      once the output says "Listening for transport dt_socket at
      address: 5005" (probing the port could take the agent's one
      connection). Running again stops the previous run.
  - *Verified (2026-09-28):*
    - Unit tests in `test/test-run.el`: the three pre-written parser
      tests, now against the module; the self-checking keymap test
      replaced by the module's real `C-c r`; plus IntelliJ's and Eclipse's
      details and skipped types, the order and deduplication, the command
      lines (run and debug), a real task run through a fake `gradlew`
      (environment, envrc's, comint, clickable frames, `C-c r l`), and a
      main class without JDTLS.
    - `test/integration/run-e2e.el` passed on maven-demo and gradle-demo.
      The fixture's copy gets a Probe class and one configuration from
      each source. Checked:
      - each run got its own arguments, JVM options and environment, and
        IntelliJ's `$PROJECT_DIR$/src` working directory;
      - it ran on the JDK JDTLS gives the project (21 for maven-demo; 25,
        the JVM running Gradle, for gradle-demo, which has no toolchain);
      - `M-g n` opened Probe.java from the stack trace, and `C-c r l`
        reran;
      - `C-c r d` stopped at a breakpoint with the environment in place;
      - gradle-demo's `run` task ran, and debugging it attached and
        stopped at a breakpoint in App.java.
    - Startup 0.029s.
    - Not yet: `spring-boot:run` and `bootRun` against a real Spring Boot
      app (the 12.4 *Verify*'s fixture).
    - A test-harness note: the Gradle daemon JDTLS starts outlives the
      e2e scripts and can recreate `.gradle/` in the deleted copy. The
      e2e's own task runs with `--no-daemon`, but that one daemon remains
      (this affects java-e2e with gradle-demo too).

- [x] **Spring Boot language server** (`:lang java +spring`): (2026-09-28;
      unit tests only, `test/integration/spring-e2e.el` written but not run)
  - `application.properties` and `application.yml` completion and
    validation.
  - Navigation to beans and request mappings, through `lsp-java-boot`.
  - Pinned and installed by `sync` like the other servers.
- [x] **Profiles and actuator.** (2026-09-28: profiles, unit tests only;
      actuator not done) The run list offers each configuration once
      per Spring profile found in `application-*.yml`.
- *Verify:* a Spring Boot fixture (Maven and Gradle, with a profile and an H2
  database so it starts without infrastructure) runs, is debugged with a
  breakpoint in a controller, and reloads a changed class with hot swap. An
  IntelliJ `.run.xml` from the fixture runs unchanged. Property completion
  works in `application.yml`.

#### 12.5 Tests and coverage

- [x] **A test results view.** (2026-09-28: `:tools test`, `C-c t`;
      `test/test-results-view.el`, and the view read the real reports of
      java/maven-demo, java/gradle-demo and kotlin/gradle-demo, RET landing
      on the failing assertion. Rerun and refresh verified by unit tests only.
      Not yet: reports from dap-java test runs, which write none.)
  - After any test run (`:tools build`, dap-java or `:tools run`), the JUnit
    XML reports are read into a `tabulated-list-mode` buffer: suites, tests,
    time, and failures with their message.
  - Reports come from `build/test-results/**/*.xml` for Gradle and
    `target/surefire-reports/*.xml` / `failsafe-reports` for Maven. That is
    the format every build tool already writes, so it works for Java,
    Kotlin, Groovy and Scala alike.
  - `RET` jumps to the test, `r` reruns the one at point, `f` reruns the
    failures, `g` refreshes.
  - The echo-area `[TEST DAMNATION]` line gains "see *hellmacs-tests*".
- [x] **Coverage.** (2026-09-28: `C-c t c`/`s`/`h`; `test/test-coverage.el`.
      The per-file summary is its own view, `c` from the results. Not yet
      checked against a real JaCoCo run: that's the *Verify* below.)
  - Coverage comes from JaCoCo's XML report (`jacocoTestReport` in Gradle,
    `jacoco:report` in Maven; the module adds the task on the command line,
    never to the build file).
  - The report is read into fringe marks, or margin marks in a terminal:
    covered, partly covered and missed lines in the source buffers of the
    project.
  - `M-x hellmacs-coverage-show` and `-hide`, plus a per-file summary in the
    results view.
- [x] **Continuous testing (optional flag).** (2026-09-28: `(test +watch)`,
      `hellmacs-test-watch-mode`; a saved class also runs its ...Test class;
      unit tests only) `+watch` reruns the tests of
      the class you just saved, through the build tool's own test filter.
- *Verify:* the fixtures' passing and failing tests appear correctly for
  Gradle and Maven, reruns work, and the coverage marks match JaCoCo's own
  HTML report on the fixture.

#### 12.6 Enterprise tool belt

Each tool is its own module, off by default, and is picked in a findings
pass against what enterprise developers already use.

- [x] **`:tools http`: an HTTP client that reads IntelliJ's `.http` files**
      (the HTTP Client format shared with VS Code's REST Client).
  - Findings: how much of the format restclient.el, verb and others
    support. The criterion is running a team's existing `.http` files
    unchanged, including environments from `http-client.env.json`.
  - The best fit is adopted, extended where it falls short, and pinned.
  - *Found (2026-09-28):*
    - **restclient.el** (moved to emacsorphanage and maintained, MELPA
      2026-06) reads much of the format: `###` separators (any `#` line
      separates requests), `@var = value`, `{{var}}`, `< file` bodies,
      environment JSON files with `$shared`, and REST Client's
      `rest-client.environmentVariables`. It falls short in four ways:
      - IntelliJ's two env files (`http-client.env.json` and
        `http-client.private.env.json`) aren't found or merged;
      - no `{{$uuid}}`-style dynamic variables;
      - JavaScript response handlers (`> {% ... %}`) and `>> file` lines
        are sent as part of the body;
      - no named-request references.
      Its own mode keys include `C-c n n` (narrow), a `C-c <letter>` key; as
      with markdown-mode, a package's own mode keys stay as shipped.
    - **verb** and **walkman** are maintained, but they use their own Org
      formats, not `.http` files. ob-http is Org Babel.
    - **httpyac** (npm, MIT, `6.16.7`, 213 packages locked with integrity
      hashes; only protobufjs has an install script) runs IntelliJ and REST
      Client files unchanged. Checked against a local echo server with a
      real IntelliJ file: `http-client.env.json` plus
      `http-client.private.env.json`, `{{$uuid}}`, and a `> {% %}` handler
      whose `client.global.set` token reached the next request. It runs one
      request by line (`-l`) or all of them (`--all`).
    - **Adopted:** restclient for interactive requests, extended with
      IntelliJ's environments, dynamic variables, and handler lines
      stripped (with a note). With `+httpyac`, httpyac is pinned by lockfile
      like 10.1's servers and runs a request or the whole file with
      handlers, for full fidelity. That needs Node, which is why it's a
      flag.
  - *Done (2026-09-28):* `modules/tools/http/`, off by default.
    `hellmacs-http-mode` (derived from restclient-mode) for `.http` and
    `.rest` files. Its keys are the mode's own `C-c C-<letter>` keys, and it
    lists the file's requests in imenu.
  - *Verified so far:*
    - Unit tests: `test/test-http.el`.
    - A throwaway profile with `(http +httpyac)` synced for real: restclient
      from its recipe, and httpyac installed and verified from the lockfile.
      Doctor was clean.
    - Against a local echo server, `C-c C-c` sent an IntelliJ file's Login
      request. The password came from the private env file, `{{$uuid}}` was
      filled in, and the handler was left out, with a note.
    - `C-c C-a` ran the whole file with httpyac, and the Login handler's
      token reached the Me request.
  - *Not yet:* the container-based end-to-end script (12.6's *Verify*).
- [x] **`:tools db`: a database client over JDBC.**
  - JDBC is how enterprises reach Oracle, SQL Server, DB2, PostgreSQL and
    MySQL, and there's always a JVM on hand.
  - Findings: ejc-sql (JDBC through Clojure), versus built-in `sql.el` with
    each database's CLI.
  - Connections are defined per project in `.hellmacs/db.eld`, with
    passwords from `auth-source` (never in the file).
  - Results go in a table buffer; queries run from `sql-mode` buffers.
  - *Found (2026-09-28):*
    - **ejc-sql** is maintained (2026-09), but it needs Leiningen and
      resolves JDBC drivers at runtime through Aether, from any repository.
      That's the unpinned fetching Hellmacs rules out.
    - **sql.el with each database's CLI** needs psql, mysql, sqlplus,
      sqlcmd and db2 installed. Enterprise laptops rarely have Oracle's or
      DB2's, and each behaves differently.
    - **sql.el with sqlline** (Apache's JDBC shell, `sqlline:sqlline:1.12.0`,
      BSD, one 3MB jar with its dependencies) keeps sql.el's `sql-mode` and
      SQLi buffers and reaches every database over JDBC.
      - Checked over a pipe, as comint drives it, on H2: `!connect URL USER
        PASSWORD` sent on stdin connects without echoing the password, and
        nothing shows in `ps`.
      - `--outputformat=table` draws result tables. It needs `--maxWidth`:
        under a dumb terminal the width is 0 and rows come out empty.
      - Multi-line statements end at `;`, and errors print their SQL state.
      - JLine's and JDK 24+'s native-access warnings are silenced with
        `-Dorg.jline.terminal.dumb=true` and
        `--enable-native-access=ALL-UNNAMED`.
    - **Drivers**, pinned by SHA-256 from Maven Central (each SHA-1 matches
      Central's): PostgreSQL 42.7.13, MySQL Connector/J 26.7.0, MariaDB
      3.5.10, SQL Server 13.6.0.jre11, Oracle ojdbc11 23.26.3.0.0, DB2 jcc
      12.1.5.0 (not the newer `_special_` build), H2 2.5.252, SQLite
      3.53.4.0. H2 and ojdbc11 need Java 11+.
    - **Adopted:** sql.el and sqlline. Sync installs sqlline and the drivers
      in `hellmacs-db-drivers`; others are installed, pinned, on first
      connect.
  - *Done (2026-09-28):* `modules/tools/db/`, off by default. sqlline is an
    sql.el product (`sqlline`). `hellmacs-db-mode` in `sql-mode` buffers
    remaps `sql-send-paragraph` and `sql-send-buffer`, so no key is added.
    The "java of at least release N" choice moved to core
    (`hellmacs-jdk-java-executable`), shared with `:editor format`.
  - *Verified so far:*
    - Unit tests: `test/test-db.el`. The connect test uses a fake sqlline
      that records its stdin: the login arrives there, and the password is
      never in the buffer.
    - A throwaway profile synced sqlline and PostgreSQL's driver for real.
      A project's H2 connection installed H2's driver on first use, and
      `C-c C-c` in a `sql-mode` buffer ran a create, an insert and a
      multi-line select, with the result as a table.
    - That live run found two bugs, now fixed and tested:
      - the SQL product helper lacked an autoload cookie, so a synced
        profile failed when opening a `.sql` file;
      - an empty password made sqlline take the next statement as the
        password.
  - *Not yet:* PostgreSQL in a container (no Docker daemon on this machine),
    and 12.6's end-to-end script.
- [ ] **`:tools docker` and `:tools kubernetes`.**
  - Phase 10.1's `:lang docker` handles the files.
  - These add containers, images and logs (docker.el), and pods, logs, port
    forwards and exec (kubel or kubernetes-el).
  - Both work through the developer's own `docker` / `kubectl` and their
    context.
- [ ] **`:checkers static`.**
  - SonarLint through its language server (lsp-sonarlint), pinned, as
    flymake diagnostics, with connected mode to a company SonarQube or
    SonarCloud where one exists.
  - Checkstyle, PMD and SpotBugs results from the build tool's own reports,
    as compilation errors and flymake diagnostics, using the rules
    configured in the build. Nothing is duplicated in Emacs.
- *Verify:* per module, one end-to-end script against a local service in a
  container: an HTTP echo server, PostgreSQL, a kind cluster, a SonarQube
  community edition.

#### 12.7 Scale and performance

- [ ] **A reference monorepo** for measurements: a public large project
      (Spring Framework itself, or Apache Kafka, both Gradle; Apache Camel,
      Maven) added to `java-parity.el`'s runs.
- [ ] **Budgets, measured in CI weekly and recorded here:**

  | Measurement | Budget |
  |---|---|
  | Emacs startup, synced profile, all enterprise modules on | < 0.3 s |
  | JDTLS first import of the reference monorepo | within 1.5x IntelliJ's own import on the same machine |
  | Completion latency (p95) in a large class | < 200 ms |
  | Memory, Emacs plus JDTLS, after import | < IntelliJ's for the same project |
- [ ] **Tuning** that the measurements justify:
  - Exclude generated directories from JDTLS and file watching.
  - JDTLS heap auto-sized from the project (`hellmacs-jvm-vmargs`), and
    Gradle's build cache and configuration cache on for imports.
  - Phase 11.4's compiled startup and cached lookups.
- [ ] **Kotlin's server.** Track JetBrains' own Kotlin LSP. When it is
      released and pinnable, it replaces kotlin-language-server in
      `:lang kotlin` behind the same status and keys, and the matrix's Kotlin
      row is re-checked.
- *Verify:* the budget table is filled in from real runs; a regression past
  a budget fails the weekly job.

#### 12.8 Team adoption

- [ ] **A team layer.**
  - `$HELLMACS_TEAM_DIR` (or a git URL in `init.el`) holds a team's shared
    modules, `packages.el`, lock file, mirrors and proxy defaults.
  - It is loaded between Hellmacs and the user's config, so each developer
    still overrides what they need.
  - It builds on the private-module support that already exists
    (`test-modules/private-module-overrides-and-modulep!`).
  - `bin/hellmacs upgrade` updates it with the rest.
- [x] **Formatting shared with IDE users.** (2026-09-28: a committed Eclipse
      profile is found and JDTLS formats Java with it; `.editorconfig` waits for 10.3)
  - Phase 10.2's formatters, plus JDTLS's own Eclipse formatter profiles
    (`lsp-java-format-settings-url` and `-profile`). Eclipse exports them,
    and IntelliJ imports and exports the same XML.
  - A team keeps one formatter file for everyone, whatever their editor.
  - `.editorconfig` applies in every mode (built in, Phase 10.3).
- [ ] **Keys for migrants, without breaking the keybinding policy.**
  - There's no IntelliJ keymap. A cheat sheet (12.10) maps IntelliJ and
    Eclipse actions to their Hellmacs keys, and
    `M-x hellmacs-where-is-intellij` answers "what is Shift-F6 here?"
    (rename: `C-c l r r`).
  - which-key already shows every `C-c` group.
- [x] **Configs keep up with new default modules.** (Added 2026-09-28; done the same day, moved to the front at the user's request.)
  - The gap: a new module is enabled by default in `static/init.example.el`,
    but that file is only copied when a user has no config yet, and nothing
    rewrites an existing `init.el` (rightly). So a config made before a
    module existed never gets it, and nothing says so.
  - Found on a real config from an early template: no `:tools` section at
    all. It had no version control manager (`:tools magit`: Magit, `C-x g`),
    no build, debugger, direnv or LSP, and no `:lang` modules. The Linux
    distribution had no Magit either.
  - `doctor`, under Configuration:
    - lists each module that `static/init.example.el` enables but your
      `hellmacs!` block neither enables nor mentions in a comment (a
      commented-out module is a choice, so it isn't listed);
    - shows it with its one-line description and the line to add, e.g.
      `:tools magit ; Git via Magit: C-x g status ...`.
    - It's an info note, not an error.
  - `bin/hellmacs upgrade` prints the same list after updating, since that
    is when new defaults arrive.
  - `bin/hellmacs config --add-defaults`, only when asked, inserts those
    lines into the right group of your `hellmacs!` block (creating the
    group, like `:tools`, if it's missing). It keeps your other lines and
    comments, keeps `init.el.bak`, and ends by saying to run
    `bin/hellmacs sync`, which installs the new packages (Magit and its
    dependencies included). Nothing changes your `init.el` otherwise.
  - *Verify:* unit tests with an `init.el` from an early template (no
    `:tools`, no `:lang`). Doctor lists `:tools build debugger direnv lsp
    magit` and the default `:lang` modules, and not the ones commented out.
    `config --add-defaults` gives a block that enables them with everything
    else intact. A sync after it installs Magit, and `C-x g` opens a
    repository's status.
  - *Done:*
    - `core/hellmacs-config.el` reads the defaults from
      `static/init.example.el`'s block, with each module's line.
    - It finds your block's modules, and the ones you commented out, by
      reading the `hellmacs!` form itself.
    - `bin/hellmacs config` lists what's missing; doctor lists it under
      Configuration; `upgrade` prints it after updating.
    - `--add-defaults` adds the lines, merged per place, bottom up. A
      keyword sharing a line with `(hellmacs!` is moved to its own line.
      The file is checked afterwards and restored from the backup if it
      doesn't read back complete.
  - *Verified (2026-09-28):*
    - Unit tests in `test/test-config.el` (six, written first): the
      defaults, what's missing (with a commented module and no block),
      the report, adding to new groups and to an existing one (with a
      backup already there), the CLI.
    - A copy of the real early-template config: `config` listed the 8
      missing modules and `--add-defaults` added them. The diff touched
      only the block: `:tools` and `:lang` went before `:config`.
    - A sync of it installed Magit, `C-x g` ran `magit-status` and opened
      the repository's status, and doctor's Magit check passed. Doctor on
      the real config lists the 8.
    - Not run: the `upgrade` message after a real update (it prints the
      same lines as doctor).

- [ ] **Onboarding in one command.** `bin/hellmacs install --team URL`:
      clone, install, sync, env, doctor, and a first-run page on the
      dashboard with the keys a new user needs this week.
- *Verify:* a fixture team repository with a module, a lock file and a
  formatter profile. A fresh user installs from it with one command, and a
  file formatted in Hellmacs is byte-identical to the same file formatted
  by Eclipse's formatter with that profile.

#### 12.9 Security and compliance

- [ ] **SBOM.** `bin/hellmacs sbom` writes a CycloneDX (JSON) bill of
      materials for everything installed: Emacs packages at their locked
      commits, language servers, jars, grammars, with versions, sources and
      SHA-256 sums. It is also produced with every release (12.10).
- [ ] **License report.** `bin/hellmacs licenses`: each component's license,
      from its package headers or its release, flagged when unknown. It is
      checked in CI so a new dependency with a problematic license is seen
      before it ships.
- [ ] **No telemetry, stated and enforced.**
  - Hellmacs sends nothing. Packages that could (lsp-mode's and servers'
    own features, if any) are configured off, and the findings pass lists
    each one.
  - The 12.1 proxy test doubles as a check: during a normal editing session,
    only the configured hosts are contacted.
- [ ] **Supply chain.**
  - All downloads are pinned by SHA-256, and packages by commit
    (`bin/hellmacs lock`). Release tags are signed.
  - `bin/hellmacs verify` re-checks every installed file against the lock
    and the pins.
- [ ] **Releases and support window.**
  - Semantic versions, a changelog, and a stable channel (tagged releases)
    next to `main`.
  - Each release states the Emacs versions and platforms it supports, and a
    security-fix window for the previous release.
  - `bin/hellmacs upgrade --channel stable` is the enterprise default.
- *Verify:* the SBOM validates against the CycloneDX schema; `verify`
  catches a modified jar; the license report is complete for the full
  module set.

#### 12.10 Documentation

The README stays the front page; the docs move to `docs/`, written for three
readers.

- [ ] **Developers:**
  - `docs/getting-started.md`.
  - `docs/migrating-from-intellij.md` and `docs/migrating-from-eclipse.md`:
    concepts (project, run configuration, tool windows), the action-to-key
    cheat sheet, and what to expect to be different.
  - Per-module pages.
- [ ] **Administrators** (`docs/admin-guide.md`):
  - proxy, CA, mirrors, offline bundles (12.1);
  - the team layer (12.8);
  - SBOM, licenses and verification (12.9);
  - rolling out to many machines;
  - the support policy.
- [ ] **Evaluators** (`docs/feature-matrix.md`): the matrix above, kept
      current, with each row linked to the script that checks it.
- [ ] **Troubleshooting:** every `doctor` failure has an entry, linked from
      `doctor`'s own output.
- *Verify:* each guide is followed from scratch on a clean machine by
  someone who didn't write it, and every step that didn't work is fixed.

#### 12.11 Enterprise pilot and 1.0

- [ ] **Pilot codebases.** At least three, chosen to cover the objective's
      criteria:
  - a Spring Boot Maven multi-module monolith;
  - a set of Gradle (Kotlin DSL) microservices;
  - a legacy Java 8 application.

  Each is built with internal repositories only, behind a proxy with a
  corporate CA, on macOS and on Linux or WSL2.
- [ ] **A working week per codebase.** One developer uses Hellmacs as their
      only IDE for a week of real tickets and logs every time they reached
      for another tool, and why. Every entry becomes a fix, a matrix row, or
      a documented gap.
- [ ] **Exit criteria for 1.0:**
  - Each of the objective's six criteria is met, with its evidence linked:
    CI runs, end-to-end scripts, measurements, the pilot logs.
  - No open "reached for the IDE" entry is rated blocking.
  - The admin guide, SBOM and license report ship with the release.
- *Verify:* the pilot logs and the exit checklist are recorded here. 1.0 is
  tagged only when the checklist is complete.

#### Not in this phase

- **An IntelliJ keymap or emulation.** It would break the keybinding
  policy; migrants get the cheat sheet and `hellmacs-where-is-intellij`
  instead.
- **Paid-IDE-only features without an open server or tool behind them**:
  IntelliJ's own inspections engine, its profiler UI, and JPA/Hibernate
  diagram tools. They go in the feature matrix as gaps, with the open
  alternative where one exists (async-profiler's flame graphs, for example).
- **A graphical project-tree-first workflow.** `project.el`, `C-x p` and
  Consult cover navigation; treemacs stays an opt-in dependency.

#### Risks

- **JDTLS installed by our own pinned download (12.1)** means following its
  releases ourselves instead of relying on lsp-mode's installer. It is the
  same trade already made for Kotlin, Clojure and java-debug, and it's what
  makes mirrors and offline installs possible.
- **Spring Boot's language server ships inside a VS Code extension.** If it
  can't be pinned on its own, `+spring` falls back to what JDTLS and the
  build give, and the matrix says so.
- **Coverage and static analysis depend on the build's plugins.** Adding
  JaCoCo from the command line works for standard builds; exotic builds may
  need a documented one-line change, never an automatic edit.
### Phase 13: The Hellmacs Manual & Purist Vanilla Onboarding

**Objective:** Guarantee that any developer who has used GNU Emacs for decades
feels instantly respected and productive, while having comprehensive, offline,
in-editor documentation formatted according to GNU standards.

#### 13.1 The Hellmacs GNU Info Manual
- [ ] Author and compile a complete GNU Texinfo manual (`docs/hellmacs.texi`)
      generating `hellmacs.info`.
- [ ] Add `hellmacs.info` to Emacs' `Info-directory-list` so it appears inside
      the standard Info top-level directory (`C-h i` / `M-x info`).
- [ ] Bind `C-h H` (or `C-c h ?`) directly to the Hellmacs Info manual node.
- [ ] Structure the manual into chapters:
  1. *The Purist Guarantee & Architecture*
  2. *The JVM Nether-Stack (JDTLS, DAP, CIDER, Kotlin, Lombok)*
  3. *Keybinding Policies & Prefix Maps (`C-c` leader)*
  4. *Enterprise Workflows (Proxies, Offline Bundles, Multi-JDKs)*
  5. *Module System & Private Customization*
  6. *Troubleshooting & FAQ*

#### 13.2 Vanilla Emacs Discoverability on The Altar
- [ ] Enhance The Altar (`*hellmacs*`) and `:ui dashboard` to provide direct
      access to classic vanilla GNU Emacs onboarding options alongside project
      launchers:
      - `[ Emacs Tutorial ]` (`help-with-tutorial` / `C-h t`)
      - `[ Guided Tour ]` (GNU Emacs Guided Tour)
      - `[ Hellmacs Manual ]` (`info hellmacs` / `C-h H`)
      - `[ Open Directory / Dired ]` (`dired` / `C-x d`)
      - `[ Customize ]` (`customize` / `C-h c`)
- [ ] Ensure `special-mode` navigation (`TAB`, `S-TAB`, `RET`, `q`, `g`) remains
      100% compliant with standard Emacs keys.

#### 13.3 Purist Help System Integration (`C-h`)
- [ ] Integrate Hellmacs module lookups into standard `C-h` help commands:
  - `C-h m` (`describe-mode`): Enhanced summary of active LSP servers, DAP
    sessions, and active Hellmacs module flags.
  - `C-h P` (`describe-package`): Clean metadata from Elpaca recipes.
  - `C-h l` (`hellmacs-describe-module`): Interactive documentation browser
    for declared `:ui`, `:editor`, `:tools`, and `:lang` modules.

---

### Out of scope

- straight.el
- Doom's `compat` module and v2 deprecation shims
- The docs system (`doom-docs.el`)
- Windows-specific hacks, until 12.2's second stage decides on native
  Windows (WSL2 is supported from 12.2 on)
- The full `defcli!` framework
- The `:doom` and `:user` virtual modules. Depth numbers are enough.

## Risks

Phase 12 has its own risks, specific to the enterprise objective (see
"Phase 12: Enterprise readiness"). These are the framework's.

- **Phase 3 was the hard part.** Elpaca is asynchronous, so the profile can
  only be written after `elpaca-wait` returns and every build step has
  finished. Autoload order must follow Elpaca's dependency graph. Shared
  dependencies must be declared up front (see the `compat` fix above).
- **The XDG move reinstalls every package once.**
