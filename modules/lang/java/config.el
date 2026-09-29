;;; lang/java/config.el -*- lexical-binding: t; -*-

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


;; Java, through Eclipse JDTLS (lsp-java): project import and indexing
;; (Maven, Gradle), completion with auto-import, navigation into JDK and
;; library classes (decompiled), refactoring and code generation.
;;
;; Owns `C-c l j' (Java-only commands; the rest of `C-c l' is lsp-mode's).
;; JDTLS reports its progress in the echo area -- [FORGE IGNITED] when
;; the server starts, [DAEMON READY] once the project is imported -- and
;; in the mode-line (JVM:igniting / JVM:ready).
;;
;; JDTLS is installed by `bin/hellmacs sync' (or on first use). It needs
;; a JDK 21+ to run; projects can target older ones.
;;
;; Flags:
;;   +lombok       Load Lombok into JDTLS (a pinned jar that `bin/hellmacs
;;                 sync' downloads and checks), so the getters, builders,
;;                 ... Lombok generates resolve instead of showing as errors.
;;   +tree-sitter  Use `java-ts-mode' (`bin/hellmacs sync' builds the pinned grammar)
;;                 instead of the built-in `java-mode'.

(hellmacs-module-load "+paths")

(defgroup hellmacs-jvm nil
  "Hellmacs' Java/JVM support."
  :group 'hellmacs)

(defvar hellmacs-maven-settings nil
  "The Maven settings.xml JDTLS imports projects with.
nil means Maven's own, ~/.m2/settings.xml, when there is one. Your
internal repositories, mirrors and proxy stay configured there, as for
the command line; Hellmacs never writes to it.")

(defun hellmacs-jvm-maven-settings ()
  "The settings.xml JDTLS uses, or nil if there's none."
  (let ((file (expand-file-name (or hellmacs-maven-settings "~/.m2/settings.xml"))))
    (and (file-readable-p file) file)))

;; The JDK that runs JDTLS (`hellmacs-jvm-java-home', chosen among those it
;; runs on) and `hellmacs-jvm-java-executable' are in +paths.el, so
;; `bin/hellmacs doctor' checks the same one.

;; Projects compile against the JDK of the release they target (a Java 8
;; project against a JDK 8), while JDTLS itself runs on 21+ (Phase 12.3).
(defvar lsp-java-configuration-runtimes)

(defcustom hellmacs-jdks nil
  "The JDKs projects compile against, as (NAME . HOME) pairs.
NAME is JDTLS's name for the release: (\"JavaSE-1.8\" . \"/opt/jdk8\"),
\(\"JavaSE-17\" . \"/opt/jdk-17\"). nil uses the JDKs `bin/hellmacs sync'
found: SDKMAN's, /usr/lib/jvm, macOS's, asdf's, jenv's, mise's and
JAVA_HOME. The JDK running JDTLS (`hellmacs-jvm-jdtls-java-home') is
the default for projects that name no release."
  :type '(alist :key-type string :value-type directory))

(defvar hellmacs-jvm--runtimes nil
  "The `lsp-java-configuration-runtimes' Hellmacs set last, to tell it from yours.")

(defun hellmacs-jvm-apply-jdks ()
  "Give JDTLS the JDKs (`hellmacs-jdks') as `lsp-java-configuration-runtimes'.
Runtimes you set yourself are left alone."
  (when (or (seq-empty-p lsp-java-configuration-runtimes)
            (eq lsp-java-configuration-runtimes hellmacs-jvm--runtimes))
    (setq hellmacs-jvm--runtimes
          (hellmacs-jvm-lsp-runtimes (or hellmacs-jdks (hellmacs-jdk-read)))
          lsp-java-configuration-runtimes hellmacs-jvm--runtimes)))

(after! lsp-java
  (hellmacs-jvm-apply-jdks))

;;; Status: echo-area announcements and the mode-line segment ------------------

;; Both are core/hellmacs-lsp-status.el's; this says which of JDTLS's
;; signals mean "imported" and "failed".
(require 'hellmacs-lsp-status)

(defun hellmacs-jvm-state (root)
  "The state of JDTLS for project ROOT: igniting, ready, failed or nil."
  (hellmacs-lsp-status-state 'jdtls root))

(defun hellmacs-jvm--import-failure-reason (message)
  "A short reason for the import failure described by log MESSAGE."
  (cond ((string-match "Cannot find a Java installation[^\n]*languageVersion=\\([0-9]+\\)" message)
         (format "the build needs a JDK %s that Gradle can't find (install it, then C-c l j u)"
                 (match-string 1 message)))
        ((string-match-p "Gradle" message) "the Gradle sync failed (see the *lsp-log* buffer)")
        ((string-match-p "Maven" message) "the Maven import failed (see the *lsp-log* buffer)")
        (t "see the *lsp-log* buffer")))

(defun hellmacs-jvm--note-log (root message)
  "React to JDTLS log MESSAGE for project ROOT: a failed import is announced.
JDTLS goes on to say ServiceReady even then, but nothing works."
  (when (string-match-p "\\`[^\n]*Synchronize project .* failed" message)
    (hellmacs-lsp-status-fail 'jdtls root (hellmacs-jvm--import-failure-reason message))))

(defun hellmacs-jvm--note-notification (root method params)
  "React to JDTLS's notification METHOD with PARAMS for project ROOT.
Its `language/status' ServiceReady means ready, unless the import failed;
a later ProjectStatus OK (after fixing the cause) means it recovered."
  (when (equal method "language/status")
    (let ((type (hellmacs-lsp-status-get params :type)))
      (cond ((equal type "ServiceReady")
             (hellmacs-lsp-status-ready 'jdtls root))
            ((and (equal type "ProjectStatus")
                  (equal (hellmacs-lsp-status-get params :message) "OK"))
             (hellmacs-lsp-status-ready 'jdtls root 'recovered))))))

(hellmacs-lsp-status-register 'jdtls
  :label "JDTLS"
  :on-log #'hellmacs-jvm--note-log
  :on-notification #'hellmacs-jvm--note-notification)

;;; lsp-java -------------------------------------------------------------------

(defconst hellmacs-jvm--base-vmargs
  '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90"
    "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms256m")
  "JVM arguments for JDTLS: lsp-java's defaults, with twice the heap (1GB
is tight for real multi-module projects).")

(defun hellmacs-jvm--vmargs ()
  "Return the JVM arguments JDTLS starts with.
With +lombok, Lombok is loaded as a javaagent, so JDTLS sees the code
Lombok generates (getters, builders, ...). Only its existence is
checked here; `bin/hellmacs sync' and doctor verify its checksum. Your
proxy and CA come last (`hellmacs-net-jvm-options')."
  (append hellmacs-jvm--base-vmargs
          (hellmacs-net-jvm-options)
          (when (modulep! +lombok)
            (if (file-exists-p hellmacs-jvm-lombok-jar)
                (list (concat "-javaagent:" hellmacs-jvm-lombok-jar))
              (display-warning
               'hellmacs "+lombok: the Lombok jar isn't installed; run `bin/hellmacs sync'")
              nil))))

;; A missing JDTLS is installed with sync's pinned installer: lsp-java's
;; runs Maven on an unpinned pom.xml (docs/roadmap.md, 12.1).
(defun hellmacs-jvm--install-server-a (_client callback error-callback _update)
  "Replaces `lsp-java--ensure-server'."
  (hellmacs-lsp-install-pinned '(:lang . java) #'hellmacs-jvm-sync-install-server
                               callback error-callback))
(advice-add 'lsp-java--ensure-server :override #'hellmacs-jvm--install-server-a)

(use-package lsp-java
  ;; Loaded in the background after startup, so opening the first Java
  ;; file doesn't wait for it. (Otherwise lsp-mode loads it itself when
  ;; the first Java buffer asks for a server: `lsp-client-packages'.)
  :defer-incrementally (lsp-java)
  :hook
  ((java-mode java-ts-mode) . lsp-deferred)
  :custom
  (lsp-java-java-path (hellmacs-jvm-java-executable))
  (lsp-java-vmargs (hellmacs-jvm--vmargs))
  ;; Your build tools' own settings, as on the command line: Maven's
  ;; settings.xml, Gradle's home (with its gradle.properties and init.d),
  ;; and the proxy and truststore for the Gradle JVM JDTLS imports with.
  (lsp-java-configuration-maven-user-settings (hellmacs-jvm-maven-settings))
  (lsp-java-import-gradle-user-home (getenv "GRADLE_USER_HOME"))
  (lsp-java-import-gradle-jvm-arguments (and (hellmacs-net-jvm-options)
                                             (vconcat (hellmacs-net-jvm-options))))
  (lsp-java-content-provider-preferred "fernflower") ; decompile library classes for M-.
  (lsp-java-maven-download-sources t)
  (lsp-java-references-code-lens-enabled t)
  (lsp-java-implementations-code-lens-enabled t)
  (lsp-java-completion-favorite-static-members
   ["org.junit.jupiter.api.Assertions.*" "org.assertj.core.api.Assertions.*"
    "org.mockito.Mockito.*" "org.mockito.ArgumentMatchers.*"]))

;; `C-x p c' proposes the project's own Gradle/Maven build, and tests run
;; through it (:tools build).
(declare-function hellmacs-forge-annotated-test-at-point "../../tools/build/autoload")

(defun hellmacs-jvm-test-method ()
  "The name of the JUnit test method point is in, or nil.
Not a helper or a setup method: see `hellmacs-forge-annotated-test-at-point'."
  (hellmacs-forge-annotated-test-at-point "\\_<\\([[:alpha:]_$][[:alnum:]_$]*\\)[ \t\n]*("))

(defun hellmacs-jvm--setup-build-h ()
  "Use the project's build, and Java's test methods, in this buffer."
  (hellmacs-forge-setup-build-h)
  ;; The class is the file's name: forge's default.
  (setq-local hellmacs-forge-test-method-function #'hellmacs-jvm-test-method))

(when (modulep! :tools build)
  (add-hook! (java-mode java-ts-mode) #'hellmacs-jvm--setup-build-h))

;; `C-c h r' (the Crucible) hot-swaps into a debug session (:tools debugger).
(declare-function dap--cur-session "ext:dap-mode")
(declare-function hellmacs-debug-hot-swap "../../tools/debugger/autoload")

(defun hellmacs-jvm-reload ()
  "Save and hot-swap the changed classes into the running debug session."
  (if (and (fboundp 'dap--cur-session) (dap--cur-session))
      (hellmacs-debug-hot-swap)
    (user-error "The Crucible is cold: no debug session to hot-swap into (C-c d d starts one)")))

(defun hellmacs-jvm--setup-reload-h ()
  (setq-local hellmacs-reload-function #'hellmacs-jvm-reload))

;; +spring: Spring Boot's language server (Phase 12.4), through lsp-java's
;; lsp-java-boot, beside JDTLS. It completes and checks properties in
;; application*.yml/.properties, and knows beans and request mappings
;; (workspace symbols `@+' and `@/'). `bin/hellmacs sync' installs the
;; pinned server (+paths.el). lsp-java-boot's own launch is for an older
;; server that connected back over TCP: this one talks over stdio, as VS
;; Code runs it, and embeds a web server, which must stay off.
(defvar lsp-java-bundles)
(defvar lsp-language-id-configuration)

(declare-function lsp-stdio-connection "ext:lsp-mode")
(defvar lsp-clients)

(defun hellmacs-jvm-spring-ls-command ()
  "The command starting the Spring Boot server, which talks over stdio.
Its log goes to files in the cache: on the console it would mix with
the protocol."
  (let ((logs (expand-file-name "spring-boot/" hellmacs-cache-dir)))
    (make-directory logs t)
    (list (hellmacs-jvm-java-executable)
          "-Xmx1024m"
          "-Dsts.lsp.client=vscode"
          "-Dspring.config.location=classpath:/application.properties"
          "-Dspring.main.web-application-type=NONE"
          "-Djdk.util.zip.disableZip64ExtraFieldValidation=true"
          "-Dlogging.pattern.console="
          (concat "-Dsts.log.file=" (expand-file-name "sts.log" logs))
          (concat "-Dlogging.file.name=" (expand-file-name "server.log" logs))
          "-jar" (hellmacs-jvm-spring-server-jar))))

(declare-function lsp--path-to-uri "ext:lsp-mode")
(declare-function lsp-session "ext:lsp-mode")
(declare-function lsp-session-folders "ext:lsp-mode")

(defun hellmacs-jvm-spring-initialization-options (folders)
  "What the Spring Boot server needs to initialize, for the project FOLDERS.
As VS Code sends it; without it, the server fails on a JSON null."
  (list :workspaceFolders (vconcat (mapcar #'lsp--path-to-uri folders))
        :enableJdtClasspath :json-false))

(defun hellmacs-jvm--spring-lsp-h ()
  "Start lsp in a Spring Boot config file (application.yml...), for its server."
  (when (and buffer-file-name (hellmacs-spring-config-file-p buffer-file-name))
    (lsp-deferred)))

(defun hellmacs-jvm--spring-client-use-stdio ()
  "Have lsp-java-boot's client, with its handlers, talk over stdio instead of TCP.
Returns non-nil if it could. Each slot is stored at its position, looked
up by name now: no `setf' of it can be expanded where this file is read,
before lsp-mode (or cl-lib's setters) are loaded. Should lsp-java-boot
no longer register the client, or lsp-mode rename a slot, a warning says
so, rather than an error in the middle of loading lsp-java."
  (condition-case err
      (let ((client (or (gethash 'boot-ls lsp-clients)
                        (error "lsp-java-boot registered no `boot-ls' client")))
            (connection (cl-struct-slot-offset 'lsp--client 'new-connection))
            (options (cl-struct-slot-offset 'lsp--client 'initialization-options)))
        (aset client connection (lsp-stdio-connection #'hellmacs-jvm-spring-ls-command
                                                      #'hellmacs-jvm-spring-server-jar))
        (aset client options (lambda () (hellmacs-jvm-spring-initialization-options
                                         (lsp-session-folders (lsp-session)))))
        t)
    (error
     (display-warning
      'hellmacs (format "+spring: the Spring Boot server can't be set up (%s); \
lsp-java or lsp-mode may have changed" (error-message-string err)))
     nil)))

(when (modulep! +spring)
  (after! lsp-java
    ;; Before JDTLS starts: its extensions come with its initialization.
    (when (hellmacs-jvm-spring-installed-p)
      (setq lsp-java-bundles (append lsp-java-bundles (hellmacs-jvm-spring-extension-jars))))
    (require 'lsp-java-boot)
    (advice-add 'lsp-java-boot--server-jar :override #'hellmacs-jvm-spring-server-jar)
    (hellmacs-jvm--spring-client-use-stdio))
  (after! lsp-mode
    ;; First, so they win over the modes' own (yaml, properties).
    (dolist (entry (reverse hellmacs-spring-language-ids))
      (add-to-list 'lsp-language-id-configuration entry)))
  (add-hook! (yaml-mode conf-javaprop-mode) #'hellmacs-jvm--spring-lsp-h))

;; A launched program runs on its project's JDK (a Java 8 project on JDK 8),
;; not on the one running JDTLS. java-debug falls back to JDTLS's own
;; without a :javaExec, and dap-java gives none; this asks JDTLS for the
;; project's, as VS Code does.
(declare-function lsp-send-execute-command "ext:lsp-mode")

(defun hellmacs-jvm--resolve-java-executable (main-class project-name)
  "The java of the JDK PROJECT-NAME compiles against, as JDTLS resolves it for
MAIN-CLASS; nil if it can't say."
  (ignore-errors
    (let ((java (lsp-send-execute-command "vscode.java.resolveJavaExecutable"
                                          (vector main-class project-name))))
      (and (stringp java) (not (string-empty-p java)) java))))

(defun hellmacs-jvm--launch-on-project-jdk-a (conf)
  "Give launch configuration CONF its project's java as :javaExec, unless it has one.
A `:filter-return' advice on `dap-java--populate-launch-args'."
  (let ((main (plist-get conf :mainClass))
        (project (plist-get conf :projectName)))
    (if-let* (((not (plist-get conf :javaExec)))
              ((and main project))
              (java (hellmacs-jvm--resolve-java-executable main project)))
        (plist-put conf :javaExec java)
      conf)))

;; Debugging (:tools debugger): dap-java, shipped with lsp-java, loads with it.
(when (modulep! :tools debugger)
  (add-hook! (java-mode java-ts-mode) #'hellmacs-jvm--setup-reload-h)
  (with-eval-after-load 'dap-java
    (advice-add 'dap-java--populate-launch-args :filter-return #'hellmacs-jvm--launch-on-project-jdk-a)
    (setq dap-java-java-command (hellmacs-jvm-java-executable)
          ;; JDTLS already builds on save; don't ask before every launch.
          dap-java-build 'always)
    ;; For a JVM started with -agentlib:jdwp=transport=dt_socket,server=y,address=5005
    (dap-register-debug-template "Java Attach (localhost:5005)"
                                 (list :type "java" :request "attach"
                                       :hostName "localhost" :port 5005))))

;;; C-c l j -- Java commands ---------------------------------------------------

(defvar-keymap hellmacs-jvm-map
  :doc "Java commands, on `C-c l j' in Java buffers."
  "b" (cons "build project" #'lsp-java-build-project)
  "u" (cons "update project config" #'hellmacs-jvm-update-project-configuration)
  "o" (cons "organize imports" #'lsp-java-organize-imports)
  "i" (cons "add unimplemented methods" #'lsp-java-add-unimplemented-methods)
  "g" (cons "generate getters/setters" #'lsp-java-generate-getters-and-setters)
  "s" (cons "generate toString" #'lsp-java-generate-to-string)
  "e" (cons "generate equals/hashCode" #'lsp-java-generate-equals-and-hash-code)
  "m" (cons "extract method" #'lsp-java-extract-method)
  "v" (cons "extract local variable" #'lsp-java-extract-to-local-variable)
  "c" (cons "extract constant" #'lsp-java-extract-to-constant)
  "h" (cons "type hierarchy" #'lsp-java-type-hierarchy)
  "t" (cons "run test at point" #'hellmacs-jvm-test-at-point)
  "T" (cons "run test class" #'hellmacs-jvm-test-class))

;; In Hellmacs' own minor mode, not cc-mode's or java-ts-mode's map:
;; `C-c' and a letter is the user's, and Hellmacs binds for the user.
;; lsp-mode's `C-c l' map has no `j', so the full key reaches this one.
(defvar-keymap hellmacs-jvm-keys-mode-map
  "C-c l j" (cons "java" hellmacs-jvm-map))

(define-minor-mode hellmacs-jvm-keys-mode
  "Java commands on `C-c l j' (`hellmacs-jvm-map')."
  :keymap hellmacs-jvm-keys-mode-map)

(add-hook! (java-mode java-ts-mode) #'hellmacs-jvm-keys-mode)
