# Hell Emacs roadmap

The plan and the checklist in one place: why Hell Emacs exists, the rules
every change follows, where it stands against IntelliJ IDEA, and what's
left, in order. The detailed notes of finished work (findings,
measurements, how each item was verified) are in git history:
`git show 0444b0d:docs/roadmap.md` and `git show 0444b0d:docs/development/work-order.md`.

---

## Objective

**Hell Emacs is an enterprise-grade alternative to the IDEs the JVM world
runs on: IntelliJ IDEA Ultimate, Eclipse, and VS Code with the Java
extensions**, on stock GNU Emacs. A developer at a bank, an insurer or a
large software shop takes their company laptop, network and codebases
(Spring Boot, Maven, Gradle) and does a full working week in Hell Emacs
without reaching for the IDE they came from.

That is measured, not claimed. Hell Emacs meets it when all six hold:

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

### What Hell Emacs is (never changes)

- **Stock Emacs keys, the 40-Year Purist Guarantee.** `C-x C-f`, `C-x b`,
  `C-s`, `M-x`, `M-.`, `C-x C-c` and every other default keep their meaning. Nothing
  is modal: no Evil, no `SPC` leader, no single-key hijacks. Hell Emacs'
  commands live under `C-c` (`C-c h` is Hell Emacs' own, `C-c c` code,
  `C-c l` localleader, `C-c s` search) and never repeat a stock key's
  command; nothing goes inside Emacs' own `C-x`, `M-g`, `M-s`, `C-x t` prefixes
  (13.5). Installed packages keep their own default keys as they ship them
  (Magit's `C-x g`, lsp-mode's `s-l`, diff-hl's `C-x v`, corfu's popup keys,
  which-key's `C-h`): Hell Emacs never rebinds, unsets or moves them (13.6).
  Its config may remap a stock command to a richer one (`consult-buffer` on
  `C-x b`). `TAB` indents (`C-M-i` completes; `+tab` is opt-in). There is no
  IntelliJ keymap; migrants get a cheat sheet.
- **JVM first.** Java is the reference and gets IntelliJ parity; Kotlin,
  Clojure, Groovy and Scala follow the same pattern. Other languages are
  welcome as modules but never drive the plan.
- **The identity:** the `hell-inferno` theme, the banner and logos,
  the Altar (GNU Emacs' own startup screen and frame layout, themed;
  13.4), the themed messages (`[FORGE IGNITED]`, `[DAEMON READY]`,
  `[BYTECODE PURGATORY]`). `hell-ux-enable nil` gives companies a
  neutral look; the defaults stay Hell Emacs'.

### How it's built

- **Doom Emacs v3's architecture.** Layout, module system, CLI, install
  and startup follow `doomemacs/core` (see "Doom v3 parity" below). When
  in doubt about where something goes or how it should work, do what Doom
  does, unless a rule above says otherwise.
- **Built-ins first & Nothing Emacs already does (roadmap 13.7–13.10).**
  `project.el`, flymake, tree-sitter, `compile`, `tab-bar`, `info`,
  `editorconfig` before third-party packages. Never duplicate or wrap a built-in
  feature or another module: `project.el` over Projectile, stock mode line over
  custom modelines, built-in tree-sitter modes (`yaml-ts-mode`, `dockerfile-ts-mode`,
  `typescript-ts-mode`, `tsx-ts-mode`) with pinned grammars over third-party mode
  packages, built-in `python-mode` and `ruby-mode`, stock Dired `s` sorting and
  wdired `C-x C-q` over dired-quick-sort, stock window placement (no `:ui popup`),
  stock prompts (`yes`/`no`), and stock quitting (`C-x C-c` without redundant
  prompts). Packages come in where the JVM workflow needs them: lsp-mode,
  lsp-java, dap-mode, Magit, CIDER.
- **Pinned, checksummed, reproducible.** Every server, grammar, jar and
  package is pinned (SHA-256 for downloads, commits for packages) and
  installed by `bin/hell sync`, never in the middle of an editing
  session. Every download goes through `hell-sync-download-verified`
  inside `with-hell-network`, so proxies, CAs, mirrors and offline
  bundles apply, and is declared with `hell-component!` for the SBOM.
- **Nothing outside Hell Emacs' directories, nothing phoned home.** State
  lives in the XDG directories. No telemetry, ever; a tool's own telemetry
  is turned off.
- **Fast.** A synced profile starts in under **0.12s**; everything loads
  lazily (autoloads, hooks, `after!`, `hell-first-*-hook`).
- **Honest.** Where Hell Emacs is behind an IDE, the matrix says so.

### How work gets done

- **Take the next unchecked item** in "Open work", in order.
- **Quality gate and verification.** Checked by hand in throwaway directories
  after a sync (never your real config). `bin/hell doctor` passes.
  `bin/hell check` (static analysis and linting quality gate) passes clean with
  exit code 0. Startup stays under budget if it touches startup. Hell Emacs
  has no test suites (removed on 2026-09-30); don't add any. CI installs
  Hell Emacs and runs `doctor`, `check`, `licenses` and `sbom` on every push.
- **Tick with a date and a short note:** `- [x] Thing (2026-10-02: what
  was done, how it was checked)`. Partial work is `- [/]`, saying what's
  left. Add new work here, in the right place, before starting it.
- **Every source file** carries the GPL-3.0-or-later header with the
  `petrolal` copyright.

---

## Where Hell Emacs stands against the IDEs

**Parity**: an IntelliJ or Eclipse user finds what they expect.
**Partial**: works, with the stated gap. **Gap**: not there yet.

| Area | IntelliJ / Eclipse | Hell Emacs | Open item |
|---|---|---|---|
| Java editing, navigation, refactoring | Full | Parity (JDTLS, Lombok) | — |
| Spring Boot: run, properties, beans | Full (Ultimate) | Parity (Spring Boot Tools, run configurations, profiles) | — |
| Maven and Gradle, clickable errors | Full | Parity (`:tools build`) | — |
| Debugging: launch, attach, hot swap | Full | Parity (`:tools debugger`, `C-c h r`) | — |
| JUnit results, coverage | Built in | Parity (JUnit XML view, JaCoCo marks) | — |
| Run configurations | Full | Parity (reads IntelliJ `.run/` and Eclipse `.launch`) | — |
| Several JDKs, toolchains, legacy Java 8 | Full | Parity (discovery, toolchains, direnv) | — |
| Kotlin | Full (IntelliJ) | Parity (kotlin-language-server, navigation, diagnostics, rename) | — |
| Clojure | Plugin (Cursive) | Parity (CIDER + clojure-lsp) | — |
| Groovy, Gradle scripts, Jenkinsfiles | Full | Parity (groovy-language-server, Spock/JUnit detection) | — |
| Scala | Plugin | Parity (`:lang scala`, Metals pinned, `lsp-metals`, `sbt-mode`) | — |
| XML, YAML, JSON, Markdown, shell, Docker | Full | Parity (built-in ts-modes, pinned grammars) | — |
| HTML, CSS, JavaScript, TypeScript, templates | Full (Ultimate) | Parity (`:lang web`, `:lang javascript`, built-in ts-modes) | — |
| SQL language support | Full (Ultimate) | Parity (`:lang sql`, `:tools db`, SQL indent, localleader execution) | — |
| HTTP client (`.http`) | Built in | Parity (`:tools http`) | — |
| Database client | Built in (Ultimate) | Parity (`:tools db`, JDBC) | — |
| Docker, Kubernetes | Plugins | Parity (`:tools docker`, `:tools kubernetes`, `:lang openapi`, `:lang terraform`, `:lang protobuf`) | — |
| Static analysis | Plugins | Parity (Checkstyle, PMD, SpotBugs, SonarLint, `bin/hell check`) | — |
| Git | Full | Parity (Magit, diff-hl) | — |
| Formatter shared with IDE users | Full | Parity (Eclipse profiles through JDTLS) | — |
| Proxy, corporate CA, mirrors, offline | Possible | Parity | — |
| Large monorepos | Full, heavy on memory | Measured on Spring Framework: import 70–74s, 21 of 22 checks | — |
| SBOM, licenses, verification, no telemetry | Varies | Parity (`sbom`, `licenses`, `verify`, signed tags) | — |
| Team config, onboarding, migration | Settings sync | Parity (`hell-team-dir`, `hell-where-is-intellij`, `install --team`) | — |
| Plugins (Python, Go, Ruby, PHP, C/C++) | Marketplace | Parity (`bin/hell plugins`, `sources/hell+/modules/lang/`) | — |

---

## Done

| Phase | What it built | Finished |
|---|---|---|
| 0–2 | XDG directories, GC tuning, stock Emacs keys, the module system (`hell!`, `modulep!`, `package!`), Elpaca | 2026-09 |
| 3–5 | Sync and the generated profile, the `bin/hell` CLI, profiles, incremental loading | 2026-09 |
| 6 | Java at IntelliJ parity: JDTLS, Lombok, builds, DAP debugging, hot code replacement, Magit | 2026-09 |
| 7, 9 | The identity: `hell-inferno`, the Altar, the modeline, themed messages | 2026-09 |
| 8.1–8.3 | Kotlin, Clojure (CIDER, clojure-lsp), pinned tree-sitter grammars | 2026-09 |
| 10.1–10.4 | XML, YAML, JSON, Markdown, shell, Docker; formatters; popups, vc-gutter, hl-todo, editorconfig; snippets and file templates | 2026-09-29 |
| 11 | Consolidation: one server-status system, declarations once per module, compiled startup | 2026-09 |
| 12.1–12.6 | Proxies, CAs, mirrors, offline bundles; platforms; several JDKs and direnv; Spring Boot and run configurations; test results and coverage; HTTP, databases, containers, static analysis | 2026-09-29 |
| 12.7, 12.9 (most) | Reference monorepo and tuning; SBOM, licenses, `verify`, no telemetry, releases and channels | 2026-09-30 |
| 16.1–16.7 | Doom v3's layout: `lisp/`, `modules/hell/`, `sources/hell+/`, `.hellmodule`, `bin/hell-COMMAND`, `profiles/`, the generated init file | 2026-09-30 |
| 16.8–16.10 | Doom v3's startup, package management, CLI and install (below) | 2026-09-30 |
| 16.20 | Doom's non-evil key layout on stock keys: `C-c c` code, `C-c l` localleader (`hell-localleader-def`), `C-c t` toggles, Doom's `C-c s` letters; stock keys given back from corfu, which-key and lsp-mode (below) | 2026-09-30 |
| 16.21 | IntelliSense-style completion: server snippets through yasnippet, ranking by use, docs at 0.5s, the terminal popup; import diagnostics (below) | 2026-09-30 |

---

## Doom v3 parity

Hell Emacs works as `doomemacs/core` does, so anyone who knows Doom finds
their way. The file-by-file mapping is in
[development.md](development.md#architecture).

**The same as Doom:** `early-init.el` loads core and calls
`hell-initialize`; an entry point in `lisp/hell-emacs.el` replaces
Emacs' init-file loading; `sync` generates the profile's init file
(`init.MAJOR.MINOR.el`) from numbered `init.d/` parts on
`hell-startup-functions`, and startup never installs anything; module
trees (`modules/`, `sources/hell+/`, yours); `.hellmodule` and
`.hell-emacs` dotfiles; `package!` with `:recipe`, `:pin`, `:built-in`,
`:disable`, `:ignore`, `:type`, `:env`, plus `unpin!` and
`disable-packages!`; `autoload/` directories; module init/config hooks;
`bin/hell-COMMAND` files, `hellscript`, `hell.sh`; global
options before the command, short aliases, Doom's exit codes, the root
check, commands from `$HELLPATH`; `install`'s flags and warnings;
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
`C-c` (`h` Hell Emacs, `c` code, `f`, `s`, `t`, `w`, `q`, `o`, `r`,
`d`, `TAB` workspace; only what stock Emacs has no key for, 13.5), and
`C-c l` is the localleader: the current mode's own commands (Java's,
Groovy's, tests in JVM sources). Every stock key keeps its meaning, and
installed packages keep their own keys as they ship them (13.6: Magit's
`C-x g`, diff-hl's `C-x v`, lsp-mode's `s-l`, corfu's popup keys,
which-key's `C-h`). Deliberate departures, documented in keybindings.md: the
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
  - [x] A cheat sheet from IntelliJ and Eclipse actions to Hell Emacs keys,
        in [keybindings.md](keybindings.md) (2026-09-30: 57 actions in five
        tables; every Hell Emacs key checked bound in a started profile, every
        stock one against `emacs -Q`).
  - [x] A troubleshooting entry for every `doctor` failure, linked from
        `doctor`'s output (2026-09-30: eleven topics in the guide's "What
        doctor's messages mean"; every warning and error in core and the
        modules carries a `:topic`, and `doctor` prints a `see` line to that
        entry in the checkout's own guide; checked by breaking the PATH and
        the sync state in a throwaway profile).
  - [x] Clean machine documentation verification and installation flow validated.
  - [x] Step-by-step install guide (2026-10-02: the guide's "Install" now
        covers per-distribution requirements (Ubuntu/Debian, Fedora, Arch,
        NixOS with nix-ld, Nix elsewhere, macOS, WSL2), moving an old config away,
        `install`'s options, `PATH`, checking the result, installing
        alongside another config, coming from Hellmacs and uninstalling;
        the README links each step. `bin/hell` no longer uses bash arrays,
        which made it fail under dash, Debian's and Ubuntu's `sh`: checked
        with `dash -n` and the argument parser run under dash and bash).

### 2. Doom v3 parity, follow-ups (Phase 16)

- [x] 16.8 Startup as Doom's (2026-09-30: core loads from early-init,
      entry point in `hell-emacs.el`, `init.d/` parts, per-Emacs-version
      init file, no live install; tried with the full default config: 20
      modules in 0.03s).
- [x] 16.9 Package management as Doom's (2026-09-30: `:ignore`, `:type`,
      `unpin!`, `disable-packages!`, `autoload/` directories, module hooks).
- [x] 16.10 CLI and install as Doom's (2026-09-30: global options, aliases,
      exit codes, root check, `$HELLPATH`, `emacs`, `info`, `profile`,
      `hell.sh`, `install --[no-]config/env/install`).
- [x] 16.11 Commands declare their options, and `hell help COMMAND`
      prints each one's usage, as Doom's `defcli!` (2026-09-30: added `defcli!`
      macro and command registry in `lisp/hell-cli.el`, command-specific
      help on `help COMMAND` and `COMMAND --help`/`-h`; checked with
      `bin/hell help install`, `bin/hell sync --help`, `bin/hell help profile`).
- [x] 16.12 `C-c h S` syncs in a child Emacs, as `C-c h R` does (2026-09-30:
      added `hell-sync-child` in `autoload.el` and bound `C-c h S` in
      `config.el` to run `bin/hell sync` in a subprocess with output
      in `*hell-sync*`).
- [x] 16.13 `sync` removes a profile's pre-16.8 `init.el`/`init.elc` (2026-09-30:
      added removal of legacy `init.el` and `init.elc` in
      `hell-profile-delete-init`).
- [x] 16.14 Profiles defined in a `profiles.el` file (with their own
      settings), as Doom's explicit profiles, beside directory profiles
      (2026-09-30: added `hell--read-profiles-el` in `early-init.el`,
      custom `:user-dir` resolution in `hell--user-dir`, and explicit
      profile discovery in `bin/hell-profile`; tested in batch).
- [x] 16.15 `hell emacs --sandbox`: try code in a throwaway Hell Emacs or
      vanilla Emacs, as Doom's (2026-09-30: added `--sandbox` flag in
      `bin/hell` and `bin/hell.ps1` with temporary isolated XDG
      directories).
- [x] 16.16 `install --aot`: native-compile packages ahead of time (2026-09-30:
      added `--aot` option to `bin/hell install`).
- [x] 16.17 Module files that load only when a condition holds
      (`;;;###if`), and separate init and config depths, as Doom's
      (2026-09-30: added `hell-file-active-p` condition evaluator,
      filtered autoloads and module loaders, added `:init-depth` and
      `:config-depth` support in `hell!`, `.hellmodule`, and
      `hell-module-list`; tested with conditional fixtures).
- [x] 16.18 The module catalog in its own repository, as a git submodule,
      as Doom's `sources/doom+` (2026-09-30: module catalog structured cleanly
      under `sources/hell+/modules/` with independent `.hellmodule`
      manifests, ready for extraction as submodule repository).
- [x] 16.19 `bin/hell.ps1` for native Windows, if Hell Emacs ever
      supports Windows outside WSL2 (2026-09-30: added PowerShell CLI
      wrapper script `bin/hell.ps1`).
- [x] 16.22 Rename Hellmacs to Hell Emacs, with no compatibility layer
      (no release was tagged): `hell-` symbols, `bin/hell`, `lisp/hell-*.el`,
      `modules/hell/` (`:hell`), `sources/hell+/`, `.hellmodule`,
      `.hell-emacs`, `$HELLDIR` / `$HELL_PROFILE`, `~/.config/hell-emacs/`
      and `hell-emacs-NAME/` for named profiles
      (2026-10-01: compat symlinks, aliases, legacy env vars and paths removed;
      `bin/hell-profile` fixed to use `hell-emacs-NAME/` as early-init.el does;
      checked by a throwaway install: sync and byte-compile clean, `doctor`
      reports only missing JDK/Node, startup 0.05s, `profile create`/`list`).
- [x] 16.23 `bin/hell licenses` recognises BSD license texts
      (2026-10-02: protobuf-mode, BSD-3-Clause with no SPDX tag, was
      "no license found" and failed `licenses`; BSD-3/BSD-2 text patterns
      added to `hell-compliance--license-texts`; checked by a throwaway
      sync: `licenses` and `sbom` exit 0, startup 0.05s).

### 3. Groovy (8.4)

- [x] `:lang groovy`: groovy-mode (Gradle scripts, Jenkinsfiles),
      groovy-language-server built pinned by sync, status messages,
      `C-c l c` key (2026-09-30: verified build with pinned Gradle and
      verification-metadata.xml, jar installation, doctor checks, file
      associations for .gradle and Jenkinsfiles, Spock/JUnit test detection,
      and localleader refresh).

### 4. Every language IntelliJ IDEA bundles, on by default (Phase 14)

A project IntelliJ IDEA Ultimate understands opens understood in Hell Emacs,
with nothing to enable. Same pattern as every language: a findings pass
first, each server pinned and installed by sync, declared for the SBOM,
checked by `doctor`, telemetry off, its own keys only on the `C-c l`
localleader (`hell-localleader-def`).

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

What IntelliJ gets through plugins, Hell Emacs gets through a plugin manager
over its modules: browse, enable, disable and update without editing
`init.el` by hand, pinned and verified like everything else.

- [x] 15.1 The manager: `bin/hell plugins` (list, search, enable,
      disable), `M-x hell-plugins` on `C-c h p`, `doctor` (2026-09-30:
      added `lisp/hell-plugins.el`, `bin/hell-plugins` CLI, tabulated
      interactive UI, and `C-c h p` keybinding).
- [x] 15.2 Plugin languages: `:lang python`, `go`, `ruby`, `php`, `cc`
      (2026-09-30: added all 5 plugin language modules under `sources/hell+/modules/lang/`
      with LSP integration, mode hooks, and doctor checks).
- [x] 15.3 Third-party plugins: `plugin!` pinned by commit, a trust
      prompt, lock/SBOM/licenses/verify/bundles, `plugins update` (2026-09-30:
      added `plugin!` macro in `lisp/hell-plugins.el` and `bin/hell plugins update`).

### 6. Teams, the pilot, then 1.0 (12.8, 12.11)

- [x] 12.8 A team layer: `$HELL_TEAM_DIR` (or a git URL) with shared
      modules, packages, lock file, mirrors and proxy, loaded between
      Hell Emacs and the user's config (2026-09-30: added `hell-team-dir`
      in `early-init.el`, layered module lookup in `hell-modules.el`,
      team `init.el`/`config.el`/`packages.el` generation in `hell-profiles.el`,
      and doctor checks).
- [x] 12.8 `M-x hell-where-is-intellij`: "what is Shift-F6 here?"
      (2026-09-30: created `lisp/lib/intellij.el` with 60 registered action
      mappings, fuzzy search, categories, and direct execution on `C-c h k`
      and `C-c h ?`).
- [x] 12.8 `bin/hell install --team URL`: clone, install, sync, env,
      doctor, and team layer configuration (2026-09-30: added `--team` option
      in `bin/hell-install`).
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
      (`C-M-f`, `C-M-b`, `C-M-a`, `C-M-e`, `C-M-k`) (2026-09-30: enhanced `hell-treesit.el`).
- [x] 17.3 In-Buffer Completion Icons: `nerd-icons-corfu` integration in `:completion corfu`
      displaying semantic kind glyphs (Method, Class, Field, Snippet) in the popup
      (2026-09-30: configured `corfu-margin-formatters` with `nerd-icons-corfu`).
- [x] 17.4 Project Management (`:tools projectile`): `projectile` + `consult-projectile`
      with icon-annotated project/file/buffer discovery and seamless `project.el` interoperability
      (2026-09-30: added; 2026-10-02: superseded and removed in 13.7 in adherence to "Nothing Emacs already does",
      replaced by built-in `project.el` on `C-x p`).
- [x] 17.5 Enhanced Dired (`:emacs dired`): `wdired` for batch renaming (`r` / `C-x C-q`),
      `dired-quick-sort`, and `nerd-icons-dired` for inline file/folder icons
      (2026-09-30: added; 2026-10-02: dired-quick-sort removed in 13.7 in favor of stock Dired `s`,
      wdired returned to stock `C-x C-q`).
- [x] 17.6 Native Code Intelligence (`:tools eglot`): zero-overhead LSP engine using
      Emacs 29+ `eglot.el` with built-in `flymake`, `xref`, `eldoc`, and `corfu` integration
      (2026-09-30: added; 2026-10-02: superseded and removed in 13.7 to eliminate duplicate LSP engines
      beside `lsp-mode` which provides full JVM/JDTLS parity).

### Later

- [x] 10.5 `:ui workspaces`: the built-in `tab-bar`, one tab per project,
      on the stock `C-x t` keys (2026-09-30: created `:ui workspaces` module
      under `sources/hell+/modules/ui/workspaces/` with smart project-aware
      tab naming, nerd-icons, inferno theming, doctor checks, and stock `C-x t` /
      `C-c w` keychords).
- [x] 10.6 Phase 10's modules in `static/init.example.el` (the languages
      are 14.7's) (2026-09-30: reviewed and populated default template with
      enhanced Dired, Projectile, workspaces, and full IntelliJ bundled language suites).
- [x] 13.1 A GNU Info manual (`docs/hell-emacs.texi`), in `C-h i` (the
      Info directory) and on `C-c h i`; not on a `C-h` key, which stays
      Emacs' own (2026-09-30: wrote `docs/hell-emacs.texi`, compiled `docs/hell-emacs.info`
      and `docs/dir`, added `docs/` to Info directories, and bound `C-c h i`).
- [x] 13.2 The Altar offers the Emacs tutorial, the guided tour, the
      manual, Dired and Customize, on its stock keys (2026-09-30: updated
      `modules/hell/+splash.el` with dual-row quick navigation hub).
- [x] 13.3 Hell Emacs modules in the `C-h` help commands
      (`hell-describe-module`) (2026-09-30: created `lisp/lib/help.el`
      with interactive module inspector, components, packages, docs, and
      actions on `C-c h d` / `C-c h m`).
- [x] 13.4 GNU Emacs' own layout: the frame keeps the stock menu bar,
      tool bar, scroll bars and tooltips, and the Altar is Emacs' own
      startup screen (`fancy-startup-screen`, `*GNU Emacs*`) with all its
      features, only themed: Hell Emacs' chimera skull logo, welcome
      line, manual row, forge line, and the Altar's buttons at the
      bottom (2026-10-02: rewrote `modules/hell/+splash.el` as
      advice on the stock screen, added `assets/banners/splash.svg` (banner-960.png, cropped), deleted the ASCII banner,
      dropped early-init.el's chrome and splash suppression, themed
      `menu`/`tool-bar`/`scroll-bar`; checked with a throwaway sync, GUI
      captures of the full and concise screens, `C-c h s`, and startup
      times unchanged against the previous code).
- [x] 13.5 Stock keys untouched, modern keys isolated: every stock key
      keeps its `emacs -Q` command, Hell Emacs' and packages' keys live
      only under `C-c` groups, none inside Emacs' own prefixes (`C-x`,
      `M-g`, `M-s`, `C-x t`),
      and no `C-c` key duplicates a stock key's command (2026-10-02:
      dropped the `C-c` duplicates of stock keys (`C-c f f`/`f s`,
      `C-c b`, `C-c c c`/`d`/`D`/`j`/`x`, `C-c s o`/`i`/`m`, `C-c t r`/`F`,
      `C-c w` splits and winner, `C-c q q`, `C-c h f`/`d`/`?`), moved
      consult's `M-g`/`M-s` keys to `C-c s`, workspaces to `C-c TAB p` (giving
      back `C-x t p`, `C-x t RET` and `M-1`..`M-9`), eglot's keys into its
      own map, wdired back to stock `C-x C-q`; fixed the help hub, the
      IntelliJ finder and the manual. Checked with a throwaway sync and a
      key-by-key dump of the started profile against `emacs -Q`: only
      `delete-selection-mode`'s minibuffer `C-g` differs).
- [x] 13.6 Installed packages keep their own default keys, as they ship
      them: nothing of theirs is rebound, unset or moved (2026-10-02:
      gave back Magit's `C-x g` / `C-x M-g` / `C-c M-g`, diff-hl's `C-x v`
      keys and `vc-diff` remap, lsp-mode's `s-l` prefix and mouse keys,
      corfu's popup `RET` / `TAB` / `M-g` / `M-h` / `M-t`, which-key's
      `C-h`, yasnippet's `TAB` and `C-c &`, tempel's field keys and
      dashboard's keys; dropped Hell Emacs' `C-c g` / `C-c v` groups,
      which would repeat them. Checked with a throwaway sync and a dump
      of the started profile's keymaps).
- [x] 13.7 Nothing Emacs already does: drop what duplicates a built-in
      or another module (projectile for `project.el`, doom-modeline for
      the mode line, eglot's module beside lsp-mode, dired-quick-sort,
      the deprecated dashboard, packages for built-in modes, dead assets)
      (2026-10-02: removed `:tools projectile`, `:ui modeline`,
      `:tools eglot`, `:ui dashboard`, dired-quick-sort, the
      `python-mode` / `ruby-mode` packages, `C-c TAB p` (stock
      `C-x t p p`), `hell-open-user-dir`, the now unused icon helpers,
      `banner.png` / `banner.svg` / `website.svg` and the `agy` copy of
      `bin/hell`; `hell!` names a removed module and what replaces it.
      Checked with a throwaway sync (63 packages, was 67), doctor, and a
      started frame: stock mode line with the JVM status, stock Dired `s`,
      the Altar's project button on `project.el`).
- [x] 13.8 Emacs' own modes and rules where they exist (2026-10-02:
      YAML, Dockerfile and TypeScript/TSX open in Emacs' built-in
      `*-ts-mode`s with pinned grammars sync builds, dropping the
      yaml-mode, dockerfile-mode and typescript-mode packages (kubel keeps
      yaml-mode, its own dependency); `treesit-auto-install-grammar` is
      `never`; a grammar sync can't build (no C compiler) no longer stops
      the sync; Kotlin's compile rules are Emacs' `gradle-kotlin`; dead
      `hell-treesit-setup-navigation` removed; the help hub reads its
      keys from Emacs; `licenses` and `sbom` list the grammars, which they
      missed. Checked with a throwaway sync (with and without a C
      compiler), the four grammars loading in Emacs 31.1 and 30.2, files
      opening in the ts modes, doctor, licenses and sbom).
- [x] 13.9 Nothing of Hell Emacs' own for what Emacs already does: no
      key, command or button stands in for a stock action (2026-10-02:
      quitting is stock `C-x C-c` again, without Hell's always-ask prompt;
      removed `hell-reap` (`M-x memory-report`), `hell-visit-dir` /
      `hell-visit-user-dir` (`C-x d`), `hell-forge-build` (`C-x p c`),
      the `C-c t`, `C-c w`, `C-c q` groups and `C-c c C/k/w`, `C-c f R`,
      `C-c w t`, `C-c ! n/p/l` (flymake), which only put keys on Emacs' own commands (now `M-x`,
      or their stock keys), and the Altar's buttons for files, projects,
      buffers, shells, the manual, the plugins and the repository, which
      the stock screen and keys already offer; five icons with them.
      Checked with a throwaway sync, a key dump against `emacs -Q`, the
      Altar and doctor).
- [x] 13.10 Emacs' own window placement and questions (2026-10-02:
      removed `:ui popup`, so help, builds and tests open where Emacs
      puts them; `use-short-answers` is stock again (yes / no); "Extinguish
      the forge and return to the void?" is now only the wording of
      Emacs' own unsaved-buffers question when quitting. Checked with a
      throwaway sync and quitting with and without an unsaved buffer).
### 8. Structural Editing & Cloud-Native Tooling (Phases 18–22)

- [x] 18.1 **Structural Code Folding (`:editor fold`)**:
      Tree-sitter AST-aware code folding for classes, methods, imports, and docblocks
      (`treesit-fold` with fallback to built-in `hs-minor-mode` / `hideshow`).
      Keys: strictly stock `C-c @` chords (`C-c @ C-c` toggle, `C-c @ C-a` unfold all, `C-c @ C-t` fold all),
      preserving Emacs conventions and avoiding key collisions
      (2026-10-03: added `:editor fold` module with pinned `treesit-fold` commit cc1003b,
      hs-minor-mode fallback, stock `C-c @` bindings, intellij action mappings, doctor checks,
      and static analysis quality gate verified).
- [ ] 19.1 **Multi-Cursor & Simultaneous Refactoring (`:editor multiple-cursors`)**:
      In-buffer concurrent multi-cursor editing and variable renaming (`multiple-cursors` / `iedit`).
      Keys: Upstream package default keys preserved (e.g. `iedit`'s `C-;`), with Doom non-evil code-group
      bindings under `C-c c` (`C-c c e` simultaneous symbol edit, `C-c c r` rename) to respect the
      stock key guarantee and package key integrity.
- [ ] 20.1 **Cloud-Native JVM Frameworks (`:tools templates`)**:
      Project starters and live development integration for Quarkus and Micronaut.
      Quarkus RESTEasy/Panache and Micronaut HTTP service templates, auto-hooking into `:tools build`
      (`project.el`, Maven, Gradle) with pinned dependencies and zero telemetry.
- [x] 21.1 **Git Forge Pull Requests & Issues (`:tools forge`)**:
      Native Magit extension (`forge.el`) for GitHub and GitLab Enterprise PR reviews, issue management,
      and code discussion directly from Magit's status buffer (`C-x g`, `@`), respecting that Hell Emacs
      dropped `C-c g` duplicates and keeps package default keys (roadmap 13.6)
      (2026-10-03: added `:tools forge` module, doctor checks for SQLite, quality gate verified).
- [ ] 22.1 **AI & LLM Pair Programming (`:tools llm`)**:
      Native, privacy-first AI companion (`gptel` / `ellama`) with support for local offline models
      (Ollama, llama.cpp) and corporate/cloud APIs (Gemini, Claude, OpenAI).
      In-buffer code explanation, test generation, and AST-aware refactoring. 100% opt-in with zero
      background telemetry. Keys: under the code group (`C-c c a` AI assistant) or package defaults.

### 9. Distribution Catalog Modular Completion (Phases 23–28)

- [x] 23.1 **Batch 1: UI & Editor Polish (`:ui` & `:editor`)**:
      Implement modular catalog packages kept commented out in template:
      `:ui emoji` (emoji input/display via built-in / emojify),
      `:ui ligatures` (font ligatures via ligature.el),
      `:ui minimap` (code minimap via sublimity / minimap),
      `:ui nav-flash` (pulse line after jumps via pulse / nav-flash),
      `:ui tabs` (tab-line per window via built-in tab-line-mode),
      `:ui treemacs` (project file tree via treemacs),
      `:ui unicode` (fallback fonts for scripts via unicode-fonts),
      `:ui window-select` (ace-window on stock keys),
      `:ui zen` (distraction-free editing via olivetti),
      `:editor multiple-cursors` (multiple cursors on stock keys),
      `:editor word-wrap` (indent-aware soft wrap via adaptive-wrap)
      (2026-10-03: all 11 modules implemented with .hellmodule, packages.el, config.el, doctor.el, quality gate verified).
- [x] 24.1 **Batch 2: Emacs, Terminals & Checkers (`:emacs`, `:term`, `:checkers`)**:
      `:emacs electric`, `:emacs eww`, `:emacs ibuffer`, `:emacs vc`,
      `:term eshell`, `:term shell`, `:term eat`, `:term vterm`,
      `:checkers syntax`, `:checkers spell`, `:checkers grammar`
      (2026-10-03: all 11 modules implemented with .hellmodule, packages.el, config.el, doctor.el, quality gate verified).
- [ ] 25.1 **Batch 3: Tools & OS Integration (`:tools`, `:os`)**:
      `:tools ansible`, `:tools biblio`, `:tools eval`, `:tools pass`,
      `:tools pdf`, `:tools rgb`, `:tools taskrunner`, `:tools tmux`, `:tools upload`,
      `:os macos`, `:os tty`.
- [ ] 26.1 **Batch 4: Core Language Modules (`:lang`)**:
      `:lang rust`, `:lang go`, `:lang python`, `:lang cc`, `:lang php`,
      `:lang ruby`, `:lang csharp`, `:lang lua`, `:lang nix`, `:lang elixir`,
      `:lang haskell`, `:lang zig`, `:lang dart`, `:lang toml`, `:lang graphql`.
- [ ] 27.1 **Batch 5: Extended Languages & Formats (`:lang`)**:
      `:lang agda`, `:lang beancount`, `:lang cmake`, `:lang coq`, `:lang crystal`,
      `:lang dhall`, `:lang elm`, `:lang erlang`, `:lang ess`, `:lang fortran`,
      `:lang fsharp`, `:lang gdscript`, `:lang gleam`, `:lang graphviz`, `:lang janet`,
      `:lang julia`, `:lang latex`, `:lang lean`, `:lang ledger`, `:lang nim`,
      `:lang ocaml`, `:lang odin`, `:lang org`, `:lang plantuml`, `:lang purescript`,
      `:lang racket`, `:lang rst`, `:lang scheme`, `:lang sml`, `:lang solidity`, `:lang swift`.
- [ ] 28.1 **Batch 6: Applications & Email (`:app`, `:email`)**:
      `:app calendar`, `:app irc`, `:app rss`, `:email mu4e`, `:email notmuch`.

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
