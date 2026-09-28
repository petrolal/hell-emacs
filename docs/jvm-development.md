# JVM Development Guide

Hellmacs is built first and foremost as a high-performance environment for the Java Virtual Machine ecosystem (Java, Kotlin, Clojure, Scala, Groovy).

---

## Java Development (`:lang java`)

Java support is powered by **Eclipse JDTLS**, **LSP Mode**, **Tree-sitter**, and **DAP Mode**.

### Enabling Java
In `~/.config/hellmacs/init.el`:

```elisp
(hellmacs! :tools
           build              ; Gradle / Maven build integration
           debugger           ; DAP debugger & Hot Code Replace
           lsp                ; LSP Mode
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

### Several JDKs
JDTLS itself runs on one JDK, and each project compiles against the JDK of the release it targets: a Java 8 project against a JDK 8, a Java 17 one against a JDK 17.
* **The JDK that runs JDTLS** must be one the pinned JDTLS supports: 21 to 25 for JDTLS 1.57 (it fails to start on JDK 27). Hellmacs chooses it: `$JAVA_HOME`'s JDK if JDTLS runs on it, else the `PATH`'s `java`, else the newest suitable JDK that `bin/hellmacs sync` found. So a newer system JDK doesn't break Java editing. `bin/hellmacs doctor` says which JDK it chose, and why it passed over the others. To choose it yourself, set `hellmacs-jvm-java-home` in `init.el`.
* `bin/hellmacs sync` finds your JDKs and tells JDTLS about them. It looks in `JAVA_HOME`, the `java` on your `PATH`, SDKMAN (`~/.sdkman`), `/usr/lib/jvm`, macOS's `JavaVirtualMachines`, asdf, jenv and mise. It keeps one JDK per release, and `JAVA_HOME`'s wins for its release.
* After installing another JDK, run `bin/hellmacs sync` again. `bin/hellmacs doctor` lists the JDKs, marks the default (JDTLS's own), and warns about any it finds that the last sync didn't store.
* If your JDKs are elsewhere, list them yourself in `~/.config/hellmacs/init.el`, named as JDTLS names releases:
  ```elisp
  (setq hellmacs-jdks '(("JavaSE-1.8" . "/opt/jdk8")
                        ("JavaSE-17"  . "/opt/jdk-17")))
  ```
  `doctor` checks that each one is a JDK of that release. If you set `lsp-java-configuration-runtimes` yourself, Hellmacs leaves it alone.
* A program you debug (`:tools debugger`) runs on its project's JDK too: a Java 8 program on JDK 8. A `:javaExec` in your own launch configuration wins.
* The command-line build (`C-x p c`) runs on the JDK its environment gives it, as in a terminal. Maven needs `JAVA_HOME` to be the project's JDK: give the project an `.envrc` (next section). Gradle finds the JDK its toolchain asks for on its own, if it's installed where Gradle looks.

### Run configurations (`:tools run`, `C-c r`)
A run configuration is a main class or a build task, with its arguments, JVM options, environment, Spring profiles and working directory. Hellmacs reads them from, in order:
1. `.hellmacs/run.eld` in the project, Hellmacs' own, committed with the code:
   ```elisp
   ((:name "Server" :main "com.example.App" :args ("--port=8080")
     :jvm-args ("-Xmx1g") :env (("STAGE" . "local")) :profiles ("dev"))
    (:name "Boot" :task "bootRun" :profiles ("dev")))   ; a build task
   ```
   Other keys: `:cwd` (relative to the project), `:project` (JDTLS's project name), `:build-args` (for the build tool itself).
2. IntelliJ's shared `.run/*.run.xml`: Application, Spring Boot, Gradle and Maven configurations.
3. Eclipse `.launch` files in the project: Java applications, and Spring Tools' Boot launches.

A team's existing shared configurations work as they are. A name that appears twice is taken from the first source, and types Hellmacs doesn't run (JUnit...) are skipped: tests run through `:tools build`.

* `C-c r r` runs one. A main class runs on the classpath JDTLS resolves and on the project's JDK. A task runs through the project's `gradlew`/`mvnw`. Output goes to `*run: NAME*`, with colours, highlighted exceptions and clickable stack frames (`M-g n`). Running it again stops the previous run first.
* `C-c r d` debugs it. A main class launches through dap-java. `run`/`bootRun` (Gradle) and `spring-boot:run` (Maven) start with a JDWP agent on port 5005 (`hellmacs-run-debug-port`), and the debugger attaches when the application says it's listening. Other tasks can't be debugged.
* `C-c r l` runs the last one again, the same way.
* The run gets the environment of the buffer you started it from (including an `.envrc`'s), plus the configuration's own. For Gradle tasks, JVM options come from the build; for `spring-boot:run` they're passed along.

### Build toolchains
Builds that ask for a JDK themselves keep doing so; Hellmacs only reads their files, never changes them.
* **Gradle** (`JavaLanguageVersion.of(N)`, or Kotlin's `jvmToolchain(N)`) finds the JDK on its own: where Hellmacs looks too, plus `org.gradle.java.installations.paths`, or it downloads one if the build has a toolchain resolver. If it can't, JDTLS's import fails and the echo area says which JDK is missing.
* **Maven** (`maven-toolchains-plugin`) takes it from `~/.m2/toolchains.xml`.
* Run `bin/hellmacs doctor` inside a project to check. It names a JDK the build asks for that isn't there, with the file and line that asked (`build.gradle:10 asks for a JDK 11 toolchain, and none is installed`). It also checks that every JDK `~/.m2/toolchains.xml` lists exists and is the release it claims.

### Per-project environments (`:tools direnv`)
A project's `.envrc`, run by [direnv](https://direnv.net), sets its own `JAVA_HOME`, `MAVEN_OPTS`, `GRADLE_USER_HOME`, proxy variables and so on. With `:tools direnv` (on by default), those apply to that project's buffers only. Everything started from them gets them: the build and tests (`C-x p c`, `C-c l j t`), shell commands, a language server. Switch to another project's buffer and its own environment applies.
```sh
# legacy-app/.envrc
export JAVA_HOME=$HOME/.sdkman/candidates/java/8.0.402-tem
export MAVEN_OPTS="-Xmx1g"
```
* Install `direnv` from your package manager; `bin/hellmacs doctor` checks for it. Without it, the module does nothing.
* A new or changed `.envrc` must be allowed first, as in a shell: `M-x envrc-allow` (or `direnv allow` in a terminal), then `M-x envrc-reload`.
* No keys are bound. To put envrc's commands on a prefix of your own:
  ```elisp
  (with-eval-after-load 'envrc
    (keymap-set envrc-mode-map "C-c e" 'envrc-command-map))
  ```
* JDTLS keeps running on a JDK it supports, whatever `JAVA_HOME` a project's `.envrc` sets. One JDTLS serves every open Java project, and it starts with the environment of the buffer that started it.

### Java Keybindings (`C-c l j`)
| Key | Command | Description |
|---|---|---|
| `C-c l j b` | `lsp-java-build-project` | Trigger a full/incremental JDTLS build |
| `C-c l j u` | `lsp-java-update-project-configuration` | Re-import `pom.xml` or `build.gradle` changes |
| `C-c l j o` | `lsp-java-organize-imports` | Clean and optimize Java imports |
| `C-c l j g` | `lsp-java-generate-getters-and-setters` | Generate getters/setters for fields |
| `C-c l j s` | `lsp-java-generate-to-string` | Generate `toString()` method |
| `C-c l j e` | `lsp-java-generate-equals-and-hash-code` | Generate `equals()` and `hashCode()` |
| `C-c l j i` | `lsp-java-add-unimplemented-methods` | Implement interface or abstract methods |
| `C-c l j m` | `lsp-java-extract-method` | Refactor: Extract selected code to a method |
| `C-c l j v` | `lsp-java-extract-to-local-variable` | Refactor: Extract expression to local variable |
| `C-c l j c` | `lsp-java-extract-to-constant` | Refactor: Extract expression to constant |
| `C-c l j h` | `lsp-java-type-hierarchy` | View class/type hierarchy |
| `C-c l j t` | `hellmacs-build-test-at-point` | Run the test method at point |
| `C-c l j T` | `hellmacs-build-test-class` | Run the entire test class |

### Building with Maven & Gradle (`:tools build`)
* `C-x p c` (`project-compile`): Runs Gradle or Maven build tasks using the wrapper (`./gradlew` / `./mvnw`) or system binaries.
* `M-g n` / `M-g p`: Jump to next / previous compilation error or failing test assertion in buffer.

---

## Kotlin Development (`:lang kotlin`)

Kotlin support is powered by `kotlin-language-server` and `kotlin-ts-mode`.

### Enabling Kotlin
```elisp
(hellmacs! :tools
           build
           lsp
           :lang
           (kotlin +tree-sitter))
```

### Kotlin Workflow
* **Server**: Automatically downloaded and pinned by `bin/hellmacs sync`.
* **Navigation & Refactoring**: Full `M-.` (Go to Definition), `M-?` (References), semantic rename (`C-c l r r`), and parameter hints.
* **Testing & Building**:
  * `C-c l k b`: Build Kotlin project via Gradle.
  * `C-c l k t`: Run the test method at point (supports backticked names).
  * `C-c l k T`: Run the test class.

---

## Clojure Development (`:lang clojure`)

Clojure support combines **CIDER** for interactive REPL-driven development with **clojure-lsp** for semantic code intelligence.

### Enabling Clojure
```elisp
(hellmacs! :tools
           lsp
           :lang
           (clojure +tree-sitter))
```

### Clojure Keybindings
* `C-c M-j`: Jack in (starts REPL via `lein`, `clojure`, or `bb`).
* `C-c M-c`: Connect to an existing remote/local nREPL server.
* `C-c C-k`: Load and compile current Clojure buffer.
* `C-M-x`: Evaluate top-level form at point.
* `C-c C-t t`: Run the test under point.
* `C-c C-z`: Switch between Clojure buffer and REPL buffer.
* `C-c h r`: Reload current buffer changes directly into the active REPL.

---

## Troubleshooting Project Imports

The mode-line shows the state of the buffer's language server (JDTLS, kotlin-language-server or clojure-lsp): `JVM:igniting`, `JVM:ready`, or `JVM:purgatory` when the project failed to import or its last build failed (`JVM:failed` with `hellmacs-ux-enable` off). A failed build clears on the next good one.

If you see `[BYTECODE PURGATORY] <project> failed to import: ...` and `JVM:purgatory` on the mode-line:
1. **Toolchain Version Mismatch**: Your build may specify a JDK version not currently on your system. Install the required JDK (via SDKMAN or system package manager).
2. **Re-import Project**: Run `C-c l j u` (`lsp-java-update-project-configuration`) to force JDTLS to re-evaluate the build configuration.
3. **Environment Sync**: Run `bin/hellmacs env` in your terminal to refresh `PATH` and `JAVA_HOME` variables recognized by Emacs.
