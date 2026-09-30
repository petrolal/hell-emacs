;;; lang/java/+paths.el -*- lexical-binding: t; -*-

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


;; Where JDTLS, its workspace and the debugger's test runner live. Loaded
;; by config.el at startup and by cli.el in bin/hellmacs, before
;; lsp-java: `lsp-java-server-install-dir' is computed from
;; `lsp-server-install-dir' when lsp-java loads.

;; JDTLS's workspace and project index: regenerable, but only by
;; reimporting every project, so data rather than disposable cache.
(setq lsp-java-workspace-dir (expand-file-name "jvm/workspace/" hellmacs-data-dir)
      lsp-java-workspace-cache-dir (expand-file-name "jvm/workspace/.cache/" hellmacs-data-dir))

;; JDTLS itself: a pinned milestone, checked by SHA-256 (eclipse.org's own
;; .sha256 matched), installed by `bin/hellmacs sync'. lsp-java's installer
;; isn't used: it runs Maven on a pom.xml from lsp-java's master branch,
;; unpinned, and reaches four hosts (docs/roadmap.md, 12.1).
(defconst hellmacs-jvm-jdtls-version "1.57.0"
  "JDTLS milestone `bin/hellmacs sync' installs.")

(defconst hellmacs-jvm-jdtls-sha256
  "f7ffa93fe1bbbea95dac13dd97cdcd25c582d6e56db67258da0dcceb2302601e"
  "SHA-256 of the pinned JDTLS tarball.")

(defconst hellmacs-jvm-jdtls-build "202602261110"
  "Build timestamp of the pinned JDTLS milestone, part of its tarball's name.")

(defconst hellmacs-jvm-jdtls-url
  (format "https://download.eclipse.org/jdtls/milestones/%s/jdt-language-server-%s-%s.tar.gz"
          hellmacs-jvm-jdtls-version hellmacs-jvm-jdtls-version hellmacs-jvm-jdtls-build)
  "Where the pinned JDTLS tarball is downloaded from.")

;; The JDKs the pinned JDTLS runs on. Its bundled bytecode tools reject
;; newer class files: 1.57 fails to start on JDK 27 ("Unsupported class
;; file major version 71", in m2e's activation). Raise the maximum with
;; the pin, once JDTLS is verified on the newer JDK.
(defconst hellmacs-jvm-jdtls-java-min 21
  "The oldest JDK the pinned JDTLS runs on.")

(defconst hellmacs-jvm-jdtls-java-max 25
  "The newest JDK the pinned JDTLS is verified to run on.")

(defcustom hellmacs-jvm-java-home nil
  "JDK that runs JDTLS itself (and debuggees), or nil to choose one.
nil takes $JAVA_HOME's JDK, else the PATH's java, when JDTLS runs on it
\(`hellmacs-jvm-jdtls-java-min' to `hellmacs-jvm-jdtls-java-max'), else
the newest such JDK `bin/hellmacs sync' found. Projects compile against
other JDKs: see `hellmacs-jdks'."
  :type '(choice (const :tag "Choose one" nil) directory))

(defvar hellmacs-jvm-maven-toolchains "~/.m2/toolchains.xml"
  "Maven's toolchains.xml, which `bin/hellmacs doctor' checks. Only read.")

(defun hellmacs-jvm--path-java-home ()
  "The JDK home of the java on the PATH, or nil."
  (when-let* ((java (executable-find "java")))
    (directory-file-name
     (file-name-directory (directory-file-name (file-name-directory (file-truename java)))))))

(defun hellmacs-jvm-jdtls-java-home ()
  "The JDK home that runs JDTLS: see `hellmacs-jvm-java-home'.
nil when none JDTLS runs on is known (then the PATH's java is tried)."
  (or hellmacs-jvm-java-home
      (hellmacs-jdk-pick
       (append (list (let ((home (getenv "JAVA_HOME")))
                       (and home (not (string-empty-p home)) (directory-file-name (expand-file-name home))))
                     (hellmacs-jvm--path-java-home))
               (reverse (mapcar #'cdr (or (bound-and-true-p hellmacs-jdks) (hellmacs-jdk-read)))))
       hellmacs-jvm-jdtls-java-min hellmacs-jvm-jdtls-java-max)))

(defun hellmacs-jvm-runtime-jdks (jdks)
  "JDKS, as (NAME . HOME), without the releases the pinned JDTLS doesn't know.
JDTLS rejects a runtime newer than it knows (\"not compatible with the
'JavaSE-27' environment\"); `hellmacs-jvm-jdtls-java-max' marks it."
  (hellmacs-require 'hellmacs-lib 'jdk)
  (seq-filter (lambda (jdk)
                (let ((major (hellmacs-jdk--name-major (car jdk))))
                  (and major (<= major hellmacs-jvm-jdtls-java-max))))
              jdks))

(defun hellmacs-jvm-lsp-runtimes (jdks)
  "`lsp-java-configuration-runtimes' for JDKS: those JDTLS knows, the default
the one it runs on (`hellmacs-jvm-runtime-jdks', `hellmacs-jdk-lsp-runtimes')."
  (hellmacs-jdk-lsp-runtimes (hellmacs-jvm-runtime-jdks jdks) (hellmacs-jvm-jdtls-java-home)))

(defun hellmacs-jvm-java-executable ()
  "The java that runs JDTLS and debuggees: `hellmacs-jvm-jdtls-java-home''s, else the PATH's."
  (if-let* ((home (hellmacs-jvm-jdtls-java-home)))
      (expand-file-name "bin/java" home)
    "java"))

(defvar hellmacs-jvm-jdtls-dir (expand-file-name "eclipse.jdt.ls/" lsp-server-install-dir)
  "Where JDTLS is installed (lsp-java's `lsp-java-server-install-dir').")

(hellmacs-component! :name "eclipse.jdt.ls" :version hellmacs-jvm-jdtls-version :license "EPL-2.0"
                     :url hellmacs-jvm-jdtls-url :sha256 hellmacs-jvm-jdtls-sha256
                     :path hellmacs-jvm-jdtls-dir)

(defun hellmacs-jvm--jdtls-marker ()
  (expand-file-name ".hellmacs-pin" hellmacs-jvm-jdtls-dir))

(defun hellmacs-jvm-jdtls-installed-p ()
  "Non-nil if the pinned JDTLS is installed: its launcher is there, and the
marker says it's the pinned release."
  (and (file-expand-wildcards (expand-file-name "plugins/org.eclipse.equinox.launcher_*.jar"
                                                hellmacs-jvm-jdtls-dir))
       (hellmacs-marker-current-p (hellmacs-jvm--jdtls-marker) hellmacs-jvm-jdtls-sha256)))

;; dap-java's JUnit runner (`C-c l j t' with :tools debugger), pinned too
;; (Maven Central's SHA-1 matched). Its default is under
;; `user-emacs-directory', Hellmacs' disposable cache.
(setq dap-java-test-runner
      (expand-file-name "eclipse.jdt.ls/test-runner/junit-platform-console-standalone.jar"
                        lsp-server-install-dir))

(defconst hellmacs-jvm-junit-runner-version "1.9.0"
  "junit-platform-console-standalone release `bin/hellmacs sync' installs.")

(defconst hellmacs-jvm-junit-runner-sha256
  "a7b9590966ec414920fc54eb4b2a5900f90a6fffacee66e5a987583ee13027a2"
  "SHA-256 of the pinned JUnit console runner.")

(defconst hellmacs-jvm-junit-runner-url
  (format "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"
          hellmacs-jvm-junit-runner-version hellmacs-jvm-junit-runner-version)
  "Where the pinned JUnit console runner is downloaded from.")

(hellmacs-component! :name "junit-platform-console-standalone" :type "library"
                     :version hellmacs-jvm-junit-runner-version :license "EPL-2.0"
                     :url hellmacs-jvm-junit-runner-url :sha256 hellmacs-jvm-junit-runner-sha256
                     :path dap-java-test-runner)

(defun hellmacs-jvm-junit-runner-valid-p ()
  "Non-nil if dap-java's test runner is the pinned release."
  (hellmacs-file-pinned-p dap-java-test-runner hellmacs-jvm-junit-runner-sha256))

;; Lombok (the +lombok flag): pinned, and checked by SHA-256 when it's
;; downloaded. Maven Central only publishes a SHA-1 for it; this SHA-256
;; was computed from a download whose SHA-1 matched Central's.
(defconst hellmacs-jvm-lombok-version "1.18.48"
  "Lombok release fetched by `bin/hellmacs sync' with +lombok.")

(defconst hellmacs-jvm-lombok-sha256
  "85477a4655ebb2c074a9099cfb749be454449fee564d4282610df1b85f7c508b"
  "SHA-256 of the pinned Lombok jar.")

(defconst hellmacs-jvm-lombok-url
  (format "https://repo1.maven.org/maven2/org/projectlombok/lombok/%s/lombok-%s.jar"
          hellmacs-jvm-lombok-version hellmacs-jvm-lombok-version)
  "Where the pinned Lombok jar is downloaded from.")

(defconst hellmacs-jvm--default-lombok-jar
  (expand-file-name (format "jvm/lombok-%s.jar" hellmacs-jvm-lombok-version) hellmacs-data-dir)
  "Where `bin/hellmacs sync' puts the pinned Lombok jar.")

(hellmacs-component! :name "lombok" :type "library" :version hellmacs-jvm-lombok-version :license "MIT"
                     :url hellmacs-jvm-lombok-url :sha256 hellmacs-jvm-lombok-sha256
                     :path hellmacs-jvm--default-lombok-jar)

(defvar hellmacs-jvm-lombok-jar hellmacs-jvm--default-lombok-jar
  "Lombok jar loaded into JDTLS as a javaagent, with the +lombok flag.
By default, the pinned release `bin/hellmacs sync' downloads. Set it in
your init.el to use your own jar instead (sync then leaves it alone).")

(defun hellmacs-jvm-lombok-jar-valid-p ()
  "Return non-nil if `hellmacs-jvm-lombok-jar' is usable.
The pinned jar must match `hellmacs-jvm-lombok-sha256'; a jar of your
own only has to exist."
  (if (equal hellmacs-jvm-lombok-jar hellmacs-jvm--default-lombok-jar)
      (hellmacs-file-pinned-p hellmacs-jvm-lombok-jar hellmacs-jvm-lombok-sha256)
    (file-exists-p hellmacs-jvm-lombok-jar)))

;; The debugger's java-debug bundle (:tools debugger). lsp-java installs
;; 0.46.0 with JDTLS, which cannot start a debuggee on JDK 22 or newer
;; ("Unrecognized option: -Xnoagent"), so sync replaces it with a
;; pinned newer release, checked by SHA-256 (Maven Central only publishes
;; a SHA-1; this SHA-256 is from a download whose SHA-1 matched).
(defconst hellmacs-jvm-java-debug-version "0.53.1"
  "java-debug release `bin/hellmacs sync' installs with :tools debugger.")

(defconst hellmacs-jvm-java-debug-sha256
  "4f4778d452a6a0665536f43ce4e32403a24be6593336b80dc85a322912859e24"
  "SHA-256 of the pinned java-debug plugin jar.")

(defconst hellmacs-jvm-java-debug-url
  (format "https://repo1.maven.org/maven2/com/microsoft/java/com.microsoft.java.debug.plugin/%s/com.microsoft.java.debug.plugin-%s.jar"
          hellmacs-jvm-java-debug-version hellmacs-jvm-java-debug-version)
  "Where the pinned java-debug plugin jar is downloaded from.")

(defvar hellmacs-jvm-java-debug-jar
  (expand-file-name "eclipse.jdt.ls/bundles/java.debug.plugin.jar" lsp-server-install-dir)
  "Where JDTLS loads the java-debug plugin from (lsp-java's bundle name).")

(hellmacs-component! :name "com.microsoft.java.debug.plugin" :type "library"
                     :version hellmacs-jvm-java-debug-version :license "EPL-1.0"
                     :url hellmacs-jvm-java-debug-url :sha256 hellmacs-jvm-java-debug-sha256
                     :path hellmacs-jvm-java-debug-jar)

(defun hellmacs-jvm-java-debug-jar-valid-p ()
  "Return non-nil if the java-debug jar JDTLS loads is the pinned release."
  (hellmacs-file-pinned-p hellmacs-jvm-java-debug-jar hellmacs-jvm-java-debug-sha256))

;;; Spring Boot's language server (+spring) --------------------------------------

;; From VS Code's Spring Boot Tools, its 2.4.0 release on Open VSX (the
;; daily builds between releases are marked pre-release there). Its
;; SHA-256 matched Open VSX's published one. The server needs Java 21+,
;; like JDTLS, and runs on JDTLS's JDK. Kept apart from JDTLS's own
;; directory, which a JDTLS update replaces whole.
(defconst hellmacs-jvm-spring-version "2.4.0"
  "Spring Boot Tools release `bin/hellmacs sync' installs with +spring.")

(defconst hellmacs-jvm-spring-sha256
  "7743e50a9028a6c1ba8f82986576a95c613dd6222650f8e9795ecf7a1aaebb79"
  "SHA-256 of the pinned Spring Boot Tools VSIX.")

(defconst hellmacs-jvm-spring-url
  (format "https://open-vsx.org/api/VMware/vscode-spring-boot/%s/file/VMware.vscode-spring-boot-%s.vsix"
          hellmacs-jvm-spring-version hellmacs-jvm-spring-version)
  "Where the pinned Spring Boot Tools VSIX is downloaded from.")

(defvar hellmacs-jvm-spring-dir (expand-file-name "spring-boot/" lsp-server-install-dir)
  "Where the Spring Boot language server and its JDTLS extensions are installed.")

(hellmacs-component! :name "vscode-spring-boot" :version hellmacs-jvm-spring-version :license "EPL-1.0"
                     :url hellmacs-jvm-spring-url :sha256 hellmacs-jvm-spring-sha256
                     :path hellmacs-jvm-spring-dir)

(defconst hellmacs-jvm-spring-extensions
  '("io.projectreactor.reactor-core.jar" "org.reactivestreams.reactive-streams.jar"
    "jdt-ls-commons.jar" "jdt-ls-extension.jar" "sts-gradle-tooling.jar")
  "The JDTLS extensions the pinned release gives JDTLS, in order (its
package.json's javaExtensions): its `sts.java.*' commands live there.")

(defun hellmacs-jvm-spring-server-jar ()
  "The installed Spring Boot language server's jar, or nil."
  (car (file-expand-wildcards (expand-file-name "language-server/*-exec.jar" hellmacs-jvm-spring-dir))))

(defun hellmacs-jvm-spring-extension-jars ()
  "The JDTLS extensions' jars, as installed."
  (mapcar (lambda (jar) (expand-file-name (concat "jars/" jar) hellmacs-jvm-spring-dir))
          hellmacs-jvm-spring-extensions))

(defun hellmacs-jvm-spring--marker ()
  (expand-file-name ".hellmacs-sha256" hellmacs-jvm-spring-dir))

(defun hellmacs-jvm-spring-installed-p ()
  "Non-nil if the pinned Spring Boot server and its JDTLS extensions are installed."
  (and (hellmacs-jvm-spring-server-jar)
       (seq-every-p #'file-exists-p (hellmacs-jvm-spring-extension-jars))
       (hellmacs-marker-current-p (hellmacs-jvm-spring--marker) hellmacs-jvm-spring-sha256)))
