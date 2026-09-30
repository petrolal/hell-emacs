# CLI Reference (`bin/hellmacs`)

Hellmacs includes a command-line tool (`bin/hellmacs`) to install, synchronize, upgrade, lock, test, and troubleshoot your installation without launching interactive Emacs.

As in Doom Emacs v3, each command is its own file: `bin/hellmacs` dispatches `bin/hellmacs sync` to `bin/hellmacs-sync`, loaded only when it runs. With `bin/` on your `PATH`, a command also runs on its own (`hellmacs-sync`, `hellmacs-doctor`), through `bin/hellmacsscript`; it goes through `bin/hellmacs` either way, so `--profile` and the rest apply. Where `/usr/bin/env` is missing (Android's Termux), use `bin/hellmacs.sh`, as Doom's `doom.sh`.

More commands come from:
* enabled modules' `cli.el`;
* a `hellmacs-NAME` file in your config's `bin/` (`~/.config/hellmacs/bin/`), or in a directory on `$HELLMACSPATH` (colon-separated), as Doom's `$DOOMPATH`: it's `bin/hellmacs NAME`.

Short names, as Doom's: `s` (sync), `up` (upgrade), `doc` (doctor), `pf` (profile), `h` (help), `v` (version).

### Options

Before the command, as `doom`'s:

| Option | Environment | Does |
|---|---|---|
| `-p NAME`, `--profile NAME` | `HELLMACS_PROFILE` | Act on a named profile (below) |
| `--hellmacsdir DIR` | `HELLMACSDIR` | Use the config in `DIR` |
| `-D`, `--debug` | `DEBUG=1` | Debug output, and backtraces on errors |
| `-!`, `--force` | `HELLMACS_FORCE=1` | Don't ask: accept every prompt |

### Exit codes

As `doom`'s: `0` success; `1` the command couldn't complete (a check failed); `2` an error; `3` Emacs couldn't be run; `5` no such command; `6` a wrong, missing or extra option.

---

## Commands

### `install`
```sh
bin/hellmacs install [--[no-]config] [--[no-]env] [--[no-]install] [--from-bundle FILE]
```
Performs initial setup, as `doom install` (safe to run again):
* Warns about what would make Emacs skip Hellmacs: a `~/.emacs` (or `~/.emacs.el`, `~/_emacs`), or a `~/.emacs.d` when Hellmacs is in `~/.config/emacs`.
* Copies starter templates from `static/` to `~/.config/hellmacs/` (unless `--no-config` is provided or files already exist).
* Executes `sync` to download and compile all packages (unless `--no-install`: then run `sync` yourself before starting Emacs).
* Offers to export your shell environment into `~/.local/share/hellmacs/env` (as `bin/hellmacs env`). `--env` says yes, `--no-env` no; without a terminal, and with neither, it doesn't; `-!` says yes.
* Executes `doctor` to ensure everything is operational.
* With `--from-bundle FILE`, installs from an offline bundle (see [`bundle`](#bundle)) with no network access at all:
  * The bundle must be for this platform and Emacs major version, and carry every module (and flag) your config enables. Otherwise nothing is installed.
  * Every file is checked against the SHA-256 in the bundle's manifest before anything is put in place. A damaged, missing or extra file stops the install.
  * The bundle's lock file becomes yours. A different lock file already there is kept as `packages.lock.eld.before-bundle`.
  * The `sync` that follows refuses the network: url.el fetches and git's network transports fail. Anything the bundle lacks stops the install with its name, instead of being downloaded.

---

### `bundle`
```sh
bin/hellmacs bundle OUT.tar.zst [--modules SPEC]
```
Run on a connected machine. It syncs, then packs everything the sync installed into one archive, for machines without internet:
* Elpaca's repositories, builds and recipe caches.
* Every pinned language server and jar (JDTLS with java-debug and the JUnit runner, Lombok, kotlin-language-server, clojure-lsp) and the tree-sitter grammars.
* A lock file with the exact commit of every package, and a manifest with the SHA-256 of every file.

Details:
* Compression follows the file name: `.tar.zst` (needs `zstd`), `.tar.gz`, `.tar.xz`, or `.tar`.
* It prints the bundle's own SHA-256, so you can publish it next to the bundle. The manifest's sums catch a damaged or altered file, but they travel inside the bundle, so get the bundle itself from a place you trust.
* A bundle is for one platform (grammars and clojure-lsp are native code) and one Emacs major version (packages are byte-compiled). Make one per platform your team uses.
* It carries what your enabled modules install. `--modules` packs another set, written like a `hellmacs!` block: `--modules ":lang (java +lombok) kotlin :tools lsp build"`. That also syncs this machine for those modules, so run it under its own profile (`bin/hellmacs --profile bundle bundle ...`) to leave yours alone.
* A server you use from your `PATH` (clojure-lsp, for example) isn't installed by sync, so the bundle doesn't carry it either. The installing machine then needs it on its `PATH` too.

Then, on the offline machine: `bin/hellmacs install --from-bundle hellmacs.tar.zst`.

---

### `sync`
```sh
bin/hellmacs sync
```
* Analyzes all active modules declared in your `init.el` and `packages.el`.
* Uses Elpaca to fetch missing packages and compile Tree-sitter grammars.
* Merges every package's autoloads into one compiled file, and byte-compiles core plus each enabled module's `init.el` and `config.el` into the profile's `compiled/` directory. Startup uses the compiled files only while they match their sources; edit a file and it loads from source until the next `sync`.
* Generates the profile's init file, `init.MAJOR.MINOR.el` (one per Emacs version), from numbered parts in `init.d/`, as `doom sync` does, and compiles it. Emacs starts from it: Hellmacs has no `init.el` in its checkout, as Doom v3 hasn't. The file holds everything startup needs, decided now: the enabled modules, where every package is, what to autoload. So **run `sync` after every change to your `hellmacs!` block, a `packages.el` or a module's autoloads**; until you do, Emacs keeps starting as the last sync left it (`doctor` says when your config changed since). Without any sync, Emacs starts plain and says to run it.

---

### `upgrade`
```sh
bin/hellmacs upgrade [--packages] [--channel stable|main]
```
* Moves Hellmacs itself to its channel's latest: `stable` (the default, `hellmacs-upgrade-channel`) checks out the latest release tag, `main` pulls the development branch. See [Releases and Support](releases.md).
* Updates all installed packages that do not have a fixed `:pin`.
* Runs `sync` to generate a fresh profile.
* With `--packages`, upgrades only installed packages, leaving Hellmacs itself as it is.

---

### `version`
```sh
bin/hellmacs version
```
* Shows Hellmacs' version and commit, the update channel `upgrade` follows, and the Emacs it runs on.

---

### `verify`
```sh
bin/hellmacs verify
```
* Checks that everything `sync` installed is as it left it: every installed file (language servers, jars, grammars, the packages' compiled files) against the SHA-256 sync recorded, and every package's checkout at the commit it installed, with no local changes, and at the commit your lock file pins.
* Exits 1 and names each difference. To repair one, delete what changed and run `sync`, which reinstalls what's missing; undo a package's local changes with git.
* Each sync records what it installed in the profile's `installed.eld`.

---

### `sbom`
```sh
bin/hellmacs sbom [FILE]
```
* Writes a CycloneDX (JSON) software bill of materials of everything installed: every package at its commit, each pinned download (language servers, jars) with its SHA-256, npm dependencies from their lock files, and the tree-sitter grammars. To FILE, or to standard output.

---

### `licenses`
```sh
bin/hellmacs licenses
```
* Lists each installed component's license, from its package headers, its LICENSE file, or its pin's declaration. Exits 1 on a license it can't tell, and flags one outside the SPDX list, so a new dependency's license is seen before it ships.

---

### `lock`
```sh
bin/hellmacs lock
```
* Generates a lockfile (`~/.config/hellmacs/packages.lock.eld`) pinning the exact Git commit SHA of every installed package.
* Commit this lockfile into your dotfiles repo to achieve 100% reproducible environments across team laptops and CI.

---

### `doctor`
```sh
bin/hellmacs doctor [--network]
```
Runs a health check on your system, reporting:
* Emacs version and native-compilation status.
* External CLI tools (`git`, `rg`, `fd`, `mvn`, `gradle`, `unzip`, JDKs).
* The network: the proxy, CA bundle and mirrors in use, the JVM truststore, and whether each host Hellmacs fetches from (package sources, language-server downloads) can be reached through them. A host whose certificate isn't trusted is reported as a CA missing from `hellmacs-ca-bundle`. Hosts are checked whenever a proxy, CA or mirror is set, and otherwise only with `--network`.
* The Maven `settings.xml` and Gradle home JDTLS imports with (`:lang java`).
* Module-specific assets (fonts, icons, language server binaries).
* Configuration and profile validity.

---

### `env`
```sh
bin/hellmacs env [--clear]
```
* Captures your current shell environment (`PATH`, `JAVA_HOME`, proxy settings, etc.) into `~/.local/share/hellmacs/env.eld`.
* Allows Emacs launched from GUI desktop launchers (which lack full shell environment) to discover all system tools.
* `--clear` removes the saved environment file.

---

### `config`
```sh
bin/hellmacs config [--add-defaults]
```
* Lists the modules that are on by default (`static/init.example.el`) but missing from your `hellmacs!` block, each with its line. A config made from an older template misses every module added since, `:tools magit` for one. `doctor` shows the same list, and so does `upgrade` after updating.
* A module you commented out in your block is your choice, so it isn't listed. Flags are yours too: only missing modules count.
* With `--add-defaults`, it adds them to your block, each in its group, as the template writes it. A missing group is created, in the template's order. `init.el` is kept as `init.el.bak`, or `init.el.bak.N` if that exists. If the result doesn't read back with the modules in it, the old file is restored.
* Then run `sync` to install them.

---

### `gc`
```sh
bin/hellmacs gc [-n]
```
* Removes old and orphaned package installations that are no longer referenced by any enabled module.
* Use `-n` for a dry run.

---

### `emacs`
```sh
bin/hellmacs [--profile NAME] emacs [--vanilla] [-- EMACS-ARGS]
```
* Starts Emacs on this Hellmacs checkout (and profile), wherever the checkout is, as `doom emacs`.
* `--vanilla` starts Emacs with no config at all (`emacs -Q`), to tell a Hellmacs problem from an Emacs one.

---

### `profile`
```sh
bin/hellmacs profile [list]
bin/hellmacs profile sync --all
```
* `list`: every profile there is (see below), `*` marking the one `--profile` chose, and whether each is synced for this Emacs.
* `sync --all`: syncs each of them, as `doom profile sync --all`.

---

### `info`
```sh
bin/hellmacs info
```
* Prints what a bug report needs, as `doom info`: Hellmacs' version and commit, Emacs' version and build features, the system, the profile and whether it's synced, your config's directory and modules.

---

### `test`
```sh
bin/hellmacs test [SELECTOR]
```
* Executes the internal ERT unit test suite.

---

## Multi-Profile Flag (`--profile`)

Every command accepts `--profile <NAME>` (or `-p NAME`) before it:

```sh
bin/hellmacs --profile work sync
bin/hellmacs --profile work doctor
bin/hellmacs --profile work upgrade
```

A profile's config is `~/.config/hellmacs-NAME/`, else `profiles/NAME/` in your config, else `profiles/NAME/` in Hellmacs; its packages, caches and history are its own. Hellmacs ships `safe-mode`: its core with no other module and none of your config, for finding what broke Emacs (`bin/hellmacs --profile safe-mode sync`, then `bin/hellmacs --profile safe-mode emacs`). See [`profiles/README.md`](../profiles/README.md).
