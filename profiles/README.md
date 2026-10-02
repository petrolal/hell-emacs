# Profiles

A profile is a separate Hell Emacs configuration, with its own packages,
caches and history; as in Doom v3, a directory is a profile. Hell Emacs ships
one here:

- **`safe-mode`**: Hell Emacs' core and its own module (the Altar, the themed
  messages), no other module and none of your config. When something breaks
  Emacs, start here, then add your modules back one at a time:

  ```sh
  bin/hell -p safe-mode sync
  bin/hell -p safe-mode emacs
  ```

To create a new in-tree profile directly inside this directory:

```sh
bin/hell profile create dev --in-tree
bin/hell -p dev emacs
```

How profiles are found, and how to make your own: the
[guide](../docs/guide.md#4-profiles) and [development guide](../docs/development.md#development-environments--workflows).
