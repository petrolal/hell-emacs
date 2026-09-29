;;; test-jdk.el --- Tests for JDK detection and toolchains -*- lexical-binding: t; -*-

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
(require 'hellmacs-modules)

(defvar test-jdk--root)
(defvar hellmacs-jdk-roots)
(defvar hellmacs-jdk-file)

(defmacro test-jdk--with-fake-fs (dirs files &rest body)
  "Run BODY with a mock filesystem containing DIRS and FILES alist."
  (declare (indent 2))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-jdk" t))))
     (unwind-protect
         (progn
           (dolist (d ,dirs)
             (make-directory (expand-file-name d root) t))
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path
                 (insert (cdr f)))))
           (let ((test-jdk--root root))
             ,@body))
       (delete-directory root t))))

(ert-deftest test-jdk/parse-version-string ()
  "Standard Java release numbers parse into JDTLS standard names."
  (should (equal (hellmacs-jdk-release-name "1.8") "JavaSE-1.8"))
  (should (equal (hellmacs-jdk-release-name "8") "JavaSE-1.8"))
  (should (equal (hellmacs-jdk-release-name "11") "JavaSE-11"))
  (should (equal (hellmacs-jdk-release-name "17") "JavaSE-17"))
  (should (equal (hellmacs-jdk-release-name "21") "JavaSE-21"))
  (should (equal (hellmacs-jdk-release-name "25") "JavaSE-25")))

(ert-deftest test-jdk/version-normalization-edge-cases ()
  "Handles complex JAVA_VERSION strings with build metadata and LTS suffixes."
  (should (equal (hellmacs-jdk-parse-release-content "JAVA_VERSION=\"21.0.2+13-LTS\"\n") "JavaSE-21"))
  (should (equal (hellmacs-jdk-parse-release-content "JAVA_VERSION='17.0.9+9'\n") "JavaSE-17"))
  (should (equal (hellmacs-jdk-parse-release-content "JAVA_VERSION=\"1.8.0_402-b06\"\n") "JavaSE-1.8"))
  (should (equal (hellmacs-jdk-parse-release-content "JAVA_VERSION=\"11.0.22\"\n") "JavaSE-11")))

(ert-deftest test-jdk/detect-from-sources ()
  "JDK detection scans standard paths and managers."
  (test-jdk--with-fake-fs
      '("sdkman/candidates/java/17.0.9-tem"
        "sdkman/candidates/java/21.0.2-graal"
        "usr/lib/jvm/java-11-openjdk"
        "usr/lib/jvm/java-8-openjdk"
        "Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"
        "asdf/installs/java/adoptopenjdk-11.0.11+9"
        "jenv/versions/17.0"
        "mise/installs/java/21.0.1")
      '(("sdkman/candidates/java/17.0.9-tem/release" . "JAVA_VERSION=\"17.0.9\"\n")
        ("sdkman/candidates/java/21.0.2-graal/release" . "JAVA_VERSION=\"21.0.2\"\n")
        ("usr/lib/jvm/java-11-openjdk/release" . "JAVA_VERSION=\"11.0.22\"\n")
        ("usr/lib/jvm/java-8-openjdk/release" . "JAVA_VERSION=\"1.8.0_402\"\n")
        ("Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/release" . "JAVA_VERSION=\"21.0.1\"\n")
        ("asdf/installs/java/adoptopenjdk-11.0.11+9/release" . "JAVA_VERSION=\"11.0.11\"\n")
        ("jenv/versions/17.0/release" . "JAVA_VERSION=\"17.0.0\"\n")
        ("mise/installs/java/21.0.1/release" . "JAVA_VERSION=\"21.0.1\"\n"))
    (let* ((scan-roots
            (list (expand-file-name "sdkman/candidates/java" test-jdk--root)
                  (expand-file-name "usr/lib/jvm" test-jdk--root)
                  (expand-file-name "Library/Java/JavaVirtualMachines" test-jdk--root)
                  (expand-file-name "asdf/installs/java" test-jdk--root)
                  (expand-file-name "jenv/versions" test-jdk--root)
                  (expand-file-name "mise/installs/java" test-jdk--root)))
           (found (hellmacs-jdk-scan-roots scan-roots)))
      (should (assoc "JavaSE-1.8" found))
      (should (assoc "JavaSE-11" found))
      (should (assoc "JavaSE-17" found))
      (should (assoc "JavaSE-21" found)))))

(ert-deftest test-jdk/lsp-java-configuration-runtimes ()
  "Generates valid vector of plists for `lsp-java-configuration-runtimes'."
  (let* ((jdks '(("JavaSE-1.8" . "/usr/lib/jvm/java-8")
                 ("JavaSE-11"  . "/usr/lib/jvm/java-11")
                 ("JavaSE-17"  . "/usr/lib/jvm/java-17")
                 ("JavaSE-21"  . "/usr/lib/jvm/java-21")))
         (default-path "/usr/lib/jvm/java-21")
         (runtimes (hellmacs-jdk-lsp-runtimes jdks default-path)))
    (should (vectorp runtimes))
    (should (= (length runtimes) 4))
    (should (equal (plist-get (aref runtimes 0) :name) "JavaSE-1.8"))
    (should (equal (plist-get (aref runtimes 0) :path) "/usr/lib/jvm/java-8"))
    (should (equal (plist-get (aref runtimes 0) :default) :json-false))
    (should (equal (plist-get (aref runtimes 3) :name) "JavaSE-21"))
    (should (equal (plist-get (aref runtimes 3) :default) t))))

(ert-deftest test-jdk/toolchains-xml-parsing ()
  "Parses Maven toolchains.xml to identify requested JDK versions."
  (test-jdk--with-fake-fs
      '("m2")
      '(("m2/toolchains.xml" .
         "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<toolchains>
  <toolchain>
    <type>jdk</type>
    <provides>
      <version>1.8</version>
      <vendor>temurin</vendor>
    </provides>
    <configuration>
      <jdkHome>/opt/jdks/jdk-8</jdkHome>
    </configuration>
  </toolchain>
  <toolchain>
    <type>jdk</type>
    <provides>
      <version>17</version>
    </provides>
    <configuration>
      <jdkHome>/opt/jdks/jdk-17</jdkHome>
    </configuration>
  </toolchain>
</toolchains>"))
    (let* ((xml-file (expand-file-name "m2/toolchains.xml" test-jdk--root))
           (versions (hellmacs-jdk-parse-toolchains-xml xml-file)))
      (should (member "JavaSE-1.8" versions))
      (should (member "JavaSE-17" versions)))))

(ert-deftest test-jdk/gradle-toolchain-detection ()
  "Detects Java toolchain version requirements in Gradle build files."
  (let ((kts-content "java {\n    toolchain {\n        languageVersion.set(JavaLanguageVersion.of(17))\n    }\n}")
        (groovy-content "java {\n    toolchain {\n        languageVersion = JavaLanguageVersion.of(11)\n    }\n}"))
    (should (equal (hellmacs-jdk-parse-gradle-toolchain kts-content) "JavaSE-17"))
    (should (equal (hellmacs-jdk-parse-gradle-toolchain groovy-content) "JavaSE-11"))))

(ert-deftest test-jdk/release-names-across-eras ()
  "JDTLS's names: J2SE-1.5, JavaSE-1.6 to 1.8, then JavaSE-9 on; junk is nil."
  (should (equal (hellmacs-jdk-release-name "1.5") "J2SE-1.5"))
  (should (equal (hellmacs-jdk-release-name "1.7.0_80") "JavaSE-1.7"))
  (should (equal (hellmacs-jdk-release-name "9") "JavaSE-9"))
  (should (equal (hellmacs-jdk-release-name "17.0.9") "JavaSE-17"))
  (should (equal (hellmacs-jdk-release-name 21) "JavaSE-21"))
  (should-not (hellmacs-jdk-release-name "abc"))
  (should-not (hellmacs-jdk-release-name nil))
  (should-not (hellmacs-jdk-parse-release-content "IMPLEMENTOR=\"Eclipse Adoptium\"\n")))

(ert-deftest test-jdk/scan-keeps-one-per-release ()
  "One JDK per release, in version order; links and non-JDKs are skipped."
  (test-jdk--with-fake-fs
      '("jvm/a-17" "jvm/b-17" "jvm/not-a-jdk" "jvm/x-11"
        "macos/temurin-8.jdk/Contents/Home")
      '(("jvm/a-17/release" . "JAVA_VERSION=\"17.0.1\"\n")
        ("jvm/b-17/release" . "JAVA_VERSION=\"17.0.9\"\n")
        ("jvm/x-11/release" . "JAVA_VERSION=\"11.0.2\"\n")
        ("jvm/stray-file" . "")
        ("macos/temurin-8.jdk/Contents/Home/release" . "JAVA_VERSION=\"1.8.0_402\"\n"))
    (make-symbolic-link (expand-file-name "jvm/x-11" test-jdk--root)
                        (expand-file-name "jvm/default-java" test-jdk--root))
    (let ((found (hellmacs-jdk-scan-roots
                  (list (expand-file-name "jvm" test-jdk--root)
                        (expand-file-name "macos" test-jdk--root)
                        (expand-file-name "missing" test-jdk--root)))))
      (should (equal (mapcar #'car found) '("JavaSE-1.8" "JavaSE-11" "JavaSE-17")))
      (should (equal (cdr (assoc "JavaSE-17" found))
                     (expand-file-name "jvm/a-17" test-jdk--root)))
      (should (equal (cdr (assoc "JavaSE-1.8" found))
                     (expand-file-name "macos/temurin-8.jdk/Contents/Home" test-jdk--root))))))

(ert-deftest test-jdk/detect-prefers-java-home ()
  "JAVA_HOME counts even outside the scanned places, and wins its release."
  (test-jdk--with-fake-fs
      '("jvm/distro-21" "elsewhere/my-21" "jvm/distro-17")
      '(("jvm/distro-21/release" . "JAVA_VERSION=\"21.0.1\"\n")
        ("jvm/distro-17/release" . "JAVA_VERSION=\"17.0.1\"\n")
        ("elsewhere/my-21/release" . "JAVA_VERSION=\"21.0.4\"\n"))
    (let ((hellmacs-jdk-roots (list (expand-file-name "jvm" test-jdk--root)))
          (process-environment (cons (concat "JAVA_HOME=" (expand-file-name "elsewhere/my-21" test-jdk--root))
                                     process-environment))
          (exec-path nil))              ; no java on the PATH to find
      (should (equal (hellmacs-jdk-detect)
                     (list (cons "JavaSE-17" (expand-file-name "jvm/distro-17" test-jdk--root))
                           (cons "JavaSE-21" (expand-file-name "elsewhere/my-21" test-jdk--root))))))))

(ert-deftest test-jdk/default-roots ()
  "The places searched follow SDKMAN's, asdf's and mise's own variables."
  (let ((process-environment (append '("SDKMAN_DIR=/sdk" "ASDF_DATA_DIR=/asdf" "MISE_DATA_DIR=/mise")
                                     process-environment)))
    (let ((roots (hellmacs-jdk-default-roots)))
      (should (member "/sdk/candidates/java" roots))
      (should (member "/asdf/installs/java" roots))
      (should (member "/mise/installs/java" roots))
      (should (member "/usr/lib/jvm" roots))
      (should (member "/Library/Java/JavaVirtualMachines" roots))
      (should (member (expand-file-name "~/.jenv/versions") roots)))))

(ert-deftest test-jdk/store-round-trip ()
  "What sync found is written, and read back at startup; nothing stored reads as nil."
  (let ((hellmacs-jdk-file (make-temp-file "hellmacs-test-jdks" nil ".eld")))
    (unwind-protect
        (progn
          (delete-file hellmacs-jdk-file)
          (should-not (hellmacs-jdk-read))
          (hellmacs-jdk-write '(("JavaSE-11" . "/j/11") ("JavaSE-21" . "/j/21")))
          (should (equal (hellmacs-jdk-read) '(("JavaSE-11" . "/j/11") ("JavaSE-21" . "/j/21"))))
          (with-temp-file hellmacs-jdk-file (insert "(unbalanced"))
          (should-not (hellmacs-jdk-read)))
      (when (file-exists-p hellmacs-jdk-file) (delete-file hellmacs-jdk-file)))))

(ert-deftest test-jdk/runtimes-default-fallback ()
  "Without a matching default, the newest JDK is; no JDKs, an empty vector."
  (let ((runtimes (hellmacs-jdk-lsp-runtimes '(("JavaSE-11" . "/j/11") ("JavaSE-21" . "/j/21")) nil)))
    (should (equal (plist-get (aref runtimes 0) :default) :json-false))
    (should (equal (plist-get (aref runtimes 1) :default) t)))
  (let ((runtimes (hellmacs-jdk-lsp-runtimes '(("JavaSE-11" . "/j/11") ("JavaSE-21" . "/j/21")) "/j/11/")))
    (should (equal (plist-get (aref runtimes 0) :default) t))
    (should (equal (plist-get (aref runtimes 1) :default) :json-false)))
  (should (equal (hellmacs-jdk-lsp-runtimes nil nil) [])))

(ert-deftest test-jdk/toolchain-versions-and-ranges ()
  "Version ranges name their lower bound; no toolchain block, nil."
  (test-jdk--with-fake-fs
      '("m2")
      '(("m2/toolchains.xml" . "<toolchains><toolchain><type>jdk</type><provides><version>[11,)</version></provides></toolchain>\
<toolchain><type>netbeans</type><provides><version>12</version></provides></toolchain></toolchains>"))
    (should (equal (hellmacs-jdk-parse-toolchains-xml (expand-file-name "m2/toolchains.xml" test-jdk--root))
                   '("JavaSE-11")))
    (should-not (hellmacs-jdk-parse-toolchains-xml (expand-file-name "m2/none.xml" test-jdk--root))))
  (should-not (hellmacs-jdk-parse-gradle-toolchain "plugins { id 'java' }"))
  (should (equal (hellmacs-jdk-parse-gradle-toolchain "languageVersion = JavaLanguageVersion.of( 8 )")
                 "JavaSE-1.8")))

(ert-deftest test-jdk/home-major-and-pick ()
  "A JDK's major release comes from its release file; the pick is the first in range."
  (test-jdk--with-fake-fs
      '("j8" "j21" "j25" "j27" "junk")
      '(("j8/release" . "JAVA_VERSION=\"1.8.0_402\"\n")
        ("j21/release" . "JAVA_VERSION=\"21.0.1\"\n")
        ("j25/release" . "JAVA_VERSION=\"25.0.4\"\n")
        ("j27/release" . "JAVA_VERSION=\"27\"\n"))
    (let ((home (lambda (d) (expand-file-name d test-jdk--root))))
      (should (= (hellmacs-jdk-home-major (funcall home "j8")) 8))
      (should (= (hellmacs-jdk-home-major (funcall home "j25")) 25))
      (should-not (hellmacs-jdk-home-major (funcall home "junk")))
      (should-not (hellmacs-jdk-home-major nil))
      (should (equal (hellmacs-jdk-pick (list nil (funcall home "j27") (funcall home "junk")
                                              (funcall home "j8") (funcall home "j25") (funcall home "j21"))
                                        21 25)
                     (funcall home "j25")))
      (should-not (hellmacs-jdk-pick (list (funcall home "j27") (funcall home "j8")) 21 25)))))

(ert-deftest test-jdk/toolchains-xml-jdks ()
  "toolchains.xml's JDKs, with the home each gives."
  (test-jdk--with-fake-fs
      '("m2")
      '(("m2/toolchains.xml" . "<toolchains>
  <toolchain><type>jdk</type><provides><version>1.8</version></provides>
    <configuration><jdkHome>/opt/jdks/jdk-8</jdkHome></configuration></toolchain>
  <toolchain><type>jdk</type><provides><version>17</version></provides></toolchain>
</toolchains>"))
    (should (equal (hellmacs-jdk-toolchains-xml-jdks (expand-file-name "m2/toolchains.xml" test-jdk--root))
                   '(("JavaSE-1.8" . "/opt/jdks/jdk-8") ("JavaSE-17"))))))

(ert-deftest test-jdk/gradle-build-request ()
  "What a Gradle build asks its toolchain for, and where, from anywhere inside it."
  (test-jdk--with-fake-fs
      '("app/src/main/java")
      '(("app/settings.gradle" . "rootProject.name = 'app'\n")
        ("app/build.gradle" . "plugins {\n    id 'java'\n}\n\njava {\n    toolchain {\n        languageVersion = JavaLanguageVersion.of(11)\n    }\n}\n"))
    (let ((root (expand-file-name "app/" test-jdk--root)))
      (should (equal (hellmacs-jdk-build-request (expand-file-name "src/main/java/" root))
                     (list :tool 'gradle :release "JavaSE-11"
                           :file (expand-file-name "build.gradle" root) :line 7)))))
  (test-jdk--with-fake-fs
      '("k")
      '(("k/build.gradle.kts" . "kotlin {\n    jvmToolchain(17)\n}\n"))
    (should (equal (plist-get (hellmacs-jdk-build-request (expand-file-name "k/" test-jdk--root)) :release)
                   "JavaSE-17")))
  (test-jdk--with-fake-fs
      '("plain")
      '(("plain/build.gradle" . "plugins { id 'java' }\n"))
    (should-not (hellmacs-jdk-build-request (expand-file-name "plain/" test-jdk--root)))))

(ert-deftest test-jdk/maven-build-request ()
  "What maven-toolchains-plugin asks for, in either of its forms; nothing without it."
  (test-jdk--with-fake-fs
      '("m" "s" "none")
      '(("m/pom.xml" . "<project>
  <build><plugins>
    <plugin>
      <artifactId>maven-compiler-plugin</artifactId>
      <configuration><release>8</release></configuration>
    </plugin>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-toolchains-plugin</artifactId>
      <configuration>
        <toolchains>
          <jdk>
            <version>[17,)</version>
          </jdk>
        </toolchains>
      </configuration>
    </plugin>
  </plugins></build>
</project>")
        ("s/pom.xml" . "<project><build><plugins><plugin>
<artifactId>maven-toolchains-plugin</artifactId>
<configuration>
<version>21</version>
</configuration></plugin></plugins></build></project>")
        ("none/pom.xml" . "<project><properties><maven.compiler.release>8</maven.compiler.release></properties></project>"))
    (should (equal (hellmacs-jdk-build-request (expand-file-name "m/" test-jdk--root))
                   (list :tool 'maven :release "JavaSE-17"
                         :file (expand-file-name "m/pom.xml" test-jdk--root) :line 13)))
    (should (equal (plist-get (hellmacs-jdk-build-request (expand-file-name "s/" test-jdk--root)) :release)
                   "JavaSE-21"))
    (should-not (hellmacs-jdk-build-request (expand-file-name "none/" test-jdk--root)))))

(ert-deftest test-jdk/gradle-installations-and-provisioning ()
  "Gradle's own JDK list (installations.paths) and whether it downloads JDKs."
  (test-jdk--with-fake-fs
      '("gh" "proj")
      '(("gh/gradle.properties" . "org.gradle.jvmargs=-Xmx1g\norg.gradle.java.installations.paths=/opt/a, /opt/b\n")
        ("proj/gradle.properties" . "org.gradle.java.installations.paths=/opt/c\n")
        ("proj/settings.gradle.kts" . "plugins {\n    id(\"org.gradle.toolchains.foojay-resolver-convention\") version \"1.0.0\"\n}\n"))
    (let ((process-environment (cons (concat "GRADLE_USER_HOME=" (expand-file-name "gh" test-jdk--root))
                                     process-environment))
          (proj (expand-file-name "proj/" test-jdk--root)))
      (should (equal (hellmacs-jdk-gradle-installation-paths proj) '("/opt/c" "/opt/a" "/opt/b")))
      (should (hellmacs-jdk-gradle-provisions-p proj))
      (should-not (hellmacs-jdk-gradle-provisions-p (expand-file-name "gh/" test-jdk--root))))))

(ert-deftest test-jdk/default-roots-include-intellij ()
  "IntelliJ's downloaded JDKs (~/.jdks), which Gradle finds too."
  (should (member (expand-file-name "~/.jdks") (hellmacs-jdk-default-roots))))

(ert-deftest test-jdk/java-executable-new-enough ()
  "A java of at least a release: JAVA_HOME's, then those sync found, then the PATH's."
  (require 'hellmacs-jdk)
  (let ((root (file-name-as-directory (make-temp-file "hellmacs-test-jdk-java" t))))
    (unwind-protect
        (cl-flet ((jdk (name major)
                    (let ((home (expand-file-name name root)))
                      (make-directory (expand-file-name "bin" home) t)
                      (with-temp-file (expand-file-name "release" home)
                        (insert (format "JAVA_VERSION=\"%d.0.2\"\n" major)))
                      home)))
          (let ((jdk11 (jdk "jdk11" 11)) (jdk17 (jdk "jdk17" 17)) (jdk25 (jdk "jdk25" 25)))
            (cl-letf (((symbol-function 'hellmacs-jdk-read)
                       (lambda () (list (cons "JavaSE-17" jdk17) (cons "JavaSE-25" jdk25))))
                      ((symbol-function 'executable-find) #'ignore))
              (let ((process-environment (cons (concat "JAVA_HOME=" jdk11) process-environment)))
                (should (equal (hellmacs-jdk-java-executable 11) (expand-file-name "bin/java" jdk11)))
                (should (equal (hellmacs-jdk-java-executable 17) (expand-file-name "bin/java" jdk17)))
                (should (equal (hellmacs-jdk-java-executable 21) (expand-file-name "bin/java" jdk25)))
                ;; None new enough: plain "java", for the error to name.
                (should (equal (hellmacs-jdk-java-executable 99) "java"))))))
      (delete-directory root t))))

(provide 'test-jdk)
;;; test-jdk.el ends here
