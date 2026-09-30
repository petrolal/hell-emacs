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
| `C-x b` / `C-x 4 b` / `C-x 5 b` / `C-x t b` | `consult-buffer` (with previews), here / other window / frame / tab | `:completion vertico` |
| `C-x p b` | `consult-project-buffer` | vertico |
| `M-y` | `consult-yank-pop` | vertico |
| `M-g g` / `M-g i` | `consult-goto-line` / `consult-imenu` | vertico |
| `M-g f` / `M-g o` | Jump to a diagnostic / a heading (free `M-g` keys) | vertico |
| `C-x r b` | `consult-bookmark` | vertico |
| `M-s l` / `M-s r` / `M-s d` | Search lines / ripgrep the project / find files by name (consult's own keys) | vertico |
| `M-.` / `M-?` / `M-,` | Definition / references / back, through the language server | `:tools lsp` |
| `C-M-.` | Workspace symbols | lsp |
| `C-x p c` | Build the project with its wrapper; errors clickable with `M-g n` / `M-g p` | `:tools build` |
| `C-x g` / `C-x M-g` / `C-c M-g` | Magit status / dispatch / file actions | `:tools magit` |
| `C-x v [` `]` / `*` / `n` / `S` | Previous, next changed hunk / show / revert / stage it | `:ui vc-gutter` |

---

## `C-c` groups

Laid out as Doom Emacs' non-evil leader, with Emacs' own commands. The
groups gather stock commands in one place; the stock keys keep working.

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

### `C-c c`: code

| Key | Command |
|---|---|
| `C-c c c` / `C-c c C` | Compile the project (its build tool with `:tools build`) / recompile |
| `C-c c d` / `C-c c D` | Jump to the definition / the references |
| `C-c c j` | Jump to a symbol in the project |
| `C-c c k` | Documentation at point |
| `C-c c w` | Delete trailing whitespace |
| `C-c c x` | List the buffer's errors |

With a language server (`:tools lsp`) the group also has `C-c c a` code
actions, `C-c c r` rename, `C-c c o` organize imports, `C-c c f` format,
`C-c c i` / `C-c c t` implementations / type definition, and lsp-mode's
whole map on `C-c c l` (`w r` restart the server, `T` toggles, `g` goto
and the rest; which-key lists them).

### `C-c l`: the localleader

The current mode's own commands, as Doom's localleader: only in the
buffers they belong to, unbound elsewhere.

| In | Keys |
|---|---|
| Java | `b` build (JDTLS), `u` update project, `g` getters/setters, `s` toString, `e` equals/hashCode, `i` unimplemented methods, `m` / `v` / `c` extract method / variable / constant, `h` type hierarchy |
| Groovy | `c` refresh the classpath |
| A JVM source with `:tools build` | `t t` / `t T` test at point / class; with `:tools test`, `t r` results, `t f` rerun the failures, `t c` run with coverage, `t s` / `t h` show / hide coverage |

### `C-c f` file, `C-c b` buffer, `C-c s` search

| Key | Command |
|---|---|
| `C-c f f` / `C-c f s` / `C-c f R` | Find a file / save / rename the visited file |
| `C-c f r` | A recent file |
| `C-c b b` / `C-c b d` / `C-c b r` | Switch buffer / kill it / revert it |
| `C-c s s` / `C-c s p` | Search the buffer / the project |
| `C-c s f` / `C-c s i` / `C-c s m` | Locate a file / jump to a symbol / to a bookmark |
| `C-c s o` | occur |

### `C-c t`: toggle

| Key | Command |
|---|---|
| `C-c t l` / `C-c t c` | Line numbers / fill column indicator |
| `C-c t w` / `C-c t v` | Soft line wrapping / visible mode |
| `C-c t r` / `C-c t F` | Read-only / frame fullscreen |
| `C-c t f` / `C-c t s` | Flymake / the spell checker |

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

### `C-c !`: diagnostics

Flymake's, wherever it runs: `C-c ! n` / `C-c ! p` next / previous,
`C-c ! l` the list.

### `C-c d`: debugging (`:tools debugger`)

| Key | Command |
|---|---|
| `C-c d d` / `C-c d D` | Start a session / start the last one again |
| `C-c d r` / `C-c d q` | Restart / disconnect |
| `C-c d b` / `B` / `L` / `x` | Toggle a breakpoint / its condition / log message / delete all |
| `C-c d n` / `i` / `o` / `c` | Next / step in / step out / continue; then `n`, `i`, `o`, `c` alone keep stepping, as in edebug |
| `C-c d e` / `C-c d E` | Evaluate at point / an expression |
| `C-c d t` / `C-c d T` | Debug the test at point / the test class |

### `C-c r` run, `C-c o` open

| Key | Command |
|---|---|
| `C-c r r` / `C-c r d` / `C-c r l` | Run a configuration / debug one / run the last again (`:tools run`) |
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
  failures, `g` reread the reports (`revert-buffer`), `c` coverage per file.

---

## Your own keys

In `config.el`, under `C-c` (one letter after `C-c` is yours by Emacs'
convention):

```elisp
(keymap-global-set "C-c y g" #'my-command)
(hellmacs-leader-def            ; with a which-key label
  "y g" '("my command" . my-command))
(hellmacs-localleader-def 'python-mode   ; C-c l r, in Python buffers
  "r" '("run file" . my-python-run))
```

`hellmacs-prefix-map` is the `C-c h` map, if you want it on another key:
`(keymap-global-set "<f12>" hellmacs-prefix-map)`.
