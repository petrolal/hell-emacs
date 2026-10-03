;;; tools/templates/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; Project starters and live development integration for Cloud-Native JVM
;; frameworks (Quarkus and Micronaut) with zero telemetry.

;;; Code:

(require 'project)
(require 'subr-x)

(defgroup hell-templates nil
  "Cloud-native JVM project starters and templates for Hell Emacs."
  :group 'hell)

;;; Framework Detection

(defun hell-templates--root ()
  "Return the current project root directory, or `default-directory'."
  (if-let* ((proj (project-current)))
      (project-root proj)
    default-directory))

(defun hell-quarkus-project-p (&optional dir)
  "Return non-nil if DIR (or current project) is a Quarkus project."
  (let ((root (or dir (hell-templates--root))))
    (or (file-exists-p (expand-file-name ".quarkus" root))
        (let ((pom (expand-file-name "pom.xml" root))
              (gradle (expand-file-name "build.gradle" root)))
          (or (and (file-exists-p pom)
                   (with-temp-buffer
                     (insert-file-contents pom nil 0 4000)
                     (search-forward "quarkus" nil t)))
              (and (file-exists-p gradle)
                   (with-temp-buffer
                     (insert-file-contents gradle nil 0 4000)
                     (search-forward "quarkus" nil t))))))))

(defun hell-micronaut-project-p (&optional dir)
  "Return non-nil if DIR (or current project) is a Micronaut project."
  (let ((root (or dir (hell-templates--root))))
    (or (file-exists-p (expand-file-name "micronaut-cli.yml" root))
        (let ((pom (expand-file-name "pom.xml" root))
              (gradle (expand-file-name "build.gradle" root)))
          (or (and (file-exists-p pom)
                   (with-temp-buffer
                     (insert-file-contents pom nil 0 4000)
                     (search-forward "micronaut" nil t)))
              (and (file-exists-p gradle)
                   (with-temp-buffer
                     (insert-file-contents gradle nil 0 4000)
                     (search-forward "micronaut" nil t))))))))

;;; Live Development Run Commands

;;;###autoload
(defun hell-quarkus-dev ()
  "Start Quarkus live development mode with zero telemetry."
  (interactive)
  (let* ((root (hell-templates--root))
         (mvnw (expand-file-name "mvnw" root))
         (gradlew (expand-file-name "gradlew" root))
         (default-directory root)
         (cmd (cond ((file-executable-p mvnw)
                     "./mvnw quarkus:dev -Dquarkus.analytics.disabled=true")
                    ((file-executable-p gradlew)
                     "./gradlew quarkusDev -Dquarkus.analytics.disabled=true")
                    ((executable-find "mvn")
                     "mvn quarkus:dev -Dquarkus.analytics.disabled=true")
                    ((executable-find "gradle")
                     "gradle quarkusDev -Dquarkus.analytics.disabled=true")
                    (t "./mvnw quarkus:dev -Dquarkus.analytics.disabled=true"))))
    (compile cmd)))

;;;###autoload
(defun hell-micronaut-dev ()
  "Start Micronaut continuous live development mode."
  (interactive)
  (let* ((root (hell-templates--root))
         (mvnw (expand-file-name "mvnw" root))
         (gradlew (expand-file-name "gradlew" root))
         (default-directory root)
         (cmd (cond ((file-executable-p mvnw)
                     "./mvnw mn:run")
                    ((file-executable-p gradlew)
                     "./gradlew run --continuous")
                    ((executable-find "mvn")
                     "mvn mn:run")
                    ((executable-find "gradle")
                     "gradle run --continuous")
                    (t "./mvnw mn:run"))))
    (compile cmd)))

;;; Project Generators

(defun hell-template--write (path content)
  "Write CONTENT to PATH, creating parent directories if needed."
  (let ((dir (file-name-directory path)))
    (unless (file-directory-p dir)
      (make-directory dir t)))
  (with-temp-file path
    (insert content)))

;;;###autoload
(defun hell-template-new-quarkus (dir group-id artifact-id build-tool)
  "Scaffold a new Quarkus RESTEasy Panache project at DIR."
  (interactive
   (list (read-directory-name "Project directory: ")
         (read-string "Group ID (e.g. com.example): " "com.example")
         (read-string "Artifact ID (e.g. demo): " "demo")
         (completing-read "Build tool: " '("maven" "gradle") nil t "maven")))
  (let* ((target (expand-file-name artifact-id dir))
         (pkg-path (replace-regexp-in-string "\\." "/" group-id))
         (java-src (expand-file-name (format "src/main/java/%s" pkg-path) target))
         (res-dir (expand-file-name "src/main/resources" target))
         (run-dir (expand-file-name ".hell-emacs" target)))
    (make-directory target t)
    ;; application.properties with strict zero telemetry
    (hell-template--write
     (expand-file-name "application.properties" res-dir)
     (concat "# Quarkus Configuration (Zero Telemetry Enforced)\n"
             "quarkus.http.port=8080\n"
             "quarkus.analytics.disabled=true\n"
             "quarkus.datasource.db-kind=h2\n"
             "quarkus.hibernate-orm.database.generation=drop-and-create\n"))
    ;; GreetingResource.java
    (hell-template--write
     (expand-file-name "GreetingResource.java" java-src)
     (format (concat "package %s;\n\n"
                     "import jakarta.ws.rs.GET;\n"
                     "import jakarta.ws.rs.Path;\n"
                     "import jakarta.ws.rs.Produces;\n"
                     "import jakarta.ws.rs.core.MediaType;\n\n"
                     "@Path(\"/hello\")\n"
                     "public class GreetingResource {\n\n"
                     "    @GET\n"
                     "    @Produces(MediaType.TEXT_PLAIN)\n"
                     "    public String hello() {\n"
                     "        return \"Hello from Quarkus RESTEasy Panache!\";\n"
                     "    }\n"
                     "}\n")
             group-id))
    ;; Panache Entity: Person.java
    (hell-template--write
     (expand-file-name "entity/Person.java" java-src)
     (format (concat "package %s.entity;\n\n"
                     "import io.quarkus.hibernate.orm.panache.PanacheEntity;\n"
                     "import jakarta.persistence.Entity;\n\n"
                     "@Entity\n"
                     "public class Person extends PanacheEntity {\n"
                     "    public String name;\n"
                     "    public String status;\n"
                     "}\n")
             group-id))
    ;; Build file
    (if (string-equal build-tool "maven")
        (hell-template--write
         (expand-file-name "pom.xml" target)
         (format (concat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                         "<project xmlns=\"http://maven.apache.org/POM/4.0.0\"\n"
                         "         xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n"
                         "         xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd\">\n"
                         "  <modelVersion>4.0.0</modelVersion>\n"
                         "  <groupId>%s</groupId>\n"
                         "  <artifactId>%s</artifactId>\n"
                         "  <version>1.0.0-SNAPSHOT</version>\n"
                         "  <properties>\n"
                         "    <maven.compiler.release>21</maven.compiler.release>\n"
                         "    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>\n"
                         "    <quarkus.platform.version>3.15.1</quarkus.platform.version>\n"
                         "    <quarkus.analytics.disabled>true</quarkus.analytics.disabled>\n"
                         "  </properties>\n"
                         "  <dependencyManagement>\n"
                         "    <dependencies>\n"
                         "      <dependency>\n"
                         "        <groupId>io.quarkus.platform</groupId>\n"
                         "        <artifactId>quarkus-bom</artifactId>\n"
                         "        <version>${quarkus.platform.version}</version>\n"
                         "        <type>pom</type>\n"
                         "        <scope>import</scope>\n"
                         "      </dependency>\n"
                         "    </dependencies>\n"
                         "  </dependencyManagement>\n"
                         "  <dependencies>\n"
                         "    <dependency>\n"
                         "      <groupId>io.quarkus</groupId>\n"
                         "      <artifactId>quarkus-resteasy-reactive</artifactId>\n"
                         "    </dependency>\n"
                         "    <dependency>\n"
                         "      <groupId>io.quarkus</groupId>\n"
                         "      <artifactId>quarkus-hibernate-orm-panache</artifactId>\n"
                         "    </dependency>\n"
                         "    <dependency>\n"
                         "      <groupId>io.quarkus</groupId>\n"
                         "      <artifactId>quarkus-jdbc-h2</artifactId>\n"
                         "    </dependency>\n"
                         "    <dependency>\n"
                         "      <groupId>io.quarkus</groupId>\n"
                         "      <artifactId>quarkus-arc</artifactId>\n"
                         "    </dependency>\n"
                         "    <dependency>\n"
                         "      <groupId>io.quarkus</groupId>\n"
                         "      <artifactId>quarkus-junit5</artifactId>\n"
                         "      <scope>test</scope>\n"
                         "    </dependency>\n"
                         "  </dependencies>\n"
                         "  <build>\n"
                         "    <plugins>\n"
                         "      <plugin>\n"
                         "        <groupId>io.quarkus.platform</groupId>\n"
                         "        <artifactId>quarkus-maven-plugin</artifactId>\n"
                         "        <version>${quarkus.platform.version}</version>\n"
                         "        <executions>\n"
                         "          <execution>\n"
                         "            <goals>\n"
                         "              <goal>build</goal>\n"
                         "            </goals>\n"
                         "          </execution>\n"
                         "        </executions>\n"
                         "      </plugin>\n"
                         "    </plugins>\n"
                         "  </build>\n"
                         "</project>\n")
                 group-id artifact-id))
      (hell-template--write
       (expand-file-name "build.gradle" target)
       (format (concat "plugins {\n"
                       "    id 'java'\n"
                       "    id 'io.quarkus' version '3.15.1'\n"
                       "}\n\n"
                       "group = '%s'\n"
                       "version = '1.0.0-SNAPSHOT'\n\n"
                       "repositories {\n"
                       "    mavenCentral()\n"
                       "}\n\n"
                       "dependencies {\n"
                       "    implementation enforcedPlatform('io.quarkus.platform:quarkus-bom:3.15.1')\n"
                       "    implementation 'io.quarkus:quarkus-resteasy-reactive'\n"
                       "    implementation 'io.quarkus:quarkus-hibernate-orm-panache'\n"
                       "    implementation 'io.quarkus:quarkus-jdbc-h2'\n"
                       "    implementation 'io.quarkus:quarkus-arc'\n"
                       "    testImplementation 'io.quarkus:quarkus-junit5'\n"
                       "}\n\n"
                       "java {\n"
                       "    toolchain { languageVersion = JavaLanguageVersion.of(21) }\n"
                       "}\n")
               group-id)))
    ;; .hell-emacs/run.eld
    (hell-template--write
     (expand-file-name "run.eld" run-dir)
     (concat "((:name \"Quarkus Live Dev\"\n"
             "  :type shell\n"
             "  :command \"./mvnw quarkus:dev -Dquarkus.analytics.disabled=true\"\n"
             "  :directory \".\"))\n"))
    (message "Quarkus project created at %s" target)
    (dired target)))

;;;###autoload
(defun hell-template-new-micronaut (dir group-id artifact-id build-tool)
  "Scaffold a new Micronaut HTTP Service project at DIR."
  (interactive
   (list (read-directory-name "Project directory: ")
         (read-string "Group ID (e.g. com.example): " "com.example")
         (read-string "Artifact ID (e.g. demo): " "demo")
         (completing-read "Build tool: " '("maven" "gradle") nil t "maven")))
  (let* ((target (expand-file-name artifact-id dir))
         (pkg-path (replace-regexp-in-string "\\." "/" group-id))
         (java-src (expand-file-name (format "src/main/java/%s" pkg-path) target))
         (res-dir (expand-file-name "src/main/resources" target))
         (run-dir (expand-file-name ".hell-emacs" target)))
    (make-directory target t)
    ;; application.yml
    (hell-template--write
     (expand-file-name "application.yml" res-dir)
     (format (concat "micronaut:\n"
                     "  application:\n"
                     "    name: %s\n"
                     "  server:\n"
                     "    port: 8080\n")
             artifact-id))
    ;; Application.java
    (hell-template--write
     (expand-file-name "Application.java" java-src)
     (format (concat "package %s;\n\n"
                     "import io.micronaut.runtime.Micronaut;\n\n"
                     "public class Application {\n"
                     "    public static void main(String[] args) {\n"
                     "        Micronaut.run(Application.class, args);\n"
                     "    }\n"
                     "}\n")
             group-id))
    ;; HelloController.java
    (hell-template--write
     (expand-file-name "HelloController.java" java-src)
     (format (concat "package %s;\n\n"
                     "import io.micronaut.http.MediaType;\n"
                     "import io.micronaut.http.annotation.Controller;\n"
                     "import io.micronaut.http.annotation.Get;\n\n"
                     "@Controller(\"/hello\")\n"
                     "public class HelloController {\n\n"
                     "    @Get(produces = MediaType.TEXT_PLAIN)\n"
                     "    public String index() {\n"
                     "        return \"Hello from Micronaut!\";\n"
                     "    }\n"
                     "}\n")
             group-id))
    ;; Build file
    (if (string-equal build-tool "maven")
        (hell-template--write
         (expand-file-name "pom.xml" target)
         (format (concat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                         "<project xmlns=\"http://maven.apache.org/POM/4.0.0\"\n"
                         "         xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n"
                         "         xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd\">\n"
                         "  <modelVersion>4.0.0</modelVersion>\n"
                         "  <parent>\n"
                         "    <groupId>io.micronaut.platform</groupId>\n"
                         "    <artifactId>micronaut-parent</artifactId>\n"
                         "    <version>4.6.3</version>\n"
                         "  </parent>\n"
                         "  <groupId>%s</groupId>\n"
                         "  <artifactId>%s</artifactId>\n"
                         "  <version>1.0.0-SNAPSHOT</version>\n"
                         "  <properties>\n"
                         "    <jdk.version>21</jdk.version>\n"
                         "    <exec.mainClass>%s.Application</exec.mainClass>\n"
                         "  </properties>\n"
                         "  <dependencies>\n"
                         "    <dependency>\n"
                         "      <groupId>io.micronaut</groupId>\n"
                         "      <artifactId>micronaut-http-server-netty</artifactId>\n"
                         "    </dependency>\n"
                         "    <dependency>\n"
                         "      <groupId>io.micronaut.serde</groupId>\n"
                         "      <artifactId>micronaut-serde-jackson</artifactId>\n"
                         "    </dependency>\n"
                         "  </dependencies>\n"
                         "</project>\n")
                 group-id artifact-id group-id))
      (hell-template--write
       (expand-file-name "build.gradle" target)
       (format (concat "plugins {\n"
                       "    id 'com.github.johnrengelman.shadow' version '8.1.1'\n"
                       "    id 'io.micronaut.application' version '4.4.2'\n"
                       "}\n\n"
                       "version = '1.0.0-SNAPSHOT'\n"
                       "group = '%s'\n\n"
                       "repositories {\n"
                       "    mavenCentral()\n"
                       "}\n\n"
                       "dependencies {\n"
                       "    annotationProcessor 'io.micronaut.serde:micronaut-serde-processor'\n"
                       "    implementation 'io.micronaut.serde:micronaut-serde-jackson'\n"
                       "    implementation 'io.micronaut:micronaut-http-server-netty'\n"
                       "}\n\n"
                       "application {\n"
                       "    mainClass = '%s.Application'\n"
                       "}\n\n"
                       "java {\n"
                       "    toolchain { languageVersion = JavaLanguageVersion.of(21) }\n"
                       "}\n")
               group-id group-id)))
    ;; .hell-emacs/run.eld
    (hell-template--write
     (expand-file-name "run.eld" run-dir)
     (concat "((:name \"Micronaut Live Dev\"\n"
             "  :type shell\n"
             "  :command \"./mvnw mn:run\"\n"
             "  :directory \".\"))\n"))
    (message "Micronaut project created at %s" target)
    (dired target)))

;;;###autoload
(defun hell-template-new-project ()
  "Prompt for and scaffold a new cloud-native JVM project from templates."
  (interactive)
  (let ((choice (completing-read "Framework template: "
                                '("Quarkus RESTEasy Panache"
                                  "Micronaut HTTP Service")
                                nil t)))
    (pcase choice
      ("Quarkus RESTEasy Panache" (call-interactively #'hell-template-new-quarkus))
      ("Micronaut HTTP Service" (call-interactively #'hell-template-new-micronaut)))))

;;; Keybindings

(hell-leader-def
  "c n" '("new project from template" . hell-template-new-project)
  "r q" '("run quarkus dev" . hell-quarkus-dev)
  "r m" '("run micronaut dev" . hell-micronaut-dev))

(hell-localleader-def '(java-mode java-ts-mode)
  "q" '("cloud live dev" . (lambda () (interactive)
                             (cond ((hell-quarkus-project-p) (hell-quarkus-dev))
                                   ((hell-micronaut-project-p) (hell-micronaut-dev))
                                   (t (call-interactively #'hell-quarkus-dev))))))

(provide 'tools-templates-config)
;;; config.el ends here
