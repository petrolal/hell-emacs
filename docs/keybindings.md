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

## HTTP Requests (`.http` buffers)
With `:tools http`. These are the mode's own keys, active only in `.http` buffers.

| Key | Command | Description |
|---|---|---|
| `C-c C-c` | `hellmacs-http-send-request` | Send the request at point |
| `C-c C-e` | `hellmacs-http-select-environment` | Choose an environment (`http-client.env.json`) |
| `C-c M-e` | `hellmacs-http-reload-environment` | Reload the environment |
| `C-c C-l` | `hellmacs-http-run-request` | Run the request with httpyac (`+httpyac`) |
| `C-c C-a` | `hellmacs-http-run-file` | Run the file with httpyac (`+httpyac`) |

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

## Containers & Clusters (`C-c o`)
With `:tools docker` and `:tools kubernetes`, through your own `docker` (or `podman`) and `kubectl`, in their current context.

| Key | Command | Description |
|---|---|---|
| `C-c o d` | `docker` | docker.el's menu: containers, images, volumes, networks, Compose, contexts |
| `C-c o k` | `kubel` | kubel: pods and other resources, logs, port forwards, shells; `C` context, `n` namespace |

Inside their buffers the keys are docker.el's and kubel's own (`?` lists them).

---

## Snippets (`:editor snippets`)

Type a snippet's name (`junit`, `controller`, `dataclass`, `deftest`, `munit`) and complete it.

| Key | Command | Description |
|---|---|---|
| `C-M-i` | `completion-at-point` | Expand the snippet named at point (the corfu popup offers it too) |
| `M-x tempel-insert` | `tempel-insert` | Pick any snippet for the buffer from a list |
| `M-}` / `M-{` | `tempel-next` / `tempel-previous` | Next / previous field, inside a snippet (remaps of the paragraph keys) |
| `ESC ESC ESC` | `tempel-abort` | Take the snippet back out, inside a snippet |

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
| `C-x v [` / `C-x v ]` | `diff-hl-previous-hunk` / `diff-hl-next-hunk` | Previous / next changed hunk (`:ui vc-gutter`) |
| `C-x v *` | `diff-hl-show-hunk` | Show the hunk at point (`:ui vc-gutter`) |
| `C-x v n` | `diff-hl-revert-hunk` | Revert the hunk at point (`:ui vc-gutter`) |
| `C-x v S` | `diff-hl-stage-dwim` | Stage the hunk at point, or the region (`:ui vc-gutter`) |
| `C-x v =` | `diff-hl-diff-goto-hunk` | With `:ui vc-gutter`, `vc-diff` jumps to the hunk at point |

---

## Window Management (`C-c w`) & Quit (`C-c q`)

| Key | Command | Description |
|---|---|---|
| `C-c w /` / `C-x 3` | `split-window-right` | Split window vertically |
| `C-c w -` / `C-x 2` | `split-window-below` | Split window horizontally |
| `C-c w d` / `C-x 0` | `delete-window` | Close current window |
| `C-c w o` / `C-x 1` | `delete-other-windows` | Maximize current window |
| `C-c w t` | `window-toggle-side-windows` | Hide or bring back the bottom popup (`:ui popup`) |
| `C-c q q` / `C-x C-c` | `save-buffers-kill-terminal` | Prompt to save and quit Emacs |
