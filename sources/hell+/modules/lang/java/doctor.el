;;; lang/java/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; Checked by `bin/hell doctor'.

(hell-module-load "+paths")

;; The JDK that runs JDTLS: one it runs on, chosen unless you set one (cli.el).
(hell-jvm-doctor-jdtls-jdk)

;; The JDKs projects compile against, each for its own release (cli.el).
(hell-jvm-doctor-jdks)

;; The JDKs builds ask for: Maven's toolchains.xml, and the toolchain of
;; the build doctor runs in (cli.el).
(hell-jvm-doctor-toolchains default-directory)

;; The build tools' own settings, which JDTLS imports with (config.el):
;; internal repositories and mirrors configured there work in Emacs too.
(let ((file (expand-file-name (or (bound-and-true-p hell-maven-settings) "~/.m2/settings.xml"))))
  (cond ((file-readable-p file)
         (hell-doctor-ok "Maven settings: %s" (abbreviate-file-name file)))
        ((bound-and-true-p hell-maven-settings)
         (hell-doctor-error :topic 'config "`hell-maven-settings' is %s, which can't be read" (abbreviate-file-name file)))
        (t (hell-doctor-info "No Maven settings.xml (%s); Maven's defaults apply" (abbreviate-file-name file)))))
(let* ((home (or (getenv "GRADLE_USER_HOME") (expand-file-name "~/.gradle")))
       (inits (length (file-expand-wildcards (expand-file-name "init.d/*.gradle*" home))))
       (found (delq nil (list (and (file-exists-p (expand-file-name "gradle.properties" home))
                                   "gradle.properties")
                              (and (> inits 0) (format "%d init.d script%s" inits (if (= inits 1) "" "s")))))))
  (hell-doctor-info "Gradle home: %s%s%s" (abbreviate-file-name home)
                        (if (getenv "GRADLE_USER_HOME") " ($GRADLE_USER_HOME)" "")
                        (if found (concat ", with " (string-join found " and ")) "")))

(hell-doctor-reachable hell-jvm-jdtls-url "installing JDTLS")
(hell-doctor-reachable hell-jvm-junit-runner-url "the JUnit runner, and projects' Maven dependencies")

(hell-doctor-executable "gradle" "Gradle projects without a ./gradlew wrapper")
(hell-doctor-executable "mvn" "Maven projects without a ./mvnw wrapper, and installing JDTLS faster" nil "--version")

(hell-doctor-pinned "JDTLS" hell-jvm-jdtls-version (hell-jvm-jdtls-installed-p)
                        (file-directory-p (expand-file-name "plugins/" hell-jvm-jdtls-dir))
                        :where hell-jvm-jdtls-dir)
(hell-doctor-pinned "JUnit test runner" hell-jvm-junit-runner-version
                        (hell-jvm-junit-runner-valid-p) (file-exists-p dap-java-test-runner))

;; +spring: Spring Boot's language server, pinned; it runs on JDTLS's JDK.
(when (modulep! +spring)
  (hell-doctor-pinned "Spring Boot Tools" hell-jvm-spring-version
                          (hell-jvm-spring-installed-p)
                          (file-directory-p hell-jvm-spring-dir)
                          :where hell-jvm-spring-dir))

(when (modulep! +lombok)
  (cond ((hell-jvm-lombok-jar-valid-p)
         (hell-doctor-ok "Lombok: %s" (abbreviate-file-name hell-jvm-lombok-jar)))
        ((file-exists-p hell-jvm-lombok-jar)
         (hell-doctor-error :topic 'installs "Lombok jar %s fails its SHA-256 check; `bin/hell sync' downloads it again"
                                (abbreviate-file-name hell-jvm-lombok-jar)))
        (t
         (hell-doctor-error :topic 'installs "+lombok is on but Lombok isn't installed; run `bin/hell sync'"))))

(when (modulep! :tools debugger)
  (hell-doctor-pinned "java-debug" hell-jvm-java-debug-version
                          (hell-jvm-java-debug-jar-valid-p) (file-exists-p hell-jvm-java-debug-jar)
                          :stale-note " (the one lsp-java installs can't debug on JDK 22+)"
                          :missing-note " with JDTLS"))

;; The guard (+paths.el) against JDTLS silently folding a second
;; project into a session already running for a first one (two
;; clients' codebases sharing one server) advises a private lsp-mode
;; function. An lsp-mode update could rename or drop it, turning the
;; guard into a silent no-op. Requiring lsp-mode here runs the
;; `with-eval-after-load' that attaches the advice, so this checks the
;; real thing, not just that the code defining it loaded.
(if (not hell-jvm-isolate-sessions)
    (hell-doctor-info "JDTLS session isolation is off (`hell-jvm-isolate-sessions' is nil)")
  (if (not (require 'lsp-mode nil t))
      (hell-doctor-warn :topic 'installs "lsp-mode isn't installed yet; can't check the JDTLS session-isolation guard")
    (cond
     ((not (fboundp 'lsp--find-multiroot-workspace))
      (hell-doctor-error :topic 'config "lsp-mode no longer has `lsp--find-multiroot-workspace'; the guard stopping JDTLS from merging different clients' projects into one session is now silently a no-op"))
     ((advice-member-p #'hell-jvm--no-silent-multiroot-a 'lsp--find-multiroot-workspace)
      (hell-doctor-ok "JDTLS session isolation: different projects never silently share a server"))
     (t
      (hell-doctor-error :topic 'config "The guard stopping JDTLS from merging different clients' projects into one session isn't attached")))))
