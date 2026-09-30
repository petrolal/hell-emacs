# Vision, Business Rules & Operational Invariants

This document outlines the core product vision, target audience, architectural invariants, and operational guidelines for **Hellmacs** — serving both human contributors and AI coding agents.

---

## 1. Product Vision & Target Audience

Hellmacs is an **enterprise-grade Emacs distribution designed specifically for the JVM ecosystem** (Java, Kotlin, Clojure, Scala, Groovy).

### The Problem It Solves
Monolithic modern IDEs (IntelliJ IDEA Ultimate, Eclipse, VS Code with heavy extension packs) suffer from:
* High idle resource consumption (several gigabytes of RAM).
* Slow startup times and UI freezes during indexing.
* Frequent modal disruptions and visual bloat.
* Fragmented configurations across team members.

### The Core Thesis: Purist GNU Emacs DNA + Modern Enterprise Horsepower
Modern distributions (Doom Emacs, Spacemacs) assumed modernizing Emacs required converting it into a **modal Vim/Evil clone** with spacebar leaders (`SPC f f`).

While appealing to Vim switchers, this creates friction for:
1. **The 40-Year Emacs Veteran**: Senior engineers and architects who have used GNU Emacs for decades have deep muscle memory built on `C-x`, `C-c`, `M-x`, `C-s`, `M-f`, `C-y`, buffers, `dired`, `compile`, and Info manuals. Forcing modal editing breaks their flow.
2. **The Enterprise JVM Reality**: Vanilla GNU Emacs out-of-the-box requires extensive, brittle Elisp configuration to support Eclipse JDTLS, Lombok, DAP debugging, Hot Code Replacement, multi-module Maven/Gradle builds, and GC tuning.

**Hellmacs fills this exact void:**
* **100% Respect for Classic Emacs Reflexes**: Standard GNU keybindings are sacred. No modal editing by default. Custom features live strictly under `C-c`.
* **Zero-Compromise Enterprise Power**: Parity with IntelliJ IDEA Ultimate and Eclipse on daily JVM development (Spring Boot, Java 21+, Kotlin, Clojure, Maven, Gradle, DAP debugging, Hot Code Replacement).
* **Instant Startup**: Starts in **~0.05 seconds** with low-pause GC tuning.

---

## 2. Inviolable Business Rules & Architectural Invariants

When developing features, extending modules, or writing code for Hellmacs:

```
+-------------------------------------------------------------------------+
|                         HELLMACS INVARIANTS                             |
+------------------------------------+------------------------------------+
| 1. Stock Emacs Reflexes            | 5. Offline & Corporate Resilience  |
|    - Default keys unchanged        |    - Full proxy, CA, mirror support|
|    - No Evil/modal emulation       |    - Zero-network offline bundles  |
+------------------------------------+------------------------------------+
| 2. JVM-First Priority              | 6. Clean XDG Isolation             |
|    - Java is reference target      |    - Zero home-directory pollution |
|    - Kotlin/Clojure follow pattern |    - State/Cache/Data separation   |
+------------------------------------+------------------------------------+
| 3. Built-ins First                 | 7. Zero Telemetry & Privacy        |
|    - project.el, treesit, compile  |    - No telemetry or tracking      |
|    - Minimal external dependencies |    - Reproducible lockfiles        |
+------------------------------------+------------------------------------+
| 4. Sub-0.12s Startup Budget        | 8. Strict Test-Driven Development  |
|    - Compiled static profiles      |    - Failing ERT tests first (RED) |
|    - Deferred / lazy evaluation    |    - Direct verification (GREEN)   |
+------------------------------------+------------------------------------+
```

### Key Directives for Contributors & AI Agents
1. **The 40-Year Purist Guarantee**:
   * All keybinding proposals and bindings MUST use standard GNU Emacs conventions (`C-c`, `C-x`, `M-x`, `M-.`, `C-s`, `dired`).
   * Never introduce Vim/Evil modal states or single-letter key hijackings.
   * Hellmacs leader shortcuts belong strictly under `C-c` (`C-c h`, `C-c f`, `C-c b`, `C-c s`, `C-c d`, `C-c l`, `C-c w`, `C-c q`, `C-c r`).
2. **Preserve Vanilla Discoverability**:
   * Built-in GNU Emacs help mechanisms (`C-h t`, `C-h i`, `C-h f`, `C-h v`, `C-h k`) must remain unhindered.
3. **Preserve XDG Directory Isolation**:
   * Never hardcode `~/.emacs.d` or write state to `$HOME`.
   * Use `hellmacs-state-file`, `hellmacs-cache-dir`, and `hellmacs-data-dir`.
4. **Package Declarations**:
   * Declare package dependencies via `(package! <name>)` in `packages.el` managed by `bin/hellmacs sync` / Elpaca.
5. **Strict Test-Driven Development (TDD)**:
   * Write failing ERT unit and integration tests *before* writing production code (RED).
   * Assert directly against target APIs and behaviors without self-mocking in test bodies.
   * Implement minimal code to satisfy tests (GREEN), refactor, and verify with `bin/hellmacs test`.
6. **Work Order & Roadmap Progress**:
   * Pick up work in order of [`work-order.md`](work-order.md) and update checkboxes in both `work-order.md` and `docs/roadmap.md`.
7. **Respect the Doom v3 Layout** (Phase 16, [`architecture.md`](architecture.md) §2):
   * Engine code goes in `lisp/`; library parts in `lisp/lib/` and CLI parts in `lisp/cli/`, loaded with `hellmacs-require`, never put on `load-path`.
   * What every configuration gets and that is user-facing or package-backed goes in core's own module, `modules/hellmacs/`; every other feature is a module in `sources/hellmacs+/modules/<group>/<name>/`, with a `.hellmacsmodule`.
   * A new `bin/hellmacs` command is a new `bin/hellmacs-COMMAND` file. There is no root `init.el`: `sync` generates each profile's init file (`lisp/hellmacs-profiles.el`), and that file is the startup sequence, as in Doom.

---

## 3. Real-World Enterprise Use Cases

### Use Case 1: Corporate Monorepo / Multi-Module Builds
* **Scenario**: Banking application with 40+ Gradle/Maven sub-modules, internal BOMs, and custom build scripts.
* **Hellmacs**: Eclipse JDTLS automatically maps the project hierarchy. Builds execute via `C-x p c`, capturing compiler errors and test failures with clickable navigation links (`M-g n` / `M-g p`).

### Use Case 2: Multi-JDK Environments (Legacy Java 8/11 + Modern Java 21+)
* **Scenario**: Developer maintains legacy services on Java 8/11 while creating new services on Java 21.
* **Hellmacs**: JDTLS runs on Java 21 while targeting project-specific JVM runtimes and toolchains configured in `.envrc` or `hellmacs-jdks`.

### Use Case 3: Restricted Corporate Network (Proxy + Root CA + Artifactory)
* **Scenario**: Corporate network blocks public internet, requiring HTTP/HTTPS proxies, custom root CAs, and internal artifact mirrors.
* **Hellmacs**: Configured via `hellmacs-proxy`, `hellmacs-ca-bundle`, and `hellmacs-mirrors`. Offline bundles (`bin/hellmacs bundle` / `install --from-bundle`) support air-gapped environments.

### Use Case 4: Fast Feedback Loop with Hot Code Replacement
* **Scenario**: Debugging a Spring Boot microservice where application restart takes 45 seconds.
* **Hellmacs**: Attach debugger (`C-c d d`), edit code, and press `C-c h r` (Crucible) to immediately hot-swap modified bytecode into the running JVM.
