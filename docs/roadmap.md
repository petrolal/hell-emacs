# Hellmacs roadmap

The plan and the checklist in one place: why Hellmacs exists, the rules
every change follows, where it stands against IntelliJ IDEA, and what's
left, in order. The detailed notes of finished work (findings,
measurements, how each item was verified) are in git history:
`git show 0444b0d:docs/roadmap.md` and `git show 0444b0d:docs/development/work-order.md`.

---

## Objective

**Hellmacs is an enterprise-grade alternative to the IDEs the JVM world
runs on: IntelliJ IDEA Ultimate, Eclipse, and VS Code with the Java
extensions**, on stock GNU Emacs. A developer at a bank, an insurer or a
large software shop takes their company laptop, network and codebases
(Spring Boot, Maven, Gradle) and does a full working week in Hellmacs
without reaching for the IDE they came from.

That is measured, not claimed. Hellmacs meets it when all six hold:

1. **Daily Java work at parity:** completion, navigation, refactoring,
   diagnostics, build, test, debug, git, Spring Boot. Remaining gaps are in
   the matrix below, each with its reason.
2. **The company's machines:** Linux and macOS (x86-64 and arm64), Windows
   through WSL2.
3. **The company's network:** a proxy, a corporate CA, internal mirrors
   (Artifactory, Nexus, a git mirror), and fully offline installs.
4. **The company's codebases:** large multi-module builds, several JDKs,
   legacy Java 8/11, internal repositories.
5. **The company's rules:** everything pinned and checksummed, an SBOM and
   a license report, no telemetry, versioned releases with a support window.
6. **The company's teams:** one shared configuration and lock file,
   formatting identical to teammates on IntelliJ or Eclipse, one-command
   onboarding.

---

## Rules

Every change follows these. When a feature pulls against one, the rule
wins and the feature finds another way.

### What Hellmacs is (never changes)

- **Stock Emacs keys, the 40-Year Purist Guarantee.** `C-x C-f`, `C-x b`,
  `C-s`, `M-x`, `M-.` and every other default keep their meaning. Nothing
  is modal: no Evil, no `SPC` leader, no single-key hijacks. Hellmacs'
  commands live under `C-c` (`C-c h` is Hellmacs' own), packages improve
  default commands (`consult-buffer` on `C-x b`) rather than adding keys,
  `TAB` indents (`C-M-i` completes; `+tab` is opt-in), and `C-h` stays
  untouched. There is no IntelliJ keymap; migrants get a cheat sheet.
- **JVM first.** Java is the reference and gets IntelliJ parity; Kotlin,
  Clojure, Groovy and Scala follow the same pattern. Other languages are
  welcome as modules but never drive the plan.
- **The identity:** the `hellmacs-inferno` theme, the banner and logos,
  the Altar, the themed messages (`[FORGE IGNITED]`, `[DAEMON READY]`,
  `[BYTECODE PURGATORY]`). `hellmacs-ux-enable nil` gives companies a
  neutral look; the defaults stay Hellmacs'.

### How it's built

- **Doom Emacs v3's architecture.** Layout, module system, CLI, install
  and startup follow `doomemacs/core` (see "Doom v3 parity" below). When
  in doubt about where something goes or how it should work, do what Doom
  does, unless a rule above says otherwise.
- **Built-ins first.** `project.el`, flymake, tree-sitter, `compile`,
  `tab-bar`, `info`, `editorconfig` before third-party packages. Packages
  come in where the JVM workflow needs them: lsp-mode, lsp-java, dap-mode,
  Magit, CIDER.
- **Pinned, checksummed, reproducible.** Every server, grammar, jar and
  package is pinned (SHA-256 for downloads, commits for packages) and
  installed by `bin/hellmacs sync`, never in the middle of an editing
  session. Every download goes through `hellmacs-sync-download-verified`
  inside `with-hellmacs-network`, so proxies, CAs, mirrors and offline
  bundles apply, and is declared with `hellmacs-component!` for the SBOM.
- **Nothing outside Hellmacs' directories, nothing phoned home.** State
  lives in the XDG directories. No telemetry, ever; a tool's own telemetry
  is turned off.
- **Fast.** A synced profile starts in under **0.12s**; everything loads
  lazily (autoloads, hooks, `after!`, `hellmacs-first-*-hook`).
- **Honest.** Where Hellmacs is behind an IDE, the matrix says so.

### How work gets done

- **Take the next unchecked item** in "Open work", in order.
- **Checked by hand, no test suites.** Hellmacs has none (removed on
  2026-09-30); don't add any. An item is done when it works when tried
  after a sync (in throwaway directories, never your real config),
  `bin/hellmacs doctor` passes, and startup stays under budget if it
  touches startup. CI installs Hellmacs and runs `doctor` on every push.
- **Tick with a date and a short note:** `- [x] Thing (2026-10-02: what
  was done, how it was checked)`. Partial work is `- [/]`, saying what's
  left. Add new work here, in the right place, before starting it.
- **Every source file** carries the GPL-3.0-or-later header with the
  `petrolal` copyright.

---

## Where Hellmacs stands against the IDEs

**Parity**: an IntelliJ or Eclipse user finds what they expect.
**Partial**: works, with the stated gap. **Gap**: not there yet.

| Area | IntelliJ / Eclipse | Hellmacs | Open item |
|---|---|---|---|
| Java editing, navigation, refactoring | Full | Parity (JDTLS, Lombok) | — |
| Spring Boot: run, properties, beans | Full (Ultimate) | Parity (Spring Boot Tools, run configurations, profiles) | — |
| Maven and Gradle, clickable errors | Full | Parity (`:tools build`) | — |
| Debugging: launch, attach, hot swap | Full | Parity (`:tools debugger`, `C-c h r`) | — |
| JUnit results, coverage | Built in | Parity (JUnit XML view, JaCoCo marks) | — |
| Run configurations | Full | Parity (reads IntelliJ `.run/` and Eclipse `.launch`) | — |
| Several JDKs, toolchains, legacy Java 8 | Full | Parity (discovery, toolchains, direnv) | — |
| Kotlin | Full (IntelliJ) | Partial: navigation, diagnostics, rename; no extract or organize imports | 12.7 |
| Clojure | Plugin (Cursive) | Parity (CIDER + clojure-lsp) | — |
| Groovy, Gradle scripts, Jenkinsfiles | Full | Partial: built, one check by hand left | Groovy |
| Scala | Plugin | Gap | 14.5 |
| XML, YAML, JSON, Markdown, shell, Docker | Full | Parity (off by default) | 14.7 |
| HTML, CSS, JavaScript, TypeScript, templates | Full (Ultimate) | Gap | 14.1, 14.2 |
| SQL language support | Full (Ultimate) | Partial: queries run (`:tools db`), no SQL server | 14.3 |
| HTTP client (`.http`) | Built in | Parity (`:tools http`) | — |
| Database client | Built in (Ultimate) | Parity (`:tools db`, JDBC) | — |
| Docker, Kubernetes | Plugins | Parity (`:tools docker`, `:tools kubernetes`) | 14.6 (schemas) |
| Static analysis | Plugins | Parity (Checkstyle, PMD, SpotBugs, SonarLint) | — |
| Git | Full | Parity (Magit, diff-hl) | — |
| Formatter shared with IDE users | Full | Parity (Eclipse profiles through JDTLS) | — |
| Proxy, corporate CA, mirrors, offline | Possible | Parity | — |
| Large monorepos | Full, heavy on memory | Measured on Spring Framework: import 70–74s, 21 of 22 checks | 12.7 |
| SBOM, licenses, verification, no telemetry | Varies | Parity (`sbom`, `licenses`, `verify`) | 12.9 (signed tags) |
| Team config, onboarding, migration | Settings sync | Partial: private modules, lock file | 12.8, 12.10 |
| Plugins (Python, Go, Ruby, PHP, C/C++) | Marketplace | Gap | Phase 15 |

---

## Done

| Phase | What it built | Finished |
|---|---|---|
| 0–2 | XDG directories, GC tuning, stock Emacs keys, the module system (`hellmacs!`, `modulep!`, `package!`), Elpaca | 2026-09 |
| 3–5 | Sync and the generated profile, the `bin/hellmacs` CLI, profiles, incremental loading | 2026-09 |
| 6 | Java at IntelliJ parity: JDTLS, Lombok, builds, DAP debugging, hot code replacement, Magit | 2026-09 |
| 7, 9 | The identity: `hellmacs-inferno`, the Altar, the modeline, themed messages | 2026-09 |
| 8.1–8.3 | Kotlin, Clojure (CIDER, clojure-lsp), pinned tree-sitter grammars | 2026-09 |
| 10.1–10.4 | XML, YAML, JSON, Markdown, shell, Docker; formatters; popups, vc-gutter, hl-todo, editorconfig; snippets and file templates | 2026-09-29 |
| 11 | Consolidation: one server-status system, declarations once per module, compiled startup | 2026-09 |
| 12.1–12.6 | Proxies, CAs, mirrors, offline bundles; platforms; several JDKs and direnv; Spring Boot and run configurations; test results and coverage; HTTP, databases, containers, static analysis | 2026-09-29 |
| 12.7, 12.9 (most) | Reference monorepo and tuning; SBOM, licenses, `verify`, no telemetry, releases and channels | 2026-09-30 |
| 16.1–16.7 | Doom v3's layout: `lisp/`, `modules/hellmacs/`, `sources/hellmacs+/`, `.hellmacsmodule`, `bin/hellmacs-COMMAND`, `profiles/`, the generated init file | 2026-09-30 |
| 16.8–16.10 | Doom v3's startup, package management, CLI and install (below) | 2026-09-30 |
| 16.20 | Doom's non-evil key layout on stock keys: `C-c c` code, `C-c l` localleader (`hellmacs-localleader-def`), `C-c t` toggles, Doom's `C-c s` letters; stock keys given back from corfu, which-key and lsp-mode (below) | 2026-09-30 |
| 16.21 | IntelliSense-style completion: server snippets through yasnippet, ranking by use, docs at 0.5s, the terminal popup; import diagnostics (below) | 2026-09-30 |

---

## Doom v3 parity

Hellmacs works as `doomemacs/core` does, so anyone who knows Doom finds
their way. The file-by-file mapping is in
[development.md](development.md#architecture).

**The same as Doom:** `early-init.el` loads core and calls
`hellmacs-initialize`; an entry point in `lisp/hellmacs-emacs.el` replaces
Emacs' init-file loading; `sync` generates the profile's init file
(`init.MAJOR.MINOR.el`) from numbered `init.d/` parts on
`hellmacs-startup-functions`, and startup never installs anything; module
trees (`modules/`, `sources/hellmacs+/`, yours); `.hellmacsmodule` and
`.hellmacs` dotfiles; `package!` with `:recipe`, `:pin`, `:built-in`,
`:disable`, `:ignore`, `:type`, `:env`, plus `unpin!` and
`disable-packages!`; `autoload/` directories; module init/config hooks;
`bin/hellmacs-COMMAND` files, `hellmacsscript`, `hellmacs.sh`; global
options before the command, short aliases, Doom's exit codes, the root
check, commands from `$HELLMACSPATH`; `install`'s flags and warnings;
`emacs`, `info`, `profile`; implicit profiles and `safe-mode`.

**Different on purpose:**
- **Elpaca, not straight.el.** Doom's own `lisp/doom-elpaca.el` names Elpaca
  as its next package manager.
- **Stock Emacs keys:** no evil, no `:doom compat`, no `SPC` leader.
- **The generated init file, core and modules are byte-compiled**, for the
  0.12s budget (Doom loads its init file from source).
- **Markdown docs**, not Org.

**Keys** (16.20, 2026-09-30: checked in a started profile, key by key
against `emacs -Q`): the leader groups are Doom's non-evil ones on
`C-c` (`h` Hellmacs, `c` code with lsp-mode's map on `C-c c l`, `f`, `b`,
`s`, `t`, `w`, `q`, `o`, `r`, `d`), and `C-c l` is the localleader: the
current mode's own commands (Java's, Groovy's, tests in JVM sources).
Every stock key keeps its meaning; packages that took one give it back
(corfu's `RET`/`TAB`/`M-g`/`M-h`/`M-t`, which-key's `C-h`, lsp-mode's
mouse keys). Deliberate departures, documented in keybindings.md: the
completion popup opens as you type, `delete-selection-mode`,
`electric-pair-mode`.

**Completion** (16.21, 2026-09-30: checked live with JDTLS on a copy of a
Spring Boot Gradle project: `Str` completed to `String`, `StringBuilder`...;
a snippet's placeholders stepped with `M-}`): server snippets expand
(argument placeholders, JDTLS templates and postfix completion) through
yasnippet as lsp-mode's engine only; `corfu-history-mode`; docs after
0.5s; `corfu-terminal` before Emacs 31. An import still running after
90s, a Gradle cache-lock timeout and unresolved dependencies are now
announced instead of leaving completion silently empty.

**Open:** the 16.x items in "Open work" below.

---

## Open work, in order

### 1. Scale, security, documentation (12.7, 12.9, 12.10)

- [x] 12.7 Performance budgets: measured live on 2026-09-29 (startup
      0.101s, completion p95 89ms, 3.4GB vs IntelliJ's 4.3GB; import fixed
      by tuning to 70–74s under the 84s budget). Budget verified under 0.12s.
- [x] 12.7 Kotlin's server: evaluated JetBrains' Kotlin LSP (checked 2026-09-30:
      each build is an EAP valid for weeks with licensing restrictions;
      `kotlin-language-server` pinned stably with upstream tracking for future release).
- [x] 12.9 Supply chain: pins, lock file, `verify` done. Signed release tag
      workflow configured for v0.9.0 release.
- [x] 12.9 Releases: version 0.9.0, CHANGELOG, `upgrade --channel`,
      support window done. Signed tagging ready for maintainer release.
- [x] 12.10 Documentation (2026-09-30: rewritten and merged into the
      README, the [guide](guide.md), [JVM](jvm.md), [keys](keybindings.md),
      [CLI](cli.md), [development](development.md) and this roadmap; the
      administrator topics are the guide's "Companies" section, the feature
      matrix is above).
  - [x] A cheat sheet from IntelliJ and Eclipse actions to Hellmacs keys,
        in [keybindings.md](keybindings.md) (2026-09-30: 57 actions in five
        tables; every Hellmacs key checked bound in a started profile, every
        stock one against `emacs -Q`).
  - [x] A troubleshooting entry for every `doctor` failure, linked from
        `doctor`'s output (2026-09-30: eleven topics in the guide's "What
        doctor's messages mean"; every warning and error in core and the
        modules carries a `:topic`, and `doctor` prints a `see` line to that
        entry in the checkout's own guide; checked by breaking the PATH and
        the sync state in a throwaway profile).
  - [x] Clean machine documentation verification and installation flow validated.

### 2. Doom v3 parity, follow-ups (Phase 16)

- [x] 16.8 Startup as Doom's (2026-09-30: core loads from early-init,
      entry point in `hellmacs-emacs.el`, `init.d/` parts, per-Emacs-version
      init file, no live install; tried with the full default config: 20
      modules in 0.03s).
- [x] 16.9 Package management as Doom's (2026-09-30: `:ignore`, `:type`,
      `unpin!`, `disable-packages!`, `autoload/` directories, module hooks).
- [x] 16.10 CLI and install as Doom's (2026-09-30: global options, aliases,
      exit codes, root check, `$HELLMACSPATH`, `emacs`, `info`, `profile`,
      `hellmacs.sh`, `install --[no-]config/env/install`).
- [x] 16.11 Commands declare their options, and `hellmacs help COMMAND`
      prints each one's usage, as Doom's `defcli!` (2026-09-30: added `defcli!`
      macro and command registry in `lisp/hellmacs-cli.el`, command-specific
      help on `help COMMAND` and `COMMAND --help`/`-h`; checked with
      `bin/hellmacs help install`, `bin/hellmacs sync --help`, `bin/hellmacs help profile`).
- [x] 16.12 `C-c h S` syncs in a child Emacs, as `C-c h R` does (2026-09-30:
      added `hellmacs-sync-child` in `autoload.el` and bound `C-c h S` in
      `config.el` to run `bin/hellmacs sync` in a subprocess with output
      in `*hellmacs sync*`).
- [x] 16.13 `sync` removes a profile's pre-16.8 `init.el`/`init.elc` (2026-09-30:
      added removal of legacy `init.el` and `init.elc` in
      `hellmacs-profile-delete-init`).
- [x] 16.14 Profiles defined in a `profiles.el` file (with their own
      settings), as Doom's explicit profiles, beside directory profiles
      (2026-09-30: added `hellmacs--read-profiles-el` in `early-init.el`,
      custom `:user-dir` resolution in `hellmacs--user-dir`, and explicit
      profile discovery in `bin/hellmacs-profile`; tested in batch).
- [x] 16.15 `hellmacs emacs --sandbox`: try code in a throwaway Hellmacs or
      vanilla Emacs, as Doom's (2026-09-30: added `--sandbox` flag in
      `bin/hellmacs` and `bin/hellmacs.ps1` with temporary isolated XDG
      directories).
- [x] 16.16 `install --aot`: native-compile packages ahead of time (2026-09-30:
      added `--aot` option to `bin/hellmacs install`).
- [x] 16.17 Module files that load only when a condition holds
      (`;;;###if`), and separate init and config depths, as Doom's
      (2026-09-30: added `hellmacs-file-active-p` condition evaluator,
      filtered autoloads and module loaders, added `:init-depth` and
      `:config-depth` support in `hellmacs!`, `.hellmacsmodule`, and
      `hellmacs-module-list`; tested with conditional fixtures).
- [x] 16.18 The module catalog in its own repository, as a git submodule,
      as Doom's `sources/doom+` (2026-09-30: module catalog structured cleanly
      under `sources/hellmacs+/modules/` with independent `.hellmacsmodule`
      manifests, ready for extraction as submodule repository).
- [x] 16.19 `bin/hellmacs.ps1` for native Windows, if Hellmacs ever
      supports Windows outside WSL2 (2026-09-30: added PowerShell CLI
      wrapper script `bin/hellmacs.ps1`).

### 3. Groovy (8.4)

- [x] `:lang groovy`: groovy-mode (Gradle scripts, Jenkinsfiles),
      groovy-language-server built pinned by sync, status messages,
      `C-c l c` key (2026-09-30: verified build with pinned Gradle and
      verification-metadata.xml, jar installation, doctor checks, file
      associations for .gradle and Jenkinsfiles, Spock/JUnit test detection,
      and localleader refresh).

### 4. Every language IntelliJ IDEA bundles, on by default (Phase 14)

A project IntelliJ IDEA Ultimate understands opens understood in Hellmacs,
with nothing to enable. Same pattern as every language: a findings pass
first, each server pinned and installed by sync, declared for the SBOM,
checked by `doctor`, telemetry off, its own keys only on the `C-c l`
localleader (`hellmacs-localleader-def`).

- [x] 14.0 Findings: each language's server, how it ships, license,
      telemetry; the cost of all-on (sync time, disk, bundle size, startup).
- [x] 14.1 `:lang web`: HTML, CSS/Less/SCSS, Thymeleaf, FreeMarker,
      Velocity, JSP (2026-09-30: `web-mode` & `css-mode` integration, LSP
      deferred hooks).
- [x] 14.2 `:lang javascript`: JavaScript, TypeScript, JSX/TSX, ESLint
      (2026-09-30: `js-mode`, `js-ts-mode`, `typescript-mode`, `typescript-ts-mode`,
      `tsx-ts-mode`, Node doctor check).
- [x] 14.3 `:lang sql`: a SQL server on `:tools db`'s connections
      (2026-09-30: `sql-mode`, `sql-indent`, localleader `C-c l` execution).
- [x] 14.4 XSLT and XPath; `.properties` with Spring keys (2026-09-30:
      `.xslt?`/`.xpath` in `nxml-mode` with lemminx, `.properties` Spring
      boot support).
- [x] 14.5 `:lang scala`: scala-mode, sbt-mode, Metals pinned,
      `metals/status`, localleader keys (2026-09-30: `scala-mode`, `sbt-mode`,
      `lsp-metals`, doctor check, localleader `C-c l` bindings).
- [x] 14.6 Kubernetes schemas, `:lang openapi`, `:lang terraform`,
      `:lang protobuf` (2026-09-30: `:lang openapi`, `:lang terraform`,
      `:lang protobuf` modules with LSP hooks and doctor checks).
- [x] 14.7 All of them on by default (with 10.1's six and Groovy), Node a
      `doctor` warning, no telemetry with everything on, a fresh install
      under the 0.12s budget.

### 5. Plugins (Phase 15)

What IntelliJ gets through plugins, Hellmacs gets through a plugin manager
over its modules: browse, enable, disable and update without editing
`init.el` by hand, pinned and verified like everything else.

- [x] 15.1 The manager: `bin/hellmacs plugins` (list, search, enable,
      disable), `M-x hellmacs-plugins` on `C-c h p`, `doctor` (2026-09-30:
      added `lisp/hellmacs-plugins.el`, `bin/hellmacs-plugins` CLI, tabulated
      interactive UI, and `C-c h p` keybinding).
- [x] 15.2 Plugin languages: `:lang python`, `go`, `ruby`, `php`, `cc`
      (2026-09-30: added all 5 plugin language modules under `sources/hellmacs+/modules/lang/`
      with LSP integration, mode hooks, and doctor checks).
- [x] 15.3 Third-party plugins: `plugin!` pinned by commit, a trust
      prompt, lock/SBOM/licenses/verify/bundles, `plugins update` (2026-09-30:
      added `plugin!` macro in `lisp/hellmacs-plugins.el` and `bin/hellmacs plugins update`).

### 6. Teams, the pilot, then 1.0 (12.8, 12.11)

- [x] 12.8 A team layer: `$HELLMACS_TEAM_DIR` (or a git URL) with shared
      modules, packages, lock file, mirrors and proxy, loaded between
      Hellmacs and the user's config (2026-09-30: added `hellmacs-team-dir`
      in `early-init.el`, layered module lookup in `hellmacs-modules.el`,
      team `init.el`/`config.el`/`packages.el` generation in `hellmacs-profiles.el`,
      and doctor checks).
- [x] 12.8 `M-x hellmacs-where-is-intellij`: "what is Shift-F6 here?"
      (2026-09-30: created `lisp/lib/intellij.el` with 60 registered action
      mappings, fuzzy search, categories, and direct execution on `C-c h k`
      and `C-c h ?`).
- [x] 12.8 `bin/hellmacs install --team URL`: clone, install, sync, env,
      doctor, and team layer configuration (2026-09-30: added `--team` option
      in `bin/hellmacs-install`).
- [ ] 12.11 Three pilot codebases: a Spring Boot Maven monolith, Gradle
      (Kotlin DSL) microservices, a legacy Java 8 application, each behind
      a proxy with a corporate CA, on macOS and on Linux or WSL2.
- [ ] 12.11 A working week per codebase, logging every time the developer
      reached for another tool; each entry becomes a fix, a matrix row or a
      documented gap.
- [ ] 1.0 exit criteria: the six objectives met with evidence, no blocking
      pilot entry open, SBOM and license report shipped with the release.
- [ ] 1.0 release.

### 7. Centaur Emacs balance & modern iconography (Phase 17)

A modern, high-performance IDE experience anchored strictly in traditional GNU
Emacs conventions, non-modal keychords, buffer workflows, and clean visual
iconography (`nerd-icons`):

- [x] 17.1 Visual Minibuffer: `nerd-icons-completion` for `marginalia` and
      `vertico`, enriching `consult-buffer`, `consult-find`, and `consult-ripgrep`
      with file/mode/directory glyphs (2026-09-30: configured `nerd-icons-completion`
      on `marginalia-mode-hook`).
- [x] 17.2 Native Tree-sitter & AST navigation: transparent `ts-mode` fallback
      with pinned offline grammar management, preserving standard navigation chords
      (`C-M-f`, `C-M-b`, `C-M-a`, `C-M-e`, `C-M-k`) (2026-09-30: enhanced `hellmacs-treesit.el`).
- [x] 17.3 In-Buffer Completion Icons: `nerd-icons-corfu` integration in `:completion corfu`
      displaying semantic kind glyphs (Method, Class, Field, Snippet) in the popup
      (2026-09-30: configured `corfu-margin-formatters` with `nerd-icons-corfu`).
- [x] 17.4 Project Management (`:tools projectile`): `projectile` + `consult-projectile`
      with icon-annotated project/file/buffer discovery and seamless `project.el` interoperability
      (2026-09-30: added `:tools projectile` module under `sources/hellmacs+/modules/tools/projectile/`).
- [x] 17.5 Enhanced Dired (`:emacs dired`): `wdired` for batch renaming (`r` / `C-x C-q`),
      `dired-quick-sort`, and `nerd-icons-dired` for inline file/folder icons
      (2026-09-30: added `:emacs dired` module under `sources/hellmacs+/modules/emacs/dired/`).
- [x] 17.6 Native Code Intelligence (`:tools eglot`): zero-overhead LSP engine using
      Emacs 29+ `eglot.el` with built-in `flymake`, `xref`, `eldoc`, and `corfu` integration
      (2026-09-30: added `:tools eglot` module under `sources/hellmacs+/modules/tools/eglot/`).

### Later

- [x] 10.5 `:ui workspaces`: the built-in `tab-bar`, one tab per project,
      on the stock `C-x t` keys (2026-09-30: created `:ui workspaces` module
      under `sources/hellmacs+/modules/ui/workspaces/` with smart project-aware
      tab naming, nerd-icons, inferno theming, doctor checks, and stock `C-x t` /
      `C-c w` keychords).
- [x] 10.6 Phase 10's modules in `static/init.example.el` (the languages
      are 14.7's) (2026-09-30: reviewed and populated default template with
      enhanced Dired, Projectile, workspaces, and full IntelliJ bundled language suites).
- [x] 13.1 A GNU Info manual (`docs/hellmacs.texi`), in `C-h i` (the
      Info directory) and on `C-c h i`; not on a `C-h` key, which stays
      Emacs' own (2026-09-30: wrote `docs/hellmacs.texi`, compiled `docs/hellmacs.info`
      and `docs/dir`, added `docs/` to Info directories, and bound `C-c h i`).
- [x] 13.2 The Altar offers the Emacs tutorial, the guided tour, the
      manual, Dired and Customize, on its stock keys (2026-09-30: updated
      `modules/hellmacs/+splash.el` with dual-row quick navigation hub).
- [x] 13.3 Hellmacs modules in the `C-h` help commands
      (`hellmacs-describe-module`) (2026-09-30: created `lisp/lib/help.el`
      with interactive module inspector, components, packages, docs, and
      actions on `C-c h d` / `C-c h m`).
- Ideas, only if asked for: `treesit-fold` folding, multiple cursors on
  stock keys, Forge pull requests, Quarkus and Micronaut templates,
  `:tools lookup`, `:tools llm`, `:ui treemacs`, lsp-ui.

---

## Out of scope

- An IntelliJ keymap, Evil, or any modal editing.
- straight.el, and Doom's `compat` module and v2 shims.
- Paid-IDE-only features with no open server behind them (IntelliJ's
  inspections engine, its profiler UI, JPA diagrams): gaps in the matrix,
  with the open alternative where one exists.
- A project-tree-first workflow: `project.el`, `C-x p` and Consult cover
  navigation.

## Risks

- **Pinning servers ourselves** (JDTLS, Kotlin, Clojure, Groovy) means
  following their releases by hand. It's what makes mirrors and offline
  installs possible.
- **Spring Boot's server ships inside a VS Code extension.** If it can't be
  pinned on its own, `+spring` falls back to what JDTLS gives.
- **Coverage and static analysis depend on the build's plugins.** Exotic
  builds may need a documented one-line change, never an automatic edit.
- **No test suites.** Regressions surface when someone tries the change;
  `doctor` and CI's install catch the rest. Check by hand, carefully.
