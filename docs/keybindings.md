# Keybindings

Hell Emacs keys come in three layers, kept apart:

- **Traditional:** every stock GNU Emacs key keeps its meaning, and
  nothing is added inside Emacs' own prefixes (`C-x`, `M-g`, `M-s`,
  `C-x v`, `C-x t`). Packages improve the default commands in place
  (`C-x b` switches buffers with previews) instead of adding keys.
- **Modern:** Hell Emacs' and its packages' commands (debugger, git,
  language servers, tests, runs) live only under `C-c`, the prefix Emacs
  reserves for users, in the groups below; a mode's own commands on the
  `C-c l` localleader. A `C-c` key never repeats a stock key's command:
  when stock Emacs has a key, that is the key.
- **Installed packages:** each keeps its own default keys exactly as it
  ships them -- Magit's `C-x g`, diff-hl's `C-x v [ ]`, lsp-mode's
  `s-l`, corfu's popup keys, which-key's `C-h`, yasnippet's `TAB` and
  `C-c &`. Hell Emacs never rebinds, unsets or moves them, and adds no
  key of its own that would repeat one.

Nothing is modal: no Evil, no `SPC` leader. which-key shows what
follows any prefix; `C-h` there is which-key's (pages, help), as it
ships.

`TAB` indents, as in stock Emacs; `C-M-i` completes (`(corfu +tab)` makes
`TAB` complete too). While the completion popup is open, its keys are
corfu's own: `M-n` / `M-p` and the arrows move, `RET` / `TAB` insert,
`M-g` the candidate's location, `M-h` its documentation, `C-g` closes it.

---

## Stock keys, improved

| Key | Command | With |
|---|---|---|
| `C-x b` / `C-x 4 b` / `C-x 5 b` / `C-x t b` | `consult-buffer` (with previews), here / other window / frame / tab | `:completion vertico` |
| `C-x p b` | `consult-project-buffer` | vertico |
| `C-x C-b` | `ibuffer` (built in) | `:config default` |
| `M-/` | `hippie-expand`: dabbrev as before, then file names, abbrevs, Lisp symbols | `:config default` |
| `M-y` | `consult-yank-pop` | vertico |
| `M-g g` / `M-g i` | `consult-goto-line` / `consult-imenu` | vertico |
| `C-x r b` | `consult-bookmark` | vertico |
| `M-.` / `M-?` / `M-,` | Definition / references / back, through the language server | `:tools lsp` |
| `C-M-.` | Workspace symbols | lsp |
| `C-x p c` | Build the project with its wrapper; errors clickable with `M-g n` / `M-g p` | `:tools build` |
| `C-x g` / `C-x M-g` / `C-c M-g` | Magit status / dispatch / file actions (Magit's own keys) | `:tools magit` |
| `C-x v [` `]` / `*` / `n` / `S`, `C-x v =` | Previous, next changed hunk / show / revert / stage it, a diff at the hunk (diff-hl's own keys) | `:ui vc-gutter` |
| `C-x t 2` / `0` / `o` / `RET` / `p p` | New tab / close / next / switch / a project in a new tab, with the tab bar shown | `:ui workspaces` |
| `C-/` / `C-?` (`C-M-_` in a terminal) | Undo / redo, Emacs' own; history kept across restarts | `:editor undo` |

With `(default +repeat)`, Emacs' own `repeat-mode` lets the last key
repeat a command: `C-x o o o`, `C-x { {`, `M-g n n`. It's off by default,
because right after `C-x o` a plain `o` then switches windows.

**Deliberate departures from stock**, for modern editing: typing
replaces the selected region (`delete-selection-mode`), brackets and
quotes are inserted in pairs (`electric-pair-mode`), and the completion
popup opens as you type (`:completion corfu`). While that popup is open,
the movement keys (`C-n` / `C-p`, the arrows, `M-<` / `M->`, `C-v` /
`M-v`) move in it; `C-g` closes it and gives them back. Turn any of
them off in your `config.el`: `(delete-selection-mode -1)`,
`(electric-pair-mode -1)`, `(setq corfu-auto nil)` (then `C-M-i` opens
the popup).
lsp-mode keeps its own mouse keys: `mouse-3` its menu, `C-mouse-1` its actions.

---

## `C-c` groups

Laid out as Doom Emacs' non-evil leader. Each group holds only what stock
Emacs has no key for: finding files, saving, switching or killing
buffers, splitting windows, going to a definition, building, quitting --
those are on their stock keys, listed beside each group.

### `C-c h`: Hell Emacs

| Key | Command |
|---|---|
| `C-c h s` | The Altar (GNU Emacs' startup screen, themed) |
| `C-c h i` | Grimoire Manual (open Hell Emacs native Info manual) |
| `C-c h h` | The help hub: the JVM toolchain's state and the keys |
| `C-c h k` | IntelliJ Exorcism (Rosetta Stone / IntelliJ key finder) |
| `C-c h p` | Relic Chamber (Hell Emacs plugin & module manager) |
| `C-c h r` | The Crucible: hot-swap changed classes into the debugged JVM, or reload into the Clojure REPL |
| `C-c h c` | The Reaper: collect garbage now, and say how much memory is in use |
| `C-c h S` | Sync (install what your config declares) |
| `C-c h R` | Sync in a child Emacs, then reload your config |
| `C-c h u` / `C-c h v` | Open your config directory / Hell Emacs' directory |
| `C-c h m` / `C-c h M` | Describe a module / list the enabled modules |

A project's file is stock **`C-x p f`**.

### `C-c c`: code

| Key | Command |
|---|---|
| `C-c c C` | Recompile |
| `C-c c k` | Documentation at point |
| `C-c c w` | Delete trailing whitespace |

With a language server (`:tools lsp`) the group also has `C-c c a` code
actions, `C-c c r` rename, `C-c c o` organize imports, `C-c c f` format,
`C-c c i` / `C-c c t` implementations / type definition. lsp-mode's
own whole map stays on its `s-l` (`s-l w r` restart the server, `T`
toggles, `g` goto and the rest; which-key lists them).

Stock: **`M-.`** / **`M-?`** / **`C-M-.`** definition / references /
project symbol, **`C-x p c`** build the project, **`C-h .`** help at point.

### `C-c l`: the localleader

The current mode's own commands, as Doom's localleader: only in the
buffers they belong to, unbound elsewhere.

| In | Keys |
|---|---|
| Java | `b` build (JDTLS), `u` update project, `g` getters/setters, `s` toString, `e` equals/hashCode, `i` unimplemented methods, `m` / `v` / `c` extract method / variable / constant, `h` type hierarchy |
| Groovy | `c` refresh the classpath |
| A JVM source with `:tools build` | `t t` / `t T` test at point / class; with `:tools test`, `t r` results, `t f` rerun the failures, `t c` run with coverage, `t s` / `t h` show / hide coverage |

### `C-c f` file, `C-c s` search

| Key | Command |
|---|---|
| `C-c f r` / `C-c f R` | A recent file / rename the visited file |
| `C-c s s` / `C-c s p` | Search the buffer's lines / ripgrep the project |
| `C-c s f` | Locate a file by name |
| `C-c s o` / `C-c s e` | Jump to a heading / a diagnostic |

Stock: **`C-x C-f`** find, **`C-x C-s`** save, **`C-x b`** / **`C-x k`**
switch / kill buffer, **`C-x x g`** revert, **`M-s o`** occur, **`M-g i`**
a symbol of the buffer, **`C-x r b`** a bookmark.

### `C-c t`: toggle

| Key | Command |
|---|---|
| `C-c t l` / `C-c t c` | Line numbers / fill column indicator |
| `C-c t w` / `C-c t v` | Soft line wrapping / visible mode |
| `C-c t f` / `C-c t s` | Flymake / the spell checker |

Stock: **`C-x C-q`** read-only, **`<f11>`** fullscreen.

### `C-c w` window, `C-c q` quit

| Key | Command |
|---|---|
| `C-c w b` `f` `p` `n` | Move to the window left, right, up, down |
| `C-c w t` | Hide or bring back the bottom popup (`:ui popup`) |
| `C-c q r` | Restart Emacs |

Stock: **`C-x 2`** / **`C-x 3`** split, **`C-x 0`** / **`C-x 1`** delete
this / the others, **`C-x o`** other window, **`C-x +`** balance,
winner's **`C-c <left>`** / **`C-c <right>`** undo / redo the layout,
**`C-x C-c`** quit, **`C-x t`** tabs.

### `C-c !`: diagnostics

Flymake's, wherever it runs: `C-c ! n` / `C-c ! p` next / previous,
`C-c ! l` the list; `C-c s e` jumps to one.

|---|---|
| `C-c g g` / `C-c g d` / `C-c g f` | Magit status / dispatch / the current file's actions |
| `C-c M-g`, then `b` / `l` | Blame / log of the current file |
| `C-c v [` `]` / `*` / `n` / `S` | Previous, next changed hunk / show / revert / stage it |

Magit's own `C-x g`, `C-x M-g` and `C-c M-g` are turned off, so `C-x`
stays stock; Emacs' own vc stays on **`C-x v`**, `C-x v =` included.

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

## Coming from IntelliJ IDEA or Eclipse

The same actions, on Hell Emacs keys. IntelliJ's column is its default
keymap on Windows and Linux (macOS uses `Cmd` for most of them). Keys in
**bold** are stock Emacs; the rest are Hell Emacs' `C-c` groups. There is
no IntelliJ keymap: these are the Emacs ways to do the same thing.

**Finding things**

| Action | IntelliJ IDEA | Eclipse | Hell Emacs |
|---|---|---|---|
| Any command | `Ctrl+Shift+A` | `Ctrl+3` | **`M-x`** |
| A file in the project | `Ctrl+Shift+N` | `Ctrl+Shift+R` | **`C-x p f`** |
| A class or symbol in the project | `Ctrl+N`, `Ctrl+Alt+Shift+N` | `Ctrl+Shift+T` | **`C-M-.`** |
| Recent files | `Ctrl+E` | — | `C-c f r` |
| Switch between open files | `Ctrl+Tab` | `Ctrl+E` | **`C-x b`** (with previews) |
| Structure of this file | `Ctrl+F12` | `Ctrl+O` | **`M-g i`** |
| Go to line | `Ctrl+G` | `Ctrl+L` | **`M-g g`** |
| Find in this file | `Ctrl+F` | `Ctrl+F` | **`C-s`**; a list of matches: **`M-s o`**, or `C-c s s` |
| Find in the project | `Ctrl+Shift+F` | `Ctrl+H` | **`C-x p g`**, or `C-c s p` (ripgrep) |
| Replace / in the project | `Ctrl+R` / `Ctrl+Shift+R` | `Ctrl+F` / `Ctrl+H` | **`M-%`** / **`C-x p r`** |
| Project files as a tree | `Alt+1` | Package Explorer | **`C-x p D`** (Dired) |

**Navigating code**

| Action | IntelliJ IDEA | Eclipse | Hell Emacs |
|---|---|---|---|
| Go to declaration | `Ctrl+B`, `Ctrl+Click` | `F3` | **`M-.`** |
| Back | `Ctrl+Alt+Left` | `Alt+Left` | **`M-,`** |
| Find usages | `Alt+F7` | `Ctrl+Shift+G` | **`M-?`** |
| Go to implementation | `Ctrl+Alt+B` | `Ctrl+T` | `C-c c i` |
| Go to type declaration | `Ctrl+Shift+B` | — | `C-c c t` |
| Type hierarchy | `Ctrl+H` | `F4` | `C-c l h` (Java) |
| Quick documentation | `Ctrl+Q` | `F2` | `C-c c k`; while typing, in the echo area |
| Parameter info | `Ctrl+P` | `Ctrl+Shift+Space` | Shown by itself after `(` and `,` |
| Next / previous error | `F2` / `Shift+F2` | `Ctrl+.` / `Ctrl+,` | `C-c ! n` / `C-c ! p`; jump to one: `C-c s e` |
| All errors of the file | `Alt+6` | Problems view | `C-c ! l` |
| Last edit location | `Ctrl+Shift+Backspace` | `Ctrl+Q` | **`C-u C-SPC`** (back through the marks) |
| Bookmark / go to one | `F11` / `Shift+F11` | — | **`C-x r m`** / **`C-x r b`** |

**Editing and refactoring**

| Action | IntelliJ IDEA | Eclipse | Hell Emacs |
|---|---|---|---|
| Completion | `Ctrl+Space` | `Ctrl+Space` | As you type; on demand **`C-M-i`** |
| Live templates / postfix | `Ctrl+J` / `.for`, `.var`... | Templates | Complete `sysout`, `foreach`, `list.for`, `x.var` like any name |
| Quick fix, intention actions | `Alt+Enter` | `Ctrl+1` | `C-c c a` |
| Rename | `Shift+F6` | `Alt+Shift+R` | `C-c c r` |
| Extract method / variable / constant | `Ctrl+Alt+M` / `V` / `C` | `Alt+Shift+M` / `L` / — | `C-c l m` / `v` / `c` (Java) |
| Generate getters, `toString`, `equals` | `Alt+Insert` | `Alt+Shift+S` | `C-c l g` / `s` / `e` (Java) |
| Implement methods | `Ctrl+I` | Quick fix | `C-c l i` (Java) |
| Optimize imports | `Ctrl+Alt+O` | `Ctrl+Shift+O` | `C-c c o` |
| Reformat | `Ctrl+Alt+L` | `Ctrl+Shift+F` | `C-c c f` |
| Comment line | `Ctrl+/` | `Ctrl+/` | **`C-x C-;`**; at the end of a line **`M-;`** |
| Delete line | `Ctrl+Y` | `Ctrl+D` | **`C-S-<backspace>`** |
| Duplicate line | `Ctrl+D` | `Ctrl+Alt+Down` | `M-x duplicate-dwim` (no stock key) |
| Move line | `Ctrl+Shift+Up/Down` | `Alt+Up/Down` | **`C-x C-t`** swaps it with the line above |
| Undo / redo | `Ctrl+Z` / `Ctrl+Shift+Z` | `Ctrl+Z` / `Ctrl+Y` | **`C-/`** / **`C-?`** (**`C-M-_`** in a terminal) |
| Save all | `Ctrl+S` | `Ctrl+Shift+S` | **`C-x s`** |
| Close the file | `Ctrl+F4` | `Ctrl+W` | **`C-x k`** |

**Build, run, test, debug**

| Action | IntelliJ IDEA | Eclipse | Hell Emacs |
|---|---|---|---|
| Build the project | `Ctrl+F9` | `Ctrl+B` | **`C-x p c`** |
| Run / debug a configuration | `Shift+F10` / `Shift+F9` | `Ctrl+F11` / `F11` | `C-c r r` / `C-c r d` |
| Run the last again | `Ctrl+F5` | `Ctrl+F11` | `C-c r l` |
| Run the test at point / the class | `Ctrl+Shift+F10` | `Alt+Shift+X T` | `C-c l t t` / `C-c l t T` |
| Test results / rerun failures | `Alt+4` | JUnit view | `C-c l t r` / `C-c l t f` |
| Coverage | Run with Coverage | — | `C-c l t c` |
| Debug the test at point | `Ctrl+Shift+F9` | `Alt+Shift+D T` | `C-c d t` |
| Toggle breakpoint | `Ctrl+F8` | `Ctrl+Shift+B` | `C-c d b` |
| Step over / into / out | `F8` / `F7` / `Shift+F8` | `F6` / `F5` / `F7` | `C-c d n` / `i` / `o`, then `n`, `i`, `o` alone |
| Resume | `F9` | `F8` | `C-c d c`, then `c` |
| Evaluate expression | `Alt+F8` | `Ctrl+Shift+I` | `C-c d E` |
| Hot-swap changed classes | `Ctrl+F9` while debugging | Save while debugging | `C-c h r` |

**Git and the rest**

| Action | IntelliJ IDEA | Eclipse | Hell Emacs |
|---|---|---|---|
| Git: status, commit, push | `Alt+9`, `Ctrl+K`, `Ctrl+Shift+K` | Git Staging | `C-x g` (Magit), then `c c` commit, `P p` push |
| Blame / history of this file | Annotate / Show History | Show Annotations / History | `C-c g b` / `C-c g l` |
| Terminal | `Alt+F12` | — | **`C-x p s`** (shell) or **`C-x p e`** (eshell), in the project |
| Split the editor | Split Right | — | **`C-x 3`** / **`C-x 2`** |
| Close a popup | `Esc` | `Esc` | **`C-g`**, or `q` in it |
| Settings | `Ctrl+Alt+S` | Preferences | `C-c h u` (your config directory) |

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
- **Snippets from the language server (`:tools lsp`, yasnippet's own
  keys):** `TAB` expands; inside an expansion `TAB` / `S-TAB` next /
  previous placeholder, `C-g` leaves; `C-c &` yasnippet's commands.
- **Snippets (`:editor snippets`):** complete a snippet's name with `C-M-i`;
  inside one, tempel's own keys: `M-}` / `M-{` next / previous field,
  `ESC ESC ESC` abort.
- **The Altar:** GNU Emacs' startup screen and its keys: `TAB` / `S-TAB`
  move between links, `RET` follows one, `SPC` / `DEL` scroll, `q` dismisses.
- **Test results:** `RET` go to the test, `r` rerun it, `f` rerun the
  failures, `g` reread the reports (`revert-buffer`), `c` coverage per file.

---

## Your own keys

In `config.el`, under `C-c` (one letter after `C-c` is yours by Emacs'
convention):

```elisp
(keymap-global-set "C-c y g" #'my-command)
(hell-leader-def            ; with a which-key label
  "y g" '("my command" . my-command))
(hell-localleader-def 'python-mode   ; C-c l r, in Python buffers
  "r" '("run file" . my-python-run))
```

`hell-prefix-map` is the `C-c h` map, if you want it on another key:
`(keymap-global-set "<f12>" hell-prefix-map)`.
