;;; lang/java/+paths.el -*- lexical-binding: t; -*-

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


;; Where JDTLS, its workspace and the debugger's test runner live. Loaded
;; by config.el at startup and by cli.el in bin/hell, before
;; lsp-java: `lsp-java-server-install-dir' is computed from
;; `lsp-server-install-dir' when lsp-java loads.

;; JDTLS's workspace and project index: regenerable, but only by
;; reimporting every project, so data rather than disposable cache.
(setq lsp-java-workspace-dir (expand-file-name "jvm/workspace/" hell-data-dir)
      lsp-java-workspace-cache-dir (expand-file-name "jvm/workspace/.cache/" hell-data-dir))

;; JDTLS itself: a pinned milestone, checked by SHA-256 (eclipse.org's own
;; .sha256 matched), installed by `bin/hell sync'. lsp-java's installer
;; isn't used: it runs Maven on a pom.xml from lsp-java's master branch,
;; unpinned, and reaches four hosts (docs/roadmap.md, 12.1).
(defconst hell-jvm-jdtls-version "1.57.0"
  "JDTLS milestone `bin/hell sync' installs.")

(defconst hell-jvm-jdtls-sha256
  "f7ffa93fe1bbbea95dac13dd97cdcd25c582d6e56db67258da0dcceb2302601e"
  "SHA-256 of the pinned JDTLS tarball.")

(defconst hell-jvm-jdtls-build "202602261110"
  "Build timestamp of the pinned JDTLS milestone, part of its tarball's name.")

(defconst hell-jvm-jdtls-url
  (format "https://download.eclipse.org/jdtls/milestones/%s/jdt-language-server-%s-%s.tar.gz"
          hell-jvm-jdtls-version hell-jvm-jdtls-version hell-jvm-jdtls-build)
  "Where the pinned JDTLS tarball is downloaded from.")

;; The JDKs the pinned JDTLS runs on. Its bundled bytecode tools reject
;; newer class files: 1.57 fails to start on JDK 27 ("Unsupported class
;; file major version 71", in m2e's activation). Raise the maximum with
;; the pin, once JDTLS is verified on the newer JDK.
(defconst hell-jvm-jdtls-java-min 21
  "The oldest JDK the pinned JDTLS runs on.")

(defconst hell-jvm-jdtls-java-max 25
  "The newest JDK the pinned JDTLS is verified to run on.")

(defcustom hell-jvm-java-home nil
  "JDK that runs JDTLS itself (and debuggees), or nil to choose one.
nil takes $JAVA_HOME's JDK, else the PATH's java, when JDTLS runs on it
\(`hell-jvm-jdtls-java-min' to `hell-jvm-jdtls-java-max'), else
the newest such JDK `bin/hell sync' found. Projects compile against
other JDKs: see `hell-jdks'."
  :type '(choice (const :tag "Choose one" nil) directory))

(defvar hell-jvm-maven-toolchains "~/.m2/toolchains.xml"
  "Maven's toolchains.xml, which `bin/hell doctor' checks. Only read.")

(defun hell-jvm--path-java-home ()
  "The JDK home of the java on the PATH, or nil."
  (when-let* ((java (executable-find "java")))
    (directory-file-name
     (file-name-directory (directory-file-name (file-name-directory (file-truename java)))))))

(defun hell-jvm-jdtls-java-home ()
  "The JDK home that runs JDTLS: see `hell-jvm-java-home'.
nil when none JDTLS runs on is known (then the PATH's java is tried)."
  (or hell-jvm-java-home
      (hell-jdk-pick
       (append (list (let ((home (getenv "JAVA_HOME")))
                       (and home (not (string-empty-p home)) (directory-file-name (expand-file-name home))))
                     (hell-jvm--path-java-home))
               (reverse (mapcar #'cdr (or (bound-and-true-p hell-jdks) (hell-jdk-read)))))
       hell-jvm-jdtls-java-min hell-jvm-jdtls-java-max)))

(defun hell-jvm-runtime-jdks (jdks)
  "JDKS, as (NAME . HOME), without the releases the pinned JDTLS doesn't know.
JDTLS rejects a runtime newer than it knows (\"not compatible with the
'JavaSE-27' environment\"); `hell-jvm-jdtls-java-max' marks it."
  (hell-require 'hell-lib 'jdk)
  (seq-filter (lambda (jdk)
                (let ((major (hell-jdk--name-major (car jdk))))
                  (and major (<= major hell-jvm-jdtls-java-max))))
              jdks))

(defun hell-jvm-lsp-runtimes (jdks)
  "`lsp-java-configuration-runtimes' for JDKS: those JDTLS knows, the default
the one it runs on (`hell-jvm-runtime-jdks', `hell-jdk-lsp-runtimes')."
  (hell-jdk-lsp-runtimes (hell-jvm-runtime-jdks jdks) (hell-jvm-jdtls-java-home)))

(defun hell-jvm-java-executable ()
  "The java that runs JDTLS and debuggees: `hell-jvm-jdtls-java-home''s, else the PATH's."
  (if-let* ((home (hell-jvm-jdtls-java-home)))
      (expand-file-name "bin/java" home)
    "java"))

(defvar hell-jvm-jdtls-dir (expand-file-name "eclipse.jdt.ls/" lsp-server-install-dir)
  "Where JDTLS is installed (lsp-java's `lsp-java-server-install-dir').")

(hell-component! :name "eclipse.jdt.ls" :version hell-jvm-jdtls-version :license "EPL-2.0"
                 :url hell-jvm-jdtls-url :sha256 hell-jvm-jdtls-sha256
                     :path hell-jvm-jdtls-dir)

(defun hell-jvm--jdtls-marker ()
  (expand-file-name ".hell-pin" hell-jvm-jdtls-dir))

(defun hell-jvm-jdtls-installed-p ()
  "Non-nil if the pinned JDTLS is installed: its launcher is there, and the
marker says it's the pinned release."
  (and (file-expand-wildcards (expand-file-name "plugins/org.eclipse.equinox.launcher_*.jar"
                                                hell-jvm-jdtls-dir))
       (hell-marker-current-p (hell-jvm--jdtls-marker) hell-jvm-jdtls-sha256)))

;; dap-java's JUnit runner (`C-c l t t' with :tools debugger), pinned too
;; (Maven Central's SHA-1 matched). Its default is under
;; `user-emacs-directory', Hell Emacs' disposable cache.
(setq dap-java-test-runner
      (expand-file-name "eclipse.jdt.ls/test-runner/junit-platform-console-standalone.jar"
                        lsp-server-install-dir))

(defconst hell-jvm-junit-runner-version "1.9.0"
  "junit-platform-console-standalone release `bin/hell sync' installs.")

(defconst hell-jvm-junit-runner-sha256
  "a7b9590966ec414920fc54eb4b2a5900f90a6fffacee66e5a987583ee13027a2"
  "SHA-256 of the pinned JUnit console runner.")

(defconst hell-jvm-junit-runner-url
  (format "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"
          hell-jvm-junit-runner-version hell-jvm-junit-runner-version)
  "Where the pinned JUnit console runner is downloaded from.")

(hell-component! :name "junit-platform-console-standalone" :type "library"
                 :version hell-jvm-junit-runner-version :license "EPL-2.0"
                     :url hell-jvm-junit-runner-url :sha256 hell-jvm-junit-runner-sha256
                     :path dap-java-test-runner)

(defun hell-jvm-junit-runner-valid-p ()
  "Non-nil if dap-java's test runner is the pinned release."
  (hell-file-pinned-p dap-java-test-runner hell-jvm-junit-runner-sha256))

;; Lombok (the +lombok flag): pinned, and checked by SHA-256 when it's
;; downloaded. Maven Central only publishes a SHA-1 for it; this SHA-256
;; was computed from a download whose SHA-1 matched Central's.
(defconst hell-jvm-lombok-version "1.18.48"
  "Lombok release fetched by `bin/hell sync' with +lombok.")

(defconst hell-jvm-lombok-sha256
  "85477a4655ebb2c074a9099cfb749be454449fee564d4282610df1b85f7c508b"
  "SHA-256 of the pinned Lombok jar.")

(defconst hell-jvm-lombok-url
  (format "https://repo1.maven.org/maven2/org/projectlombok/lombok/%s/lombok-%s.jar"
          hell-jvm-lombok-version hell-jvm-lombok-version)
  "Where the pinned Lombok jar is downloaded from.")

(defconst hell-jvm--default-lombok-jar
  (expand-file-name (format "jvm/lombok-%s.jar" hell-jvm-lombok-version) hell-data-dir)
  "Where `bin/hell sync' puts the pinned Lombok jar.")

(hell-component! :name "lombok" :type "library" :version hell-jvm-lombok-version :license "MIT"
                 :url hell-jvm-lombok-url :sha256 hell-jvm-lombok-sha256
                     :path hell-jvm--default-lombok-jar)

(defvar hell-jvm-lombok-jar hell-jvm--default-lombok-jar
  "Lombok jar loaded into JDTLS as a javaagent, with the +lombok flag.
By default, the pinned release `bin/hell sync' downloads. Set it in
your init.el to use your own jar instead (sync then leaves it alone).")

(defun hell-jvm-lombok-jar-valid-p ()
  "Return non-nil if `hell-jvm-lombok-jar' is usable.
The pinned jar must match `hell-jvm-lombok-sha256'; a jar of your
own only has to exist."
  (if (equal hell-jvm-lombok-jar hell-jvm--default-lombok-jar)
      (hell-file-pinned-p hell-jvm-lombok-jar hell-jvm-lombok-sha256)
    (file-exists-p hell-jvm-lombok-jar)))

;; The debugger's java-debug bundle (:tools debugger). lsp-java installs
;; 0.46.0 with JDTLS, which cannot start a debuggee on JDK 22 or newer
;; ("Unrecognized option: -Xnoagent"), so sync replaces it with a
;; pinned newer release, checked by SHA-256 (Maven Central only publishes
;; a SHA-1; this SHA-256 is from a download whose SHA-1 matched).
(defconst hell-jvm-java-debug-version "0.53.1"
  "java-debug release `bin/hell sync' installs with :tools debugger.")

(defconst hell-jvm-java-debug-sha256
  "4f4778d452a6a0665536f43ce4e32403a24be6593336b80dc85a322912859e24"
  "SHA-256 of the pinned java-debug plugin jar.")

(defconst hell-jvm-java-debug-url
  (format "https://repo1.maven.org/maven2/com/microsoft/java/com.microsoft.java.debug.plugin/%s/com.microsoft.java.debug.plugin-%s.jar"
          hell-jvm-java-debug-version hell-jvm-java-debug-version)
  "Where the pinned java-debug plugin jar is downloaded from.")

(defvar hell-jvm-java-debug-jar
  (expand-file-name "eclipse.jdt.ls/bundles/java.debug.plugin.jar" lsp-server-install-dir)
  "Where JDTLS loads the java-debug plugin from (lsp-java's bundle name).")

(hell-component! :name "com.microsoft.java.debug.plugin" :type "library"
                 :version hell-jvm-java-debug-version :license "EPL-1.0"
                     :url hell-jvm-java-debug-url :sha256 hell-jvm-java-debug-sha256
                     :path hell-jvm-java-debug-jar)

(defun hell-jvm-java-debug-jar-valid-p ()
  "Return non-nil if the java-debug jar JDTLS loads is the pinned release."
  (hell-file-pinned-p hell-jvm-java-debug-jar hell-jvm-java-debug-sha256))

;;; Spring Boot's language server (+spring) --------------------------------------

;; From VS Code's Spring Boot Tools, its 2.4.0 release on Open VSX (the
;; daily builds between releases are marked pre-release there). Its
;; SHA-256 matched Open VSX's published one. The server needs Java 21+,
;; like JDTLS, and runs on JDTLS's JDK. Kept apart from JDTLS's own
;; directory, which a JDTLS update replaces whole.
(defconst hell-jvm-spring-version "2.4.0"
  "Spring Boot Tools release `bin/hell sync' installs with +spring.")

(defconst hell-jvm-spring-sha256
  "7743e50a9028a6c1ba8f82986576a95c613dd6222650f8e9795ecf7a1aaebb79"
  "SHA-256 of the pinned Spring Boot Tools VSIX.")

(defconst hell-jvm-spring-url
  (format "https://open-vsx.org/api/VMware/vscode-spring-boot/%s/file/VMware.vscode-spring-boot-%s.vsix"
          hell-jvm-spring-version hell-jvm-spring-version)
  "Where the pinned Spring Boot Tools VSIX is downloaded from.")

(defvar hell-jvm-spring-dir (expand-file-name "spring-boot/" lsp-server-install-dir)
  "Where the Spring Boot language server and its JDTLS extensions are installed.")

(hell-component! :name "vscode-spring-boot" :version hell-jvm-spring-version :license "EPL-1.0"
                 :url hell-jvm-spring-url :sha256 hell-jvm-spring-sha256
                     :path hell-jvm-spring-dir)

(defconst hell-jvm-spring-extensions
  '("io.projectreactor.reactor-core.jar" "org.reactivestreams.reactive-streams.jar"
    "jdt-ls-commons.jar" "jdt-ls-extension.jar" "sts-gradle-tooling.jar")
  "The JDTLS extensions the pinned release gives JDTLS, in order (its
package.json's javaExtensions): its `sts.java.*' commands live there.")

(defun hell-jvm-spring-server-jar ()
  "The installed Spring Boot language server's jar, or nil."
  (car (file-expand-wildcards (expand-file-name "language-server/*-exec.jar" hell-jvm-spring-dir))))

(defun hell-jvm-spring-extension-jars ()
  "The JDTLS extensions' jars, as installed."
  (mapcar (lambda (jar) (expand-file-name (concat "jars/" jar) hell-jvm-spring-dir))
          hell-jvm-spring-extensions))

(defun hell-jvm-spring--marker ()
  (expand-file-name ".hell-sha256" hell-jvm-spring-dir))

(defun hell-jvm-spring-installed-p ()
  "Non-nil if the pinned Spring Boot server and its JDTLS extensions are installed."
  (and (hell-jvm-spring-server-jar)
       (seq-every-p #'file-exists-p (hell-jvm-spring-extension-jars))
       (hell-marker-current-p (hell-jvm-spring--marker) hell-jvm-spring-sha256)))
