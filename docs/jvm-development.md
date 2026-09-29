# JVM Development Guide

Hellmacs is built first and foremost as a high-performance, enterprise-grade environment for the Java Virtual Machine ecosystem (Java, Kotlin, Clojure, Scala, Groovy).

---

## 1. Java Development (`:lang java`)

Java support is powered by **Eclipse JDTLS**, **LSP Mode**, **Tree-sitter**, and **DAP Mode**.

### Enabling Java
In `~/.config/hellmacs/init.el`:

```elisp
(hellmacs! :completion
           (corfu +tab)       ; In-buffer completion popups
           vertico            ; Minibuffer completion (Consult + Marginalia + Orderless)

           :tools
           build              ; Gradle / Maven build integration & test assertion links
           debugger           ; DAP debugger & Hot Code Replacement
           lsp                ; Language Server Protocol (lsp-mode)
           magit              ; Git interface

           :lang
           (java +lombok +tree-sitter)) ; Java module with Lombok agent and Tree-sitter
```

Run `bin/hellmacs sync` to download JDTLS, Lombok, the Java debug server, and compile tree-sitter grammars.

### First Launch & Project Import
When you open a `.java` file in a Maven or Gradle project:
1. `lsp-mode` asks to import the project root directory. Choose **Import** (saved automatically).
2. The echo area displays `[FORGE IGNITED]` while JDTLS starts up.
3. Once indexed, `[DAEMON READY]` appears, and the mode-line reports `JVM:ready`.

---

## 2. Completion & Minibuffer Search

Hellmacs provides a modern, fast completion stack using minimalist packages:

### In-Buffer Autocomplete (Corfu & Cape)
* **Automatic Popups**: As you type (after 2 characters and 0.15s delay), a floating child frame appears with completion candidates.
* **Documentation Hover (`corfu-popupinfo`)**: Displays Javadoc, method signatures, and markdown documentation next to the selected candidate.
* **TAB Completion**: With `(corfu +tab)` in `init.el`, `TAB` cycles through completions. `C-M-i` (`complete-at-point`) is always available.
* **Cape Fallback Extensions**: Fallback completion sources for file paths and open buffers.

### Minibuffer Completion (Vertico + Consult + Orderless)
* **Vertical Minibuffer**: Clean, vertical list UI for finding files, buffers, commands, and project symbols.
* **Orderless Matching**: Search with space-separated tokens in any order (e.g. `user contr test` matches `UserControllerTest.java`).
* **Marginalia Annotations**: Adds rich metadata to minibuffer lists (file sizes, docstrings, keybindings, timestamps).

| Key | Command | Description |
|---|---|---|
| `C-c f f` / `C-x C-f` | `find-file` | Open or find a file |
| `C-c f r` | `consult-recent-file` | Search recently opened files |
| `C-c b b` / `C-x b` | `consult-buffer` | Switch buffer with previews |
| `C-c s s` | `consult-line` | Interactive search for lines in current buffer |
| `C-c s p` / `C-c h f` | `consult-ripgrep` | Blazing-fast regex search across the entire project |
| `C-c s i` | `consult-imenu` | Jump to functions/methods/symbols in current buffer |

---

## 3. Code Navigation, Refactoring & Diagnostics

Centralized under the standard GNU keys and the **`C-c l`** (LSP) prefix:

### Semantic Navigation
| Key | Action | Description |
|---|---|---|
| `M-.` | Go to Definition | Jump to symbol definition (decompiles bytecode for 3rd-party JARs) |
| `M-?` | Find References | List all usages across the workspace |
| `M-,` | Pop Tag / Back | Jump back to where you were before `M-.` |
| `C-M-.` | Workspace Symbols | Search classes, methods, and symbols across the entire project |
| `C-c l g d` | Type Definition | Jump to declaration of the type |
| `C-c l g i` | Implementation | Jump to interface implementations |
| `C-c l j h` | Type Hierarchy | View class/type hierarchy |

### Semantic Refactoring & Code Actions
| Key | Command / Action | Description |
|---|---|---|
| `C-c l a a` | `lsp-execute-code-action` | Quick fixes, generate methods, missing imports |
| `C-c l r r` | `lsp-rename` | Semantic, workspace-wide symbol rename |
| `C-c l r o` / `C-c l j o` | `lsp-organize-imports` | Optimize and clean up unused imports |
| `C-c l = =` | `lsp-format-buffer` | Format according to project code style |
| `C-c l j g` | `lsp-java-generate-getters-and-setters` | Generate getters and setters |
| `C-c l j s` | `lsp-java-generate-to-string` | Generate `toString()` method |
| `C-c l j e` | `lsp-java-generate-equals-and-hash-code` | Generate `equals()` and `hashCode()` |
| `C-c l j i` | `lsp-java-add-unimplemented-methods` | Implement interface or abstract methods |
| `C-c l j m` | `lsp-java-extract-method` | Refactor: Extract selected code to a method |
| `C-c l j v` | `lsp-java-extract-to-local-variable` | Refactor: Extract expression to local variable |
| `C-c l j c` | `lsp-java-extract-to-constant` | Refactor: Extract expression to constant |

### Diagnostics & Errors
* Real-time errors and warnings are highlighted in the buffer.
* `C-c ! n`: Jump to next diagnostic error/warning.
* `C-c ! p`: Jump to previous diagnostic error/warning.
* `C-c ! l`: List all diagnostics in a project/buffer summary.

---

## 4. Multiple JDKs & Toolchains

JDTLS runs on one JDK, while projects compile against the JDK of their target release:
* **The JDK that runs JDTLS**: Must be supported by the pinned JDTLS version (JDK 21 to 25 for JDTLS 1.57). Hellmacs auto-detects it: `$JAVA_HOME` if suitable, else `PATH`'s `java`, else the newest suitable JDK found by `bin/hellmacs sync`. To set explicitly, define `hellmacs-jvm-java-home` in `init.el`.
* **JDK Auto-Discovery**: `bin/hellmacs sync` searches `JAVA_HOME`, `PATH`, SDKMAN (`~/.sdkman`), `/usr/lib/jvm`, macOS `JavaVirtualMachines`, asdf, jenv, and mise.
* **Manual JDK List**: In `~/.config/hellmacs/init.el`:
  ```elisp
  (setq hellmacs-jdks '(("JavaSE-1.8" . "/opt/jdk8")
                        ("JavaSE-17"  . "/opt/jdk-17")
                        ("JavaSE-21"  . "/opt/jdk-21")))
  ```
* **Build Toolchains**:
  * **Gradle**: Toolchains (`JavaLanguageVersion.of(N)` or `jvmToolchain(N)`) are resolved automatically.
  * **Maven**: Reads toolchains from `~/.m2/toolchains.xml`.
  * Run `bin/hellmacs doctor` inside a project to verify that all requested JDK toolchains exist.

### Per-Project Environments (`:tools direnv`)
A project's `.envrc` (via [direnv](https://direnv.net)) isolates `JAVA_HOME`, `MAVEN_OPTS`, `GRADLE_USER_HOME`, and proxies per project:
```sh
# .envrc
export JAVA_HOME=$HOME/.sdkman/candidates/java/17.0.10-tem
export MAVEN_OPTS="-Xmx2g"
```
* Allow with `M-x envrc-allow` (or `direnv allow` in shell), then `M-x envrc-reload`.

---

## 5. Building & Testing (`:tools build`)

* **Project Compilation**: `C-x p c` (`project-compile`) invokes the wrapper (`./gradlew` or `./mvnw`) or system build tool.
* **Clickable Error Navigation**: `M-g n` (next error) and `M-g p` (previous error) jump directly to compiler errors or failing test assertions.
* **Testing at Point**:
  * `C-c l j t`: Run the test method at point.
  * `C-c l j T`: Run the entire test class.

### Test Results & Coverage (`:tools test`, `C-c t`)

After a build that ran tests, `*hellmacs-tests*` lists them, failures first, with
suite, time and message. They come from the JUnit XML reports the build wrote
(`build/test-results/`, `target/surefire-reports/`, `failsafe-reports/`), so
Java, Kotlin, Groovy and Scala all work. The `[TEST DAMNATION]` message points to it.

| Key | Command | Description |
|---|---|---|
| `C-c t t` | `hellmacs-test-results` | Show the project's test results |
| `C-c t f` | `hellmacs-test-results-rerun-failures` | Rerun every failing test, in one build |
| `C-c t c` | `hellmacs-coverage-run` | Run the tests with JaCoCo, then mark coverage |
| `C-c t s` | `hellmacs-coverage-show` | Mark coverage from the project's JaCoCo reports |
| `C-c t h` | `hellmacs-coverage-hide` | Remove the coverage marks |

In the results view: `RET` goes to the test (to the failing line), `r` reruns the
test at point, `f` reruns the failing ones, `g` reads every report again, and
`c` shows line coverage per file.

Coverage marks covered, partly covered and missed lines in the fringe (the margin
in a terminal). JaCoCo is added on the command line only: a Gradle init script
(`test jacocoTestReport`), or the Maven plugin by its coordinates
(`org.jacoco:jacoco-maven-plugin:0.8.15`). Your build files stay unchanged.

With `(test +watch)`, saving a JVM source file reruns its class's tests
(`hellmacs-test-watch-mode`). A test class runs itself, and any other class runs its
`...Test` class if there is one.

---

## 6. Run Configurations (`:tools run`, `C-c r`)

Hellmacs reads run configurations from, in order:
1. **`.hellmacs/run.eld`** in the project root:
   ```elisp
   ((:name "Server" :main "com.example.App" :args ("--port=8080")
     :jvm-args ("-Xmx1g") :env (("STAGE" . "local")) :profiles ("dev"))
    (:name "Boot" :task "bootRun" :profiles ("dev")))
   ```
2. **IntelliJ Shared Run Configurations**: `.run/*.run.xml` (Application, Spring Boot, Gradle, Maven).
3. **Eclipse Launch Configurations**: `.launch` files in the project.

| Key | Command | Description |
|---|---|---|
| `C-c r r` | `hellmacs-run` | Select and run a configuration (output in `*run: NAME*`) |
| `C-c r d` | `hellmacs-run-debug` | Debug a configuration (attaches DAP debugger) |
| `C-c r l` | `hellmacs-run-last` | Re-run the last active configuration |

---

## 7. Debugging & Hot Code Replacement (`:tools debugger`, `C-c d`)

Debugging is powered by **DAP Mode** and `dap-java` (Microsoft `java-debug` server).

### Launching & Sessions
| Key | Command | Description |
|---|---|---|
| `C-c d d` | `dap-debug` | Start a debug session (select launch template) |
| `C-c d D` | `dap-debug-last` | Re-launch the last active debug configuration |
| `C-c d r` | `dap-debug-restart` | Restart current debug session |
| `C-c d q` | `dap-disconnect` | Disconnect and terminate debug session |

### Breakpoints
| Key | Command | Description |
|---|---|---|
| `C-c d b` | `dap-breakpoint-toggle` | Toggle breakpoint on current line |
| `C-c d B` | `dap-breakpoint-condition` | Set a conditional breakpoint (e.g. `i == 10`) |
| `C-c d L` | `dap-breakpoint-log-message` | Set a log point (logs message without halting) |
| `C-c d x` | `dap-breakpoint-delete-all` | Clear all active breakpoints across workspace |

### Stepping Through Code
When paused at a breakpoint:
* `C-c d n`: Step over (`next`)
* `C-c d i`: Step in (`step-in`)
* `C-c d o`: Step out (`step-out`)
* `C-c d c`: Continue execution (`continue`)

> **Fast Stepping**: After pressing `C-c d n` (or `i`, `o`, `c`), continue stepping simply by pressing `n`, `i`, `o`, or `c` repeatedly without the `C-c d` prefix. Press any other key to resume normal editing.

### Inspecting Variables & Tests
* `C-c d e`: Evaluate expression under point / selection.
* `C-c d E`: Prompt to evaluate an arbitrary expression.
* `C-c d t`: Debug unit test method under point.
* `C-c d T`: Debug all tests in the current test class.

### Hot Code Replacement (Crucible: `C-c h r`)
Hellmacs supports live bytecode hot-swapping into running debug sessions:
1. Start your application in debug mode via `C-c d d` (or `C-c r d`).
2. Make code edits in your Java source files.
3. Press **`C-c h r`** (Crucible).
4. JDTLS compiles the updated class files and immediately hot-swaps the new bytecode into the running JVM process without an application restart.

---

## 8. Kotlin Development (`:lang kotlin`)

Kotlin support is powered by `kotlin-language-server` and `kotlin-ts-mode`.

### Enabling Kotlin
```elisp
(hellmacs! :tools build lsp
           :lang (kotlin +tree-sitter))
```

### Kotlin Features
* **Server**: Automatically downloaded and pinned by `bin/hellmacs sync`.
* **Navigation & Refactoring**: `M-.` (Go to Definition), `M-?` (References), semantic rename (`C-c l r r`), and parameter hints.
* **Testing & Building**:
  * `C-c l k b`: Build Kotlin project via Gradle.
  * `C-c l k t`: Run test method at point (supports backticked names).
  * `C-c l k T`: Run test class.

---

## 9. Clojure Development (`:lang clojure`)

Clojure support combines **CIDER** for interactive REPL-driven development with **clojure-lsp** for semantic code intelligence.

### Enabling Clojure
```elisp
(hellmacs! :tools lsp
           :lang (clojure +tree-sitter))
```

### Clojure Workflow & Keybindings
* `C-c M-j`: Jack in (starts REPL via `lein`, `clojure`, or `bb`).
* `C-c M-c`: Connect to an existing remote/local nREPL server.
* `C-c C-k`: Load and compile current Clojure buffer.
* `C-M-x`: Evaluate top-level form at point.
* `C-c C-t t`: Run the test under point.
* `C-c C-z`: Switch between Clojure buffer and REPL buffer.
* `C-c h r`: Reload current buffer changes directly into the active REPL.

---

## Formatting (`:editor format`)

```elisp
(hellmacs! :editor (format +onsave))   ; +onsave is optional
```

The keys you already have format with each language's own formatter. lsp-mode's
`C-c l = =` runs the formatter below in these buffers; no key is added.

| Language | Formatter | Installed by `bin/hellmacs sync` |
|---|---|---|
| Java | google-java-format 1.36.1 (needs a JDK 21+, found among your JDKs) | jar pinned by SHA-256 from Maven Central, with `:lang java` |
| Kotlin | ktfmt 0.64, Kotlin conventions style (`hellmacs-format-ktfmt-style`) | jar pinned by SHA-256 from Maven Central, with `:lang kotlin` |
| Clojure | cljfmt through clojure-lsp, with the project's `.cljfmt.edn` | the clojure-lsp `:lang clojure` pins |
| XML, YAML, JSON | the language server's formatter | (Phase 10.1 modules) |

* **Shared with IDE users:** a Java project that commits an Eclipse formatter profile
  is formatted with it, through JDTLS, as Eclipse and IntelliJ format it (IntelliJ
  imports and exports the same XML). Hellmacs looks for the profile in the project
  root and in `config/`, `.settings/`, `etc/`, `codestyle/` and `build-config/`. To use
  JDTLS's formatter everywhere, set `hellmacs-format-java-formatter` to `jdtls`.
* **`+onsave`** formats every save: with the pinned formatter (asynchronously, after
  saving), or with the language server where there isn't one. It is off by default,
  so a first save doesn't reformat a whole legacy file.
* Groovy has no maintained formatter and is left alone.

---

## HTTP Requests (`:tools http`)

IntelliJ's HTTP Client files (`.http`, also VS Code REST Client's) work as they
are, so a team's shared request files run unchanged.

```elisp
(hellmacs! :tools (http +httpyac))   ; +httpyac is optional and needs Node
```

| Key (in `.http` buffers) | Command | Description |
|---|---|---|
| `C-c C-c` | `hellmacs-http-send-request` | Send the request at point (restclient) |
| `C-c C-e` | `hellmacs-http-select-environment` | Choose an environment from `http-client.env.json` |
| `C-c M-e` | `hellmacs-http-reload-environment` | Read the environment files again |
| `C-c C-l` | `hellmacs-http-run-request` | Run the request at point with httpyac, handler and all (`+httpyac`) |
| `C-c C-a` | `hellmacs-http-run-file` | Run every request in the file with httpyac (`+httpyac`) |

restclient's own keys work too: `C-c C-n`/`C-c C-p` move between requests,
`C-c C-u` copies the request as curl, and `C-c C-v` sends it without leaving the window.

* **Environments:** `http-client.env.json`, plus your uncommitted
  `http-client.private.env.json` (which wins), found from the file's directory
  upward. `$shared` applies to every environment.
* **Variables:** `@name = value`, `{{name}}`, and the dynamic `{{$uuid}}`,
  `{{$timestamp}}`, `{{$isoTimestamp}}`, `{{$randomInt}}`, `{{$random.uuid}}` and `{{$guid}}`.
* **Response handlers** (`> {% ... %}`) and `>> file` lines are JavaScript, which
  restclient can't run. They're left out of what `C-c C-c` sends. With `+httpyac`,
  `C-c C-l` and `C-c C-a` run them, so a login handler's token reaches the next request.
  httpyac is pinned by lockfile and installed by `bin/hellmacs sync`.

---

## Databases (`:tools db`)

A database client over JDBC, so every database works the same way: Oracle, SQL
Server, DB2, PostgreSQL, MySQL, MariaDB, H2 and SQLite. It uses built-in `sql-mode`
with sqlline (Apache's JDBC shell) as the interpreter. The drivers are pinned jars
from Maven Central, run on your JDK (11+).

Connections are defined per project in `.hellmacs/db.eld`:

```elisp
((:name "dev" :driver postgresql :host "localhost" :database "app" :user "ann")
 (:name "reports" :driver oracle :host "db.corp" :database "ORCLPDB1" :user "rep")
 (:name "legacy" :driver sqlserver :url "jdbc:sqlserver://h:1433;databaseName=x" :user "u"))
```

* **Passwords** never go in that file (it's refused). They come from auth-source
  (`machine localhost port 5432 login ann password ...` in `~/.authinfo.gpg`), or
  you're asked each time. The password reaches sqlline on its standard input,
  never on its command line.
* **In `sql-mode` buffers**, sql-mode's own keys connect when needed, choosing
  among the project's connections:
  * `C-c C-c` runs the statement at point (the lines between blank lines; the one
    above when point is on a blank line);
  * `C-c C-b` runs the whole buffer.

  A missing `;` is added.
* **Results** show as tables in the connection's `*SQL: NAME*` buffer
  (`M-x hellmacs-db-connect` opens one directly).
* **Drivers:** `bin/hellmacs sync` installs sqlline and the drivers in
  `hellmacs-db-drivers` (PostgreSQL by default). Any other driver is installed,
  pinned, the first time a connection uses it.

---

## 10. Project File Types (`:lang data`, `yaml`, `json`, `markdown`, `sh`, `docker`)

Every JVM project also carries XML, YAML, JSON, shell scripts, READMEs and
Dockerfiles. Each of these modules is off by default and adds a language server
through lsp-mode, so `C-c l`, `M-.`, completion and diagnostics work as they do in
Java. None of them adds keys. `bin/hellmacs sync` installs each server pinned,
and `bin/hellmacs doctor` checks it.

```elisp
(hellmacs! :tools lsp
           :lang data (yaml +tree-sitter) (json +tree-sitter) markdown
                 (sh +tree-sitter) (docker +tree-sitter))
```

| Module | Files | Server | Pinned as |
|---|---|---|---|
| `:lang data` | `pom.xml` and other XML, `.pom`, `.classpath`, `.launch` (`nxml-mode`) | lemminx 0.31.2 | uber jar by SHA-256; runs on your JDK (11+) |
| `:lang yaml` | YAML (`yaml-mode`, `yaml-ts-mode`) | yaml-language-server 1.24.0 | npm lockfile; needs Node |
| `:lang json` | JSON (`js-json-mode`, `json-ts-mode`) | vscode-json-language-server 4.10.0 | npm lockfile; needs Node |
| `:lang markdown` | Markdown (`markdown-mode`, `gfm-mode`) | marksman 2026-02-08 | binary by SHA-256 |
| `:lang sh` | Shell scripts, `gradlew`, `mvnw` (`sh-mode`, `bash-ts-mode`) | bash-language-server 5.8.1 | npm lockfile; needs Node 20+ |
| `:lang docker` | Dockerfiles, Compose files (`dockerfile-mode`, `dockerfile-ts-mode`) | docker-language-server 0.20.1 | binary by SHA-256 |

* **npm servers** are installed with `npm ci --ignore-scripts` from the lockfile in
  the module's directory, so every package is checked against its integrity hash.
  npm's cache lives in Hellmacs' cache directory, and it uses your proxy, CA
  bundle and a registry mirror (`hellmacs-mirrors` for `https://registry.npmjs.org/`).
* **XML schemas** that files name (such as Maven's POM XSD) are fetched by lemminx
  through your proxy and cached under Hellmacs' cache directory.
* **YAML schemas from SchemaStore** are off, because they would be fetched while you
  edit. Set `hellmacs-yaml-schemastore` to `t` to enable them, or map your own
  schemas in `lsp-yaml-schemas`. Spring Boot's `application*.yml` go to the Spring
  server (`:lang java +spring`).
* **Compose files** (`compose.yaml`, `docker-compose*.yml`) stay in the YAML mode
  and are handled by Docker's server instead of the YAML one.
* **ShellCheck** diagnostics appear in shell scripts when `shellcheck` is installed.

---

## 11. Troubleshooting Project Imports

The mode-line shows the state of the active language server: `JVM:igniting`, `JVM:ready`, or `JVM:purgatory` when a project fails to import or build.

If you encounter `[BYTECODE PURGATORY]`:
1. **Toolchain Version Mismatch**: Check if the project requires a JDK version not installed. Run `bin/hellmacs doctor` inside the project directory.
2. **Re-import Project**: Run `C-c l j u` (`lsp-java-update-project-configuration`) to force JDTLS to re-evaluate build configurations.
3. **Environment Sync**: Run `bin/hellmacs env` in your terminal to refresh `PATH` and `JAVA_HOME` variables for GUI Emacs.
