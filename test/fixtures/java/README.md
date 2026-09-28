# Java fixtures

Two small projects with identical sources, one built with Gradle and one with Maven,
used to verify Hellmacs' Java support (roadmap Phase 6):

- `App` — a `main` to set breakpoints in.
- `Greeter` — a plain class for completion, navigation and refactoring.
- `Person` — Lombok `@Data`: its getters exist only after annotation processing.
- `GreeterTest` — passes.
- `BrokenTest` — fails on purpose, but only with `-Dhellmacs.fail=true`, so a normal
  build passes and failure handling can still be tested.

Both target Java 21 (the minimum JDTLS runs on) and include their build tool's wrapper,
so the Hellmacs build detection (wrapper first) is exercised too:

    cd gradle-demo && ./gradlew test                       # passes
    cd gradle-demo && ./gradlew test -Dhellmacs.fail=true  # BrokenTest fails
    cd maven-demo  && ./mvnw -B test                       # passes
    cd maven-demo  && ./mvnw -B test -Dhellmacs.fail=true  # BrokenTest fails

## Legacy targets (roadmap 12.3)

Two older projects check that each project imports, builds, tests and debugs against its
own JDK while JDTLS runs on a newer one (`test/integration/legacy-jdk-e2e.el`):

- `legacy-8` — Maven, Java 8 (`maven.compiler.source/target` 1.8), JUnit 4. The
  command-line build runs on the JDK your shell gives it, so `JAVA_HOME` must be a JDK 8.
- `legacy-11-gradle` — Gradle, a Java 11 toolchain, JUnit 5 (JUnit 6 needs Java 17).
  Gradle itself runs on 17+ and compiles with the JDK 11 its toolchain finds.

        cd legacy-8         && JAVA_HOME=/path/to/jdk8 ./mvnw -B test
        cd legacy-11-gradle && ./gradlew test   # needs a JDK 11 where Gradle looks
