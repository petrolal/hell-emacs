# Profiles

A profile is a separate Hellmacs configuration, with its own packages,
caches and history; as in Doom v3, a directory is a profile. Hellmacs ships
one here:

- **`safe-mode`**: Hellmacs' core and its own module (the Altar, the themed
  messages), no other module and none of your config. When something breaks
  Emacs, start here, then add your modules back one at a time:

  ```sh
  hellmacs -p safe-mode sync
  hellmacs -p safe-mode emacs
  ```

To create a new in-tree profile directly inside this directory:

```sh
bin/hellmacs profile create dev --in-tree
bin/hellmacs -p dev emacs
```

How profiles are found, and how to make your own: the
[guide](../docs/guide.md#4-profiles) and [development guide](../docs/development.md#development-environments--workflows).
