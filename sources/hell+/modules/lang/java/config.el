;;; lang/java/config.el -*- lexical-binding: t; -*-

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


;; Java, through Eclipse JDTLS (lsp-java): project import and indexing
;; (Maven, Gradle), completion with auto-import, navigation into JDK and
;; library classes (decompiled), refactoring and code generation.
;;
;; Java-only commands on the localleader, `C-c l' (the language server's
;; common ones are the `C-c c' code group, tests `C-c l t').
;; JDTLS reports its progress in the echo area -- [FORGE IGNITED] when
;; the server starts, [DAEMON READY] once the project is imported -- and
;; in the mode-line (JVM:igniting / JVM:ready).
;;
;; JDTLS is installed by `bin/hell sync' (or on first use). It needs
;; a JDK 21+ to run; projects can target older ones.
;;
;; Flags:
;;   +lombok       Load Lombok into JDTLS (a pinned jar that `bin/hell
;;                 sync' downloads and checks), so the getters, builders,
;;                 ... Lombok generates resolve instead of showing as errors.
;;   +tree-sitter  Use `java-ts-mode' (`bin/hell sync' builds the pinned grammar)
;;                 instead of the built-in `java-mode'.

(hell-module-load "+paths")

(defgroup hell-jvm nil
  "Hell Emacs' Java/JVM support."
  :group 'hell)

(defvar hell-maven-settings nil
  "The Maven settings.xml JDTLS imports projects with.
nil means Maven's own, ~/.m2/settings.xml, when there is one. Your
internal repositories, mirrors and proxy stay configured there, as for
the command line; Hell Emacs never writes to it.")

(defun hell-jvm-maven-settings ()
  "The settings.xml JDTLS uses, or nil if there's none."
  (let ((file (expand-file-name (or hell-maven-settings "~/.m2/settings.xml"))))
    (and (file-readable-p file) file)))

;; The JDK that runs JDTLS (`hell-jvm-java-home', chosen among those it
;; runs on) and `hell-jvm-java-executable' are in +paths.el, so
;; `bin/hell doctor' checks the same one.

;; Projects compile against the JDK of the release they target (a Java 8
;; project against a JDK 8), while JDTLS itself runs on 21+ (Phase 12.3).
(defvar lsp-java-configuration-runtimes)

(defcustom hell-jdks nil
  "The JDKs projects compile against, as (NAME . HOME) pairs.
NAME is JDTLS's name for the release: (\"JavaSE-1.8\" . \"/opt/jdk8\"),
\(\"JavaSE-17\" . \"/opt/jdk-17\"). nil uses the JDKs `bin/hell sync'
found: SDKMAN's, /usr/lib/jvm, macOS's, asdf's, jenv's, mise's and
JAVA_HOME. The JDK running JDTLS (`hell-jvm-jdtls-java-home') is
the default for projects that name no release."
  :type '(alist :key-type string :value-type directory))

(defvar hell-jvm--runtimes nil
  "The `lsp-java-configuration-runtimes' Hell Emacs set last, to tell it from yours.")

(defun hell-jvm-apply-jdks ()
  "Give JDTLS the JDKs (`hell-jdks') as `lsp-java-configuration-runtimes'.
Runtimes you set yourself are left alone."
  (when (or (seq-empty-p lsp-java-configuration-runtimes)
            (eq lsp-java-configuration-runtimes hell-jvm--runtimes))
    (setq hell-jvm--runtimes
          (hell-jvm-lsp-runtimes (or hell-jdks (hell-jdk-read)))
          lsp-java-configuration-runtimes hell-jvm--runtimes)))

(after! lsp-java
  (hell-jvm-apply-jdks))

;;; Status: echo-area announcements and the mode-line segment ------------------

;; Both are lisp/lib/lsp-status.el's; this says which of JDTLS's
;; signals mean "imported" and "failed".
(hell-require 'hell-lib 'lsp-status)

(defun hell-jvm-state (root)
  "The state of JDTLS for project ROOT: igniting, ready, failed or nil."
  (hell-lsp-status-state 'jdtls root))

(defun hell-jvm--import-failure-reason (message)
  "A short reason for the import failure described by log MESSAGE."
  (cond ((string-match-p "Timeout waiting to lock\\|currently in use by another process" message)
         ;; Another Gradle daemon (often another version, from another
         ;; project) holds ~/.gradle's cache lock and doesn't let go.
         "another Gradle process holds Gradle's cache lock (stop it: `gradle --stop', or kill the old daemon), then M-x lsp-workspace-restart")
        ((string-match "Cannot find a Java installation[^\n]*languageVersion=\\([0-9]+\\)" message)
         (format "the build needs a JDK %s that Gradle can't find (install it, then C-c l u)"
                 (match-string 1 message)))
        ((string-match-p "Gradle" message) "the Gradle sync failed (see the *lsp-log* buffer)")
        ((string-match-p "Maven" message) "the Maven import failed (see the *lsp-log* buffer)")
        (t "see the *lsp-log* buffer")))

(defvar lsp-java-import-gradle-annotation-processing-enabled)
(defvar lsp--cur-workspace)
(defvar lsp--buffer-workspaces)
(declare-function lsp-find-workspace "lsp-mode")
(declare-function lsp-configuration-section "lsp-mode")
(declare-function lsp--set-configuration "lsp-mode")
(declare-function lsp-request-async "lsp-mode")

(defvar hell-jvm--reimported nil
  "Project roots being imported again without annotation processing, until
that second import reports (see `hell-jvm-import-settled-p').")

(defun hell-jvm--gradle9-apt-failure-p (message)
  "Non-nil if MESSAGE is Gradle 9 refusing JDTLS's annotation-processing script.
Gradle 9 won't resolve a project's `annotationProcessor' configuration
from an init script without a lock (Spring Framework's multi-project
build, for one); nothing else in the import is wrong."
  (string-match-p "annotationProcessor' was attempted without an exclusive lock" message))

(defun hell-jvm--reimport-without-apt (root)
  "Import ROOT again, in place, with annotation processing off for Gradle.
Off for the rest of the session, which the announcement says. JDTLS gets
the new setting, then imports the workspace again; a ProjectStatus OK
afterwards is the recovery `hell-jvm--note-notification' knows."
  (setq lsp-java-import-gradle-annotation-processing-enabled nil)
  (push root hell-jvm--reimported)
  (run-at-time 0 nil
               (lambda ()
                 (when-let* ((workspace (lsp-find-workspace 'jdtls root)))
                   (let ((lsp--cur-workspace workspace)
                         (lsp--buffer-workspaces (list workspace)))
                     (lsp--set-configuration (lsp-configuration-section "java"))
                     (lsp-request-async "workspace/executeCommand"
                                        (list :command "java.project.import")
                                        #'ignore))))))

(defvar hell-jvm--unresolved (make-hash-table :test #'equal)
  "Project root -> the dependencies its import couldn't resolve.")

(defun hell-jvm--note-unresolved (root message)
  "Remember the dependency in JDTLS log MESSAGE that ROOT's import couldn't resolve."
  (when (string-match "Unresolved dependency: \\([^ \n]+\\)" message)
    (let ((dep (match-string 1 message))
          (deps (gethash root hell-jvm--unresolved)))
      (unless (member dep deps)
        (puthash root (cons dep deps) hell-jvm--unresolved)))))

(defun hell-jvm--warn-unresolved-h (server root)
  "Once ROOT is imported, say which dependencies it couldn't resolve.
Their classes neither complete nor compile until the build can fetch
them. For `hell-lsp-status-ready-functions'."
  (when-let* (((eq server 'jdtls))
              (deps (gethash root hell-jvm--unresolved)))
    (remhash root hell-jvm--unresolved)
    ;; After the ready message has had its moment in the echo area.
    (run-with-timer
     2 nil
     (lambda ()
       (message "%s" (propertize
                      (format "%s: %d unresolved %s, whose classes won't complete: %s (is its repository reachable, or mavenLocal published?)"
                              (abbreviate-file-name root) (length deps)
                              (if (cdr deps) "dependencies" "dependency")
                              (string-join (reverse deps) ", "))
                      'face 'warning))))))

(add-hook 'hell-lsp-status-ready-functions #'hell-jvm--warn-unresolved-h)

(defun hell-jvm--note-log (root message)
  "React to JDTLS log MESSAGE for project ROOT: a failed import is announced.
JDTLS goes on to say ServiceReady even then, but nothing works. Gradle 9
refusing annotation processing is worked around: imported again without it."
  (hell-jvm--note-unresolved root message)
  (when (or (string-match-p "\\`[^\n]*Synchronize project .* failed" message)
            ;; While importing, a Gradle model the tooling API couldn't build.
            (string-match-p "\\`[^\n]*Could not fetch model of type" message)
            ;; Gradle waiting for its cache lock, which another process holds.
            (string-match-p "Timeout waiting to lock" message))
    (let ((apt (hell-jvm--gradle9-apt-failure-p message)))
      (cond ((and apt lsp-java-import-gradle-annotation-processing-enabled)
             (hell-lsp-status-fail
              'jdtls root "Gradle 9 refused JDTLS's annotation processing; importing again without it")
             (hell-jvm--reimport-without-apt root))
            ;; The same failure repeated, from before the second import.
            ((and apt (member root hell-jvm--reimported)))
            (t
             ;; A second import that failed too: that's the verdict.
             (setq hell-jvm--reimported (delete root hell-jvm--reimported))
             (hell-lsp-status-fail 'jdtls root (hell-jvm--import-failure-reason message)))))))

(defun hell-jvm--forget-reimport-h (server root)
  "SERVER is ready for ROOT: an import of ROOT being tried again is over.
For `hell-lsp-status-ready-functions'."
  (when (eq server 'jdtls)
    (setq hell-jvm--reimported (delete root hell-jvm--reimported))))

(add-hook 'hell-lsp-status-ready-functions #'hell-jvm--forget-reimport-h)

(defun hell-jvm-import-settled-p (root)
  "Non-nil once ROOT's import has an outcome: ready, or failed for good.
Not while a failed import is being tried again."
  (pcase (hell-jvm-state root)
    ('ready t)
    ('failed (not (member root hell-jvm--reimported)))))

(defun hell-jvm--note-notification (root method params)
  "React to JDTLS's notification METHOD with PARAMS for project ROOT.
Its `language/status' ServiceReady means ready, unless the import failed;
a later ProjectStatus OK (after fixing the cause) means it recovered."
  (when (equal method "language/status")
    (let ((type (hell-lsp-status-get params :type)))
      (cond ((equal type "ServiceReady")
             (hell-lsp-status-ready 'jdtls root))
            ((and (equal type "ProjectStatus")
                  (equal (hell-lsp-status-get params :message) "OK"))
             (hell-lsp-status-ready 'jdtls root 'recovered))))))

(hell-lsp-status-register 'jdtls
  :label "JDTLS"
  :on-log #'hell-jvm--note-log
  :on-notification #'hell-jvm--note-notification)

;;; lsp-java -------------------------------------------------------------------

(defconst hell-jvm--base-vmargs
  '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90"
    "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms256m")
  "JVM arguments for JDTLS: lsp-java's defaults, with twice the heap (1GB
is tight for real multi-module projects).")

(defun hell-jvm--vmargs ()
  "Return the JVM arguments JDTLS starts with.
With +lombok, Lombok is loaded as a javaagent, so JDTLS sees the code
Lombok generates (getters, builders, ...). Only its existence is
checked here; `bin/hell sync' and doctor verify its checksum. Your
proxy and CA come last (`hell-net-jvm-options')."
  (append hell-jvm--base-vmargs
          (hell-net-jvm-options)
          (when (modulep! +lombok)
            (if (file-exists-p hell-jvm-lombok-jar)
                (list (concat "-javaagent:" hell-jvm-lombok-jar))
              (display-warning
               'hell "+lombok: the Lombok jar isn't installed; run `bin/hell sync'")
              nil))))

;; A missing JDTLS is installed with sync's pinned installer: lsp-java's
;; runs Maven on an unpinned pom.xml (docs/roadmap.md, 12.1).
(defun hell-jvm--install-server-a (_client callback error-callback _update)
  "Replaces `lsp-java--ensure-server'."
  (hell-lsp-install-pinned '(:lang . java) #'hell-jvm-sync-install-server
                           callback error-callback))
(advice-add 'lsp-java--ensure-server :override #'hell-jvm--install-server-a)

(defvar c-basic-offset)
(defvar java-ts-mode-indent-offset)

(defun hell-jvm-format-tab-size ()
  "JDTLS's `java.format.tabSize': the indent of this Java buffer, else of any.
lsp-java's own reads `c-basic-offset' in whichever buffer is current when a
server asks for its settings; from a Kotlin buffer that's `set-from-style',
the reply fails to encode, and it's never sent."
  (let ((java-p (lambda () (derived-mode-p 'java-mode 'java-ts-mode))))
    (or (seq-some (lambda (buf)
                    (with-current-buffer buf
                      (when (funcall java-p)
                        (let ((n (if (derived-mode-p 'java-ts-mode)
                                     (bound-and-true-p java-ts-mode-indent-offset)
                                   (bound-and-true-p c-basic-offset))))
                          (and (integerp n) n)))))
                  (cons (current-buffer) (buffer-list)))
        4)))

(use-package lsp-java
  ;; Loaded in the background after startup, so opening the first Java
  ;; file doesn't wait for it. (Otherwise lsp-mode loads it itself when
  ;; the first Java buffer asks for a server: `lsp-client-packages'.)
  :defer-incrementally (lsp-java)
  :hook
  ((java-mode java-ts-mode) . lsp-deferred)
  :custom
  (lsp-java-java-path (hell-jvm-java-executable))
  (lsp-java-vmargs (hell-jvm--vmargs))
  ;; Your build tools' own settings, as on the command line: Maven's
  ;; settings.xml, Gradle's home (with its gradle.properties and init.d),
  ;; and the proxy and truststore for the Gradle JVM JDTLS imports with.
  (lsp-java-configuration-maven-user-settings (hell-jvm-maven-settings))
  (lsp-java-import-gradle-user-home (getenv "GRADLE_USER_HOME"))
  (lsp-java-import-gradle-jvm-arguments (and (hell-net-jvm-options)
                                             (vconcat (hell-net-jvm-options))))
  (lsp-java-content-provider-preferred "fernflower") ; decompile library classes for M-.
  (lsp-java-maven-download-sources t)
  (lsp-java-format-tab-size #'hell-jvm-format-tab-size)
  ;; Off, as in VS Code: on a big class these lenses fill JDTLS's request
  ;; threads with workspace searches, and the import took 3x as long on
  ;; the reference monorepo (docs/roadmap.md, 12.7 Tuning).
  (lsp-java-references-code-lens-enabled nil)
  (lsp-java-implementations-code-lens-enabled nil)
  (lsp-java-completion-favorite-static-members
   ["org.junit.jupiter.api.Assertions.*" "org.assertj.core.api.Assertions.*"
    "org.mockito.Mockito.*" "org.mockito.ArgumentMatchers.*"]))

;; `C-x p c' proposes the project's own Gradle/Maven build, and tests run
;; through it (:tools build).
(declare-function hell-forge-annotated-test-at-point "../../tools/build/autoload")

(defun hell-jvm-test-method ()
  "The name of the JUnit test method point is in, or nil.
Not a helper or a setup method: see `hell-forge-annotated-test-at-point'."
  (hell-forge-annotated-test-at-point "\\_<\\([[:alpha:]_$][[:alnum:]_$]*\\)[ \t\n]*("))

(defun hell-jvm--setup-build-h ()
  "Use the project's build, and Java's test methods, in this buffer.
With `:tools debugger', tests run through dap-java's JUnit runner."
  (hell-forge-setup-build-h)
  ;; The class is the file's name: forge's default.
  (setq-local hell-forge-test-method-function #'hell-jvm-test-method)
  (when (modulep! :tools debugger)
    (setq-local hell-forge-test-run-function #'hell-jvm-run-test)))

(when (modulep! :tools build)
  (add-hook! (java-mode java-ts-mode) #'hell-jvm--setup-build-h))

;; `C-c h r' (the Crucible) hot-swaps into a debug session (:tools debugger).
(declare-function dap--cur-session "ext:dap-mode")
(declare-function hell-debug-hot-swap "../../tools/debugger/autoload")

(defun hell-jvm-reload ()
  "Save and hot-swap the changed classes into the running debug session."
  (if (and (fboundp 'dap--cur-session) (dap--cur-session))
      (hell-debug-hot-swap)
    (user-error "The Crucible is cold: no debug session to hot-swap into (C-c d d starts one)")))

(defun hell-jvm--setup-reload-h ()
  (setq-local hell-reload-function #'hell-jvm-reload))

;; +spring: Spring Boot's language server (Phase 12.4), through lsp-java's
;; lsp-java-boot, beside JDTLS. It completes and checks properties in
;; application*.yml/.properties, and knows beans and request mappings
;; (workspace symbols `@+' and `@/'). `bin/hell sync' installs the
;; pinned server (+paths.el). lsp-java-boot's own launch is for an older
;; server that connected back over TCP: this one talks over stdio, as VS
;; Code runs it, and embeds a web server, which must stay off.
(defvar lsp-java-bundles)
(defvar lsp-language-id-configuration)

(declare-function lsp-stdio-connection "ext:lsp-mode")
(defvar lsp-clients)

(defun hell-jvm-spring-ls-command ()
  "The command starting the Spring Boot server, which talks over stdio.
Its log goes to files in the cache: on the console it would mix with
the protocol."
  (let ((logs (expand-file-name "spring-boot/" hell-cache-dir)))
    (make-directory logs t)
    (list (hell-jvm-java-executable)
          "-Xmx1024m"
          "-Dsts.lsp.client=vscode"
          "-Dspring.config.location=classpath:/application.properties"
          "-Dspring.main.web-application-type=NONE"
          "-Djdk.util.zip.disableZip64ExtraFieldValidation=true"
          "-Dlogging.pattern.console="
          (concat "-Dsts.log.file=" (expand-file-name "sts.log" logs))
          (concat "-Dlogging.file.name=" (expand-file-name "server.log" logs))
          "-jar" (hell-jvm-spring-server-jar))))

(declare-function lsp--path-to-uri "ext:lsp-mode")
(declare-function lsp-session "ext:lsp-mode")
(declare-function lsp-session-folders "ext:lsp-mode")

(defun hell-jvm-spring-initialization-options (folders)
  "What the Spring Boot server needs to initialize, for the project FOLDERS.
As VS Code sends it; without it, the server fails on a JSON null."
  (list :workspaceFolders (vconcat (mapcar #'lsp--path-to-uri folders))
        :enableJdtClasspath :json-false))

(defun hell-jvm--spring-lsp-h ()
  "Start lsp in a Spring Boot config file (application.yml...), for its server."
  (when (and buffer-file-name (hell-spring-config-file-p buffer-file-name))
    (lsp-deferred)))

(defun hell-jvm--spring-client-use-stdio ()
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
            (options (cl-struct-slot-offset 'lsp--client 'initialization-options))
            (notifications (cl-struct-slot-offset 'lsp--client 'notification-handlers)))
        (aset client connection (lsp-stdio-connection #'hell-jvm-spring-ls-command
                                                      #'hell-jvm-spring-server-jar))
        (aset client options (lambda () (hell-jvm-spring-initialization-options
                                         (lsp-session-folders (lsp-session)))))
        ;; Its notifications for VS Code's views: quiet, not "Unknown notification".
        (hell-spring-ignore-notifications (aref client notifications))
        t)
    (error
     (display-warning
      'hell (format "+spring: the Spring Boot server can't be set up (%s); \
lsp-java or lsp-mode may have changed" (error-message-string err)))
     nil)))

(defconst hell-jvm--spring-lifecycle-commands
  '("vscode-spring-boot.ls.start" "vscode-spring-boot.ls.stop")
  "What JDTLS's Spring extension asks VS Code to do with the Spring server.")

(defun hell-jvm--spring-client-command-a (orig workspace params)
  "Around lsp-java's handler of JDTLS's `workspace/executeClientCommand'.
JDTLS waits for the answer, with its import on hold, so it always gets
one. Starting and stopping the Spring server is Hell Emacs' own business
(lsp-java would forward them to it, and fail on their empty arguments);
anything else is forwarded as before, and a failure is logged instead
of leaving JDTLS waiting."
  (let ((command (hell-lsp-status-get params :command)))
    (unless (member command hell-jvm--spring-lifecycle-commands)
      (condition-case err
          (funcall orig workspace params)
        (error (message "Hell Emacs: JDTLS's client command %s failed: %s"
                        command (error-message-string err))
               nil)))))

(when (modulep! +spring)
  (after! lsp-java
    ;; Before JDTLS starts: its extensions come with its initialization.
    (when (hell-jvm-spring-installed-p)
      (setq lsp-java-bundles (append lsp-java-bundles (hell-jvm-spring-extension-jars))))
    (require 'lsp-java-boot)
    (advice-add 'lsp-java-boot--server-jar :override #'hell-jvm-spring-server-jar)
    (advice-add 'lsp-java-boot--workspace-execute-client-command
                :around #'hell-jvm--spring-client-command-a)
    (hell-jvm--spring-client-use-stdio))
  (after! lsp-mode
    ;; First, so they win over the modes' own (yaml, properties).
    (dolist (entry (reverse hell-spring-language-ids))
      (add-to-list 'lsp-language-id-configuration entry)))
  (add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode))
  (add-hook! (yaml-ts-mode conf-javaprop-mode) #'hell-jvm--spring-lsp-h))

;; A launched program runs on its project's JDK (a Java 8 project on JDK 8),
;; not on the one running JDTLS. java-debug falls back to JDTLS's own
;; without a :javaExec, and dap-java gives none; this asks JDTLS for the
;; project's, as VS Code does.
(declare-function lsp-send-execute-command "ext:lsp-mode")

(defun hell-jvm--resolve-java-executable (main-class project-name)
  "The java of the JDK PROJECT-NAME compiles against, as JDTLS resolves it for
MAIN-CLASS; nil if it can't say."
  (ignore-errors
    (let ((java (lsp-send-execute-command "vscode.java.resolveJavaExecutable"
                                          (vector main-class project-name))))
      (and (stringp java) (not (string-empty-p java)) java))))

(defun hell-jvm--launch-on-project-jdk-a (conf)
  "Give launch configuration CONF its project's java as :javaExec, unless it has one.
A `:filter-return' advice on `dap-java--populate-launch-args'."
  (let ((main (plist-get conf :mainClass))
        (project (plist-get conf :projectName)))
    (if-let* (((not (plist-get conf :javaExec)))
              ((and main project))
              (java (hell-jvm--resolve-java-executable main project)))
        (plist-put conf :javaExec java)
      conf)))

;; Debugging (:tools debugger): dap-java, shipped with lsp-java, loads with it.
(when (modulep! :tools debugger)
  (add-hook! (java-mode java-ts-mode) #'hell-jvm--setup-reload-h)
  (with-eval-after-load 'dap-java
    (advice-add 'dap-java--populate-launch-args :filter-return #'hell-jvm--launch-on-project-jdk-a)
    (setq dap-java-java-command (hell-jvm-java-executable)
          ;; JDTLS already builds on save; don't ask before every launch.
          dap-java-build 'always)
    ;; For a JVM started with -agentlib:jdwp=transport=dt_socket,server=y,address=5005
    (dap-register-debug-template "Java Attach (localhost:5005)"
                                 (list :type "java" :request "attach"
                                       :hostName "localhost" :port 5005))))

;;; C-c l -- Java commands (the localleader) ----------------------------------
;;
;; Organize imports is the code group's `C-c c o'; tests are the build's
;; `C-c l t' group.

(hell-localleader-def '(java-mode java-ts-mode)
  "b" '("build project" . lsp-java-build-project)
  "u" '("update project config" . hell-jvm-update-project-configuration)
  "i" '("add unimplemented methods" . lsp-java-add-unimplemented-methods)
  "g" '("generate getters/setters" . lsp-java-generate-getters-and-setters)
  "s" '("generate toString" . lsp-java-generate-to-string)
  "e" '("generate equals/hashCode" . lsp-java-generate-equals-and-hash-code)
  "m" '("extract method" . lsp-java-extract-method)
  "v" '("extract local variable" . lsp-java-extract-to-local-variable)
  "c" '("extract constant" . lsp-java-extract-to-constant)
  "h" '("type hierarchy" . lsp-java-type-hierarchy))
