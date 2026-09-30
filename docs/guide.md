# Hellmacs Guide

Everything about installing, configuring and running Hellmacs. For the JVM
languages and tools, see the [JVM guide](jvm.md); for keys, the
[keybindings](keybindings.md); for every command, the [CLI reference](cli.md).

Hellmacs installs and works like [Doom Emacs](https://github.com/doomemacs/core):
if you know Doom, you know where everything is. The difference is the keys:
Hellmacs keeps stock GNU Emacs bindings.

---

## 1. Install

### Requirements

| Tool | Version | For |
|---|---|---|
| GNU Emacs | 29.1+ (30.1+ for `clojure-ts-mode`); native-comp and tree-sitter recommended | Everything |
| Git | 2.25+ (2.31+ behind a proxy or mirror) | Packages, Magit |
| JDK | 21+ | Running JDTLS; your projects can target Java 8 and up |
| ripgrep, fd | any recent | Project search |
| A C compiler and `make` | any | Building the pinned tree-sitter grammars |
| `unzip` | any | Installing the Kotlin and Clojure servers |

Optional: Maven or Gradle (projects without a wrapper), `clojure`/`lein`/`bb`
(Clojure REPLs), `direnv` (per-project environments), Node 20+ (the YAML,
JSON, shell and `+httpyac` servers), a [Nerd Font](https://www.nerdfonts.com)
(icons). Language servers aren't on this list: `sync` installs pinned copies.

### Steps

```sh
git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs
~/.config/emacs/bin/hellmacs install
emacs
```

`install` is safe to run again. It:

1. warns about anything that would make Emacs skip Hellmacs (a `~/.emacs`,
   or a `~/.emacs.d` while Hellmacs is in `~/.config/emacs`);
2. creates your config in `~/.config/hellmacs/` from `static/`
   (`--no-config` skips it);
3. syncs: installs every package and language server your modules need,
   and generates the file Emacs starts from (`--no-install` skips it);
4. offers to save your shell environment (`PATH`, `JAVA_HOME`, ...) for
   Emacs started from a desktop launcher (`--env` / `--no-env` answer for
   you);
5. runs `doctor` and says how to start Emacs.

Put `~/.config/emacs/bin` on your `PATH`: then `hellmacs sync`,
`hellmacs doctor` and the rest work from anywhere. Don't clone with
`--depth 1`: `hellmacs upgrade` follows release tags.

Hellmacs can live anywhere: clone it to `~/hellmacs` and start it with
`hellmacs emacs` (or `emacs --init-directory ~/hellmacs`).

### Platforms

- **Linux** (x86-64, arm64): as above.
- **macOS** (Apple Silicon, Intel): `brew install emacs-plus openjdk@21
  ripgrep fd`, then as above. Run `hellmacs env` so a GUI Emacs gets your
  shell's `PATH` and `JAVA_HOME`.
- **Windows**: through WSL2, as on Linux. Keep Hellmacs and your projects
  on the Linux filesystem (`~/...`), not `/mnt/c/`: the Windows mount is
  slow. WSLg shows GUI Emacs on Windows 11.
- **Try it in Docker**, without touching your machine:
  ```sh
  docker run -it --rm alpine:edge sh -c '
    apk add bash git emacs-nativecomp ripgrep fd openjdk21 unzip build-base &&
    git clone https://github.com/petrolal/hellmacs.git ~/.config/emacs &&
    ~/.config/emacs/bin/hellmacs -! install && emacs -nw'
  ```

---

## 2. Your configuration

Your config is `~/.config/hellmacs/` (`$HELLMACSDIR` moves it; Doom's is
`~/.config/doom/`). Hellmacs never writes into its own checkout.

| File | What goes in it |
|---|---|
| `init.el` | The `hellmacs!` block: which modules are on. Settings Hellmacs reads early (theme, proxy, ...) |
| `packages.el` | Extra packages (`package!`) |
| `config.el` | Everything else: `use-package`, `setq`, `after!`, your keys |
| `custom.el` | Written by `M-x customize` |
| `modules/` | Your own modules |

**After changing `init.el`'s block or `packages.el`, run `hellmacs sync`**
and restart Emacs (or press `C-c h R`, which syncs and reloads). Startup
only replays what the last sync decided, as in Doom; `hellmacs doctor` says
when your config changed since.

### Modules

```elisp
(hellmacs! :ui         theme dashboard modeline popup
           :editor     undo
           :completion vertico (corfu +tab)
           :tools      build debugger direnv lsp magit run test editorconfig
           :lang       (java +lombok +spring) kotlin clojure
           :config     default)
```

Your `init.el` lists every module Hellmacs has, the optional ones commented
out: uncomment one (`:lang groovy`, `:tools db`, ...), then sync. Flags
(`+name`) switch on a module's options, for example:

| Flag | Does |
|---|---|
| `(corfu +tab)` | `TAB` completes when there's nothing to indent |
| `(java +lombok +spring)` | Lombok's agent in JDTLS; Spring Boot's language server |
| `(java +tree-sitter)`, and on most languages | Tree-sitter modes, with pinned grammars |
| `(format +onsave)` | Format on every save |
| `(test +watch)` | Rerun a class's tests when you save it |
| `(http +httpyac)` | Run `.http` files' JavaScript handlers (needs Node) |
| `(static +sonarlint)` | SonarLint's analysis, on top of the build's reports |

An empty `(hellmacs!)` turns every module off except Hellmacs' own core
module (the Altar, the themed messages), which is always on. Without a
block at all, you get the defaults in `static/init.example.el`.

Your `init.el` is never rewritten, so modules made default after you
installed don't appear in it. `hellmacs doctor` lists them;
`hellmacs config --add-defaults` adds them (keeping `init.el.bak`).

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
`:commands`) or `:demand t`. `hellmacs lock` pins every package's exact
commit so another machine installs the same; `hellmacs gc` deletes the ones
nothing declares any more. A plugin manager (`hellmacs plugins`) is planned
([roadmap](roadmap.md), Phase 15).

### Your own modules

Copy `static/module-template/` to `~/.config/hellmacs/modules/<group>/<name>/`,
name it in its `.hellmacsmodule`, enable `:group name` in your block, sync.
A module of yours with the same name as one of Hellmacs' replaces it. The
files a module can have are in [development.md](development.md#modules).

### Look and feel

- **`:ui theme`**: `hellmacs-inferno`, Hellmacs' own theme.
  `(setq hellmacs-theme 'modus-vivendi)` in `init.el` uses another; `nil`,
  none.
- **`:ui dashboard`**: the Altar, the startup screen: the sigil, the
  startup time, recent files, projects and bookmarks. `TAB`/`S-TAB` move,
  `RET` opens, `g` redraws, `q` buries it, `C-c h s` brings it back.
  `(setq hellmacs-splash-enable nil)` starts on `*scratch*`.
- **`:ui modeline`**: the buffer and position; the language server's state
  (`JVM:ready`, `JVM:purgatory`), the debugger, the mode, the Git branch,
  flymake's counts.
- **Icons** come from a Nerd Font; without one, text. `M-x
  nerd-icons-install-fonts` installs one. In a terminal, the Altar shows the
  ASCII sigil and both draw text, unless you set
  `hellmacs-dashboard-tty-icons` and `hellmacs-modeline-tty-icons` to `t`.
- **A neutral look** for workplaces that want one:
  `(setq hellmacs-ux-enable nil)` gives stock quit prompts and messages.

---

## 3. Staying up to date

| Command | Does |
|---|---|
| `hellmacs sync` | Install what your config declares; regenerate the startup file |
| `hellmacs upgrade` | Update Hellmacs, then every unpinned package, then sync |
| `hellmacs upgrade --packages` | Only the packages |
| `hellmacs version` | Version, commit, update channel, Emacs |

**Versions.** A release is a signed tag `vMAJOR.MINOR.PATCH`
([Semantic Versioning](https://semver.org/)); the [CHANGELOG](../CHANGELOG.md)
says what changed. Before 1.0 a minor release may change configuration (the
changelog says how to adapt). From 1.0: PATCH is fixes only, MINOR adds
without breaking (deprecations warn until the next MAJOR), MAJOR may remove
what was deprecated or raise the minimum Emacs.

**Channels.** `upgrade` follows `stable` by default, the latest release;
`main` is the development branch. `hellmacs upgrade --channel main` for one
run, or `(setq hellmacs-upgrade-channel 'main)` in `init.el`.
`(setq hellmacs-upgrade-verify-tags t)` refuses tags not signed by a key in
your GPG keyring. Your lock file applies on either channel.

**Support.** Each release states the Emacs versions (29.1+), platforms and
JDKs it supports. The latest release gets every fix; the one before gets
security fixes for 6 months. Report vulnerabilities privately to
petrolalucas@gmail.com, not in an issue.

---

## 4. Profiles

A profile is a separate configuration with its own packages, caches and
history. As in Doom, a directory is a profile: for `--profile NAME`,
Hellmacs uses the first that exists of `~/.config/hellmacs-NAME/`,
`~/.config/hellmacs/profiles/NAME/`, and `profiles/NAME/` in Hellmacs.

```sh
hellmacs -p work sync        # set up the "work" profile
hellmacs -p work emacs       # start Emacs on it (or: emacs --profile work)
hellmacs profile list        # every profile, and whether it's synced
```

Its files are `~/.local/share/hellmacs-NAME/` and so on, never your default
profile's. Hellmacs ships **`safe-mode`**: its core and nothing else, for
finding what broke (see below).

---

## 5. Where files live

| Directory | Holds | Safe to delete? |
|---|---|---|
| `~/.config/emacs/` | Hellmacs itself (the git checkout) | Reinstall it |
| `~/.config/hellmacs/` | Your config | **No** |
| `~/.local/share/hellmacs/` | Packages, language servers, the generated startup file (`profiles/default/`), the saved environment | Yes: `sync` rebuilds it |
| `~/.cache/hellmacs/` | Native-compiled code, caches | Yes |
| `~/.local/state/hellmacs/` | History, recent files, bookmarks, undo, backups | Yes, losing that history |

---

## 6. Companies: networks, offline machines, compliance

**Proxy, corporate CA, mirrors.** In `init.el`, then sync:

```elisp
(setq hellmacs-proxy "http://proxy.corp.example:3128")   ; nil: $HTTPS_PROXY
(setq hellmacs-no-proxy '("localhost" ".corp.example"))  ; nil: $NO_PROXY
(setq hellmacs-ca-bundle "~/certs/corp-root-ca.pem")      ; added to the system's CAs
(setq hellmacs-mirrors
      '(("https://github.com/" . "https://git.corp.example/github/")
        ("https://repo1.maven.org/maven2/" . "https://artifactory.corp.example/maven/")))
```

The proxy and CA apply to all of Emacs; mirrors apply to what Hellmacs
fetches (packages, servers, grammars, npm). Every pinned download is still
checked by SHA-256, so a mirror can't serve a different file. `hellmacs
doctor` shows what's in use and checks each host can be reached through it
(`doctor --network` does so without any setting).

**No internet.** On a connected machine of the same platform and Emacs
version: `hellmacs bundle hellmacs.tar.zst` (`--modules` packs another
module set). On the offline one: `hellmacs install --from-bundle
hellmacs.tar.zst`, which checks every file's SHA-256 and never touches the
network.

**Compliance.** `hellmacs sbom` writes a CycloneDX bill of materials of
everything installed; `hellmacs licenses` reports each license and fails
on an unknown one; `hellmacs verify` checks that nothing installed has
changed since sync. Hellmacs sends no telemetry and turns off that of the
tools it installs (docker-language-server's, SonarLint's, clojure-lsp's
ClojureDocs download); it only goes online during `sync`, `install`,
`upgrade` and `doctor --network`.

**Rolling out.** Clone at a release tag, share a `packages.lock.eld`
(`hellmacs lock`) with the team's `init.el`, and install with
`hellmacs -! install` (no prompts). A team layer and `install --team URL`
are planned ([roadmap](roadmap.md), 12.8).

---

## 7. When something breaks

1. **`hellmacs doctor`**: checks Emacs, tools, your config, every module's
   needs, and whether you forgot to sync.
2. **Did you sync?** Emacs starts plain, with a warning, until the first
   sync; after config changes it keeps starting as the last sync left it.
3. **`safe-mode`**: Hellmacs without your modules and config.
   ```sh
   hellmacs -p safe-mode sync && hellmacs -p safe-mode emacs
   ```
   If that works, add your modules back one at a time.
4. **`hellmacs emacs --vanilla`**: plain Emacs (`emacs -Q`), to tell a
   Hellmacs problem from an Emacs one.
5. **`hellmacs -D ...`** or `DEBUG=1 emacs`: backtraces and debug output.
6. **Reporting a bug:** include `hellmacs info`'s output.

JVM projects that won't import: see the [JVM guide](jvm.md#when-a-project-wont-import).
