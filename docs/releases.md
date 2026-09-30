# Releases and Support

## Versions

Hellmacs uses [Semantic Versioning](https://semver.org/). A release is a
git tag `vMAJOR.MINOR.PATCH` on `main`, and `hellmacs-version` carries its
number. Before 1.0, a minor release (0.9 → 0.10) may change behavior or
configuration; the changelog says how to adapt. From 1.0 on:

- **PATCH** (1.0.1): fixes only, including security fixes. Nothing to change
  in your config.
- **MINOR** (1.1.0): new modules, flags and commands. What worked keeps
  working; anything deprecated keeps working, with a warning, until the
  next MAJOR.
- **MAJOR** (2.0.0): may remove what was deprecated, or raise the minimum
  Emacs version.

What each release changed is in [CHANGELOG.md](../CHANGELOG.md).

## Channels

`bin/hellmacs upgrade` updates Hellmacs itself, then every package:

| Channel | What Hellmacs moves to | For |
|---|---|---|
| `stable` (default) | The latest release tag | Teams and companies: a known, tested version |
| `main` | The tip of the development branch | Contributors, and trying what's next |

Choose one for a run with `bin/hellmacs upgrade --channel main`, or for
good in your `init.el`:

```elisp
(setq hellmacs-upgrade-channel 'main)
```

To only accept releases whose tags are signed by a key in your GPG keyring,
also set `(setq hellmacs-upgrade-verify-tags t)`; an unsigned or unknown
tag is then refused. `bin/hellmacs version` shows the version, the commit
and the channel.

Packages follow your lock file when you have one (`bin/hellmacs lock`), on
either channel.

## What a release supports

Each release states, in its changelog entry:

- **Emacs:** 29.1 and later (the minimum is only raised in a MAJOR release).
  CI installs Hellmacs and runs `doctor` on 29.1 and 30.1.
- **Platforms:** Linux x86_64 and arm64, macOS Apple Silicon and Intel, and
  Windows through WSL2 (the table in the README). Pinned downloads exist
  for each of them.
- **JDKs:** JDTLS runs on JDK 21 to 25; projects compile against any JDK
  JDTLS knows (8 and up).

## Security fixes

- The latest release gets every fix.
- The release before it gets **security fixes for 6 months** after the new
  one is out, as PATCH releases.
- Report a vulnerability privately to the maintainer
  (petrolalucas@gmail.com), not in a public issue.

## Making a release (maintainers)

1. Move `[Unreleased]` in CHANGELOG.md under the new version and date, with
   its supported Emacs versions and platforms.
2. Set `hellmacs-version` to it.
3. `bin/hellmacs doctor` passes, and CI is green.
4. Tag it, signed: `git tag -s vX.Y.Z -m "Hellmacs X.Y.Z"`, and push the tag.
5. Set `hellmacs-version` on `main` to the next version.
