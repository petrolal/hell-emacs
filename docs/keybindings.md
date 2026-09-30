# Keybindings

Hellmacs keeps **every stock GNU Emacs key** with its usual meaning, and
adds nothing modal: no Evil, no `SPC` leader. Its own commands live under
`C-c`, the prefix Emacs reserves for users, and packages improve the
default commands in place (`C-x b` switches buffers with previews). `C-h`
is untouched, and which-key shows what follows any prefix.

`TAB` indents, as in stock Emacs; `C-M-i` completes (`(corfu +tab)` makes
`TAB` complete too).

---

## Stock keys, improved

| Key | Command | With |
|---|---|---|
| `C-x b` / `C-x 4 b` | `consult-buffer` (with previews) | `:completion vertico` |
| `C-x p b` | `consult-project-buffer` | vertico |
| `M-y` | `consult-yank-pop` | vertico |
| `M-g g` | `consult-goto-line` | vertico |
| `M-g i` | `consult-imenu` | vertico |
| `C-x r b` | `consult-bookmark` | vertico |
| `M-s l` / `M-s r` / `M-s f` | Search lines / ripgrep the project / find files by name | vertico |
| `M-.` / `M-?` / `M-,` | Definition / references / back, through the language server | `:tools lsp` |
| `C-M-.` | Workspace symbols | lsp |
| `C-x p c` | Build the project with its wrapper; errors clickable with `M-g n` / `M-g p` | `:tools build` |
| `C-x g` / `C-x M-g` / `C-c M-g` | Magit status / dispatch / file actions | `:tools magit` |
| `C-x v [` `]` / `*` / `n` / `S` | Previous, next changed hunk / show / revert / stage it | `:ui vc-gutter` |

---

## `C-c` groups

### `C-c h`: Hellmacs

| Key | Command |
|---|---|
| `C-c h s` | The Altar (the startup dashboard) |
| `C-c h f` | The Forge: find a file in the project (or pick a project first) |
| `C-c h r` | The Crucible: hot-swap changed classes into the debugged JVM, or reload into the Clojure REPL |
| `C-c h c` | The Reaper: collect garbage now, and say how much memory is in use |
| `C-c h S` | Sync (install what your config declares) |
| `C-c h R` | Sync in a child Emacs, then reload your config |
| `C-c h u` / `C-c h v` | Open your config directory / Hellmacs' directory |
| `C-c h m` | List the enabled modules |

### `C-c f` file, `C-c b` buffer, `C-c s` search

| Key | Command |
|---|---|
| `C-c f f` / `C-c f s` / `C-c f R` | Find a file / save / rename the visited file |
| `C-c f r` | A recent file |
| `C-c b b` / `C-c b d` / `C-c b r` | Switch buffer / kill it / revert it |
| `C-c s s` / `C-c s o` | isearch / occur |
| `C-c s l` / `C-c s g` / `C-c s f` / `C-c s i` | Search lines / ripgrep / find by name / jump to a symbol |

### `C-c w` window, `C-c q` quit

| Key | Command |
|---|---|
| `C-c w s` / `C-c w v` | Split below / right |
| `C-c w d` / `C-c w m` / `C-c w o` / `C-c w =` | Delete / maximize / other window / balance |
| `C-c w b` `f` `p` `n` | Move to the window left, right, up, down |
| `C-c w u` / `C-c w r` | Undo / redo the window layout |
| `C-c w t` | Hide or bring back the bottom popup (`:ui popup`) |
| `C-c q q` / `C-c q r` | Quit / restart Emacs |

The stock window keys (`C-x 2`, `C-x 3`, `C-x 0`, `C-x 1`, `C-x o`) work as
always.

### `C-c l`: the language server (`:tools lsp`)

lsp-mode's own map, in any buffer with a server: `C-c l a a` code actions,
`C-c l r r` rename, `C-c l r o` organize imports, `C-c l = =` format,
`C-c l g t` / `g i` type definition / implementations, and the rest (which-key
lists them). Each JVM language adds its own group:

| Group | In | Keys |
|---|---|---|
| `C-c l j` | Java | `b` build, `u` update project, `o` imports, `g` getters/setters, `s` toString, `e` equals/hashCode, `i` unimplemented methods, `m` / `v` / `c` extract method / variable / constant, `h` type hierarchy, `t` / `T` test at point / class |
| `C-c l k` | Kotlin | `b` build, `t` / `T` test at point / class |
| `C-c l g` | Groovy | `b` build, `t` / `T` test at point / class, `c` refresh the classpath |

Diagnostics: `C-c ! n` / `C-c ! p` next / previous, `C-c ! l` the list.

### `C-c d`: debugging (`:tools debugger`)

| Key | Command |
|---|---|
| `C-c d d` / `C-c d D` | Start a session / start the last one again |
| `C-c d r` / `C-c d q` | Restart / disconnect |
| `C-c d b` / `B` / `L` / `x` | Toggle a breakpoint / its condition / log message / delete all |
| `C-c d n` / `i` / `o` / `c` | Next / step in / step out / continue; then `n`, `i`, `o`, `c` alone keep stepping |
| `C-c d e` / `C-c d E` | Evaluate at point / an expression |
| `C-c d t` / `C-c d T` | Debug the test at point / the test class |

### `C-c r` run, `C-c t` test, `C-c o` open

| Key | Command |
|---|---|
| `C-c r r` / `C-c r d` / `C-c r l` | Run a configuration / debug one / run the last again (`:tools run`) |
| `C-c t t` / `C-c t f` | Test results / rerun the failures (`:tools test`) |
| `C-c t c` / `C-c t s` / `C-c t h` | Run with coverage / show / hide coverage marks |
| `C-c o d` / `C-c o k` | Docker / Kubernetes (`:tools docker`, `:tools kubernetes`) |

---

## Keys inside modes

These are the modes' own keys, only in their buffers.

- **Clojure (CIDER):** `C-c M-j` jack in, `C-c M-c` connect, `C-c C-k` load
  the buffer, `C-M-x` evaluate the form, `C-c C-z` REPL, `C-c C-t t` the
  test at point.
- **`.http` files (`:tools http`):** `C-c C-c` send the request at point,
  `C-c C-e` / `C-c M-e` choose / reload the environment, `C-c C-l` /
  `C-c C-a` run the request / file with httpyac (`+httpyac`).
- **SQL (`:tools db`):** `C-c C-c` run the statement at point, `C-c C-b`
  the buffer.
- **Snippets (`:editor snippets`):** complete a snippet's name with `C-M-i`;
  inside one, `M-}` / `M-{` next / previous field, `ESC ESC ESC` abort.
- **The Altar:** `TAB` / `S-TAB` move, `RET` opens, `g` redraws, `q` buries.
- **Test results:** `RET` go to the test, `r` rerun it, `f` rerun the
  failures, `g` refresh, `c` coverage per file.

---

## Your own keys

In `config.el`, under `C-c` (one letter after `C-c` is yours by Emacs'
convention):

```elisp
(keymap-global-set "C-c y g" #'my-command)
(hellmacs-leader-def            ; with a which-key label
  "y g" '("my command" . my-command))
```

`hellmacs-prefix-map` is the `C-c h` map, if you want it on another key:
`(keymap-global-set "<f12>" hellmacs-prefix-map)`.
