# Keybindings Reference

Hellmacs adheres to **stock Emacs keybindings** (no modal Vim emulation by default). All Hellmacs commands and sub-menus are grouped logically under the **`C-c`** leader prefix.

---

## Hellmacs Leader (`C-c h`)

| Key | Command | Description |
|---|---|---|
| `C-c h s` | `hellmacs-splash` | Return to The Altar (dashboard screen) |
| `C-c h f` | `hellmacs-find-file-in-project` | Forge: Find file in current project (or pick project) |
| `C-c h c` | `hellmacs-gc` | Reap: Run Garbage Collector immediately and report memory |
| `C-c h r` | `hellmacs-crucible` | Crucible: Hot-swap modified classes to JVM or reload CIDER REPL |
| `C-c h S` | `hellmacs-sync` | Synchronize packages and rewrite the static profile |
| `C-c h R` | `hellmacs-reload` | Reload user configuration |
| `C-c h u` | `hellmacs-find-user-dir` | Open user configuration directory (`~/.config/hellmacs/`) |
| `C-c h v` | `hellmacs-find-core-dir` | Open Hellmacs installation directory |
| `C-c h m` | `hellmacs-list-modules` | List all active and declared modules |

---

## File Operations (`C-c f`) & Buffer Operations (`C-c b`)

| Key | Command | Description |
|---|---|---|
| `C-c f f` / `C-x C-f` | `find-file` | Open or create a file |
| `C-c f r` | `consult-recent-file` | Open a recent file |
| `C-c f s` / `C-x C-s` | `save-buffer` | Save current buffer |
| `C-c f S` / `C-x s` | `save-some-buffers` | Save all modified buffers |
| `C-c b b` / `C-x b` | `consult-buffer` | Switch active buffer with preview |
| `C-c b k` / `C-x k` | `kill-current-buffer` | Kill the current buffer |
| `C-c b r` | `revert-buffer` | Reload current buffer from disk |

---

## Search & Navigation (`C-c s`)

| Key | Command | Description |
|---|---|---|
| `C-c s s` | `consult-line` | Interactive buffer line search |
| `C-c s p` | `consult-ripgrep` | Ripgrep search across current project |
| `C-c s i` | `consult-imenu` | Jump to classes, methods, and functions in current buffer |
| `M-.` | `xref-find-definitions` | Jump to definition |
| `M-?` | `xref-find-references` | Find all references across project |
| `M-,` | `xref-go-back` | Go back to previous location |
| `C-M-.` | `lsp-workspace-symbol` | Search workspace symbols |

---

## Debugging (`C-c d`)

| Key | Command | Description |
|---|---|---|
| `C-c d d` | `dap-debug` | Start a new debug session |
| `C-c d D` | `dap-debug-last` | Restart the last debug session |
| `C-c d b` | `dap-breakpoint-toggle` | Toggle breakpoint on current line |
| `C-c d B` | `dap-breakpoint-condition` | Set a conditional breakpoint |
| `C-c d L` | `dap-breakpoint-log-message` | Set a log point |
| `C-c d n` | `hellmacs-debug-next` | Step over (repeatable with `n`) |
| `C-c d i` | `hellmacs-debug-step-in` | Step in (repeatable with `i`) |
| `C-c d o` | `hellmacs-debug-step-out` | Step out (repeatable with `o`) |
| `C-c d c` | `hellmacs-debug-continue` | Continue execution (repeatable with `c`) |
| `C-c d e` | `dap-eval` | Evaluate expression at point |
| `C-c d E` | `dap-eval-expression` | Prompt to evaluate an expression |
| `C-c d t` | `hellmacs-debug-test-at-point` | Debug the unit test at point |
| `C-c d T` | `hellmacs-debug-test-class` | Debug the whole test class |
| `C-c d q` | `dap-disconnect` | Disconnect debug session |

---

## Run Configurations (`C-c r`)
With `:tools run`. Configurations come from `.hellmacs/run.eld`, IntelliJ's `.run/*.run.xml` and Eclipse `.launch` files (see the JVM guide).

| Key | Command | Description |
|---|---|---|
| `C-c r r` | `hellmacs-run` | Run a configuration (with completion) |
| `C-c r d` | `hellmacs-run-debug` | Debug a configuration |
| `C-c r l` | `hellmacs-run-last` | Run the last one again, the same way |

---

## Test Results & Coverage (`C-c t`)
With `:tools test`. Results come from the build's JUnit XML reports, and coverage from JaCoCo's XML report (see the JVM guide).

| Key | Command | Description |
|---|---|---|
| `C-c t t` | `hellmacs-test-results` | Show the test results (`*hellmacs-tests*`) |
| `C-c t f` | `hellmacs-test-results-rerun-failures` | Rerun the failing tests |
| `C-c t c` | `hellmacs-coverage-run` | Run the tests with coverage, then mark it |
| `C-c t s` | `hellmacs-coverage-show` | Show coverage marks |
| `C-c t h` | `hellmacs-coverage-hide` | Hide coverage marks |

In `*hellmacs-tests*`: `RET` jump to the test, `r` rerun it, `f` rerun failures, `g` refresh, `c` coverage per file.

---

## Language Server & Refactoring (`C-c l`)

| Key | Command | Description |
|---|---|---|
| `C-c l a a` | `lsp-execute-code-action` | Open code action menu (quick fixes) |
| `C-c l r r` | `lsp-rename` | Semantic rename symbol across project |
| `C-c l r o` | `lsp-organize-imports` | Organize and clean imports |
| `C-c l = =` | `lsp-format-buffer` | Format buffer |
| `C-c l j ...` | — | Java specific helpers (build, generate methods, extract) |
| `C-c l k ...` | — | Kotlin specific helpers (build, test) |

---

## Git & Version Control (`magit`)

| Key | Command | Description |
|---|---|---|
| `C-x g` | `magit-status` | Open Magit status buffer |
| `C-x M-g` | `magit-dispatch` | Open Magit command popup |
| `C-c M-g` | `magit-file-dispatch` | File actions (blame, history, diff) |

---

## Window Management (`C-c w`) & Quit (`C-c q`)

| Key | Command | Description |
|---|---|---|
| `C-c w /` / `C-x 3` | `split-window-right` | Split window vertically |
| `C-c w -` / `C-x 2` | `split-window-below` | Split window horizontally |
| `C-c w d` / `C-x 0` | `delete-window` | Close current window |
| `C-c w o` / `C-x 1` | `delete-other-windows` | Maximize current window |
| `C-c q q` / `C-x C-c` | `save-buffers-kill-terminal` | Prompt to save and quit Emacs |
