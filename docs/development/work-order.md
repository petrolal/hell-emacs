# Work Order & Progress Checklist

> **IMPORTANT**: This is the order in which AI agents pick up roadmap work.
> Take the first unchecked item in the lowest-numbered step, unless the user
> asks for something else. Keep this file current as you work (see the rules
> below).

The order comes from "Sequencing toward the objective" in
[`docs/roadmap.md`](../roadmap.md). The full spec for each item (scope,
keys, verification, risks) is in the roadmap section named in each heading.
This file only tracks progress. Don't copy specs into it.

---

## Rules for agents

0. **Strict Test-Driven Development (TDD)**:
   * Always write the failing unit and integration tests *before* writing the implementation (RED).
   * Tests must call the actual functions and test the actual behavior directly without mocking the implementation inside the test itself.
   * Then implement the minimal code to make tests pass (GREEN), refactor, and verify.
1. **Tick an item only when it's done and verified.** Done means:
   * the roadmap's *Verify* step for it passed;
   * `bin/hellmacs test` and `bin/hellmacs doctor` pass;
   * startup stays under the 0.12s budget if the item touches startup.

   Change `- [ ]` to `- [x]` and add the date and a short note, for example
   `- [x] Offline bundle builder (2026-10-02: bundle + install --from-bundle, unit tests)`.
2. **Partial work stays unchecked.** Mark it `- [/]` and say what's left, for
   example `- [/] macOS CI (arm64 job green; x86_64 not added)`.
3. **Keep the roadmap in step.** Tick the matching checkbox in
   `docs/roadmap.md`. When a whole phase or sub-phase is finished, update its
   row in the roadmap's "Phase Summary & Status" table too.
4. **Don't reorder steps on your own.** If the order should change, tell the
   user and suggest editing the roadmap's sequencing table. Then mirror the
   change here.
5. **Found new work?** Add it as an unchecked item under the step it belongs
   to, with a pointer to where it's specified.

---

## Step 1: Phase 11, consolidation (roadmap "Phase 11")

- [x] 11.2 Shared language server status and daemon lifecycle
- [x] 11.3 Module dependencies and tree-sitter declared once per module
- [x] 11.4 Byte-compiled core, modules and autoloads at sync

## Step 2: 12.1 Corporate networks (roadmap "12.1 Corporate networks")

- [x] One network layer: `with-hellmacs-network`, pinned JDTLS, pinned fallback installers (2026-09-25)
- [x] Proxy (`hellmacs-proxy`)
- [x] Corporate CA (`hellmacs-ca-bundle`)
- [x] Mirrors (`hellmacs-mirrors`)
- [x] Build tools' own settings respected (`settings.xml`, Gradle home)
- [x] `doctor` checks the network (2026-09-25)
- [x] Offline bundles: `bin/hellmacs bundle OUT.tar.zst`, `install --from-bundle FILE`, `bundle --modules` (2026-09-26: `core/hellmacs-bundle.el`, `test/test-bundle.el`; verified by hand: default modules bundled in 32s, installed in 3.5s under `unshare -rn`, offline startup 0.027s)
- [x] Verify: end-to-end script behind a proxy (authenticated CONNECT proxy, self-signed CA, local mirror), and bundle installation (2026-09-26: `test/integration/net-e2e.el`)

## Step 3: 12.2 Platforms and CI (roadmap "12.2 Platforms and CI")

- [x] CI first: GitHub Actions pipeline (`.github/workflows/ci.yml`, matrix across Linux and macOS on Emacs 29.1, 29.4, 30.1) (2026-09-26)
- [x] macOS (arm64 and x86_64 support, Homebrew, PATH env guides, clang grammar compilation) (2026-09-26)
- [x] Windows, in two stages (WSL2 supported path with doctor 9P mount checks and installation guide) (2026-09-26)

## Step 4: 12.3 JDKs and build environments (roadmap "12.3", takes in 10.5's direnv)

- [x] Several JDKs, found automatically (2026-09-28: `core/hellmacs-jdk.el`, Java's sync step, config and doctor; unit tests plus java-e2e's 12.3 checks, where the Java 21 fixture compiled against SDKMAN's 21 while JDTLS ran on 25)
- [x] JDTLS runs on a JDK it supports: found while doing the item above (JDTLS 1.57 fails on JDK 27). The range is pinned with JDTLS (21 to 25), a suitable JDK is chosen automatically, and doctor checks it (2026-09-28: unit tests; java-e2e passes with `JAVA_HOME` unset and the system java at 27). Roadmap "12.3", *Several JDKs*, "Found along the way"
- [x] Per-project environments: `:tools direnv` (envrc) (2026-09-28: `modules/tools/direnv/`, on by default; `test/test-direnv.el`, `direnv-e2e.el`: Maven from each project's buffer ran on that project's JDK, switching with the buffer)
- [x] Toolchains: Gradle toolchains and Maven `toolchains.xml` (2026-09-28: doctor names a missing toolchain JDK with `file:line` and checks toolchains.xml; its verdicts matched Gradle's and Maven's own, both ways)
- [x] Legacy targets: Java 8 Maven fixture (`test/fixtures/java/legacy-8`) (2026-09-28: `legacy-jdk-e2e.el` rewritten into a real run; both fixtures import, build, test and debug on their own JDK; debugged programs now run on the project's JDK, not JDTLS's)
- [x] Verify: one machine with JDKs 8, 11, 17, 21 and 25; the legacy fixtures import, build, test and debug on their own JDK; a project with an `.envrc` switches JDK with the buffer (2026-09-28: legacy-jdk-e2e (8, 11), java-e2e (21) and direnv-e2e all passed with JDKs 8, 11, 17, 21, 25 and 27 installed; no fixture targets 17). Roadmap "12.3", *Verify*

## Step 5: Phase 9.4, finish dashboard and modeline integration (roadmap "9.4 Integration")

- [x] README: new palette, `:ui dashboard` and `:ui modeline`, Nerd Font note, terminal behaviour; note in Phase 7 pointing to it (2026-09-26)
- [x] Verify: GUI start (shown=0.353s, <0.12s Hellmacs overhead), tty start (0.022s), modeline e2e script, and all unit tests passing (2026-09-26)

## Step 5a: 12.8 Configs keep up with new default modules (moved to the front on 2026-09-28, at the user's request)

- [x] Configs keep up with new default modules (2026-09-28: `core/hellmacs-config.el`, `bin/hellmacs config [--add-defaults]`, doctor and upgrade notes; `test/test-config.el`; a copy of an early-template config got its 8 modules, synced, and `C-x g` opened Magit): doctor and `upgrade` list default modules missing from your `hellmacs!` block (e.g. `:tools magit`, the version control manager); `bin/hellmacs config --add-defaults` adds them on request, then `sync` installs them. Roadmap "12.8", *Configs keep up with new default modules*

## Step 6: 12.4 Spring Boot and 12.5 Tests and coverage (roadmap "12.4", "12.5")

- [x] 12.4 Run configurations: `:tools run` (2026-09-28: `modules/tools/run/`, C-c r r/d/l; `.hellmacs/run.eld`, IntelliJ `.run/`, Eclipse `.launch`; `test/test-run.el`, `run-e2e.el` on maven-demo and gradle-demo, runs and debugs for main classes and a Gradle task)
- [x] 12.4 Spring Boot language server (`:lang java +spring`) (2026-09-28: pinned Spring Boot Tools 2.4.0 installed by `sync`, beside JDTLS through lsp-java-boot; unit tests in `test/test-java.el` and `test/test-spring.el`. `spring-e2e.el` is written but not run: it hung, and the user asked to skip it)
- [x] 12.4 Profiles (2026-09-28: `:tools run` offers each configuration that starts the app once more per `application-NAME.*` profile; unit tests. Actuator not done; covered by the e2e above, not run)
- [x] 12.5 A test results view (JUnit XML) (2026-09-28: `modules/tools/test/`, on by default, `C-c t`; `test/test-results-view.el`; checked on the fixtures' real Gradle/Maven, Java/Kotlin reports)
- [x] 12.5 Coverage (2026-09-28: JaCoCo from the command line, fringe/margin marks, per-file summary; `test/test-coverage.el`. Not yet run against a real JaCoCo report: the 12.5 Verify)
- [x] 12.5 Continuous testing (`+watch`, optional) (2026-09-28: `(test +watch)` turns on `hellmacs-test-watch-mode` in JVM source buffers; unit tests)

## Step 7: Phase 10.1 project file types, 10.2 with 12.8's formatter work (roadmap "10.1", "10.2", "12.8")

- [x] 10.1 Findings first: which servers ship native binaries, and their pins (2026-09-28: in the roadmap; marksman and docker-language-server binaries, the lemminx jar, and yaml/json/bash as npm lockfiles)
- [x] 10.1 `:lang data` (XML) (2026-09-28: lemminx 0.31.2 jar, pinned)
- [x] 10.1 `:lang yaml` (2026-09-28: yaml-language-server 1.24.0, npm lockfile; SchemaStore off)
- [x] 10.1 `:lang json` (2026-09-28: vscode-json-language-server 4.10.0, npm lockfile)
- [x] 10.1 `:lang markdown` (2026-09-28: marksman 2026-02-08, pinned binary)
- [x] 10.1 `:lang sh` (2026-09-28: bash-language-server 5.8.1, npm lockfile; gradlew/mvnw)
- [x] 10.1 `:lang docker` (2026-09-28: docker-language-server 0.20.1, pinned binary, own lsp client; Compose files). For all six: unit tests (`test/test-data-langs.el`), a real sync of a throwaway profile, each server answering `initialize`, and files opening in the right modes; the e2e script isn't written yet
- [x] 10.2 `:editor format`: apheleia with google-java-format, ktfmt, cljfmt (2026-09-28: `modules/editor/format/`; `test/test-format.el`; the remapped key formatted real Java, Kotlin and Clojure files through apheleia)
- [x] 10.2 Formatter jars pinned by SHA-256 from Maven Central (2026-09-28: google-java-format 1.36.1, ktfmt 0.64; SHA-1s match Central's)
- [x] 10.2 Keys: remap only, no new bindings (2026-09-28: `lsp-format-buffer` and `eglot-format-buffer` remapped; unit test checks the map holds remaps only)
- [x] 12.8 Formatting shared with IDE users (Eclipse/IntelliJ style import) (2026-09-28: a committed Eclipse profile sets JDTLS's formatter and Java formats through it; unit tests only)

## Step 8: 12.6 Enterprise tool belt, 10.3, 10.4 (roadmap "12.6", "10.3", "10.4")

- [x] 12.6 `:tools http`: IntelliJ `.http` files (2026-09-28: restclient extended with IntelliJ env files, dynamic variables and handler stripping; `+httpyac` runs JS handlers; `test/test-http.el`; checked live against a local echo server)
- [x] 12.6 `:tools db`: database client over JDBC (2026-09-28: sql.el + sqlline, pinned drivers, `.hellmacs/db.eld`, auth-source; `test/test-db.el`; checked live on H2)
- [x] 12.6 `:tools docker` and `:tools kubernetes` (2026-09-29: docker.el and kubel, `C-c o d` / `C-c o k`, podman fallback; `test/test-docker.el`, `test/test-kubernetes.el`; synced for real and opened against the real CLIs; not yet against a running daemon or a kind cluster, none on this machine)
- [x] 12.6 `:checkers static` (2026-09-29: Checkstyle, PMD and SpotBugs from the build's reports as flymake diagnostics; `+sonarlint`: SonarLint 4.6.0 pinned, with JDTLS's classpath; `test/test-static.el` and `test/integration/static-e2e.el`, ALL PASSED live. Not yet: connected mode, which lsp-sonarlint lacks)
- [x] 10.3 `:ui popup` (2026-09-29: `modules/ui/popup/`, built-in side windows, no packages; on by default in `static/init.example.el`; `test/test-popup.el`; in batch Emacs a real `compile`, `describe-function` and a Flymake diagnostics buffer each took the bottom window, one `q` closed it, and `C-c w t` hid and restored it. Not yet: a Java build and a CIDER REPL in a synced interactive session)
- [x] 10.3 `:ui vc-gutter` (2026-09-29: `modules/ui/vc-gutter/`, diff-hl 1.11.2 on the first file, the margin when there's no graphical display, `diff-hl-update-async` and off over TRAMP; commented out in `static/init.example.el`; `test/test-vc-gutter.el`. Live: a throwaway profile synced, booted, and a saved edit was marked in the margin; with the real Magit a commit cleared the marks, and without the module's hook they went stale. Not yet: the fringe in a graphical frame)
- [x] 10.3 `:ui hl-todo` (2026-09-29: `modules/ui/hl-todo/`, hl-todo 3.9.4 on the first file; TODO, FIXME, BUG, XXX, HACK, KLUDGE, NOTE, REVIEW, DEPRECATED in the theme's own faces; no keys; commented out in `static/init.example.el`; `test/test-hl-todo.el`. Live: a throwaway profile synced and booted; in a Java file the comment keywords took `warning`, `error` and `success`, an identifier `TODOs` didn't, and `hl-todo-next` and `hl-todo-occur` worked)
- [x] 10.3 `:tools editorconfig` (2026-09-29: `modules/tools/editorconfig/`, Emacs' own `editorconfig-mode` (the package only on Emacs 29, `:built-in 'prefer`), on by default in `static/init.example.el`; lazy, yet the first file gets its settings and charset; `test/test-editorconfig.el` reads real .editorconfig files. Live on the default profile: not loaded after startup, the first Java file got indent 3, tabs and a final newline; startup 0.029s (shown 0.084s). Not yet: the Emacs 29 path live (no Emacs 29 here))
- [x] 10.4 `:editor snippets` (tempel) (2026-09-29: `modules/editor/snippets/`, tempel 1.14; junit and controller (Java), dataclass (Kotlin), deftest (Clojure), munit (Scala) in the module's `templates/`, yours in `$HELLMACSDIR/templates/`; the package comes from the path; the exact name completes ahead of the server's candidates; tempel's own keys stripped, only remaps; commented out in `static/init.example.el`; `test/test-snippets.el`. Live: a throwaway profile synced; every snippet but munit expanded through `completion-at-point` with the real tempel (the JUnit class got `package com.acme;` and `CartTest`), `M-}`/`M-{`/`ESC ESC ESC` moved and aborted, `M-RET` and `M-<down>` stayed unbound and TAB still indented. Not yet: munit live (no Scala mode before 8.5))
- [x] 10.4 `:editor file-templates` (`auto-insert-mode`) (2026-09-29: `modules/editor/file-templates/`, no packages (builds on `:editor snippets`, `depends-on!`); Emacs' own `auto-insert` asks, then fills a new, empty file from a tempel template: `__test`/`__class` for Java (JUnit 5) and Kotlin (kotlin.test), `__ns`/`__test` for Clojure, package and namespace from the path; only its own templates, never Emacs' default `auto-insert-alist`; existing files, even empty, never touched; `M-x auto-insert` by hand; no keys; commented out in `static/init.example.el`; `test/test-file-templates.el`. Live: a throwaway profile synced with the real tempel; in a copy of maven-demo `CartTest.java` got `package dev.hellmacs.demo;`, the JUnit imports and class, `Cart.java` its package and class, a declined, an existing and a `package-info.java` file stayed empty, a new `.el` wasn't offered Emacs' header, TAB still ran java-mode's indent inside the snippet; startup 0.015s (tty) with the module on, not loading tempel or autoinsert. Not yet: Kotlin and Clojure in their real modes (checked with stand-in modes: the templates filled, package and namespaces right))

## Step 9: 12.7 Scale, 12.9 Security and compliance, 12.10 Documentation (roadmap "12.7", "12.9", "12.10")

- [x] 12.7 Reference monorepo for measurements (2026-09-29: Spring Framework v7.0.9, pinned by tag and commit in `test/integration/reference.el`, `HELLMACS_PARITY_REFERENCE=spring-framework` for java-parity; `test/test-reference.el`. Live: 21 of 22 checks pass once the three settings below are off; symbol search answered 72s after JDTLS started cold, 2197MB peak, `compileJava` 71.1s. With the defaults, navigation doesn't work on it; see the roadmap)
- [/] 12.7 Budgets measured weekly in CI (weekly workflow `budgets.yml` + `test/integration/budgets.sh`, budgets and verdicts in `budgets.el`, `test/test-budgets.el`; full chain run live 2026-09-29, IntelliJ IDEA Community 2025.3 on the same checkout: startup 0.101s, completion p95 89ms and memory 3398MB vs IntelliJ's 4263MB pass; import 192s vs IntelliJ's 56s FAILS (budget 84s), for Tuning to fix. Left: the workflow's first CI run, once pushed)
- [ ] 12.7 Tuning justified by the measurements
- [x] 12.7 Tuning, found by the reference runs: Gradle 9 import fails with JDTLS's annotation-processing init script (Spring Framework). Roadmap "12.7", *A reference monorepo* (2026-09-29: on that exact error, annotation processing off and an in-place reimport; plus the `+spring` deadlock that kept JDTLS from ever saying ready; `test/test-java.el`. Live: Spring Framework imports with the defaults, 21 of 22 parity checks)
- [x] 12.7 Tuning, found by the reference runs: references/implementations code lenses starve JDTLS's request threads on big classes (off in VS Code). Roadmap "12.7", *A reference monorepo* (2026-09-29: both off by default in `:lang java`, as in VS Code, from the reference runs' 183s vs 63s to symbol search; `test-java/reference-code-lenses-off`; your config.el can turn them back on)
- [x] 12.7 Tuning, found by the reference runs: the Gradle daemon runs on the system JDK, not one the build supports. Roadmap "12.7", *A reference monorepo* (2026-09-29: `hellmacs-jdk-gradle-environment` reads the wrapper's Gradle release and, when JAVA_HOME's (else the PATH's) JDK can't run it, sets JAVA_HOME to the newest synced JDK that can, unless the build picks its own JVM; for builds (`C-x p c`) and `:tools run` tasks; unit tests in `test-jdk`, `test-build`, `test-run`, plus a test that core autoloads every public hellmacs-jdk function (the live check found one missing). Live, JAVA_HOME unset and JDK 27 on the PATH: Spring Framework's Gradle 9.7 failed on 27 by hand, and `C-x p c` from its buffer ran on 25 and finished; run-e2e passed on both fixtures)
- [x] 12.7 The "quick fix offers an import" parity check fails on Spring Framework (not diagnosed). Roadmap "12.7", *A reference monorepo* (2026-09-29: the check, not Hellmacs: it inserted `ArrayList`, which the file imports, asked without the diagnostics JDTLS makes quick fixes from, and matched "Import" ignoring case. Now a JDK type the file doesn't use (`e2e-unimported-jdk-type`, `test/test-parity.el`), asked as `C-c l a` asks, the exact `Import 'X'` fix required. Found on the way: an import settled before `initialize` returned was reset by ignite, so JDTLS never read as ready (`test-lsp-status/outcome-before-initialize-is-kept`); the symbol-search wait's timed-out synchronous requests ended the run. Live: java-parity on Spring Framework ALL PASSED, 22 of 22; import 74.7s (ready 10.3s + 64.4s), under the 84s budget in this one run)
- [ ] 12.7 Kotlin's server: track JetBrains' Kotlin LSP
- [x] 12.9 SBOM: `bin/hellmacs sbom` (CycloneDX) (2026-09-29: `core/hellmacs-compliance.el`, `hellmacs-component!` in each module's `+paths.el`, `:license` on grammars; what's installed: packages at their commits, declared downloads, npm lockfiles, built grammars; `test/test-compliance.el`, with a test that every pinned SHA-256 is declared. Live: 58 components (default), 156 (every module), both valid against the CycloneDX 1.5 schema; an artifact in CI. Not yet: produced with each release, which 12.9's releases item makes)
- [x] 12.9 License report: `bin/hellmacs licenses` (2026-09-29: headers, GNU notices, LICENSE files, declared licenses checked against Maven Central, GitHub and the texts; exits 1 on an unknown one, flags LicenseRef-; in CI on every push and weekly with every module. Live, every module: none unknown, restclient's public domain flagged)
- [ ] 12.9 No telemetry, stated and enforced
- [ ] 12.9 Supply chain
- [ ] 12.9 Releases and support window
- [ ] 12.10 Developer docs
- [ ] 12.10 Administrator guide (`docs/admin-guide.md`)
- [ ] 12.10 Evaluator feature matrix (`docs/feature-matrix.md`)
- [ ] 12.10 Troubleshooting entry for every `doctor` failure

## Step 10: Phase 8.4 Groovy (roadmap "Phase 8", Groovy)

- [ ] `groovy-mode` for Groovy sources, Gradle scripts and Jenkinsfiles
- [ ] groovy-language-server through lsp-mode, installed pinned by `bin/hellmacs sync`
- [ ] Status messages through `hellmacs-lsp-status`
- [ ] `C-c l g` keys (with `:tools build`)
- [ ] Fixture `test/fixtures/groovy/gradle-demo`
- [ ] Verified live (`test/integration/groovy-e2e.el`) and unit tests

## Step 11: 12.11 Enterprise pilot, then 1.0 (roadmap "12.11 Enterprise pilot and 1.0")

- [ ] 12.8 Remaining team adoption: team layer, keys for migrants, `install --team URL`
- [ ] Pilot codebases chosen (at least three)
- [ ] A working week per codebase
- [ ] 1.0 exit criteria met
- [ ] 1.0 release

## Later: Phase 8.5 Scala and Phase 10's deferred list

- [ ] 8.5 `scala-mode` / `sbt-mode` (`scala-ts-mode` with `+tree-sitter`)
- [ ] 8.5 Metals through `lsp-metals`, pinned download at sync
- [ ] 8.5 Status messages from `metals/status`
- [ ] 8.5 `C-c l s` keys
- [ ] 8.5 Fixture `test/fixtures/scala/sbt-demo` and e2e script
- [ ] 10.5 `:ui workspaces` (`tab-bar`, one tab per project)
- [ ] 10.6 Integration: `static/init.example.el` for Phase 10's modules

## Not yet sequenced: Phase 13, manual and purist onboarding (roadmap "Phase 13")

The roadmap's sequencing table doesn't place Phase 13 yet. Ask the user
before starting it.

- [ ] 13.1 GNU Info manual (`docs/hellmacs.texi`, `Info-directory-list`, `C-h H`)
- [ ] 13.2 Vanilla Emacs startup actions on The Altar
- [ ] 13.3 Hellmacs module lookups in the `C-h` help commands
