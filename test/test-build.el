;;; test-build.el --- Tests for the :tools build module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. Builds against real Gradle and Maven are
;; checked by the Phase 6.4 probes (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'compile)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-ux)                  ; `hellmacs-ux-enable', bound below

(let ((hellmacs-modules (make-hash-table :test #'equal)))
  (hellmacs--enable-modules '(:tools build))
  (hellmacs-module--load '(:tools . build) "autoload.el"))
(hellmacs-forge--add-error-regexps)

(defmacro test-build--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES (relative paths)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-build" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name f root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert ""))))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-build/detects-tool-and-root ()
  "The wrapper's directory wins over a nearer module build file."
  (test-build--with-tree '("gradlew" "settings.gradle" "app/build.gradle" "app/src/A.java")
    (let ((default-directory (expand-file-name "app/src/" root)))
      (should (equal (hellmacs-forge-build-tool) (list 'gradle root "./gradlew")))))
  (test-build--with-tree '("pom.xml" "src/A.java")
    (let ((default-directory (expand-file-name "src/" root)))
      (should (equal (hellmacs-forge-build-tool) (list 'maven root "mvn")))))
  ;; A wrapper left behind without its build file doesn't make it that build.
  (test-build--with-tree '("gradlew" "pom.xml" "src/A.java")
    (let ((default-directory (expand-file-name "src/" root)))
      (should (equal (hellmacs-forge-build-tool) (list 'maven root "mvn")))))
  (test-build--with-tree '("gradlew" "src/A.java")
    (should-not (hellmacs-forge-build-tool)))
  (test-build--with-tree '("src/A.java")
    (should-not (hellmacs-forge-build-tool))))

(ert-deftest test-build/commands ()
  (test-build--with-tree '("gradlew" "build.gradle.kts")
    (should (equal (hellmacs-forge--command 'build) "./gradlew build --console=plain"))
    (should (equal (hellmacs-forge--command 'test "p.C#m")
                   "./gradlew test --console=plain --tests p.C.m"))
    ;; A Kotlin test named with backticks can hold spaces and quotes.
    (should (equal (hellmacs-forge--command 'test "p.K#greets user's name")
                   "./gradlew test --console=plain --tests p.K.greets\\ user\\'s\\ name")))
  (test-build--with-tree '("mvnw" "pom.xml")
    (should (equal (hellmacs-forge--command 'build) "./mvnw -B verify"))
    (should (equal (hellmacs-forge--command 'test "p.C#m")
                   "./mvnw -B test -Dtest=p.C\\#m -Dsurefire.failIfNoSpecifiedTests=false"))))

(ert-deftest test-build/test-finders ()
  "The class is the file's, qualified; the method comes from the language."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/GreeterTest.java")
    (insert "package dev.x;\n\nclass GreeterTest {\n    void greets() {}\n}\n")
    (should (equal (hellmacs-forge-package) "dev.x"))
    (should (equal (hellmacs-forge--test-class) "dev.x.GreeterTest"))
    ;; Without a language's method finder, the whole class runs.
    (let (command)
      (cl-letf (((symbol-function 'hellmacs-forge--run) (lambda (_task test) (setq command test))))
        (hellmacs-forge-test-at-point)
        (should (equal command "dev.x.GreeterTest"))
        (setq-local hellmacs-forge-test-method-function (lambda () "greets"))
        (hellmacs-forge-test-at-point)
        (should (equal command "dev.x.GreeterTest#greets"))
        (setq-local hellmacs-forge-test-class-function (lambda () "other.Name"))
        (hellmacs-forge-test-class)
        (should (equal command "other.Name"))))
    (set-buffer-modified-p nil))
  ;; No package line (Kotlin's has no `;' either way).
  (with-temp-buffer
    (setq buffer-file-name "/tmp/Loose.kt")
    (should (equal (hellmacs-forge-file-class) "Loose"))
    (insert "package dev.y\n")
    (should (equal (hellmacs-forge-qualify "A") "dev.y.A"))
    (set-buffer-modified-p nil)))

(defun test-build--parse (output &optional full)
  "Parse OUTPUT as compilation output; return (TYPE FILE-BASENAME LINE) per match.
With FULL, the file is its whole resolved path."
  (let ((dir default-directory))
    (with-current-buffer (get-buffer-create " *test-build*")
      (setq default-directory dir)        ; the buffer outlives one tree
      (let ((inhibit-read-only t)) (erase-buffer) (insert output))
      (compilation-mode)
      (setq hellmacs-forge--source-index nil)
      (compilation--ensure-parse (point-max))
      (goto-char (point-min))
      (let (out)
        (while (let ((m (text-property-search-forward 'compilation-message nil (lambda (_ v) v))))
                 (when m
                   (let* ((msg (prop-match-value m)) (loc (compilation--message->loc msg)))
                     (push (list (compilation--message->type msg)
                                 (let ((path (caar (compilation--loc->file-struct loc))))
                                   (if full path (file-name-nondirectory path)))
                                 (compilation--loc->line loc))
                           out)))))
        (nreverse out)))))

(ert-deftest test-build/error-parsing ()
  "Project frames and test failures resolve; library frames are ignored."
  (test-build--with-tree '("pom.xml" "src/test/java/dev/x/BrokenTest.java" "src/main/java/dev/x/Greeter.java")
    ;; Maven/Surefire: a JUnit frame (not in the project) and a project frame.
    (should (equal (test-build--parse
                    "org.opentest4j.AssertionFailedError: nope\n\tat org.junit.jupiter.api.Assertions.assertEquals(Assertions.java:1199)\n\tat dev.x.BrokenTest.fails(BrokenTest.java:16)\n")
                   '((2 "BrokenTest.java" 16))))
    ;; Gradle's test failure line names only the file.
    (should (equal (test-build--parse "BrokenTest > fails() FAILED\n    org.opentest4j.AssertionFailedError at BrokenTest.java:16\n")
                   '((2 "BrokenTest.java" 16))))
    ;; Kotlin: "e:" is an error, "w:" a warning; the path is a percent-encoded file: URI.
    (let ((path (expand-file-name "src/main/java/dev/x/Greeter.java" root)))
      (should (equal (test-build--parse (format "e: file://%s:12:5 Unresolved reference 'x'.\nw: file://%s:3:1 Unused\n"
                                                path path))
                     '((2 "Greeter.java" 12) (1 "Greeter.java" 3))))
      ;; The path is percent-encoded: a directory with a space resolves to the real file.
      (make-directory (expand-file-name "src/main/my dir" root) t)
      (with-temp-file (expand-file-name "src/main/my dir/Odd.kt" root) (insert "x"))
      (should (equal (test-build--parse
                      (format "e: file://%s:2:9 bad\n"
                              (string-replace " " "%20" (expand-file-name "src/main/my dir/Odd.kt" root)))
                      t)
                     (list (list 2 (expand-file-name "src/main/my dir/Odd.kt" root) 2)))))
    ;; javac, then Gradle's indented repeat of it: an error, then info.
    (let ((path (expand-file-name "src/main/java/dev/x/Greeter.java" root)))
      (should (equal (test-build--parse (format "%s:12: error: bad\n  %s:12: error: bad\n" path path))
                     '((2 "Greeter.java" 12) (0 "Greeter.java" 12)))))))

(ert-deftest test-build/builds-get-the-jvm-options ()
  "With a proxy or CA, builds from a JVM buffer get them through JAVA_TOOL_OPTIONS."
  (test-build--with-tree '("pom.xml")
    (with-temp-buffer
      (cl-letf (((symbol-function 'hellmacs-net-jvm-options) (lambda () nil)))
        (hellmacs-forge-setup-build-h)
        (should-not (local-variable-p 'compilation-environment)))
      (cl-letf (((symbol-function 'hellmacs-net-jvm-options) (lambda () '("-Dhttps.proxyHost=p" "-Dhttps.proxyPort=1")))
                ((symbol-function 'getenv) (lambda (var &rest _) (and (equal var "JAVA_TOOL_OPTIONS") "-Xss4m"))))
        (hellmacs-forge-setup-build-h)
        (should (member "JAVA_TOOL_OPTIONS=-Xss4m -Dhttps.proxyHost=p -Dhttps.proxyPort=1"
                        compilation-environment))))
    ;; As a file opens, before compile.el is loaded: no error, and the
    ;; rest of the mode hook still runs.
    (let ((saved (default-value 'compilation-environment)))
      (makunbound 'compilation-environment)
      (unwind-protect
          (with-temp-buffer
            (cl-letf (((symbol-function 'hellmacs-net-jvm-options) (lambda () '("-Dx=1"))))
              (hellmacs-forge-setup-build-h)
              (should (equal compilation-environment '("JAVA_TOOL_OPTIONS=-Dx=1")))))
        (set-default 'compilation-environment saved)))))

(ert-deftest test-build/gradle-builds-run-on-a-jdk-gradle-runs-on ()
  "Builds from a Gradle buffer get `hellmacs-jdk-gradle-environment''s JAVA_HOME."
  (test-build--with-tree '("settings.gradle" "gradlew")
    (with-temp-buffer
      (cl-letf (((symbol-function 'hellmacs-net-jvm-options) #'ignore)
                ((symbol-function 'hellmacs-jdk-gradle-environment)
                 (lambda (dir) (and (file-equal-p dir root) '("JAVA_HOME=/jdk/25")))))
        (hellmacs-forge-setup-build-h)
        (should (member "JAVA_HOME=/jdk/25" compilation-environment)))))
  ;; Maven builds are left alone.
  (test-build--with-tree '("pom.xml")
    (with-temp-buffer
      (cl-letf (((symbol-function 'hellmacs-net-jvm-options) #'ignore)
                ((symbol-function 'hellmacs-jdk-gradle-environment) (lambda (_) '("JAVA_HOME=/jdk/25"))))
        (hellmacs-forge-setup-build-h)
        (should-not (local-variable-p 'compilation-environment))))))

(ert-deftest test-build/source-index-is-kept-and-refreshed-on-a-miss ()
  "The project is walked once across builds; again only for a file that may be new."
  (test-build--with-tree '("pom.xml" "src/main/java/dev/x/Greeter.java")
    (let ((walks 0)
          (hellmacs-forge--source-indexes (make-hash-table :test #'equal))
          (hellmacs-forge--source-index-roots nil))
      (cl-letf* ((walk (symbol-function 'hellmacs-forge--build-index))
                 ((symbol-function 'hellmacs-forge--build-index)
                  (lambda (root) (cl-incf walks) (funcall walk root))))
        (dotimes (_ 2)                  ; two builds
          (test-build--parse "\tat dev.x.Greeter.greet(Greeter.java:3)\n"))
        (should (= walks 1))
        ;; JDK frames never are the project's: no walk for them.
        (test-build--parse "\tat java.lang.Thread.run(Thread.java:1583)\n")
        (should (= walks 1))
        ;; A file added since, in a package the project has: found after one walk.
        (with-temp-file (expand-file-name "src/main/java/dev/x/Added.java" root) (insert "x"))
        (should (equal (test-build--parse "\tat dev.x.Added.run(Added.java:1)\n\tat dev.x.Nope.run(Nope.java:1)\n")
                       '((2 "Added.java" 1))))
        (should (= walks 2))))))

;; Kept for the last few build roots only: an index holds every source
;; file's path, and a session visits many projects.
(ert-deftest test-build/source-indexes-kept-for-recent-roots-only ()
  (let ((hellmacs-forge--source-indexes (make-hash-table :test #'equal))
        (hellmacs-forge--source-index-roots nil)
        (hellmacs-forge-source-index-limit 2))
    (hellmacs-forge--remember-index "/a/" 'index-a)
    (hellmacs-forge--remember-index "/b/" 'index-b)
    (should (eq (hellmacs-forge--cached-index "/a/") 'index-a)) ; /a/ used last now
    (hellmacs-forge--remember-index "/c/" 'index-c)
    (should (eq (hellmacs-forge--cached-index "/a/") 'index-a))
    (should (eq (hellmacs-forge--cached-index "/c/") 'index-c))
    (should-not (hellmacs-forge--cached-index "/b/"))
    (should (= (hash-table-count hellmacs-forge--source-indexes) 2))
    ;; Walking a root again replaces its index, without counting it twice.
    (hellmacs-forge--remember-index "/c/" 'index-c2)
    (should (eq (hellmacs-forge--cached-index "/c/") 'index-c2))
    (should (eq (hellmacs-forge--cached-index "/a/") 'index-a))))

(ert-deftest test-build/no-search-outside-a-project ()
  "Output from a `compile' run outside any build or project searches nothing."
  (test-build--with-tree '("src/dev/x/Greeter.java")
    (cl-letf (((symbol-function 'project-current) #'ignore))
      (let ((walks 0))
        (cl-letf* ((walk (symbol-function 'directory-files-recursively))
                   ((symbol-function 'directory-files-recursively)
                    (lambda (&rest args) (cl-incf walks) (apply walk args))))
          (should-not (test-build--parse "\tat dev.x.Greeter.greet(Greeter.java:12)\n"))
          (should (zerop walks)))))))

(ert-deftest test-build/report-messages ()
  (let ((hellmacs-ux-enable t))
    (with-current-buffer (get-buffer-create " *test-build-report*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "BrokenTest > fails() FAILED\n\n3 tests completed, 1 failed\n"))
      (compilation-mode)
      (should (equal (hellmacs-forge--test-failures) "1 of 3 tests"))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "[ERROR] Tests run: 1, Failures: 1, Errors: 0, Skipped: 0 <<< FAILURE! -- in X\n[ERROR] Tests run: 3, Failures: 1, Errors: 1, Skipped: 0\n"))
      (should (equal (hellmacs-forge--test-failures) "2 of 3 tests"))))
  (let ((hellmacs-ux-enable t))
    (should (equal (hellmacs-forge-announce 'tempered 1.25) "[FORGE TEMPERED] Built in 1.2s"))
    (should (equal (hellmacs-forge-announce 'purgatory "A.java:3") "[BYTECODE PURGATORY] A.java:3")))
  (let ((hellmacs-ux-enable nil))
    (should (equal (hellmacs-forge-announce 'damnation "1 of 3 tests") "Tests failed: 1 of 3 tests"))))

(ert-deftest test-build/commands-for-several-tests ()
  "A list of tests runs in one build: Gradle repeats --tests, Surefire takes a comma list."
  (test-build--with-tree '("gradlew" "build.gradle")
    (should (equal (hellmacs-forge--command 'test '("p.A#one" "p.B"))
                   "./gradlew test --console=plain --tests p.A.one --tests p.B")))
  (test-build--with-tree '("pom.xml")
    (should (equal (hellmacs-forge--command 'test '("p.A#one" "p.B"))
                   "mvn -B test -Dtest=p.A\\#one,p.B -Dsurefire.failIfNoSpecifiedTests=false"))))

(ert-deftest test-build/damnation-hint ()
  "Failing tests' message ends with `hellmacs-forge-test-failures-hint', when set."
  (let ((hellmacs-ux-enable t)
        (hellmacs-forge-test-failures-hint " -- see *hellmacs-tests*")
        (shown nil))
    (with-current-buffer (get-buffer-create " *test-build-hint*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "BrokenTest > fails() FAILED\n\n3 tests completed, 1 failed\n"))
      (compilation-mode)
      (cl-letf (((symbol-function 'message) (lambda (_fmt text) (setq shown text))))
        (hellmacs-forge--report-h (current-buffer) "exited abnormally with code 1\n"))
      (kill-buffer))
    (should (equal (substring-no-properties shown)
                   "[TEST DAMNATION] 1 of 3 tests -- see *hellmacs-tests*"))))

(ert-deftest test-build/build-problem-without-a-location ()
  "Failures with no file:line show the build tool's own reason."
  (with-temp-buffer
    (insert "FAILURE: Build failed with an exception.\n\n* What went wrong:\nCould not determine the dependencies of task ':compileKotlin'.\n> Cannot find a Java installation matching: {languageVersion=21}\n\n* Try:\n")
    (should (equal (hellmacs-forge--build-problem)
                   "Cannot find a Java installation matching: {languageVersion=21}")))
  (with-temp-buffer
    (insert "* What went wrong:\nA problem occurred evaluating root project 'x'.\n\n* Try:\n")
    (should (equal (hellmacs-forge--build-problem)
                   "A problem occurred evaluating root project 'x'.")))
  (with-temp-buffer
    (insert "[INFO] BUILD FAILURE\n[ERROR] Failed to execute goal on project demo: Could not resolve dependencies for project a:b:jar:1: no such artifact\n")
    (should (equal (hellmacs-forge--build-problem)
                   "Could not resolve dependencies for project a:b:jar:1: no such artifact")))
  (with-temp-buffer
    (insert "all good\n")
    (should-not (hellmacs-forge--build-problem))))

(provide 'test-build)
;;; test-build.el ends here
