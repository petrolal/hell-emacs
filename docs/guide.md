# Hell Emacs Guide

Everything about installing, configuring and running Hell Emacs. For the JVM
languages and tools, see the [JVM guide](jvm.md); for keys, the
[keybindings](keybindings.md); for every command, the [CLI reference](cli.md).

Hell Emacs installs and works like [Doom Emacs](https://github.com/doomemacs/core):
if you know Doom, you know where everything is. The difference is the keys:
Hell Emacs keeps stock GNU Emacs bindings.

---

## 1. Install

Short version, on a machine with the [requirements](#requirements) and no
other Emacs config:

```sh
git clone https://github.com/petrolal/hell-emacs.git ~/.config/emacs
~/.config/emacs/bin/hell install
emacs
```

The rest of this section is each step in detail.

### Requirements

| Tool | Version | For |
|---|---|---|
| GNU Emacs | 29.1+ (30.1+ for `clojure-ts-mode`), built with tree-sitter (YAML, Dockerfile and TypeScript use Emacs' own tree-sitter modes); native-comp recommended | Everything |
| Git | 2.25+ (2.31+ behind a proxy or mirror) | Packages, Magit, `hell upgrade` |
| JDK | 21+ | Running JDTLS; your projects can target Java 8 and up |
| ripgrep, fd | any recent | Project search |
| A C compiler and `make` | any | Building the pinned tree-sitter grammars |
| `unzip` | any | Installing the Kotlin and Clojure servers |

Optional: Maven or Gradle (projects without a wrapper), `clojure`/`lein`/`bb`
(Clojure REPLs), `direnv` (per-project environments), Node 20+ (the YAML,
JSON, shell and `+httpyac` servers), a [Nerd Font](https://www.nerdfonts.com)
(icons). Language servers aren't on this list: `sync` installs pinned copies.

### Step 1: get the requirements

- **Ubuntu 24.04+, Debian 13+**:
  ```sh
  sudo apt install emacs git openjdk-21-jdk ripgrep fd-find build-essential unzip
  mkdir -p ~/.local/bin && ln -s "$(command -v fdfind)" ~/.local/bin/fd
  ```
  Debian names fd `fdfind`; the link makes it `fd` (with `~/.local/bin` on
  your `PATH`). Older releases (Ubuntu 22.04, Debian 12) ship Emacs 27 or
  28, too old: build Emacs or use a newer release.
- **Fedora**:
  ```sh
  sudo dnf install emacs git java-21-openjdk-devel ripgrep fd-find gcc make unzip
  ```
  (`java-latest-openjdk-devel` works too: any JDK 21 or later.)
- **Arch Linux** (and Manjaro, EndeavourOS):
  ```sh
  sudo pacman -S --needed emacs git jdk21-openjdk ripgrep fd base-devel unzip
  sudo pacman -S --needed nodejs npm   # optional: YAML, JSON and shell servers
  ```
  With several JDKs installed, `archlinux-java status` lists them and
  `sudo archlinux-java set java-21-openjdk` picks the default one (any
  21 or later works).
- **NixOS**: in `configuration.nix`, then `sudo nixos-rebuild switch`:
  ```nix
  environment.systemPackages = with pkgs; [
    emacs git jdk21 ripgrep fd gcc gnumake unzip
    nodejs   # optional: YAML, JSON and shell servers
  ];
  # clojure-lsp and marksman are prebuilt Linux binaries that sync
  # downloads: they need nix-ld to run on NixOS.
  programs.nix-ld.enable = true;
  ```
  With Home Manager, put the same packages in `home.packages` (nix-ld
  stays a system option). Install Emacs as a plain package, not through
  `programs.emacs.extraPackages`: Hell Emacs installs its own packages
  with Elpaca.
- **Nix on another Linux or macOS**:
  ```sh
  nix profile install nixpkgs#{emacs,git,jdk21,ripgrep,fd,gcc,gnumake,unzip}
  ```
  (or `nix-env -iA nixpkgs.emacs nixpkgs.git ...` without flakes). nix-ld
  isn't needed outside NixOS.
- **macOS**:
  ```sh
  brew tap d12frosted/emacs-plus
  brew install emacs-plus openjdk@21 ripgrep fd
  ```
- **Windows**: install a distribution in WSL2 (`wsl --install -d Ubuntu`),
  then follow the Ubuntu line inside it. See [Platforms](#platforms).

Check the versions before going on:

```sh
emacs --version    # GNU Emacs 29.1 or later
java -version      # 21 or later
```

Several JDKs can be installed side by side: the one that runs JDTLS only
needs to be 21+, and each project picks its own (see the
[JVM guide](jvm.md)).

### Step 2: move any other Emacs config out of the way

Emacs reads the first of `~/.emacs`, `~/.emacs.el`, `~/.emacs.d/`, then
`~/.config/emacs/`, so an older config would be loaded instead of Hell
Emacs. Rename what you have:

```sh
mv ~/.emacs      ~/.emacs.bak        # if it exists
mv ~/.emacs.d    ~/.emacs.d.bak      # if it exists
mv ~/.config/emacs ~/.config/emacs.bak  # if it exists; git won't clone into it
```

To keep using your old config, skip this step and install Hell Emacs
[somewhere else](#alongside-another-config) instead.

### Step 3: clone and install

```sh
git clone https://github.com/petrolal/hell-emacs.git ~/.config/emacs
~/.config/emacs/bin/hell install
```

Don't clone with `--depth 1`: `hell upgrade` follows release tags.

`install` takes several minutes the first time (it downloads packages and
language servers, and compiles grammars) and is safe to run again. It:

1. warns about anything that would make Emacs skip Hell Emacs (a `~/.emacs`,
   or a `~/.emacs.d` while Hell Emacs is in `~/.config/emacs`);
2. creates your config in `~/.config/hell-emacs/` from `static/`
   (`init.el`, `config.el`, `packages.el`); an existing one is kept;
3. syncs: installs every package and language server your modules need,
   each checked by SHA-256, and generates the file Emacs starts from;
4. asks whether to save your shell environment (`PATH`, `JAVA_HOME`, ...)
   for Emacs started from a desktop launcher or the macOS Dock. Say yes
   unless you only start Emacs from a terminal;
5. runs `doctor` and says how to start Emacs.

Its options:

| Option | Does |
|---|---|
| `--env` / `--no-env` | Answer the environment question without asking |
| `--no-config` | Don't create `~/.config/hell-emacs/` |
| `--no-install` | Don't sync now; run `hell sync` before starting Emacs |
| `--aot` | Native-compile every package now instead of on first use |
| `--from-bundle FILE` | Install from an offline bundle, without network ([Companies](#6-companies-networks-offline-machines-compliance)) |
| `-!` (before `install`) | Accept every prompt: for scripts and provisioning |

Behind a proxy or a corporate CA? Run `hell install --no-install` first,
set the proxy in `~/.config/hell-emacs/init.el` as in
[Companies](#6-companies-networks-offline-machines-compliance), then
`hell sync`.

### Step 4: put `hell` on your PATH

```sh
# bash
echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> ~/.bashrc
# zsh
echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> ~/.zshrc
# fish
fish_add_path ~/.config/emacs/bin
```

Open a new shell: `hell sync`, `hell doctor` and the rest now work from
anywhere. Optional, but the rest of the documentation assumes it.

### Step 5: start it and check

```sh
hell doctor   # every check passes, or says what to install
emacs
```

Emacs opens on the Altar, Hell Emacs' start screen, and `*Messages*`
(`C-h e`) says `Hell Emacs ready in 0.0Ns`. Open a Java project with
`C-x p p` or `C-x C-f`: the first time, JDTLS imports it, which takes a
minute or more on a large Maven or Gradle build; the mode-line shows
`JVM:ready` when it's done. From here:

- [Your configuration](#2-your-configuration): choose modules, add packages.
- The [JVM guide](jvm.md): building, running, testing, debugging.
- The [keybindings](keybindings.md): stock Emacs keys, plus `C-c` groups.

If something fails, `hell doctor` names it and links to the fix in
[What doctor's messages mean](#what-doctors-messages-mean).

### Alongside another config

Hell Emacs can live anywhere, and leaves your current config alone:

```sh
git clone https://github.com/petrolal/hell-emacs.git ~/hell-emacs
~/hell-emacs/bin/hell install
~/hell-emacs/bin/hell emacs        # or: emacs --init-directory ~/hell-emacs
```

Plain `emacs` keeps starting your old config. Your Hell Emacs config is still
`~/.config/hell-emacs/` (`$HELLDIR` moves it).

### Versions

`hell upgrade` updates Hell Emacs and its packages to the latest release
(the stable channel). Until the first release is tagged, a clone is the
development branch: `hell upgrade --channel main` follows it. See
[Staying up to date](#3-staying-up-to-date--updating-production).

### Platforms

- **Linux** (x86-64, arm64): as above.
- **macOS** (Apple Silicon, Intel): as above. Say yes to saving the
  environment (or run `hell env` later) so an Emacs started from the Dock
  gets your shell's `PATH` and `JAVA_HOME`.
- **Windows**: through WSL2, as on Linux. Keep Hell Emacs and your projects
  on the Linux filesystem (`~/...`), not `/mnt/c/`: the Windows mount is
  slow. WSLg shows GUI Emacs on Windows 11.
- **Termux** and systems without `/usr/bin/env`: run `bin/hell.sh` instead
  of `bin/hell`.
- **Try it in Docker**, without touching your machine:
  ```sh
  docker run -it --rm alpine:edge sh -c '
    apk add bash git emacs-nativecomp ripgrep fd openjdk21 unzip build-base &&
    git clone https://github.com/petrolal/hell-emacs.git ~/.config/emacs &&
    ~/.config/emacs/bin/hell -! install && emacs -nw'
  ```

### Coming from Hellmacs

Hell Emacs was called Hellmacs, and the old names no longer work. In your
checkout:

```sh
git pull
mv ~/.config/hellmacs ~/.config/hell-emacs
mv ~/.local/state/hellmacs ~/.local/state/hell-emacs   # keeps history, recent files, undo
rm -rf ~/.local/share/hellmacs ~/.cache/hellmacs        # rebuilt by sync
bin/hell sync
```

In your `init.el` and `config.el`, `hellmacs-` becomes `hell-` (`hellmacs!`
is `hell!`); `$HELLMACSDIR` and `$HELLMACS_PROFILE` are `$HELLDIR` and
`$HELL_PROFILE`; a named profile's `~/.config/hellmacs-NAME/` is
`~/.config/hell-emacs-NAME/`. The [CHANGELOG](../CHANGELOG.md) lists every
rename.

### Uninstall

```sh
rm -rf ~/.config/emacs ~/.local/share/hell-emacs ~/.cache/hell-emacs ~/.local/state/hell-emacs
```

and remove the `PATH` line from your shell's rc file. Keep (or back up)
`~/.config/hell-emacs/`, your config, if you might come back; named
profiles have their own `hell-emacs-NAME` directories in the same places.
Restore your old config by renaming the `.bak` files from step 2.

---

## 2. Your configuration

Your config is `~/.config/hell-emacs/` (`$HELLDIR` moves it; Doom's is
`~/.config/doom/`). Hell Emacs never writes into its own checkout.

| File | What goes in it |
|---|---|
| `init.el` | The `hell!` block: which modules are on. Settings Hell Emacs reads early (theme, proxy, ...) |
| `packages.el` | Extra packages (`package!`) |
| `config.el` | Everything else: `use-package`, `setq`, `after!`, your keys |
| `custom.el` | Written by `M-x customize` |
| `modules/` | Your own modules |

**After changing `init.el`'s block or `packages.el`, run `hell sync`**
and restart Emacs (or press `C-c h R`, which syncs and reloads). Startup
only replays what the last sync decided, as in Doom; `hell doctor` says
when your config changed since.

### Modules

```elisp
(hell! :ui         theme
       :editor     undo
       :completion vertico (corfu +tab)
       :tools      build debugger direnv lsp magit run test editorconfig
       :lang       (java +lombok +spring) kotlin clojure
       :config     default)
```

Your `init.el` lists every module Hell Emacs has, the optional ones commented
out: uncomment one (`:lang groovy`, `:tools db`, ...), then sync. Flags
(`+name`) switch on a module's options, for example:

| Flag | Does |
|---|---|
| `(corfu +tab)` | `TAB` completes when there's nothing to indent |
| `(java +lombok +spring)` | Lombok's agent in JDTLS; Spring Boot's language server |
| `(java +tree-sitter)`, and on most languages | Tree-sitter modes, with pinned grammars (YAML, Dockerfile and TypeScript always use Emacs' own tree-sitter modes) |
| `(format +onsave)` | Format on every save |
| `(test +watch)` | Rerun a class's tests when you save it |
| `(http +httpyac)` | Run `.http` files' JavaScript handlers (needs Node) |
| `(static +sonarlint)` | SonarLint's analysis, on top of the build's reports |

An empty `(hell!)` turns every module off except Hell Emacs' own core
module (the Altar, the themed messages), which is always on. Without a
block at all, you get the defaults in `static/init.example.el`.

Your `init.el` is never rewritten, so modules made default after you
installed don't appear in it. `hell doctor` lists them;
`hell config --add-defaults` adds them (keeping `init.el.bak`).

### Packages (plugins)

Declare a package in `packages.el`, configure it in `config.el`, sync:

```elisp
;; packages.el
(package! rainbow-delimiters)                         ; from MELPA / ELPA
(package! foo :recipe (:host github :repo "me/foo"))  ; from a git repo
(package! bar :pin "v1.2.0")                          ; at a commit or tag
(package! undo-fu-session :disable t)                 ; off, with its config
(disable-packages! a b)                               ; the same, for several
(package! baz :ignore t)                              ; not installed, config kept
(unpin! lsp-mode)                                     ; newest, not the pin
(unpin! (:lang java))                                 ; for a whole module
```

```elisp
;; config.el
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))
```

Packages load lazily: give each one a trigger (`:hook`, `:bind`,
`:commands`) or `:demand t`. `hell lock` pins every package's exact
commit so another machine installs the same; `hell gc` deletes the ones
nothing declares any more. A plugin manager (`hell plugins`) is planned
([roadmap](roadmap.md), Phase 15).

### Your own modules

Copy `static/module-template/` to `~/.config/hell-emacs/modules/<group>/<name>/`,
name it in its `.hellmodule`, enable `:group name` in your block, sync.
A module of yours with the same name as one of Hell Emacs' replaces it. The
files a module can have are in [development.md](development.md#modules).

### Look and feel

- **`:ui theme`**: `hell-inferno`, Hell Emacs' own theme.
  `(setq hell-theme 'modus-vivendi)` in `init.el` uses another; `nil`,
  none.
- **The Altar**: the startup screen is GNU Emacs' own (`*GNU Emacs*`, `fancy-startup-screen`), with the same layout and features: the link table, "To start...", the newcomer presets checkbox, the version line, the auto-save recovery notice, and the concise "Dismiss this startup screen" panel beside files opened from the command line. Hell Emacs changes only the logo (the chimera skull, `assets/banners/splash.svg`) and the words: a Hell Emacs welcome line and manual row, a forge line with the profile and startup time under the version, and, at the bottom, buttons only for what the stock screen has no link to: IntelliJ Exorcism (the key finder), Issue Sanctum (the issue tracker) and Release Grimoires (the changelog). "Explore Packages" opens the Relic Chamber (`hell-plugins`), since packages come from `package!`. Stock keys: `TAB`/`S-TAB` move between links, `RET` follows one, `SPC`/`DEL` scroll, `q` dismisses; `C-c h s` brings it back. `(setq hell-splash-enable nil)` starts on `*scratch*` instead; with `hell-ux-enable nil` it is the stock GNU screen.
- **GNU Emacs' frame**: the menu bar, tool bar and scroll bars stay, in
  the theme's colours. `(menu-bar-mode -1)`, `(tool-bar-mode -1)` and
  `(scroll-bar-mode -1)` in your `config.el` turn them off.
- **The mode line** is Emacs' own, in the theme's colours, with the
  language server's state (`JVM:ready`, `JVM:purgatory`) beside the mode.
- **Icons** in Dired, the minibuffer and the completion popup come from a
  Nerd Font. `M-x nerd-icons-install-fonts` installs one. In a terminal,
  the Altar is GNU Emacs' text startup screen.
- **A neutral look** for workplaces that want one:
  `(setq hell-ux-enable nil)` gives stock quit prompts and messages.

---

## 3. Staying up to date & Updating Production

Hell Emacs provides dedicated commands to upgrade core, update packages, apply configuration changes, and freeze dependencies for production environments:

### Common Update Workflows

| Scenario | Command | What happens |
|---|---|---|
| **Full Production Upgrade** | `hell upgrade` | Updates Hell Emacs repository to latest release, updates packages, recompiles bytecode, and runs health checks |
| **Update Packages Only** | `hell upgrade --packages` | Updates installed packages without altering Hell Emacs core version |
| **Apply Config Changes** | `hell sync` | Run after editing `init.el` or `packages.el` (or press `C-c h S` / `C-c h R` in Emacs) |
| **Lock Dependencies** | `hell lock` | Generates `packages.lock.eld` pinning exact commit SHAs for zero-drift deployments |
| **Clean Unused Packages** | `hell gc` | Purges orphaned packages no longer declared by your active modules |
| **Version Inspection** | `hell version` | Prints current version, commit hash, channel, and Emacs build info |

---

### Step-by-Step Production Maintenance

#### 1. Upgrading to a New Hell Emacs Release
```sh
hell upgrade
```
`upgrade` is fully automated and safe to run on production machines:
1. Fetches the latest signed release tag on your chosen channel (`stable` by default).
2. Updates packages to their declared pins.
3. Automatically runs `sync` in a clean sub-process, byte-compiling core libraries and modules.
4. Executes `doctor` to ensure zero regressions before you restart Emacs.

#### 2. Updating After Editing Your Config
Whenever you add/remove modules in `~/.config/hell-emacs/init.el` or add packages in `~/.config/hell-emacs/packages.el`:
- **From CLI**: `hell sync`
- **From GUI/Terminal Emacs**: Press `C-c h S` (background sync) or `C-c h R` (sync and live reload).

#### 3. Enterprise Reproducibility & Locking
To guarantee identical, immutable environments across a whole team or CI/CD pipelines:
```sh
hell lock
```
This writes `~/.config/hell-emacs/packages.lock.eld`. When you commit and share this lockfile, every teammate's `hell sync` will install the exact same commit for every package.

Without a lock file of your own, sync installs from `static/packages.lock.eld`: the commits this Hell Emacs release was tested with. `hell upgrade` moves past them to the newest commits (and rewrites your own lock file, if you have one). Maintainers regenerate the shipped lock with `make lock`.

---

### Releases, Channels, and Support

**Versions.** A release is a signed tag `vMAJOR.MINOR.PATCH`
([Semantic Versioning](https://semver.org/)); the [CHANGELOG](../CHANGELOG.md)
says what changed. Before 1.0 a minor release may change configuration (the
changelog says how to adapt). From 1.0: PATCH is fixes only, MINOR adds
without breaking (deprecations warn until the next MAJOR), MAJOR may remove
what was deprecated or raise the minimum Emacs.

**Channels.** `upgrade` follows `stable` by default, the latest release;
`main` is the development branch. `hell upgrade --channel main` for one
run, or `(setq hell-upgrade-channel 'main)` in `init.el`.
On `stable`, `upgrade` refuses a release whose tag isn't signed by a key in
your GPG keyring (import the maintainer's key once); `(setq
hell-upgrade-verify-tags nil)` takes unsigned ones. Your lock file applies
on either channel.

**Support.** Each release states the Emacs versions (29.1+), platforms and
JDKs it supports. The latest release gets every fix; the one before gets
security fixes for 6 months. Report vulnerabilities privately to
petrolalucas@gmail.com, not in an issue.

---

## 4. Profiles
 
A profile is a separate configuration with its own packages, caches and
history. As in Doom, a directory is a profile: for `--profile NAME`,
Hell Emacs uses the first that exists of `~/.config/hell-emacs-NAME/`,
`~/.config/hell-emacs/profiles/NAME/`, and `profiles/NAME/` in Hell Emacs.

### Profile Commands

| Command | Description |
|---|---|
| `hell profile list` | List every profile, sync status, and config path |
| `hell profile create NAME [--in-tree]` | Create a profile with starter template files |
| `hell profile sync [NAME|--all]` | Sync a specific profile or all profiles |
| `hell profile delete NAME [-!]` | Delete a profile and its isolated data/cache directories |
| `hell profile path NAME` | Print the resolved directory path of a profile |

```sh
hell profile create work --in-tree # create in-tree profile in profiles/work/
hell -p work sync                  # sync packages and generate startup file
hell -p work emacs                 # start Emacs on it (or: emacs --profile work)
```

Its files are `~/.local/share/hell-emacs-NAME/`, `~/.cache/hell-emacs-NAME/`, and
`~/.local/state/hell-emacs-NAME/`, completely isolated from your default profile.

Hell Emacs ships **`safe-mode`**: its core and nothing else, for finding what
broke (see below). For in-depth developer workflows, see [development.md](development.md#development-environments--workflows).

---

## 5. Where files live

| Directory | Holds | Safe to delete? |
|---|---|---|
| `~/.config/emacs/` | Hell Emacs itself (the git checkout) | Reinstall it |
| `~/.config/hell-emacs/` | Your config | **No** |
| `~/.local/share/hell-emacs/` | Packages, language servers, the generated startup file (`profiles/default/`), the saved environment | Yes: `sync` rebuilds it |
| `~/.cache/hell-emacs/` | Native-compiled code, caches | Yes |
| `~/.local/state/hell-emacs/` | History, recent files, bookmarks, undo, backups | Yes, losing that history |

---

## 6. Companies: networks, offline machines, compliance

**Proxy, corporate CA, mirrors.** In `init.el`, then sync:

```elisp
(setq hell-proxy "http://proxy.corp.example:3128")   ; nil: $HTTPS_PROXY
(setq hell-no-proxy '("localhost" ".corp.example"))  ; nil: $NO_PROXY
(setq hell-ca-bundle "~/certs/corp-root-ca.pem")      ; added to the system's CAs
(setq hell-mirrors
      '(("https://github.com/" . "https://git.corp.example/github/")
        ("https://repo1.maven.org/maven2/" . "https://artifactory.corp.example/maven/")))
```

The proxy and CA apply to all of Emacs; mirrors apply to what Hell Emacs
fetches (packages, servers, grammars, npm). Every pinned download is still
checked by SHA-256, so a mirror can't serve a different file. `hell
doctor` shows what's in use and checks each host can be reached through it
(`doctor --network` does so without any setting).

**No internet.** On a connected machine of the same platform and Emacs
version: `hell bundle hell-bundle.tar.zst` (`--modules` packs another
module set). On the offline one: `hell install --from-bundle
hell-bundle.tar.zst --sha256 HEX`, with the SHA-256 `bundle` printed (carry it
separately: the bundle's own manifest only proves it's whole), which checks
every file's SHA-256 and never touches the network.

**Compliance.** `hell sbom` writes a CycloneDX bill of materials of
everything installed; `hell licenses` reports each license and fails
on an unknown one; `hell verify` checks that nothing installed has
changed since sync. Hell Emacs sends no telemetry and turns off that of the
tools it installs (docker-language-server's, SonarLint's, clojure-lsp's
ClojureDocs download); it only goes online during `sync`, `install`,
`upgrade` and `doctor --network`.

**Rolling out.** Clone at a release tag, share a `packages.lock.eld`
(`hell lock`) with the team's `init.el`, and install with
`hell -! install` (no prompts). A team layer and `install --team URL`
are planned ([roadmap](roadmap.md), 12.8).

---

## 7. When something breaks

1. **`hell doctor`**: checks Emacs, tools, your config, every module's
   needs, and whether you forgot to sync.
2. **Did you sync?** Emacs starts plain, with a warning, until the first
   sync; after config changes it keeps starting as the last sync left it.
3. **`safe-mode`**: Hell Emacs without your modules and config.
   ```sh
   hell -p safe-mode sync && hell -p safe-mode emacs
   ```
   If that works, add your modules back one at a time.
4. **`hell emacs --vanilla`**: plain Emacs (`emacs -Q`), to tell a
   Hell Emacs problem from an Emacs one.
5. **`hell -D ...`** or `DEBUG=1 emacs`: backtraces and debug output.
6. **Reporting a bug:** include `hell info`'s output.

JVM projects that won't import: see the [JVM guide](jvm.md#when-a-project-wont-import).

### What doctor's messages mean

`!` is a warning (something optional is missing), `✗` an error (something
won't work; `doctor` then exits with a failure). Each prints a `see` line
pointing to its entry below, in your own copy of this guide. After any
fix, run `hell doctor` again.

#### Doctor: Emacs

- **Emacs is too old:** Hell Emacs needs Emacs 29.1 or newer. Install it
  from your package manager (or Homebrew's `emacs-plus` on macOS), then
  `hell sync`: each Emacs version gets its own synced init file.
- **A development build:** a snapshot Emacs (a version ending in `.50`
  and up) works, but packages may break on it. Use a release if they do.
- **No tree-sitter support**, which a module's grammar needs (`:lang
  yaml`, `docker` and `javascript` always; others with `+tree-sitter`):
  this Emacs was built without it. Install an Emacs built with tree-sitter
  (most distributions' Emacs 29+ is), or drop `+tree-sitter` from the
  module.
- **clojure-ts-mode needs Emacs 30.1:** drop `+tree-sitter` from
  `:lang clojure`, or upgrade Emacs.

#### Doctor: platform

- **Hell Emacs or your config on a Windows mount (`/mnt/...`)** under WSL2:
  every file read crosses to Windows and is slow. Clone Hell Emacs and keep
  your config under your Linux home (`~/`).

#### Doctor: tools

- **A program isn't found** (`git`, `rg`, `unzip`, `node`, `clojure`...):
  install it with your package manager. The message says what it's for;
  a warning means only that feature is missing, an error that the module
  can't work.
- **Found in a terminal, not in GUI Emacs:** a GUI launcher doesn't read
  your shell's PATH. Run `hell env` in a terminal, then restart Emacs.
- **Node or Git too old:** the message says the minimum; upgrade it.
- **No C compiler** (`cc`, `gcc` or `clang`): tree-sitter grammars are
  built from source. Install your system's build tools (`build-essential`,
  `base-devel`, Xcode's command-line tools).

#### Doctor: JDK

- **No JDK to run JDTLS**, or `hell-jvm-java-home` is the wrong one:
  the Java server runs on the releases the message names. Install one
  (SDKMAN, your package manager), then `hell sync`; or point
  `hell-jvm-java-home` at one in your `config.el`.
- **A server or tool needs a JDK 11+ (or 17+)** and none is found: set
  `JAVA_HOME`, put `java` on the PATH, or install one; for GUI Emacs, also
  run `hell env`.
- **`hell-jdks` names a JDK wrongly:** each entry's name must be its
  release, as JDTLS spells it (`("JavaSE-17" . "/opt/jdk-17")`).
- **JDKs not known to JDTLS yet:** you installed some since the last
  sync; `hell sync` stores them. See the JVM guide's
  [Several JDKs](jvm.md#several-jdks).

#### Doctor: toolchains

- **The build asks for a JDK toolchain that isn't installed** (Gradle's
  `languageVersion`): install that release, or tell Gradle where it is
  with `org.gradle.java.installations.paths` in
  `~/.gradle/gradle.properties`, or add a toolchain resolver to the
  build so Gradle downloads it.
- **Maven's `toolchains.xml`** is missing the JDK the build asks for, or
  one of its entries points elsewhere: add a `<toolchain>` of type `jdk`
  with the right `jdkHome`.

#### Doctor: installs

- **Not installed yet / not the pinned release / fails its SHA-256
  check:** `hell sync` installs or replaces it. Language servers,
  grammars, jars and the JVM truststore are all installed by sync, never
  while you edit.
- **No pinned build for this platform:** Hell Emacs has no checksummed
  release of that tool for your OS and CPU. Install it yourself and put
  it on the PATH; Hell Emacs uses the one it finds there.
- **Sync can't download** (offline, or a blocked host): see
  [Doctor: network](#doctor-network), or install from an offline bundle
  (`hell bundle`).

#### Doctor: network

- **A certificate isn't trusted:** your network inspects TLS. Set
  `hell-ca-bundle` to your company's CA (a PEM file) in `config.el`,
  then `hell sync`, which also builds the JVM's truststore from it.
- **`hell-ca-bundle` can't be read or holds no certificate:** check
  the path, and that the file is PEM (`-----BEGIN CERTIFICATE-----`).
- **Can't reach a host / through the proxy:** set `hell-proxy` (with
  its credentials if it needs them), or map the host to an internal
  mirror with `hell-mirrors`. The details are in
  [Companies](#6-companies-networks-offline-machines-compliance).

#### Doctor: config

- **A module needs another** ("Needs :tools lsp; add it to your
  hell! block"): add that module to `init.el`, then `hell sync`.
- **Without `:completion corfu`**, or **no module supplies a debug
  adapter**: those features are missing until you enable the module the
  message names.
- **`hell-maven-settings` can't be read:** fix the path in your
  `config.el`, or remove the setting to use `~/.m2/settings.xml`.

#### Doctor: sync

- **Not synced yet** or **out of sync** (it says what changed): run
  `hell sync`, or `C-c h S` inside Emacs, then restart Emacs. Startup
  only replays the last sync, so a changed `init.el`, `packages.el` or
  module isn't used until then.

#### Doctor: fonts

- **No Nerd Font:** icons in Dired, the minibuffer and the completion popup show as boxes.
  Run `M-x nerd-icons-install-fonts`, or install a Nerd Font from your
  distribution; Hell Emacs never installs fonts itself.

#### Doctor: checkout

- **`var/` or `etc/` left over from an older Hell Emacs:** nothing uses
  them; delete them.
- **A file of Hell Emacs itself is missing** (from
  `assets/`): your checkout is incomplete. `git status` in it shows what
  changed; `git checkout -- assets/` restores it.
