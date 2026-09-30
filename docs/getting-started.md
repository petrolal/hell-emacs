# Getting Started with Hellmacs

Welcome to **Hellmacs** — the infernal, enterprise-grade JVM hacking environment for Emacs.

---

## Prerequisites

Before installing Hellmacs, ensure you have the following installed on your system:

| Tool | Minimum Version | Purpose |
|---|---|---|
| **Emacs** | `29.1+` (30.1+ recommended for `clojure-ts-mode`) | Core editor with native compilation support |
| **Git** | `2.25+` | Package fetching via Elpaca & Magit |
| **JDK** | `21+` | Needed to run Eclipse JDTLS (target projects can use Java 8/11/17/21+) |
| **C Compiler & Make** | `gcc` / `clang`, `make` | Building Tree-sitter grammars (pinned during sync) |
| **ripgrep & fd** | Latest | Fast project search in Vertico/Consult (`rg`, `fd`) |

Optional tools:
* `mvn` / `gradle`: Maven / Gradle for building projects without wrapper scripts.
* `unzip`: Required to install pinned Kotlin / Clojure language servers.
* `lein` / `clojure` / `bb`: Clojure REPL tooling for CIDER.
* `direnv`: per-project environments from `.envrc` (`:tools direnv` is on by default; `doctor` warns when it's missing).

Language servers aren't on these lists: `sync` downloads pinned copies (JDTLS, kotlin-language-server, clojure-lsp, ...) and checks each one's SHA-256.

---

## Installation

### 1. Clone the repository
Clone Hellmacs to your Emacs configuration directory:

```sh
# Standard installation
git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs

# Or clone to any directory and point Emacs to it:
git clone https://github.com/petrolal/hellmacs.git ~/hellmacs
```

Hellmacs installs the way Doom Emacs does: clone it as your Emacs directory, then run its `bin/` installer. Your own config goes in `~/.config/hellmacs/` (Doom's is `~/.config/doom/`), never in the clone. Don't clone with `--depth 1`: `bin/hellmacs upgrade` follows release tags.

### 2. Run the installer
Run `bin/hellmacs install` with `--env` to create your user configuration and save your shell environment (`JAVA_HOME`, `PATH`, etc.):

```sh
~/.config/emacs/bin/hellmacs install --env
```

What `install` does:
1. Creates your isolated user configuration in `~/.config/hellmacs/` from templates in `static/`.
2. Runs `bin/hellmacs sync` to download and compile all packages declared in enabled modules.
3. Saves environment variables (`JAVA_HOME`, `PATH`, etc.) into `~/.local/share/hellmacs/env.eld`.
4. Runs `bin/hellmacs doctor` to verify your environment, then says how to start Emacs: plain `emacs` when Hellmacs is in `~/.config/emacs`, `emacs --init-directory DIR` when it's elsewhere.

### 3. Start Hellmacs
Launch Emacs:

```sh
emacs
# or if cloned to a custom directory:
emacs --init-directory ~/hellmacs
```

There's no `init.el` in the Hellmacs checkout: as in Doom Emacs v3, `sync` generates one for your profile, in `~/.local/share/hellmacs/`, and Emacs starts from it.

Add `~/.config/emacs/bin` to your `PATH` to run `hellmacs sync`, `hellmacs doctor` and the rest from anywhere.

### 4. Add modules
Your `~/.config/hellmacs/init.el` lists every module Hellmacs has, the optional ones commented out. Uncomment one (say `:lang groovy`), then run `hellmacs sync` and restart Emacs. For your own modules, see the [Configuration Guide](configuration.md#creating-private-custom-modules). A plugin manager for third-party modules is planned ([roadmap](roadmap.md), Phase 15).

### If something breaks
Start the `safe-mode` profile: Hellmacs' core, with none of your modules or config. If it works, add your modules back one at a time to find the culprit.

```sh
~/.config/emacs/bin/hellmacs --profile safe-mode sync
emacs --profile safe-mode
```

---

## Platform Guides

### 🍎 macOS (Apple Silicon & Intel)
1. Install Emacs 29.1+ (e.g. via Homebrew: `brew install --cask emacs` or `brew install emacs-plus`).
2. Install prerequisites:
   ```sh
   brew install openjdk@21 ripgrep fd zstd
   ```
3. Run `bin/hellmacs env` so GUI Emacs instances inherit your shell's `PATH` and `JAVA_HOME`.

### 🪟 Windows (WSL2 Supported Path)
1. Ensure **WSL2** is installed with Ubuntu or your preferred Linux distribution (`wsl --install`).
2. Launch your WSL2 terminal and follow the standard Linux installation steps.
3. **Important for performance:** Clone Hellmacs and keep your project repositories on the **Linux ext4 filesystem** (e.g., `~/projects/...` or `/home/username/...`), **not** on Windows mounts (`/mnt/c/...`). The 9P file boundary across Windows mounts incurs heavy I/O overhead.
4. For GUI mode, launch `emacs` inside WSL2 directly; WSLg handles window rendering natively on Windows 11.

---

## Directory Layout & State Isolation

Hellmacs strictly follows the **XDG Base Directory Specification**, keeping your `$HOME` clean:

| Purpose | Directory Path | Safe to delete? |
|---|---|---|
| **User Configuration** | `~/.config/hellmacs/` (or `$HELLMACSDIR`) | **No** — this contains your personal `init.el`, `config.el`, and `packages.el` |
| **Installed Packages & Profiles** | `~/.local/share/hellmacs/` (each profile's generated `init.el` too) | **Yes** — regenerated with `bin/hellmacs sync` |
| **Caches & Native Compilations** | `~/.cache/hellmacs/` | **Yes** — automatically rebuilt as needed |
| **State, History & Undo Sessions** | `~/.local/state/hellmacs/` | **Yes** — but your undo history, recent files, and bookmarks will be reset |

---

## Next Steps

* [Configuration Guide](configuration.md) — Learn how to enable/disable modules and flags.
* [JVM Development](jvm-development.md) — Set up Java, Kotlin, and Clojure workflows, code completion, and DAP debugging.
* [Keybindings Reference](keybindings.md) — Explore the full keyboard shortcut map.
* [CLI Reference](cli.md) — Manage packages, offline bundles, doctor checks, and profiles.

