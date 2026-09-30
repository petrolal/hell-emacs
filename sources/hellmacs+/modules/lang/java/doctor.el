;;; lang/java/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; Checked by `bin/hellmacs doctor'.

(hellmacs-module-load "+paths")

;; The JDK that runs JDTLS: one it runs on, chosen unless you set one (cli.el).
(hellmacs-jvm-doctor-jdtls-jdk)

;; The JDKs projects compile against, each for its own release (cli.el).
(hellmacs-jvm-doctor-jdks)

;; The JDKs builds ask for: Maven's toolchains.xml, and the toolchain of
;; the build doctor runs in (cli.el).
(hellmacs-jvm-doctor-toolchains default-directory)

;; The build tools' own settings, which JDTLS imports with (config.el):
;; internal repositories and mirrors configured there work in Emacs too.
(let ((file (expand-file-name (or (bound-and-true-p hellmacs-maven-settings) "~/.m2/settings.xml"))))
  (cond ((file-readable-p file)
         (hellmacs-doctor-ok "Maven settings: %s" (abbreviate-file-name file)))
        ((bound-and-true-p hellmacs-maven-settings)
         (hellmacs-doctor-error :topic 'config "`hellmacs-maven-settings' is %s, which can't be read" (abbreviate-file-name file)))
        (t (hellmacs-doctor-info "No Maven settings.xml (%s); Maven's defaults apply" (abbreviate-file-name file)))))
(let* ((home (or (getenv "GRADLE_USER_HOME") (expand-file-name "~/.gradle")))
       (inits (length (file-expand-wildcards (expand-file-name "init.d/*.gradle*" home))))
       (found (delq nil (list (and (file-exists-p (expand-file-name "gradle.properties" home))
                                   "gradle.properties")
                              (and (> inits 0) (format "%d init.d script%s" inits (if (= inits 1) "" "s")))))))
  (hellmacs-doctor-info "Gradle home: %s%s%s" (abbreviate-file-name home)
                        (if (getenv "GRADLE_USER_HOME") " ($GRADLE_USER_HOME)" "")
                        (if found (concat ", with " (string-join found " and ")) "")))

(hellmacs-doctor-reachable hellmacs-jvm-jdtls-url "installing JDTLS")
(hellmacs-doctor-reachable hellmacs-jvm-junit-runner-url "the JUnit runner, and projects' Maven dependencies")

(hellmacs-doctor-executable "gradle" "Gradle projects without a ./gradlew wrapper")
(hellmacs-doctor-executable "mvn" "Maven projects without a ./mvnw wrapper, and installing JDTLS faster" nil "--version")

(hellmacs-doctor-pinned "JDTLS" hellmacs-jvm-jdtls-version (hellmacs-jvm-jdtls-installed-p)
                        (file-directory-p (expand-file-name "plugins/" hellmacs-jvm-jdtls-dir))
                        :where hellmacs-jvm-jdtls-dir)
(hellmacs-doctor-pinned "JUnit test runner" hellmacs-jvm-junit-runner-version
                        (hellmacs-jvm-junit-runner-valid-p) (file-exists-p dap-java-test-runner))

;; +spring: Spring Boot's language server, pinned; it runs on JDTLS's JDK.
(when (modulep! +spring)
  (hellmacs-doctor-pinned "Spring Boot Tools" hellmacs-jvm-spring-version
                          (hellmacs-jvm-spring-installed-p)
                          (file-directory-p hellmacs-jvm-spring-dir)
                          :where hellmacs-jvm-spring-dir))

(when (modulep! +lombok)
  (cond ((hellmacs-jvm-lombok-jar-valid-p)
         (hellmacs-doctor-ok "Lombok: %s" (abbreviate-file-name hellmacs-jvm-lombok-jar)))
        ((file-exists-p hellmacs-jvm-lombok-jar)
         (hellmacs-doctor-error :topic 'installs "Lombok jar %s fails its SHA-256 check; `bin/hellmacs sync' downloads it again"
                                (abbreviate-file-name hellmacs-jvm-lombok-jar)))
        (t
         (hellmacs-doctor-error :topic 'installs "+lombok is on but Lombok isn't installed; run `bin/hellmacs sync'"))))

(when (modulep! :tools debugger)
  (hellmacs-doctor-pinned "java-debug" hellmacs-jvm-java-debug-version
                          (hellmacs-jvm-java-debug-jar-valid-p) (file-exists-p hellmacs-jvm-java-debug-jar)
                          :stale-note " (the one lsp-java installs can't debug on JDK 22+)"
                          :missing-note " with JDTLS"))
