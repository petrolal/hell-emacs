;;; test-run.el --- Tests for :tools run module (Phase 12.4) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'comint)
(require 'compile)
(require 'hellmacs-modules)

;; :tools run's code (and :tools build's, which it runs builds with).
(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools build run))
  (hellmacs-module--load '(:tools . build) "autoload.el")
  (hellmacs-module--load '(:tools . run) "autoload.el"))

(defmacro test-run--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-run" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-run/eld-configuration-parsing ()
  "Parses Hellmacs .hellmacs/run.eld format into run configurations."
  (test-run--with-tree
      '((".hellmacs/run.eld" . "((:name \"Server App\" :main \"dev.hellmacs.demo.App\" :jvm-args (\"-Xmx512m\") :args (\"--port=8080\") :env ((\"STAGE\" . \"local\"))))\n"))
    (let* ((run-file (expand-file-name ".hellmacs/run.eld" root))
           (configs (hellmacs-run-parse-eld run-file)))
      (should (= (length configs) 1))
      (let ((cfg (car configs)))
        (should (equal (plist-get cfg :name) "Server App"))
        (should (equal (plist-get cfg :main) "dev.hellmacs.demo.App"))
        (should (equal (plist-get cfg :jvm-args) '("-Xmx512m")))
        (should (equal (plist-get cfg :args) '("--port=8080")))))))

(ert-deftest test-run/intellij-run-xml-parsing ()
  "Parses IntelliJ .run/*.run.xml run configuration format into run configurations."
  (test-run--with-tree
      '((".run/App.run.xml" . "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"AppRun\" type=\"SpringBootApplicationConfigurationType\" factoryName=\"Spring Boot\">
    <option name=\"MAIN_CLASS_NAME\" value=\"dev.hellmacs.demo.App\" />
    <option name=\"VM_PARAMETERS\" value=\"-Dspring.profiles.active=dev\" />
    <option name=\"PROGRAM_PARAMETERS\" value=\"--debug\" />
  </configuration>
</component>"))
    (let* ((xml-file (expand-file-name ".run/App.run.xml" root))
           (configs (hellmacs-run-parse-intellij xml-file)))
      (should (= (length configs) 1))
      (let ((cfg (car configs)))
        (should (equal (plist-get cfg :name) "AppRun"))
        (should (equal (plist-get cfg :main) "dev.hellmacs.demo.App"))
        (should (member "-Dspring.profiles.active=dev" (plist-get cfg :jvm-args)))))))

(ert-deftest test-run/eclipse-launch-parsing ()
  "Parses Eclipse .launch configuration XML format into run configurations."
  (test-run--with-tree
      '((".launch/App.launch" . "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<launchConfiguration type=\"org.eclipse.jdt.launching.localJavaApplication\">
    <stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"dev.hellmacs.demo.App\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.VM_ARGUMENTS\" value=\"-Xms256m\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.PROGRAM_ARGUMENTS\" value=\"start\"/>
</launchConfiguration>"))
    (let* ((launch-file (expand-file-name ".launch/App.launch" root))
           (configs (hellmacs-run-parse-eclipse launch-file)))
      (should (= (length configs) 1))
      (let ((cfg (car configs)))
        (should (equal (plist-get cfg :main) "dev.hellmacs.demo.App"))
        (should (equal (plist-get cfg :jvm-args) '("-Xms256m")))))))

(ert-deftest test-run/intellij-details ()
  "Spring Boot and Application types in full; Gradle and Maven tasks; others skipped."
  (test-run--with-tree
      '((".run/Boot.run.xml" . "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"Boot (dev)\" type=\"SpringBootApplicationConfigurationType\" factoryName=\"Spring Boot\">
    <module name=\"demo\" />
    <option name=\"SPRING_BOOT_MAIN_CLASS\" value=\"dev.hellmacs.demo.App\" />
    <option name=\"ACTIVE_PROFILES\" value=\"dev, local\" />
    <option name=\"PROGRAM_PARAMETERS\" value=\"--name=&quot;a b&quot; --x\" />
    <option name=\"WORKING_DIRECTORY\" value=\"$PROJECT_DIR$/app\" />
    <envs>
      <env name=\"STAGE\" value=\"local\" />
    </envs>
    <method v=\"2\"><option name=\"Make\" enabled=\"true\" /></method>
  </configuration>
</component>")
        (".run/BootRun.run.xml" . "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"bootRun\" type=\"GradleRunConfiguration\" factoryName=\"Gradle\">
    <ExternalSystemSettings>
      <option name=\"executionName\" />
      <option name=\"externalProjectPath\" value=\"$PROJECT_DIR$\" />
      <option name=\"scriptParameters\" value=\"--info\" />
      <option name=\"taskNames\"><list><option value=\"bootRun\" /></list></option>
    </ExternalSystemSettings>
  </configuration>
</component>")
        (".run/MvnBoot.run.xml" . "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"mvn boot\" type=\"MavenRunConfiguration\" factoryName=\"Maven\">
    <MavenSettings>
      <option name=\"myRunnerParameters\">
        <MavenRunnerParameters>
          <option name=\"goals\"><list><option value=\"spring-boot:run\" /></list></option>
          <option name=\"workingDirPath\" value=\"$PROJECT_DIR$\" />
        </MavenRunnerParameters>
      </option>
    </MavenSettings>
  </configuration>
</component>")
        (".run/Tests.run.xml" . "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"All tests\" type=\"JUnit\" factoryName=\"JUnit\">
    <option name=\"PACKAGE_NAME\" value=\"dev\" />
  </configuration>
</component>"))
    (let ((boot (car (hellmacs-run-parse-intellij (expand-file-name ".run/Boot.run.xml" root)))))
      (should (equal (plist-get boot :name) "Boot (dev)"))
      (should (equal (plist-get boot :main) "dev.hellmacs.demo.App"))
      (should (equal (plist-get boot :project) "demo"))
      (should (equal (plist-get boot :profiles) '("dev" "local")))
      (should (equal (plist-get boot :args) '("--name=a b" "--x")))
      (should (equal (plist-get boot :env) '(("STAGE" . "local"))))
      (should (equal (plist-get boot :cwd) (expand-file-name "app" root))))
    (let ((gradle (car (hellmacs-run-parse-intellij (expand-file-name ".run/BootRun.run.xml" root)))))
      (should (equal (plist-get gradle :task) "bootRun"))
      (should (equal (plist-get gradle :build-args) '("--info")))
      (should-not (plist-get gradle :main)))
    (should (equal (plist-get (car (hellmacs-run-parse-intellij (expand-file-name ".run/MvnBoot.run.xml" root))) :task)
                   "spring-boot:run"))
    (should-not (hellmacs-run-parse-intellij (expand-file-name ".run/Tests.run.xml" root)))))

(ert-deftest test-run/eclipse-details ()
  "An Eclipse launch: its name, project, environment, working directory; other types skipped."
  (test-run--with-tree
      '(("Server.launch" . "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<launchConfiguration type=\"org.eclipse.jdt.launching.localJavaApplication\">
    <mapAttribute key=\"org.eclipse.debug.core.environmentVariables\">
        <mapEntry key=\"STAGE\" value=\"local\"/>
    </mapAttribute>
    <stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"dev.hellmacs.demo.App\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.PROJECT_ATTR\" value=\"demo\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.PROGRAM_ARGUMENTS\" value=\"--a &quot;b c&quot;\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.WORKING_DIRECTORY\" value=\"${workspace_loc:demo}/sub\"/>
</launchConfiguration>")
        ("Tests.launch" . "<launchConfiguration type=\"org.eclipse.jdt.junit.launchconfig\"><stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"x.T\"/></launchConfiguration>"))
    (let ((cfg (car (hellmacs-run-parse-eclipse (expand-file-name "Server.launch" root)))))
      (should (equal (plist-get cfg :name) "Server"))
      (should (equal (plist-get cfg :project) "demo"))
      (should (equal (plist-get cfg :args) '("--a" "b c")))
      (should (equal (plist-get cfg :env) '(("STAGE" . "local"))))
      (should (equal (plist-get cfg :cwd) (expand-file-name "sub" root))))
    (should-not (hellmacs-run-parse-eclipse (expand-file-name "Tests.launch" root)))))

(ert-deftest test-run/configurations-in-order ()
  "Hellmacs' own first, then IntelliJ's, then Eclipse's; a name only once; build output skipped."
  (test-run--with-tree
      '((".hellmacs/run.eld" . "((:name \"App\" :main \"a.App\"))\n")
        (".run/App.run.xml" . "<component><configuration name=\"App\" type=\"Application\"><option name=\"MAIN_CLASS_NAME\" value=\"b.App\"/></configuration></component>")
        (".run/Other.run.xml" . "<component><configuration name=\"Other\" type=\"Application\"><option name=\"MAIN_CLASS_NAME\" value=\"b.Other\"/></configuration></component>")
        ("tools/Tool.launch" . "<launchConfiguration type=\"org.eclipse.jdt.launching.localJavaApplication\"><stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"c.Tool\"/></launchConfiguration>")
        ("build/Copy.launch" . "<launchConfiguration type=\"org.eclipse.jdt.launching.localJavaApplication\"><stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"c.Copy\"/></launchConfiguration>")
        ("pom.xml" . "<project/>"))
    (let ((configs (hellmacs-run-configurations root)))
      (should (equal (mapcar (lambda (c) (plist-get c :name)) configs) '("App" "Other" "Tool")))
      (should (equal (plist-get (car configs) :main) "a.App"))
      (should (equal (plist-get (car configs) :source) ".hellmacs/run.eld"))
      (should (equal (plist-get (nth 2 configs) :source) "tools/Tool.launch")))))

(ert-deftest test-run/commands ()
  "The java command line, and the build's, for running and for debugging."
  (should (equal (hellmacs-run--java-command
                  '(:main "pkg.Main" :jvm-args ("-Xmx1g") :profiles ("dev" "local") :args ("--x"))
                  "/jdk/bin/java" '("/cp/a" "/cp/b"))
                 (list "/jdk/bin/java" "-Xmx1g" "-Dspring.profiles.active=dev,local"
                       "-cp" (concat "/cp/a" path-separator "/cp/b") "pkg.Main" "--x")))
  (let ((gradle '(gradle "/p/" "./gradlew")) (maven '(maven "/p/" "./mvnw")))
    (should (equal (hellmacs-run--task-command '(:task "bootRun" :profiles ("dev") :args ("--x")) gradle)
                   '("./gradlew" "bootRun" "--console=plain" "--args=--spring.profiles.active=dev --x")))
    (should (equal (hellmacs-run--task-command '(:task "bootRun") gradle 'debug)
                   '("./gradlew" "bootRun" "--console=plain" "--debug-jvm")))
    (should (equal (hellmacs-run--task-command '(:task "build" :build-args ("--info")) gradle)
                   '("./gradlew" "build" "--console=plain" "--info")))
    (should (equal (hellmacs-run--task-command '(:task "spring-boot:run" :profiles ("dev") :args ("--x")
                                                 :jvm-args ("-Xmx1g"))
                                               maven)
                   '("./mvnw" "-B" "spring-boot:run" "-Dspring-boot.run.profiles=dev"
                     "-Dspring-boot.run.arguments=--x" "-Dspring-boot.run.jvmArguments=-Xmx1g")))
    (should (member (concat "-Dspring-boot.run.jvmArguments="
                            "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005")
                    (hellmacs-run--task-command '(:task "spring-boot:run") maven 'debug)))
    (should-error (hellmacs-run--task-command '(:task "build") gradle 'debug) :type 'user-error)))

(ert-deftest test-run/runs-a-task-in-a-comint-buffer ()
  "A task configuration runs through the build, in a comint buffer with clickable
frames, with its environment and the buffer's (envrc's); C-c r l runs it again."
  (test-run--with-tree
      '(("settings.gradle" . "rootProject.name = 'p'\n")
        ("gradlew" . "#!/bin/sh\necho \"args: $*\"\necho \"STAGE=$STAGE FROM_ENVRC=$FROM_ENVRC\"\necho \"\tat dev.hellmacs.demo.App.main(App.java:3)\"\n"))
    (set-file-modes (expand-file-name "gradlew" root) #o755)
    (with-temp-buffer
      (setq default-directory root)
      (setq-local process-environment (cons "FROM_ENVRC=yes" process-environment))
      (let* ((config '(:name "t" :task "run" :env (("STAGE" . "local"))))
             (buf (hellmacs-run-config config)))
        (with-timeout (30) (while (process-live-p (get-buffer-process buf)) (accept-process-output nil 0.1)))
        (with-current-buffer buf
          (should (string-match-p "args: run --console=plain" (buffer-string)))
          (should (string-match-p "STAGE=local FROM_ENVRC=yes" (buffer-string)))
          (should (derived-mode-p 'comint-mode))
          (should (bound-and-true-p compilation-shell-minor-mode))
          (should (file-equal-p default-directory root)))
        (should (equal (buffer-name buf) "*run: t*"))
        (with-current-buffer buf (let ((inhibit-read-only t)) (erase-buffer)))
        (hellmacs-run-last)
        (with-timeout (30) (while (process-live-p (get-buffer-process buf)) (accept-process-output nil 0.1)))
        (should (string-match-p "STAGE=local" (with-current-buffer buf (buffer-string))))
        (kill-buffer buf)))))

(ert-deftest test-run/main-class-needs-jdtls ()
  "A main class runs on JDTLS's classpath; without it running, it says so."
  (with-temp-buffer
    (should (string-match-p "JDTLS"
                            (cadr (should-error (hellmacs-run-config '(:name "m" :main "a.Main"))
                                                :type 'user-error))))))

(ert-deftest test-run/keys ()
  "C-c r is :tools run's: run, debug, last."
  (let ((mode-specific-map (make-sparse-keymap))
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:tools build run))
    (hellmacs-module--load '(:tools . run) "config.el")
    (cl-flet ((command (key) (let ((def (keymap-lookup mode-specific-map key)))
                               (if (consp def) (cdr def) def)))) ; (LABEL . COMMAND) or COMMAND
      (should (eq (command "r r") 'hellmacs-run))
      (should (eq (command "r d") 'hellmacs-run-debug))
      (should (eq (command "r l") 'hellmacs-run-last)))))

(provide 'test-run)
;;; test-run.el ends here
