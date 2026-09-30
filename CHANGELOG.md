# Changelog

What changed in each Hellmacs release, newest first. Hellmacs follows
[Semantic Versioning](https://semver.org/): a release is the git tag
`vMAJOR.MINOR.PATCH`, and `hellmacs-version` (in `lisp/hellmacs-lib.el`)
carries its number. Which Emacs versions and platforms each release
supports, and how long it gets security fixes, is in
[docs/releases.md](docs/releases.md).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

The first tagged release will be 0.9.0. Since the project started
(2026-09-22):

### Added

- The module system (`hellmacs!`, `modulep!`, `package!`), Elpaca, and a
  synced profile that startup replays: compiled core and modules, one
  autoloads file, startup well under its 0.12s budget.
- `bin/hellmacs`: `install`, `sync`, `upgrade`, `lock`, `bundle` (offline
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
- Update channels: `bin/hellmacs upgrade --channel stable|main`, stable
  (the latest release) by default.

### Changed

- Doom Emacs v3's architecture and layout (Phase 16). The engine is in
  `lisp/` (was `core/`), with `lisp/lib/` and `lisp/cli/` loaded through
  `hellmacs-require`; core's own features are a module, `modules/hellmacs/`
  (`:hellmacs`); the module catalog is `sources/hellmacs+/modules/` (was
  `modules/<group>/`); each command is `bin/hellmacs-COMMAND`; modules carry a
  `.hellmacsmodule` and the project a `.hellmacs`; `profiles/` ships a
  `safe-mode` profile, and a directory is a profile.
- There is no `init.el` in the checkout any more: `sync` generates each
  profile's, and Emacs starts from `lisp/hellmacs-start.el` until it has.
  Batch scripts start with `emacs --batch -l early-init.el -f hellmacs-start`
  instead of `-l init.el`.
- `(require 'hellmacs-jdk)`, `hellmacs-net`, `hellmacs-lsp-status` and the
  other moved libraries no longer load that way: use
  `(hellmacs-require 'hellmacs-lib 'jdk)`.
- An empty `(hellmacs!)` block now enables no module; only an `init.el`
  without a block gets the defaults.

### Security

- Every download is pinned by SHA-256, and packages by commit, Elpaca
  included; the Groovy server's build checks every dependency.
- No telemetry: docker-language-server's (on by default) is turned off,
  and clojure-lsp no longer downloads ClojureDocs at startup. A test fails
  if code outside `lisp/lib/net.el` reaches the network.
- `bin/hellmacs env` no longer saves tokens, passwords or API keys, and
  writes the file readable by you only.
- The JDBC password no longer lands in sqlline's history file.
