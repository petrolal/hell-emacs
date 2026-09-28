# Work Order & Progress Checklist

> **IMPORTANT**: This is the order in which AI agents pick up roadmap work.
> Take the first unchecked item in the lowest-numbered step, unless the user
> asks for something else. Keep this file current as you work (see the rules
> below).

The order comes from "Sequencing toward the objective" in
[`docs/roadmap.md`](../../roadmap.md). The full spec for each item (scope,
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

- [ ] 12.4 Run configurations: `:tools run`
- [ ] 12.4 Spring Boot language server (`:lang java +spring`)
- [ ] 12.4 Profiles and actuator
- [ ] 12.5 A test results view (JUnit XML)
- [ ] 12.5 Coverage
- [ ] 12.5 Continuous testing (`+watch`, optional)

## Step 7: Phase 10.1 project file types, 10.2 with 12.8's formatter work (roadmap "10.1", "10.2", "12.8")

- [ ] 10.1 Findings first: which servers ship native binaries, and their pins
- [ ] 10.1 `:lang data` (XML)
- [ ] 10.1 `:lang yaml`
- [ ] 10.1 `:lang json`
- [ ] 10.1 `:lang markdown`
- [ ] 10.1 `:lang sh`
- [ ] 10.1 `:lang docker`
- [ ] 10.2 `:editor format`: apheleia with google-java-format, ktfmt, cljfmt
- [ ] 10.2 Formatter jars pinned by SHA-256 from Maven Central
- [ ] 10.2 Keys: remap only, no new bindings
- [ ] 12.8 Formatting shared with IDE users (Eclipse/IntelliJ style import)

## Step 8: 12.6 Enterprise tool belt, 10.3, 10.4 (roadmap "12.6", "10.3", "10.4")

- [ ] 12.6 `:tools http`: IntelliJ `.http` files
- [ ] 12.6 `:tools db`: database client over JDBC
- [ ] 12.6 `:tools docker` and `:tools kubernetes`
- [ ] 12.6 `:checkers static`
- [ ] 10.3 `:ui popup`
- [ ] 10.3 `:ui vc-gutter`
- [ ] 10.3 `:ui hl-todo`
- [ ] 10.3 `:tools editorconfig`
- [ ] 10.4 `:editor snippets` (tempel)
- [ ] 10.4 `:editor file-templates` (`auto-insert-mode`)

## Step 9: 12.7 Scale, 12.9 Security and compliance, 12.10 Documentation (roadmap "12.7", "12.9", "12.10")

- [ ] 12.7 Reference monorepo for measurements
- [ ] 12.7 Budgets measured weekly in CI
- [ ] 12.7 Tuning justified by the measurements
- [ ] 12.7 Kotlin's server: track JetBrains' Kotlin LSP
- [ ] 12.9 SBOM: `bin/hellmacs sbom` (CycloneDX)
- [ ] 12.9 License report: `bin/hellmacs licenses`
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
