<div align="center">

![Hell Emacs Banner](assets/banners/banner-960.png)

</div>

---

<h4 align="center">
  <a href="#-installation">Install</a>
  ·
  <a href="#-requirements">Requirements</a>
  ·
  <a href="#-features">Features</a>
  ·
  <a href="docs/guide.md#2-your-configuration">Setup</a>
</h4>

<p align="center">
    <a href="https://github.com/petrolal/hell-emacs/pulse"><img src="https://img.shields.io/github/last-commit/petrolal/hell-emacs?style=for-the-badge&logo=github&color=e06c75&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hell-emacs/releases/latest"><img src="https://img.shields.io/github/v/release/petrolal/hell-emacs?style=for-the-badge&logo=gitbook&color=e5c07b&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hell-emacs/stargazers"><img src="https://img.shields.io/github/stars/petrolal/hell-emacs?style=for-the-badge&logo=apachespark&color=eed49f&logoColor=D9E0EE&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hell-emacs/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-GPL_v3.0-a6da95?style=for-the-badge&logo=gnu&logoColor=D9E0EE&labelColor=1a1016"></a>
    <br>
    <a href="https://www.gnu.org/software/emacs/"><img src="https://img.shields.io/badge/Emacs-29.1+-7c5295?style=for-the-badge&logo=gnuemacs&logoColor=white&labelColor=1a1016"></a>
    <a href="https://adoptium.net/"><img src="https://img.shields.io/badge/Java-JDK_21+-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white&labelColor=1a1016"></a>
    <a href="https://clojure.org/"><img src="https://img.shields.io/badge/Clojure-1.11+-5881D8?style=for-the-badge&logo=clojure&logoColor=white&labelColor=1a1016"></a>
    <a href="https://kotlinlang.org/"><img src="https://img.shields.io/badge/Kotlin-2.0+-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white&labelColor=1a1016"></a>
    <a href="https://github.com/petrolal/hell-emacs/actions"><img src="https://img.shields.io/badge/CI-Passing-cba6f7?style=for-the-badge&logo=githubactions&logoColor=D9E0EE&labelColor=1a1016"></a>
</p>

<p align="center">
<strong>Hell Emacs</strong> is an infernal, pure native GNU Emacs distribution engineered to subjugate the Java Virtual Machine (Java, Kotlin, Clojure, Groovy, Gradle, Maven; Scala is on the roadmap). Built with stock Emacs DNA and zero modal bloat — delivering sub-50ms startup times, deep DAP debugging, hot code replacement, and enterprise IDE firepower.
</p>

---

## Features

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
  - Deferral of package loading; the frame keeps GNU Emacs' own menu bar, tool bar and scroll bars.
  - Native compilation (`native-comp`) caching cutting cold boot to **~0.05 seconds**.

- **Stock Emacs DNA (The 40-Year Purist Guarantee)**:
  - 100% pure GNU Emacs keybindings (`C-x`, `C-c`, `M-x`, `M-.`, `dired`, standard buffer switching).
  - Zero Evil/Vim modal interference — built so veterans with decades of muscle memory feel instantly empowered with 2026 IDE intelligence.
  - All custom Hell Emacs leader shortcuts live cleanly under `C-c h`.

- **Enterprise-Grade Reproducibility & CLI**:
  - Doom Emacs v3's architecture, install and CLI: `bin/hell install`, `sync`, `upgrade`, `doctor`, `emacs`, `info`, `profile`, `lock`, `bundle`, `verify`, `sbom`, `licenses` and more, one file per command; modules with `hell!` and `package!`; profiles, with `safe-mode` for when something breaks; a startup file generated by `sync`.
  - Clean XDG directory isolation (`~/.config/emacs`, `~/.config/hell-emacs`) and pinned package locks.
  - Offline bundles: `bin/hell bundle` packs packages, language servers and grammars into one archive, and `bin/hell install --from-bundle` installs it with no network access at all, checking every file's SHA-256.
  - Git supremacy via [Magit](https://github.com/magit/magit) — the definitive Git interface.

---

## Look & Feel

The look, on by default: the `:ui theme` module (`static/init.example.el`) and the Altar, in core:

- **`theme`**: `hell-inferno`, Hell Emacs' own theme with no dependencies. It covers the built-in faces, tree-sitter, the completion stack, lsp-mode, dap-mode, Magit, CIDER and the mode-line. Use another theme with `(setq hell-theme 'modus-vivendi)` in your `init.el`, or `nil` for none.
- **The Altar**: the startup screen is GNU Emacs' own (`*GNU Emacs*`, `fancy-startup-screen`), with the same layout and features: the link table, "To start...", the newcomer presets checkbox, the version line, the auto-save recovery notice, and the concise "Dismiss this startup screen" panel beside files opened from the command line. Hell Emacs changes only the logo (the chimera skull, `assets/banners/splash.svg`) and the words: a Hell Emacs welcome line and manual row, a forge line with the profile and startup time under the version, and, at the bottom, buttons only for what the stock screen has no link to: IntelliJ Exorcism (the key finder), Issue Sanctum (the issue tracker) and Release Grimoires (the changelog). "Explore Packages" opens the Relic Chamber (`hell-plugins`), since packages come from `package!`. Stock keys: `TAB`/`S-TAB` move between links, `RET` follows one, `SPC`/`DEL` scroll, `q` dismisses; `C-c h s` brings it back. `(setq hell-splash-enable nil)` starts on `*scratch*` instead; with `hell-ux-enable nil` it is the stock GNU screen. The frame keeps GNU Emacs' menu bar, tool bar and scroll bars, themed; turn them off with the stock `menu-bar-mode`, `tool-bar-mode` and `scroll-bar-mode` in your `config.el`. The mode line is Emacs' own, in the theme's colours, with the language server's state (`JVM:ready`, `JVM:purgatory` after a failed build) beside the mode.

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

Every text colour is at least 4.5:1 against the background it's drawn on.

**Icons and fonts.** Dired, the minibuffer and the completion popup draw [nerd-icons](https://github.com/rainstormstudio/nerd-icons.el) when the frame has a [Nerd Font](https://www.nerdfonts.com/font-downloads). Without one they show boxes. `bin/hell doctor` says whether one is installed, and `M-x nerd-icons-install-fonts` installs one into `~/.local/share/fonts`.

**In a terminal** (`emacs -nw`, `emacsclient -t`) the startup screen is GNU Emacs' text one.

---

## Requirements

- [GNU Emacs ≥ 29.1](https://www.gnu.org/software/emacs/), with native-comp and tree-sitter recommended
- [Java JDK ≥ 21](https://adoptium.net/) (to run Eclipse JDTLS; your projects can target Java 8 and up)
- [Git ≥ 2.25](https://git-scm.com/), [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd), a C compiler and `make` (tree-sitter grammars), `unzip`
- Optional: Maven or Gradle, the Clojure CLI or Leiningen, [direnv](https://direnv.net/), Node 20+ (YAML, JSON and shell servers), a [Nerd Font](https://www.nerdfonts.com/font-downloads) for icons

Language servers aren't on this list: `hell sync` installs pinned copies (JDTLS, kotlin-language-server, clojure-lsp, ...), each checked by SHA-256.

---

## Installation

As Doom Emacs: clone it as your Emacs directory, then run its installer.

1. **Install the [requirements](#requirements)**:
   ```bash
   # Ubuntu 24.04+ / Debian 13+ (then link fdfind to fd: see the guide)
   sudo apt install emacs git openjdk-21-jdk ripgrep fd-find build-essential unzip
   # Arch
   sudo pacman -S --needed emacs git jdk21-openjdk ripgrep fd base-devel unzip
   # Nix (on NixOS, add these to environment.systemPackages and set programs.nix-ld.enable = true)
   nix profile install nixpkgs#{emacs,git,jdk21,ripgrep,fd,gcc,gnumake,unzip}
   ```
   ([Fedora, macOS, WSL2 and the details](docs/guide.md#step-1-get-the-requirements)).
2. **Move any old config away** (`~/.emacs`, `~/.emacs.d`, `~/.config/emacs`), or
   [install alongside it](docs/guide.md#alongside-another-config).
3. **Clone and install** (takes a few minutes: packages, language servers, grammars):
   ```bash
   git clone https://github.com/petrolal/hell-emacs.git ~/.config/emacs
   ~/.config/emacs/bin/hell install
   ```
4. **Put `hell` on your `PATH`**:
   `echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> ~/.bashrc`
5. **Start it**: `emacs`. `hell doctor` checks everything if something's off.

`install` creates your config in `~/.config/hell-emacs/`, installs every package and language server (each checked by SHA-256), offers to save your shell environment, and runs `doctor`. Don't clone with `--depth 1` (`upgrade` follows release tags).

The [install guide](docs/guide.md#1-install) has each step in detail, plus proxies, offline machines, Docker, moving from Hellmacs and uninstalling.

---

## Basic Setup

Modules are chosen in `~/.config/hell-emacs/init.el`, which lists every one Hell Emacs has, the optional ones commented out:

```elisp
(hell! :ui         theme
       :editor     undo
       :completion vertico corfu
       :tools      build debugger direnv lsp magit run test editorconfig
       :lang       (java +lombok +spring) kotlin clojure
       :config     default)
```

Extra packages go in `packages.el` (`(package! name)`), your own settings in `config.el`. **After changing either, run `hell sync`** (or press `C-c h R` in Emacs). Details in the [guide](docs/guide.md#2-your-configuration).

---

## Contributing

Contributions are warmly welcomed! Read the [rules](docs/roadmap.md#rules) and the [development guide](docs/development.md), then take the next open item in the [roadmap](docs/roadmap.md#open-work-in-order). CI checks every pull request: it installs Hell Emacs, runs `doctor`, and checks every license.

---

## Credits

Sincere appreciation to the following projects, maintainers, and the GNU Emacs community that make Hell Emacs possible:

- [GNU Emacs](https://www.gnu.org/software/emacs/) — the extensible, customizable computing environment
- [Doom Emacs](https://github.com/doomemacs/doomemacs) & [hlissner](https://github.com/hlissner) — architectural inspiration for clean module and CLI paradigms
- [Vertico](https://github.com/minad/vertico), [Consult](https://github.com/minad/consult), [Corfu](https://github.com/minad/corfu), [Cape](https://github.com/minad/cape), [Marginalia](https://github.com/minad/marginalia) & [Daniel Mendler (minad)](https://github.com/minad)
- [Orderless](https://github.com/oantolin/orderless) & [Omar Antolín Camarena](https://github.com/oantolin)
- [lsp-mode](https://github.com/emacs-lsp/lsp-mode), [lsp-java](https://github.com/emacs-lsp/lsp-java) & [dap-mode](https://github.com/emacs-lsp/dap-mode)
- [CIDER](https://github.com/clojure-emacs/cider) & [Bozhidar Batsov (bbatsov)](https://github.com/bbatsov)
- [Magit](https://github.com/magit/magit) & [Jonas Bernoulli (tarsius)](https://github.com/tarsius)
- [Eclipse JDT LS](https://github.com/eclipse-jdtls/eclipse.jdt.ls)

---

## License

Hell Emacs is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0-or-later)**.

Copyright (C) 2026 petrolal <petrolalucas@gmail.com>

- **Copyleft / Open Source Requirement:** Anyone who modifies, forks, or distributes Hell Emacs (or derivative works) **must** release their changes as open source under the GNU GPL v3.0 license.
- **Attribution / Name Protection:** All copyright notices and author attributions to `petrolal` must be preserved.
- See the full license in [`LICENSE`](LICENSE).
