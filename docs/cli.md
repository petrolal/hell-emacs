# CLI Reference

`bin/hellmacs` installs, syncs, updates and checks Hellmacs without
starting Emacs, as Doom's `bin/doom`. Put `~/.config/emacs/bin` on your
`PATH` to type `hellmacs` from anywhere.

```
hellmacs [OPTIONS] COMMAND [ARGS]
```

Each command is its own file, `bin/hellmacs-COMMAND`; with `bin/` on your
`PATH` it also runs alone (`hellmacs-sync`, `hellmacs-doctor`). Where
`/usr/bin/env` is missing (Termux), use `bin/hellmacs.sh`. More commands
come from enabled modules, from `hellmacs-NAME` files in your config's
`bin/`, and from directories on `$HELLMACSPATH`.

## Options

Before the command:

| Option | Environment | Does |
|---|---|---|
| `-p NAME`, `--profile NAME` | `HELLMACS_PROFILE` | Act on a profile |
| `--hellmacsdir DIR` | `HELLMACSDIR` | Use the config in `DIR` |
| `-D`, `--debug` | `DEBUG=1` | Debug output and backtraces |
| `-!`, `--force` | `HELLMACS_FORCE=1` | Answer yes to every prompt |

Also read: `EMACS` (the Emacs to run), `XDG_CONFIG_HOME`, `XDG_DATA_HOME`,
`XDG_CACHE_HOME`, `XDG_STATE_HOME`.

**Exit codes**, as Doom's: `0` success, `1` the command couldn't complete
(a check failed), `2` an error, `3` Emacs couldn't be run, `5` no such
command, `6` a wrong or missing option.

## Commands

Short names in brackets.

### Setting up and syncing

**`install [--[no-]config] [--[no-]env] [--[no-]install] [--from-bundle FILE]`**
First-time setup, safe to repeat: warns about a `~/.emacs` or `~/.emacs.d`
that would win over Hellmacs, creates your config from `static/`, syncs,
offers to save your environment, runs `doctor`. `--no-config`,
`--no-install` and `--env`/`--no-env` skip or answer those steps.
`--from-bundle` installs from an offline bundle (see `bundle`), checking
every file's SHA-256, with no network at all.

**`sync`** [`s`]
Installs every package and language server your modules and `packages.el`
declare, builds the pinned tree-sitter grammars, byte-compiles core and
the modules, and generates the file Emacs starts from
(`init.MAJOR.MINOR.el`, one per Emacs version). Run it after every change
to your `hellmacs!` block, a `packages.el` or a module's autoloads: Emacs
starts from what the last sync decided.

**`upgrade [--packages] [--channel stable|main]`** [`up`]
Updates Hellmacs to its channel's latest (`stable`: the newest release
tag, the default; `main`: the development branch), then every unpinned
package, then syncs. `--packages` updates only the packages. It also lists
default modules your config lacks.

**`env [--clear]`**
Saves your shell's environment (`PATH`, `JAVA_HOME`, proxies...) for Emacs
started from a desktop launcher. Run it again after changing your shell's
setup; `--clear` removes it.

**`config [--add-defaults]`**
Lists the modules on by default that your `hellmacs!` block misses;
`--add-defaults` adds them (keeping `init.el.bak`). Then sync.

**`gc [-n|--dry-run]`**
Deletes installed packages nothing declares any more; `-n` only lists them.

### Running and checking

**`emacs [--vanilla] [-- ARGS]`**
Starts Emacs on this Hellmacs (and `--profile`), wherever it's installed.
`--vanilla` starts `emacs -Q`, to tell a Hellmacs problem from an Emacs one.

**`doctor [--network]`** [`doc`]
Checks Emacs, required tools, your config (including whether it changed
since the last sync), and every enabled module's needs: JDKs, language
servers, fonts, `direnv`... `--network` also checks every host Hellmacs
fetches from (always, when a proxy, CA or mirror is set).

**`info`**
What a bug report needs: Hellmacs' version and commit, Emacs and its build
features, the system, the profile, your modules.

**`version`** [`v`]
Hellmacs' version and commit, its update channel, and the Emacs it runs on.

**`profile list`**, **`profile sync --all`** [`pf`]
Lists every profile and whether it's synced; or syncs all of them.

### Reproducibility and compliance

**`lock`**
Records the exact commit of every package in
`~/.config/hellmacs/packages.lock.eld`; later syncs install those. Commit it
with your config to reproduce it elsewhere.

**`verify`**
Checks that every file sync installed still has its SHA-256, and every
package is at the commit sync installed (and your lock file pins). Fails
on any difference, naming it.

**`sbom [OUT.json]`**
A CycloneDX (JSON) bill of materials of everything installed: packages at
their commits, language servers, jars and grammars, with pins and licenses.
To stdout without a file name.

**`licenses`**
The license of everything installed; fails if one is unknown, and flags
licenses outside SPDX's list.

**`bundle OUT.tar.zst [--modules SPEC]`**
Syncs, then packs everything a sync installs (packages, servers, grammars,
the lock file) into one archive for machines without internet
(`.tar.gz`, `.tar.xz` and `.tar` work too). A bundle is for one platform
and one Emacs major version. It carries your modules, or SPEC's:
`--modules ":lang (java +lombok) kotlin :tools lsp build"`; that also
syncs this machine for those modules, so use its own profile:
`hellmacs -p bundle bundle ...`. Install it with
`hellmacs install --from-bundle FILE`.

**`help`** [`h`]
All of the above, briefly.

## Profiles

Every command acts on the default profile unless given `-p NAME`:

```sh
hellmacs -p work sync
hellmacs -p work emacs
hellmacs -p safe-mode sync     # Hellmacs' core alone, for finding what broke
```

See the [guide](guide.md#4-profiles).
