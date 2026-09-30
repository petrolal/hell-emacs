<div align="center">

![Hellmacs Banner](assets/banner-960.png)

</div>

---

<h4 align="center">
  <a href="#-installation">Install</a>
  ·
  <a href="#-requirements">Requirements</a>
  ·
  <a href="#-features">Features</a>
  ·
  <a href="docs/getting-started.md">Documentation</a>
  ·
  <a href="#-configuration">Setup</a>
  ·
  <a href="docs/keybindings.md">Keymaps</a>
  ·
  <a href="#-file-structure">Structure</a>
  ·
  <a href="docs/roadmap.md#phase-4-enterprise-parity-matrix">IntelliJ Parity</a>
</h4>

<p align="center">
    <a href="https://github.com/petrolal/hellmacs/pulse"><img src="https://img.shields.io/github/last-commit/petrolal/hellmacs?style=for-the-badge&logo=github&color=e06c75&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hellmacs/releases/latest"><img src="https://img.shields.io/github/v/release/petrolal/hellmacs?style=for-the-badge&logo=gitbook&color=e5c07b&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hellmacs/stargazers"><img src="https://img.shields.io/github/stars/petrolal/hellmacs?style=for-the-badge&logo=apachespark&color=eed49f&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hellmacs/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-GPL_v3.0-a6da95?style=for-the-badge&logo=gnu&logoColor=D9E0EE&labelColor=1a1016"></a>
    <br>
    <a href="https://www.gnu.org/software/emacs/"><img src="https://img.shields.io/badge/Emacs-29.1+-7c5295?style=for-the-badge&logo=gnuemacs&logoColor=white&labelColor=1a1016"></a>
    <a href="https://adoptium.net/"><img src="https://img.shields.io/badge/Java-JDK_21+-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white&labelColor=1a1016"></a>
    <a href="https://clojure.org/"><img src="https://img.shields.io/badge/Clojure-1.11+-5881D8?style=for-the-badge&logo=clojure&logoColor=white&labelColor=1a1016"></a>
    <a href="https://kotlinlang.org/"><img src="https://img.shields.io/badge/Kotlin-2.0+-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hellmacs/actions"><img src="https://img.shields.io/badge/CI-Passing-cba6f7?style=for-the-badge&logo=githubactions&logoColor=D9E0EE&labelColor=1a1016"></a>
</p>

<p align="center">
<strong>Hellmacs</strong> is an infernal, pure native GNU Emacs distribution engineered to subjugate the Java Virtual Machine (Java, Kotlin, Clojure, Gradle, Maven; Groovy and Scala are on the roadmap). Built with stock Emacs DNA and zero modal bloat — delivering sub-50ms startup times, deep DAP debugging, hot code replacement, and enterprise IDE firepower.
</p>

---

## ✨ Features

- **JVM Backend Platform**:
  - **Full Java Intelligence** via [lsp-java](https://github.com/emacs-lsp/lsp-java) & Eclipse JDT LS: semantic code completion, workspace symbol search, Lombok bytecode support, diagnostics, and real-time refactorings.
  - **Kotlin Engine** powered by `kotlin-mode` and `kotlin-language-server` with compiler-grade analysis and smart indenting.
  - **Clojure & REPL Dominance** via [CIDER](https://github.com/clojure-emacs/cider) and `clojure-lsp`: instantaneous interactive REPL evaluation, inline inspection, test runner, and ns navigation.
  - **Build Automation & Project Management**: Gradle and Maven detected per project (wrapper first) and run through Emacs' own `compile`, with clickable compile errors and test failures; project roots from the built-in `project.el`.
  - **Hot Code Replacement (HCR)** into running JVM debug sessions and buffer live-reloads on `C-c h r`.

- **Debugging & Runtime Execution (DAP)**:
  - Full step-by-step interactive debugging with [dap-mode](https://github.com/emacs-lsp/dap-mode).
  - Breakpoints, conditional triggers, logpoints, stack traces, locals inspection, watch expressions, and dedicated debug Hydra keys.
  - Integrated testing suites for JUnit 4/5 and Clojure test runner.

- **Modern Completion Nether-Stack**:
  - Minimalist, lightning-fast UI built on [Vertico](https://github.com/minad/vertico) for vertical minibuffer completion.
  - Rich search, grep, and preview facilities powered by [Consult](https://github.com/minad/consult).
  - Detailed metadata annotations with [Marginalia](https://github.com/minad/marginalia).
  - Flexible multi-component pattern matching via [Orderless](https://github.com/oantolin/orderless).
  - In-buffer popup completion powered by [Corfu](https://github.com/minad/corfu) + [Cape](https://github.com/minad/cape).

- **Performance & Aggressive Garbage Execution**:
  - Garbage collection held off during boot, then a low-pause runtime threshold, with `gcmh` collecting while you're idle.
  - Early-init pre-frame suppression of UI chrome (toolbars, menu bars, scroll bars) and deferral of package loading.
  - Native compilation (`native-comp`) caching cutting cold boot to **~0.05 seconds**.

- **Stock Emacs DNA (The 40-Year Purist Guarantee)**:
  - 100% pure GNU Emacs keybindings (`C-x`, `C-c`, `M-x`, `M-.`, `dired`, standard buffer switching).
  - Zero Evil/Vim modal interference — built so veterans with decades of muscle memory feel instantly empowered with 2026 IDE intelligence.
  - All custom Hellmacs leader shortcuts live cleanly under `C-c h`.

- **Enterprise-Grade Reproducibility & CLI**:
  - Dedicated CLI tool (`bin/hellmacs`) handling `install`, `sync`, `upgrade`, `doctor`, `lock`, `bundle`, `verify`, `sbom`, `licenses`, `config`, `env`, `gc`, `version` and `test`, one file per command (`bin/hellmacs-COMMAND`).
  - Doom Emacs v3's architecture and layout: the engine in `lisp/`, the module catalog as a source (`sources/hellmacs+/`), module metadata (`.hellmacsmodule`), implicit profiles (with `safe-mode` for when something breaks), and an `init.el` generated per profile by `sync`.
  - Clean XDG directory isolation (`~/.config/emacs`, `~/.config/hellmacs`) and pinned package locks.
  - Offline bundles: `bin/hellmacs bundle` packs packages, language servers and grammars into one archive, and `bin/hellmacs install --from-bundle` installs it with no network access at all, checking every file's SHA-256.
  - Git supremacy via [Magit](https://github.com/magit/magit) — the definitive Git interface.

---

## 🔥 Look & Feel

Three `:ui` modules, all on by default (`static/init.example.el`):

- **`theme`**: `hellmacs-inferno`, Hellmacs' own theme with no dependencies. It covers the built-in faces, tree-sitter, the completion stack, lsp-mode, dap-mode, Magit, CIDER, the dashboard and the mode-line. Use another theme with `(setq hellmacs-theme 'modus-vivendi)` in your `init.el`, or `nil` for none.
- **`dashboard`**: the startup screen, The Altar. It shows the sigil banner, the startup time, 5 recent files, 5 projects and 3 bookmarks, with a footer that changes on each redraw. It keeps stock keys: `TAB`/`S-TAB` move between items, `RET` opens one, `g` redraws, `q` buries it, and `C-c h s` brings it back. `(setq hellmacs-splash-enable nil)` starts on `*scratch*` instead.
- **`modeline`**: a minimal [doom-modeline](https://github.com/seagle0128/doom-modeline). Left: the buffer and position. Right: the language server's state (`JVM:ready`, `JVM:purgatory` after a failed build), the debugger, the major mode, the Git branch and flymake's counts. It turns on with the first real buffer, keeping its load out of the startup time; the startup screen has the stock mode-line, in the same colours.

The palette:

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

Every text colour is at least 4.5:1 against the background it's drawn on (`test/test-theme.el` checks each pair).

**Icons and fonts.** The dashboard and the mode-line draw [nerd-icons](https://github.com/rainstormstudio/nerd-icons.el) when the frame has a [Nerd Font](https://www.nerdfonts.com/font-downloads). Without one they fall back to plain text. `bin/hellmacs doctor` says whether one is installed, and `M-x nerd-icons-install-fonts` installs one into `~/.local/share/fonts`.

**In a terminal** (`emacs -nw`, `emacsclient -t`):
- The dashboard shows the ASCII sigil (`assets/banner-ascii.txt`) instead of the picture.
- Both modules draw text instead of icons, because a terminal can't tell Emacs which font it uses. If your terminal's font is a Nerd Font, `(setq hellmacs-dashboard-tty-icons t hellmacs-modeline-tty-icons t)` turns icons on.
- Each frame decides for itself, so a GUI frame and an `emacsclient -t` frame of the same Emacs each get what they can draw.

---

## ⚡ Requirements

- [GNU Emacs ≥ 29.1](https://www.gnu.org/software/emacs/) (Built with `native-comp`, `tree-sitter`, and `json` support recommended)
- [Java JDK ≥ 21](https://adoptium.net/) (`JAVA_HOME` configured; Eclipse JDTLS runtime requirement)
- [Git ≥ 2.25](https://git-scm.com/) (For cloning and package management)
- [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd) (Fast project search and file navigation)
- [Nerd Fonts (v3.0+)](https://www.nerdfonts.com/font-downloads) (e.g. *JetBrainsMono Nerd Font*), optional: icons on the dashboard and the mode-line, [text without](#-look--feel)
- Optional Tooling:
  - [Clojure CLI / Leiningen](https://clojure.org/) — for Clojure development & CIDER REPL
  - [Maven](https://maven.apache.org/) / [Gradle](https://gradle.org/) — for JVM project builds
  - [kotlin-language-server](https://github.com/fwcd/kotlin-language-server) — for Kotlin LSP intelligence

---

## 🛠️ Installation

<details open><summary><b>Quickstart (Linux / macOS)</b></summary>
<br>

Clone Hellmacs directly into your Emacs configuration directory and run the automated installer:

```bash
git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs
~/.config/emacs/bin/hellmacs install --env
emacs
```

</details>

<details><summary><b>Manual Installation</b></summary>
<br>

1. **Backup existing Emacs configuration:**

```bash
mv ~/.config/emacs ~/.config/emacs.bak 2>/dev/null || mv ~/.emacs.d ~/.emacs.d.bak 2>/dev/null
```

2. **Clone and run the Hellmacs CLI:**

```bash
git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs
cd ~/.config/emacs
bin/hellmacs install
bin/hellmacs doctor
```

3. **Launch Emacs:**

```bash
emacs
```

</details>

<details><summary><b>Windows (WSL2)</b></summary>
<br>

Inside your WSL2 Ubuntu/Debian environment:

```bash
git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs
~/.config/emacs/bin/hellmacs install --env
emacs
```

*Note: For optimal performance, keep projects on the Linux filesystem (`~/...`) rather than Windows mounts (`/mnt/c/...`).*

</details>

<details><summary><b>Try it with Docker</b></summary>
<br>

Test Hellmacs in an isolated, disposable container without modifying your local environment:

```bash
docker run -w /root --net=host -it --rm alpine:edge sh -c '
    apk add sudo curl bash git emacs-nativecomp ripgrep fd openjdk21 && \
    git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs && \
    ~/.config/emacs/bin/hellmacs install --env && \
    emacs -nw
'
```

</details>

---

## 🖥️ Platform Support Matrix

Continuous integration tested across platforms on Emacs 29.1, 29.4, 30.1+:

| Platform | Architecture | Tier / Status | Notes |
|---|---|:---:|---|
| **Linux** | `x86_64` | **Tier 1 (Full)** | Native Linux, primary development target |
| **Linux** | `arm64` | **Tier 1 (Full)** | Tested in automated CI |
| **macOS** | Apple Silicon (`arm64`) | **Tier 1 (Full)** | Homebrew / `emacs-plus` / `emacs-mac` supported |
| **macOS** | Intel (`x86_64`) | **Tier 1 (Full)** | Tested in automated CI |
| **Windows** | `WSL2` | **Tier 1 (Supported)** | Full Linux emulation with WSLg GUI support |

---

## 🔒 Privacy: No Telemetry

Hellmacs sends nothing about you or your code, and turns off the telemetry of what it installs:

- **Hellmacs itself** only goes online when you run `bin/hellmacs sync`, `install` or `upgrade` (packages, and pinned downloads checked by SHA-256), or `doctor --network`. Always through your proxy, CA and mirrors. A test fails if any other code reaches the network.
- **docker-language-server** sends usage data and crash reports to Docker by default; Hellmacs turns that off.
- **SonarLint** (`+sonarlint`): its telemetry is off.
- **clojure-lsp** downloads ClojureDocs' examples at startup; Hellmacs turns that off (`hellmacs-clojure-clojuredocs` turns it back on).
- The other servers (JDTLS, Spring Boot, kotlin-language-server, groovy-language-server, lemminx, marksman, the npm-installed ones) send nothing of their own; their `telemetry/event` messages go to Emacs, which drops them.

Your build tools (Gradle, Maven) and the language servers still fetch your project's dependencies from the repositories your build names.

---

## 📚 Documentation

Comprehensive guides, module references, and architectural specifications are located in [`docs/`](docs/):

| Guide | Description |
|---|---|
| 🏁 **[Getting Started](docs/getting-started.md)** | Prerequisites, installation walkthrough, directory layout, and initial setup |
| ⚙️ **[Configuration Guide](docs/configuration.md)** | Module system (`hellmacs!`), flags, custom packages, and user profiles |
| ☕ **[JVM Development](docs/jvm-development.md)** | Java, Kotlin, Clojure, autocompletion, semantic navigation, DAP debugging, and HCR |
| ⌨️ **[Keybindings Reference](docs/keybindings.md)** | Complete keyboard cheatsheet for standard GNU and `C-c` leader commands |
| 💻 **[CLI Reference](docs/cli.md)** | `bin/hellmacs` commands (`install`, `bundle`, `sync`, `upgrade`, `doctor`, `verify`, `sbom`, `licenses`, `lock`, `test`, ...) and profiles |
| 🧭 **[Profiles](profiles/README.md)** | Separate configurations, implicit profiles, and the `safe-mode` profile |
| 🗺️ **[Enterprise Roadmap](docs/roadmap.md)** | Multi-phase roadmap and IntelliJ/Eclipse feature parity matrix |
| 🏷️ **[Releases and Support](docs/releases.md)** | Versions, update channels (`stable`, `main`), supported Emacs and platforms, security fixes; see also the [Changelog](CHANGELOG.md) |


---

## ⚙️ Basic Setup

Hellmacs uses a declarative module declaration system configured in `~/.config/hellmacs/init.el` (or `static/init.example.el`):

```elisp
;;; init.el --- Hellmacs user configuration -*- lexical-binding: t; -*-

(hellmacs!
 :ui
 theme
 dashboard
 modeline

 :editor
 undo

 :completion
 vertico
 corfu

 :tools
 build
 debugger
 lsp
 magit

 :lang
 (java +lombok)
 kotlin
 clojure

 :config
 default)
```

Manage packages declaratively in `~/.config/hellmacs/packages.el` and custom hooks in `~/.config/hellmacs/config.el`.

---

## 🚀 Contributing

Contributions are warmly welcomed! Please check our development guides before contributing:
- [Contributing & Module Development](docs/development/contributing.md)
- [System Architecture & Design System](docs/development/architecture.md) (with how Hellmacs maps onto Doom Emacs v3's layout)
- [Vision & Operational Invariants](docs/development/vision-and-rules.md)
- [Roadmap Work Order](docs/development/work-order.md)


Pull requests are verified through unit and integration suites run via `bin/hellmacs test`. The [File Structure](#-file-structure) below says where each kind of code goes.

---

## 📂 File Structure

Hellmacs follows Doom Emacs v3's layout (`doomemacs/core`): the engine in
`lisp/`, core's own module in `modules/`, the module catalog as a source in
`sources/`, one file per command in `bin/`, and no `init.el` of its own
(`bin/hellmacs sync` generates each profile's):

<pre>
~/.config/emacs
├── early-init.el            # Pre-frame boot: GC tuning, dir layout, UI chrome; hands Emacs the profile's init file
├── .hellmacs                # The project: name, version, commit style (Doom's .doom)
├── bin/
│   ├── hellmacs             # Command-line tool: dispatches to bin/hellmacs-COMMAND
│   ├── hellmacs-sync, -doctor, -install, -upgrade, ...   # One file per command
│   └── hellmacsscript       # Runs a bin/hellmacs-COMMAND directly (Doom's doomscript)
├── lisp/                    # The engine: hellmacs.el (the heart), -lib, -modules, -packages, -profiles, -cli, ...
│   ├── lib/                 # Library parts, loaded with hellmacs-require (jdk, net, lsp-status)
│   └── cli/                 # The CLI's parts (bundle, compliance, config, verify)
├── modules/
│   └── hellmacs/            # Core's own module, :hellmacs, always on: the Altar, themed UX, gcmh
├── sources/
│   └── hellmacs+/modules/   # The module catalog, enabled with (hellmacs! ...)
│       ├── checkers/        # Static analysis: Checkstyle, PMD, SpotBugs, SonarLint
│       ├── completion/      # Corfu, Vertico, Consult, Orderless, Marginalia, Cape
│       ├── config/          # Default settings, key bindings
│       ├── editor/          # Undo history, formatting, snippets, file templates
│       ├── lang/            # Java, Kotlin, Clojure, Groovy, and the files JVM repos carry
│       ├── tools/           # LSP, DAP debugger, Magit, builds, runs, tests, HTTP, databases
│       └── ui/              # Dashboard, modeline, theme, popups
├── profiles/                # Profiles Hellmacs ships (safe-mode); see profiles/README.md
├── docs/                    # User, developer and AI context documentation
├── static/                  # Starter templates (init.example.el, config.example.el, packages.example.el, module-template/)
├── test/                    # ERT unit and integration test suites
└── themes/                  # Custom color themes (hellmacs-inferno-theme.el)
</pre>

Each module has a `.hellmacsmodule` (Doom's `.doommodule`) naming it. Your own
modules go in `~/.config/hellmacs/modules/<group>/<name>/` and win over
Hellmacs' own.

---

## ⭐ Credits

Sincere appreciation to the following projects, maintainers, and the GNU Emacs community that make Hellmacs possible:

- [GNU Emacs](https://www.gnu.org/software/emacs/) — the extensible, customizable computing environment
- [Doom Emacs](https://github.com/doomemacs/doomemacs) & [hlissner](https://github.com/hlissner) — architectural inspiration for clean module and CLI paradigms
- [Vertico](https://github.com/minad/vertico), [Consult](https://github.com/minad/consult), [Corfu](https://github.com/minad/corfu), [Cape](https://github.com/minad/cape), [Marginalia](https://github.com/minad/marginalia) & [Daniel Mendler (minad)](https://github.com/minad)
- [Orderless](https://github.com/oantolin/orderless) & [Omar Antolín Camarena](https://github.com/oantolin)
- [lsp-mode](https://github.com/emacs-lsp/lsp-mode), [lsp-java](https://github.com/emacs-lsp/lsp-java) & [dap-mode](https://github.com/emacs-lsp/dap-mode)
- [CIDER](https://github.com/clojure-emacs/cider) & [Bozhidar Batsov (bbatsov)](https://github.com/bbatsov)
- [Magit](https://github.com/magit/magit) & [Jonas Bernoulli (tarsius)](https://github.com/tarsius)
- [Eclipse JDT LS](https://github.com/eclipse-jdtls/eclipse.jdt.ls)

---

## 🛡️ License

Hellmacs is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0-or-later)**.

Copyright (C) 2026 petrolal <petrolalucas@gmail.com>

- **Copyleft / Open Source Requirement:** Anyone who modifies, forks, or distributes Hellmacs (or derivative works) **must** release their changes as open source under the GNU GPL v3.0 license.
- **Attribution / Name Protection:** All copyright notices and author attributions to `petrolal` must be preserved.
- See the full license in [`LICENSE`](LICENSE).
