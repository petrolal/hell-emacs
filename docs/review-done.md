# Code-Quality Review: Already Done

What the 2026-10-30 `/simplify` + altitude review found *and fixed*, across
`lisp/`, `bin/`, `modules/hell/`, `test/`, and (for the altitude pass)
`sources/hell+/modules/`. Everything below passed `make compile`, `make
test` (55/55) and `make checkdoc`. What's left for later is in
[review-todo.md](review-todo.md).

---

## `/simplify` pass (reuse, simplification, efficiency, altitude)

- **`lisp/lib/jdk.el`**: factored the "non-empty getenv, else default"
  idiom (duplicated 6×) into one `hell-jdk--getenv` helper.
- **`lisp/hell-lib.el`**: factored `hell-version-described` out of the
  `git describe` logic that `bin/hell-version`, `bin/hell-info` and
  `lisp/cli/compliance.el` each reimplemented separately.
- **`lisp/hell-plugins.el`**: replaced hand-parsing of a module's
  `.hellmodule` file with the existing `hell-module-metadata`, which
  already validates, evaluates `` ` `` forms, and caches reads.
- **`lisp/hell-modules.el`**: `hell-module-enable` now reads a module's
  `.hellmodule` once instead of walking the directory tree
  (`locate-dominating-file`) three times per module.
- **`lisp/hell-modules.el`**: factored `hell-module-enable`'s depth-fallback
  chain using a local `pick` helper instead of duplicated 4-level fallback forms.
- **`lisp/hell-modules.el`**: cached `hell-module-list` sorted orderings
  in `hell--module-list-cache`, invalidated when modules are enabled or cleared.
- **`lisp/hell-profiles.el` & `lisp/cli/sync.el`**: compute per-module autoload
  files once and thread `module-autoload-files` through `hell-sync--write-profile`,
  `hell-profile--generate-loaddefs-modules`, and `hell-profile--inputs`.
- **`lisp/cli/sync.el`**: compute `hell-profile--modules` once in `hell-sync--run`
  and pass it down to `hell-sync--finish` and `hell-sync--write-profile`.

## Altitude pass: core and `:tools` no longer name a language

Hell Emacs' architecture rule (`CLAUDE.md`) is that core and `:tools`
modules never hard-code a specific language or build tool; a `:lang`
module registers what it needs through a shared mechanism instead (the
pattern `hell-lsp-status-register` already set). Five places broke that
rule; all five are now fixed:

1. **JDK autoloads** (`lisp/hell-modules.el`). Replaced a hand-maintained
   list of 19 function names from `lisp/lib/jdk.el` with a generic scan of
   every `;;;###autoload` cookie in `lisp/lib/*.el` (the scanner,
   `hell-scan-autoloads`, moved into `lisp/hell-lib.el` so both core and
   `lisp/hell-profiles.el` share it). Core no longer names JDK functions
   at all.

2. **Build-root markers** (`lisp/hell-lib.el` +
   `sources/hell+/modules/lang/java/+paths.el`). `hell-build-files` and
   `hell-build-output-dirs` are now empty `defvar`s, populated by a new
   `hell-build-markers!` registration macro that `:lang java` calls with
   Gradle's and Maven's root files and output directories. Also fixed two
   latent staleness bugs this surfaced: `checkers/static`,
   `tools/run`, and `lang/java`'s own Spring-profile walker each
   snapshotted the list once at module-load time (`defconst`) instead of
   reading it live; converted to functions that read the (now mutable)
   variable each call.

3. **`hell-help`'s status hub** (`lisp/lib/help.el`). The hardcoded "JVM
   TOOLING & RUNTIME STATUS" section (checks naming Java/Kotlin/Clojure/
   Groovy/Gradle/Maven/kotlinc directly) is now a `hell-help-status-register`
   registry — the same shape as `hell-lsp-status-register`. Each of the
   four `:lang` modules (java, kotlin, clojure, groovy) registers its own
   rows next to the logic that actually knows the answer.

4. **IntelliJ/Eclipse keybinding table** (`lisp/lib/intellij.el`). Six rows
   (type hierarchy, extract method/variable/constant, generate
   getters/setters, implement methods) were Java-only commands
   (`lsp-java-*`) baked into the shared cheat-sheet table. Moved them into
   `lang/java/config.el` via a new `hell-intellij-register-actions`
   function, right next to the real `hell-localleader-def` bindings they
   document. Also fixed a pre-existing mismatch the move surfaced: the
   table claimed `C-c l i` ran `lsp-java-override-methods`; it's actually
   bound to `lsp-java-add-unimplemented-methods`.

5. **`bin/hell check`'s language table** (`lisp/lib/check-tools.el`, the
   biggest one — the file shrank from 775 to ~660 lines). The actual
   checker implementations (checkstyle+spotbugs, ktlint+detekt,
   kibit+clj-kondo, scalafmt+scalafix, npm-groovy-lint+codenarc — full
   process-invocation and output-parsing code) moved out of core into each
   owning `:lang` module's `cli.el`, registered with a new
   `hell-check-register-runner`. `hell-check-languages` stays in core as
   pure descriptive data (name + file extensions), since `--only java`
   has to work even without the java module enabled (a test,
   `hell-test-check-only`, depends on this) — but core no longer contains
   *how* to check any of them. Without a `:lang` module enabled, `bin/hell
   check` now reports "No `:lang` module registered a checker for X"
   instead of silently trying tools for a language you don't use. Also
   generalized the Gradle-wrapper dispatch (run `./gradlew check` instead
   of per-language native tools) via a `:gradle-managed` flag on each
   language entry, instead of hard-coding `java`/`kotlin`/`groovy-gradle`
   in two separate places. Created `sources/hell+/modules/lang/scala/cli.el`
   (didn't exist before). Renamed three previously "private"
   (double-dash) helpers — `hell-check-make-diag`,
   `hell-check-parse-standard-diagnostics`, `hell-check-run-tool` — to
   public names, since `:lang` modules now call them legitimately across
   the module boundary.

### Files touched

- `lisp/hell-lib.el`, `lisp/hell-modules.el`, `lisp/hell-profiles.el`,
  `lisp/lib/help.el`, `lisp/lib/intellij.el`, `lisp/lib/jdk.el`,
  `lisp/lib/check-tools.el`, `lisp/hell-plugins.el`
- `bin/hell-version`, `bin/hell-info`, `lisp/cli/compliance.el`, `lisp/cli/sync.el`
- `sources/hell+/modules/lang/java/{+paths,config,cli,autoload}.el`
- `sources/hell+/modules/lang/kotlin/{config,cli}.el`
- `sources/hell+/modules/lang/clojure/{config,cli}.el`
- `sources/hell+/modules/lang/groovy/{config,cli}.el`
- `sources/hell+/modules/lang/scala/cli.el` (new)
- `sources/hell+/modules/checkers/static/autoload.el`
- `sources/hell+/modules/tools/run/autoload.el`
- `test/hell-test.el`
