# Changelog

What changed in each Hell Emacs release, newest first. Hell Emacs follows
[Semantic Versioning](https://semver.org/): a release is the git tag
`vMAJOR.MINOR.PATCH`, and `hell-version` (in `lisp/hell-lib.el`)
carries its number. Which Emacs versions and platforms each release
supports, and how long it gets security fixes, is in
[the guide](docs/guide.md#3-staying-up-to-date).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

The first tagged release will be 0.9.0. Since the project started
(2026-09-22):

### Added

- The module system (`hell!`, `modulep!`, `package!`), Elpaca, and a
  synced profile that startup replays: compiled core and modules, one
  autoloads file, startup well under its 0.12s budget.
- `bin/hell`: `install`, `sync`, `upgrade`, `lock`, `bundle` (offline
  installs), `doctor`, `env`, `gc`, `config`, `sbom`, `licenses`, `test`,
  and `version`.
- Java through Eclipse JDTLS (Lombok, Spring Boot's language server),
  Kotlin (kotlin-language-server), Clojure (clojure-lsp and CIDER), Groovy
  (groovy-language-server, built from a pinned commit), and pinned
  tree-sitter grammars.
- Debugging (dap-mode, hot code replace), builds and tests through Gradle
  and Maven, test results and JaCoCo coverage, run configurations
  (IntelliJ's and Eclipse's), static analysis reports.
- Data languages (XML, YAML, JSON, Markdown, shell, Dockerfiles), `.http`
  files, JDBC connections, formatters, snippets, file templates.
- Corporate networks: proxy, CA bundle, mirrors, offline bundles.
- Several JDKs side by side, per-project toolchains, direnv.
- A CycloneDX SBOM and a license report of everything installed.
- Update channels: `bin/hell upgrade --channel stable|main`, stable
  (the latest release) by default.

### Changed

- Stock keys untouched, modern keys isolated (roadmap 13.5): Hell
  Emacs' keys live only under `C-c` groups and never repeat a stock
  key's command, and installed packages keep their own default keys as
  they ship them (13.6): Magit's `C-x g` / `C-x M-g` / `C-c M-g`,
  diff-hl's `C-x v`, lsp-mode's `s-l` (was `C-c c l`) and mouse keys,
  corfu's popup keys, which-key's `C-h`, yasnippet's and tempel's keys.
  Consult's
  `M-g f`/`M-g o`/`M-s l`/`M-s r`/`M-s d` to `C-c s e`/`s o`/`s s`/`s p`/
  `s f`, workspaces to `C-c TAB p` (`M-1`..`M-9` are `digit-argument`
  again); `C-c f f`, `C-c b`, `C-c c c`/`d`/`D`/`j`/`x`, `C-c w` splits
  and the like are gone in favour of their stock keys.

- GNU Emacs' own layout (roadmap 13.4): the frame keeps the stock menu
  bar, tool bar and scroll bars, and the Altar is now Emacs' own
  startup screen (`*GNU Emacs*`) with Hell Emacs' logo and words,
  including the concise screen beside files opened from the command
  line and the `C-h C-a` echo-area message.

- Hellmacs is now Hell Emacs: every `hellmacs-` symbol is `hell-`, the
  CLI is `bin/hell`, core's module is `:hell`, the catalog is
  `sources/hell+/`, module and project files are `.hellmodule` and
  `.hell-emacs`, the environment variables are `HELLDIR`, `HELLPATH`,
  `HELL_PROFILE` and `HELL_TEAM_DIR`, and your config lives in
  `~/.config/hell-emacs/` (a named profile in `~/.config/hell-emacs-NAME/`).
  The old names don't work any more: move `~/.config/hellmacs/` to
  `~/.config/hell-emacs/` and run `bin/hell sync`.
- The documentation is six files: docs/guide.md (from getting-started,
  configuration, releases and profiles), docs/jvm.md, docs/keybindings.md
  (now from the real bindings), docs/cli.md, docs/development.md (from
  architecture, contributing and vision-and-rules) and docs/roadmap.md,
  which absorbs the work order: the rules, IntelliJ and Doom parity, and
  every open item, including the Doom follow-ups (16.11 to 16.19).
- Keybindings are laid out as Doom's non-evil leader, still with stock
  keys only. `C-c c` is the code group (compile, xref, documentation,
  errors; with a language server also code actions, rename, organize
  imports, format), and lsp-mode's map moved from `C-c l` to `C-c c l`.
  `C-c l` is now the localleader (`hell-localleader-def`): Java's
  commands (`C-c l j X` is now `C-c l X`), Groovy's classpath, and in JVM
  sources the tests (`C-c l t t` / `t T`, and the results and coverage
  that were on `C-c t`). `C-c t` toggles built-in modes. `C-c s` has
  Doom's letters (`s` buffer, `p` project, `f` file, `m` bookmark) and
  `M-s f` became consult's `M-s d`; `M-g f` / `M-g o` jump to a
  diagnostic / heading, and `C-x 5 b` / `C-x t b` preview like `C-x b`.
  This also ends Groovy's `C-c l g` shadowing lsp-mode's goto keys.
- Stock keys stay stock where packages took them: the completion popup no
  longer swallows `RET` (it inserts only a picked candidate) or `TAB`
  (it indents; `C-M-i` completes, `+tab` as before), nor `M-g`, `M-h`,
  `M-t`; `C-h` after a prefix is Emacs' `describe-prefix-bindings` again
  (which-key pages on `<f5>`); lsp-mode no longer takes `mouse-3` and
  `C-mouse-1`. `C-x C-b` is ibuffer and `M-/` hippie-expand (dabbrev
  first); `(default +repeat)` turns on Emacs' `repeat-mode`.
- Completion is IntelliSense-like: servers' snippets expand (a method's
  argument placeholders, JDTLS's templates and postfix completion), through
  yasnippet used only as lsp-mode's engine; candidates you pick rank first
  next time (`corfu-history-mode`); documentation shows after 0.5s; and in
  a terminal on Emacs 29 and 30 the popup is drawn by `corfu-terminal`.
- An import that never finishes is no longer silent: after 90s the echo
  area says the server is still importing and that completion waits for
  it; a Gradle cache-lock timeout (another daemon holding `~/.gradle`) is
  named as the reason for a failed import; and after an import JDTLS's
  unresolved dependencies are listed.
- Every `doctor` warning and error points to its troubleshooting entry
  (`see ~/hell-emacs/docs/guide.md#doctor-jdk`): eleven entries in the
  guide's new "What doctor's messages mean". Module doctors can do the same
  with a leading `:topic` in `hell-doctor-warn` / `-error`.
- Hell Emacs has no test suites any more: `bin/hell test`, test/ and the
  budgets workflow are gone, and CI installs Hell Emacs and runs `doctor`,
  `licenses` and `sbom`.

- Startup, packages, the CLI and installing now work as Doom Emacs v3's.
  Core loads from early-init.el (`hell-initialize`), and the entry point
  in lisp/hell-emacs.el loads the profile's generated init file, now
  `init.MAJOR.MINOR.el`, built from numbered `init.d/` parts that run on
  `hell-startup-functions`. Startup no longer installs packages or reads
  packages.el: after changing your modules or packages, run `bin/hell
  sync`, as with `doom sync`. Without a sync, Emacs starts plain and says so.
  lisp/hell-start.el is gone.
- `package!` takes `:ignore` and `:type`; `unpin!` and `disable-packages!`
  are new; modules can hold `autoload/*.el`; module init and config hooks.
- `bin/hell`: options before the command (`-p`, `--helldir`, `-D`,
  `-!`), short names (`s`, `up`, `doc`, `pf`), Doom's exit codes, a refusal
  to run as root, commands from your `bin/` and `$HELLPATH`, the new
  `emacs`, `info` and `profile` commands, and `bin/hell.sh`. `install`
  takes `--[no-]config`, `--[no-]env` (it asks otherwise) and
  `--[no-]install`, and warns about a `~/.emacs` that would win.
- Layout: sync is in lisp/cli/sync.el, the `C-c` leader API is core's
  module's `autoload/keybinds.el`, and the dashboard, modeline and
  hell-inferno theme live in their modules. `C-c h R` syncs, then
  reloads.

- Doom Emacs v3's architecture and layout (Phase 16). The engine is in
  `lisp/` (was `core/`), with `lisp/lib/` and `lisp/cli/` loaded through
  `hell-require`; core's own features are a module, `modules/hell/`
  (`:hell`); the module catalog is `sources/hell+/modules/` (was
  `modules/<group>/`); each command is `bin/hell-COMMAND`; modules carry a
  `.hellmodule` and the project a `.hell-emacs`; `profiles/` ships a
  `safe-mode` profile, and a directory is a profile.
- There is no `init.el` in the checkout any more: `sync` generates each
  profile's, and Emacs starts from `lisp/hell-start.el` until it has.
  Batch scripts start with `emacs --batch -l early-init.el -f hell-start`
  instead of `-l init.el`.
- `(require 'hell-jdk)`, `hell-net`, `hell-lsp-status` and the
  other moved libraries no longer load that way: use
  `(hell-require 'hell-lib 'jdk)`.
- An empty `(hell!)` block now enables no module; only an `init.el`
  without a block gets the defaults.

### Fixed

- `bin/hell` runs under any POSIX `sh`: it used bash arrays, so on Debian
  and Ubuntu, whose `sh` is dash, every command failed with
  `Syntax error: "(" unexpected`.

### Security

- Every download is pinned by SHA-256, and packages by commit, Elpaca
  included; the Groovy server's build checks every dependency.
- No telemetry: docker-language-server's (on by default) is turned off,
  and clojure-lsp no longer downloads ClojureDocs at startup. A test fails
  if code outside `lisp/lib/net.el` reaches the network.
- `bin/hell env` no longer saves tokens, passwords or API keys, and
  writes the file readable by you only.
- The JDBC password no longer lands in sqlline's history file.
