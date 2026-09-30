# JVM Guide

Hellmacs exists for the JVM: Java at IntelliJ IDEA's level, and Kotlin,
Clojure and Groovy on the same footing. This guide covers each language and
the tools around them. Keys are stock Emacs plus the `C-c` groups in
[keybindings.md](keybindings.md).

Everything here is on by default except where it says "off": uncomment the
module in `~/.config/hellmacs/init.el`, then `hellmacs sync`. Every language
server is pinned and installed by `sync`; nothing is downloaded while you
edit.

---

## Java (`:lang java`)

Eclipse JDTLS through lsp-mode, with Lombok (`+lombok`), Spring Boot's
language server (`+spring`), and tree-sitter (`+tree-sitter`).

**Opening a project.** Open any `.java` file in a Maven or Gradle project.
lsp-mode asks once to import the root. The echo area says
`[FORGE IGNITED]` while JDTLS starts and `[DAEMON READY]` when it's done;
the mode-line says `JVM:ready`.

**Completion** (every language with a server). The popup opens as you
type, ranked by the server and then by what you've picked before, with
each candidate's type and, half a second later, its documentation.
Picking a method inserts its arguments as placeholders (`TAB` / `S-TAB`
or `M-}` / `M-{` move between them, `C-g` leaves); picking a class adds
its import. JDTLS's templates (`sysout`, `foreach`, `fori`) and postfix
completion (`list.for`, `name.nnull`, `x.var`) expand the same way.
Parameter hints show in the echo area as you type `(` and `,`.

**Navigation**

| Key | Does |
|---|---|
| `M-.` / `M-?` / `M-,` | Definition (decompiled for jars) / references / back |
| `C-M-.` | Workspace symbols |
| `C-c c t`, `C-c c i` | Type definition, implementations |
| `C-c l h` | Type hierarchy |

**Editing and refactoring**

| Key | Does |
|---|---|
| `C-c c a` | Code actions: quick fixes, missing imports, generate |
| `C-c c r` | Rename across the workspace |
| `C-c c o` | Organize imports |
| `C-c c f` | Format the buffer |
| `C-c l g` / `s` / `e` / `i` | Getters and setters / `toString` / `equals` and `hashCode` / unimplemented methods |
| `C-c l m` / `v` / `c` | Extract method / local variable / constant |
| `C-c l u` | Update the project configuration |
| `C-c l b` | Build the project (JDTLS) |
| `C-c l t t` / `C-c l t T` | Run the test at point / the test class |

`C-c c` is the code group every language shares; `C-c l`, the
localleader, holds Java's own commands. lsp-mode's full map is on
`C-c c l`.

**Diagnostics** are flymake's: `C-c ! n` / `C-c ! p` next and previous,
`C-c ! l` (or `C-c c x`) the list, `M-g f` jump to one.

**Spring Boot (`+spring`).** Spring Boot's own language server runs beside
JDTLS: completion and checks in `application*.yml` and `.properties`, and
workspace symbols for beans (`@+`) and request mappings (`@/`). Run and
debug an application with run configurations (below), one per Spring
profile.

### Several JDKs

JDTLS runs on one JDK (21 to 25 for the pinned JDTLS); each project
compiles against the JDK its build targets, Java 8 and up.

- **Found for you:** `sync` looks in `JAVA_HOME`, `PATH`, SDKMAN,
  `/usr/lib/jvm`, macOS's `JavaVirtualMachines`, asdf, jenv and mise.
- **Set them yourself** in `init.el`:
  ```elisp
  (setq hellmacs-jdks '(("JavaSE-1.8" . "/opt/jdk8")
                        ("JavaSE-21"  . "/opt/jdk-21")))
  (setq hellmacs-jvm-java-home "/opt/jdk-21")   ; the one running JDTLS
  ```
- **Build toolchains** are honored: Gradle's (`jvmToolchain(N)`) and
  Maven's `~/.m2/toolchains.xml`. `hellmacs doctor`, run in a project, says
  whether the JDKs it asks for exist.
- **Per project (`:tools direnv`):** a project's `.envrc` sets
  `JAVA_HOME`, `MAVEN_OPTS`, proxies... for that project only, JDTLS and
  builds included. `M-x envrc-allow`, then `M-x envrc-reload`.

---

## Kotlin (`:lang kotlin`)

kotlin-language-server: navigation, diagnostics, rename (`C-c c r`),
completion. With `:tools build`, `C-c c c` builds, `C-c l t t` runs the
test at point (backticked names too), `C-c l t T` the class. IntelliJ's
Kotlin refactorings (extract, organize imports) aren't there yet; Hellmacs
switches to JetBrains' Kotlin server when it can be pinned (roadmap 12.7).

## Clojure (`:lang clojure`)

CIDER for the REPL, clojure-lsp for navigation and diagnostics.

| Key | Does |
|---|---|
| `C-c M-j` / `C-c M-c` | Start a REPL (`clojure`, `lein` or `bb`) / connect to one |
| `C-c C-k` | Load the buffer |
| `C-M-x` | Evaluate the top-level form |
| `C-c C-z` | Between the buffer and the REPL |
| `C-c C-t t` | Run the test at point |
| `C-c h r` | Reload changes into the REPL |

## Groovy (`:lang groovy`, off)

Groovy sources, Gradle's Groovy scripts and Jenkinsfiles, through
groovy-language-server (built by `sync` from a pinned commit). The server
learns the project's libraries from the build: the mode-line shows
`JVM:igniting` until it has them. `C-c c c` builds, `C-c l t t` /
`C-c l t T` run the test at point (JUnit or Spock) / the class, `C-c l c`
asks the build for the classpath again.

---

## Building and testing

**Build (`:tools build`).** `C-x p c` (or `C-c c c`) builds with the project's wrapper
(`./gradlew`, `./mvnw`) or the installed tool. Errors and failing
assertions are clickable: `M-g n` / `M-g p`.

**Tests, results and coverage (`:tools build`, `:tools test`, `C-c l t`
in a source file).** After a build that ran tests, `*hellmacs-tests*`
lists them, failures first, from the JUnit XML reports (Java, Kotlin,
Groovy and Scala alike).

| Key | Does |
|---|---|
| `C-c l t t` / `C-c l t T` | Run the test at point / the test class |
| `C-c l t r` | The test results |
| `C-c l t f` | Rerun every failing test |
| `C-c l t c` | Run the tests with JaCoCo, then mark coverage |
| `C-c l t s` / `C-c l t h` | Show / hide coverage marks |

In the results: `RET` goes to the failing line, `r` reruns the test, `f`
the failures, `g` rereads the reports, `c` shows coverage per file.
Coverage marks lines in the fringe (the margin in a terminal); JaCoCo is
added on the command line, so your build files stay unchanged.
`(test +watch)` reruns a class's tests when you save it.

**Run configurations (`:tools run`, `C-c r`).** Read from
`.hellmacs/run.eld`, IntelliJ's shared `.run/*.run.xml` (Application,
Spring Boot, Gradle, Maven) and Eclipse's `.launch` files, so a team's
configurations work unchanged.

```elisp
;; .hellmacs/run.eld
((:name "Server" :main "com.example.App" :args ("--port=8080")
  :jvm-args ("-Xmx1g") :env (("STAGE" . "local")) :profiles ("dev"))
 (:name "Boot" :task "bootRun" :profiles ("dev")))
```

`C-c r r` runs one (output in `*run: NAME*`), `C-c r d` debugs it,
`C-c r l` runs the last one again.

## Debugging (`:tools debugger`, `C-c d`)

dap-mode with Microsoft's java-debug.

| Key | Does |
|---|---|
| `C-c d d` / `D` | Start a session (pick a template) / the last one again |
| `C-c d r` / `q` | Restart / disconnect |
| `C-c d b` / `B` / `L` / `x` | Toggle a breakpoint / condition / log message / delete all |
| `C-c d n` / `i` / `o` / `c` | Next / step in / step out / continue |
| `C-c d e` / `E` | Evaluate at point / an expression |
| `C-c d t` / `T` | Debug the test at point / the test class |

After `C-c d n` (or `i`, `o`, `c`), keep pressing `n`, `i`, `o` or `c`
alone; any other key goes back to editing.

**Hot code replacement, the Crucible (`C-c h r`).** In a debug session,
edit, then press `C-c h r`: the changed classes are compiled and swapped
into the running JVM, no restart. In Clojure it reloads into the REPL.

---

## Around the code

**Formatting (`:editor format`, off).** `C-c c f` formats with each
language's own formatter: google-java-format for Java, ktfmt for Kotlin,
cljfmt for Clojure, the language server's for XML, YAML and JSON. A Java
project that commits an Eclipse formatter profile (in its root, `config/`,
`.settings/`, `etc/`, `codestyle/` or `build-config/`) is formatted with it,
exactly as teammates on Eclipse or IntelliJ format.
`(format +onsave)` formats every save.

**Static analysis (`:checkers static`, off).** Checkstyle, PMD and
SpotBugs findings from your build's own reports, as flymake diagnostics in
Java and Kotlin buffers (`C-c ! n`); `M-x hellmacs-static-findings` lists
the project's. `+sonarlint` adds SonarLint's analysis as you type.

**HTTP requests (`:tools http`, off).** IntelliJ's `.http` files as they
are, with `http-client.env.json` environments (and your private
`http-client.private.env.json`), `{{variables}}` and dynamic values
(`{{$uuid}}`, `{{$timestamp}}`...).

| Key (in `.http` buffers) | Does |
|---|---|
| `C-c C-c` | Send the request at point |
| `C-c C-e` / `C-c M-e` | Choose / reload the environment |
| `C-c C-l` / `C-c C-a` | Run the request / the file with httpyac, JavaScript handlers included (`+httpyac`) |

**Databases (`:tools db`, off).** A JDBC client for Oracle, SQL Server, DB2,
PostgreSQL, MySQL, MariaDB, H2 and SQLite, through `sql-mode` and sqlline.
Connections are per project, passwords come from auth-source
(`~/.authinfo.gpg`) and never from the file:

```elisp
;; .hellmacs/db.eld
((:name "dev" :driver postgresql :host "localhost" :database "app" :user "ann")
 (:name "legacy" :driver sqlserver :url "jdbc:sqlserver://h:1433;databaseName=x" :user "u"))
```

In `sql-mode`, `C-c C-c` runs the statement at point and `C-c C-b` the
buffer; results show as tables.

**Containers (`:tools docker`, `:tools kubernetes`, off).** `C-c o d`
opens docker.el (containers, images, Compose; podman works too),
`C-c o k` opens kubel (pods, logs, port forwards, shells), with your own
`docker` and `kubectl`.

**Snippets and templates (`:editor snippets`, `:editor file-templates`,
off).** Type `junit`, `controller`, `dataclass`, `deftest` or `munit` and
complete with `C-M-i`; `M-}` / `M-{` move between fields. A new empty
`FooTest.java`, `Foo.kt` or Clojure file offers its template, package or
namespace filled in from the path.

**Project files (off: `:lang data`, `yaml`, `json`, `markdown`, `sh`,
`docker`).** `pom.xml` and other XML (lemminx), YAML, JSON, Markdown,
shell scripts and `gradlew`, Dockerfiles and Compose files, each with its
language server, so `C-c l`, `M-.` and diagnostics work as in Java. YAML,
JSON and shell servers need Node. Spring's `application*.yml` goes to the
Spring server.

---

## When a project won't import

The mode-line says `JVM:purgatory` and the echo area `[BYTECODE PURGATORY]`
when a project fails to import or build.

1. **A JDK is missing:** run `hellmacs doctor` in the project; it lists
   the JDKs the build asks for and which exist.
2. **Import again:** `C-c l u` makes JDTLS re-read the build.
3. **GUI Emacs can't find your tools:** run `hellmacs env` in a terminal,
   then restart Emacs.
4. **Behind a proxy or with internal repositories:** see the guide's
   [Companies](guide.md#6-companies-networks-offline-machines-compliance)
   section; Maven's `settings.xml` is used as is.
