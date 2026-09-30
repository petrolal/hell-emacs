# Profiles

A profile is a separate Hellmacs configuration: its own `init.el`
(`hellmacs!` block), `config.el` and `packages.el`, and its own packages,
caches and history. Start Emacs on one with `--profile NAME`, and point
`bin/hellmacs` at it the same way:

```sh
bin/hellmacs --profile NAME sync
emacs --init-directory ~/.config/emacs --profile NAME
```

(`HELLMACS_PROFILE=NAME` works for both.) Like Doom v3's, profiles are
*implicit*: a directory is a profile. For `--profile NAME`, Hellmacs uses the
first of these that exists:

1. `~/.config/hellmacs-NAME/` (under `$XDG_CONFIG_HOME`), as before;
2. `profiles/NAME/` in your config (`~/.config/hellmacs/profiles/NAME/`);
3. `profiles/NAME/` here, in Hellmacs.

`$HELLMACSDIR`, when set, wins over all three. Whichever directory holds the
config, the profile's packages, caches and history are always its own:
`~/.local/share/hellmacs-NAME/`, `~/.cache/hellmacs-NAME/` and
`~/.local/state/hellmacs-NAME/`.

## Profiles Hellmacs ships

- **`safe-mode`**: Hellmacs' core and its own module (the startup screen,
  the themed prompts), no other module and none of your config. When
  something breaks Emacs, start here, then add modules back one at a time.
