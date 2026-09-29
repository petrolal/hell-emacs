;;; test-results-view.el --- Tests for the :tools test results view (Phase 12.5) -*- lexical-binding: t; -*-

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
(require 'compile)
(require 'hellmacs-keybinds)
(require 'hellmacs-modules)

;; :tools test's code, and :tools build's, which runs the tests.
(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools build test))
  (hellmacs-module--load '(:tools . build) "autoload.el")
  (hellmacs-module--load '(:tools . test) "autoload.el")
  (hellmacs-module--load '(:tools . test) "config.el"))

(defmacro test-results--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-results" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (when (get-buffer "*hellmacs-tests*") (kill-buffer "*hellmacs-tests*"))
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
           (kill-buffer b)))
       (delete-directory root t))))

(defconst test-results--surefire
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuite name=\"com.example.AppTest\" time=\"0.125\" tests=\"3\" errors=\"0\" skipped=\"0\" failures=\"1\">
  <testcase name=\"testPass\" classname=\"com.example.AppTest\" time=\"0.010\"/>
  <testcase name=\"testFail\" classname=\"com.example.AppTest\" time=\"0.050\">
    <failure message=\"expected 42 but got 41\" type=\"org.junit.ComparisonFailure\">
      org.junit.ComparisonFailure: expected 42 but got 41
      at com.example.AppTest.testFail(AppTest.java:25)
    </failure>
  </testcase>
  <testcase name=\"testPassTwo\" classname=\"com.example.AppTest\" time=\"0.005\"/>
</testsuite>")

(defconst test-results--gradle
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuite name=\"dev.x.GreeterTest\" tests=\"4\" skipped=\"1\" failures=\"0\" errors=\"1\" time=\"0.2\">
  <properties/>
  <testcase name=\"greets()\" classname=\"dev.x.GreeterTest\" time=\"0.01\"/>
  <testcase name=\"sums(int)[2]\" classname=\"dev.x.GreeterTest\" time=\"0.02\"/>
  <testcase name=\"later()\" classname=\"dev.x.GreeterTest\" time=\"0.0\">
    <skipped/>
  </testcase>
  <testcase name=\"explodes()\" classname=\"dev.x.GreeterTest\" time=\"0.03\">
    <error message=\"boom\" type=\"java.lang.IllegalStateException\">java.lang.IllegalStateException: boom
	at dev.x.Greeter.explode(Greeter.java:9)
	at dev.x.GreeterTest.explodes(GreeterTest.java:14)
</error>
  </testcase>
  <system-out><![CDATA[]]></system-out>
</testsuite>")

(defconst test-results--app-test
  "package com.example;

class AppTest {
    void testPass() {}

    void testPassTwo() {}
}
")

(ert-deftest test-results/parse-junit-xml ()
  "Parses Maven surefire / Gradle JUnit XML test result reports."
  (test-results--with-tree
      `(("target/surefire-reports/TEST-com.example.AppTest.xml" . ,test-results--surefire))
    (let* ((xml-file (expand-file-name "target/surefire-reports/TEST-com.example.AppTest.xml" root))
           (suite (hellmacs-test-results-parse-junit-xml xml-file)))
      (should (equal (plist-get suite :suite) "com.example.AppTest"))
      (should (= (plist-get suite :total) 3))
      (should (= (plist-get suite :failures) 1))
      (let ((cases (plist-get suite :cases)))
        (should (= (length cases) 3))
        (let ((failed (cl-find-if (lambda (c) (plist-get c :failure)) cases)))
          (should failed)
          (should (equal (plist-get failed :name) "testFail"))
          (should (string-match-p "expected 42" (plist-get failed :failure))))))))

(ert-deftest test-results/parse-errors-and-skips ()
  "Errors count as failures; skipped tests are marked; each case knows its status."
  (test-results--with-tree `(("build/test-results/test/TEST-dev.x.GreeterTest.xml" . ,test-results--gradle))
    (let* ((suite (hellmacs-test-results-parse-junit-xml
                   (expand-file-name "build/test-results/test/TEST-dev.x.GreeterTest.xml" root)))
           (cases (plist-get suite :cases)))
      (should (= (plist-get suite :total) 4))
      (should (= (plist-get suite :failures) 1))
      (should (= (plist-get suite :skipped) 1))
      (should (equal (mapcar (lambda (c) (plist-get c :status)) cases) '(pass pass skip fail)))
      (should (equal (plist-get (nth 3 cases) :failure) "boom"))
      (should (string-match-p "GreeterTest.java:14" (plist-get (nth 3 cases) :trace)))
      (should (= (plist-get (nth 1 cases) :time) 0.02))))
  ;; A broken file is skipped, not an error.
  (test-results--with-tree '(("target/surefire-reports/TEST-bad.xml" . "<testsuite name="))
    (should-not (hellmacs-test-results-parse-junit-xml
                 (expand-file-name "target/surefire-reports/TEST-bad.xml" root)))))

(ert-deftest test-results/parse-cdata-traces ()
  "A trace written as CDATA (and a suite's own output) reads as text."
  (test-results--with-tree
      '(("build/test-results/test/TEST-dev.x.CdataTest.xml" .
         "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuite name=\"dev.x.CdataTest\" tests=\"1\" time=\"0.1\">
  <testcase name=\"fails\" classname=\"dev.x.CdataTest\" time=\"0.1\">
    <failure message=\"a &lt; b\"><![CDATA[java.lang.AssertionError: a < b
\tat dev.x.CdataTest.fails(CdataTest.java:9)]]></failure>
  </testcase>
  <system-out><![CDATA[log <line>]]></system-out>
</testsuite>"))
    ;; With libxml, and with xml.el where Emacs has no libxml.
    (dolist (libxml '(t nil))
      (cl-letf (((symbol-function 'libxml-available-p) (lambda () libxml)))
        (let* ((suite (hellmacs-test-results-parse-junit-xml
                       (expand-file-name "build/test-results/test/TEST-dev.x.CdataTest.xml" root)))
               (case (car (plist-get suite :cases))))
          (should (= (plist-get suite :total) 1))
          (should (equal (plist-get case :failure) "a < b"))
          (should (string-match-p "\\`java.lang.AssertionError: a < b\n\tat dev.x.CdataTest.fails(CdataTest.java:9)\\'"
                                  (plist-get case :trace))))))))

(ert-deftest test-results/locate-report-files ()
  "Finds test report XMLs across Maven target and Gradle build directories."
  (test-results--with-tree
      '(("target/surefire-reports/TEST-A.xml" . "<testsuite name=\"A\"/>")
        ("target/failsafe-reports/TEST-IT.xml" . "<testsuite name=\"IT\"/>")
        ("build/test-results/test/TEST-B.xml" . "<testsuite name=\"B\"/>"))
    (let ((reports (hellmacs-test-results-find-reports root)))
      (should (= (length reports) 3)))))

(ert-deftest test-results/reports-in-modules-only-from-test-output ()
  "Reports of every module are found; other XML files aren't reports."
  (test-results--with-tree
      '(("app/build/test-results/test/TEST-C.xml" . "<testsuite name=\"C\"/>")
        ("lib/target/surefire-reports/TEST-D.xml" . "<testsuite name=\"D\"/>")
        ("lib/target/surefire-reports/D.txt" . "summary")
        ("build/reports/tests/index.xml" . "<x/>")
        ("src/main/resources/beans.xml" . "<beans/>")
        ("pom.xml" . "<project/>"))
    (should (equal (mapcar (lambda (f) (file-relative-name f root))
                           (hellmacs-test-results-find-reports root))
                   '("app/build/test-results/test/TEST-C.xml"
                     "lib/target/surefire-reports/TEST-D.xml")))))

(ert-deftest test-results/test-ids ()
  "A case's name as the build's test filter wants it: no parentheses, no parameter index."
  (should (equal (hellmacs-test-results--test-id '(:class "p.A" :name "testFail")) "p.A#testFail"))
  (should (equal (hellmacs-test-results--test-id '(:class "p.A" :name "greets()")) "p.A#greets"))
  (should (equal (hellmacs-test-results--test-id '(:class "p.A" :name "sums(int)[2]")) "p.A#sums"))
  (should (equal (hellmacs-test-results--test-id '(:class "p.A" :name "[1] 2, 3")) "p.A")))

(ert-deftest test-results/view ()
  "The view lists every test, failures first, with suite, time and message."
  (test-results--with-tree
      `(("target/surefire-reports/TEST-com.example.AppTest.xml" . ,test-results--surefire)
        ("pom.xml" . "<project/>"))
    (with-current-buffer (hellmacs-test-results-show root)
      (should (equal (buffer-name) "*hellmacs-tests*"))
      (should (derived-mode-p 'hellmacs-test-results-mode))
      (should (derived-mode-p 'tabulated-list-mode))
      (should (equal default-directory root))
      (should (= (length tabulated-list-entries) 3))
      (goto-char (point-min))
      (let ((row (tabulated-list-get-entry)))
        (should (string-match-p "FAIL" (aref row 0)))
        (should (equal (aref row 1) "AppTest"))
        (should (equal (aref row 2) "testFail"))
        (should (string-match-p "expected 42" (aref row 4))))
      (should (string-match-p "1 failed of 3 tests" mode-line-process)))))

(ert-deftest test-results/keys ()
  (should (eq (keymap-lookup hellmacs-test-results-mode-map "RET") #'hellmacs-test-results-jump))
  (should (eq (keymap-lookup hellmacs-test-results-mode-map "r") #'hellmacs-test-results-rerun-at-point))
  (should (eq (keymap-lookup hellmacs-test-results-mode-map "f") #'hellmacs-test-results-rerun-failures))
  (should (eq (keymap-lookup hellmacs-test-results-mode-map "g") #'hellmacs-test-results-refresh))
  (should (eq (keymap-lookup hellmacs-test-results-mode-map "c") #'hellmacs-coverage-summary))
  (should (eq (keymap-lookup global-map "C-c t t") #'hellmacs-test-results))
  (should (eq (keymap-lookup global-map "C-c t f") #'hellmacs-test-results-rerun-failures))
  (should (eq (keymap-lookup global-map "C-c t c") #'hellmacs-coverage-run))
  (should (eq (keymap-lookup global-map "C-c t s") #'hellmacs-coverage-show))
  (should (eq (keymap-lookup global-map "C-c t h") #'hellmacs-coverage-hide)))

(ert-deftest test-results/rerun ()
  "`r' reruns the test at point, `f' every failing one, through :tools build."
  (test-results--with-tree
      `(("target/surefire-reports/TEST-dev.x.GreeterTest.xml" . ,test-results--gradle)
        ("target/surefire-reports/TEST-com.example.AppTest.xml" . ,test-results--surefire)
        ("pom.xml" . "<project/>"))
    (let (runs)
      (cl-letf (((symbol-function 'hellmacs-forge--run)
                 (lambda (task test) (push (list task test default-directory) runs))))
        (with-current-buffer (hellmacs-test-results-show root)
          (goto-char (point-min))
          (hellmacs-test-results-rerun-at-point)
          (should (equal (car runs) (list 'test "com.example.AppTest#testFail" root)))
          (hellmacs-test-results-rerun-failures)
          (should (equal (car runs) (list 'test '("com.example.AppTest#testFail"
                                                  "dev.x.GreeterTest#explodes")
                                          root)))))))
  (test-results--with-tree
      '(("target/surefire-reports/TEST-A.xml" .
         "<testsuite name=\"A\" tests=\"1\"><testcase name=\"ok\" classname=\"A\"/></testsuite>")
        ("pom.xml" . "<project/>"))
    (with-current-buffer (hellmacs-test-results-show root)
      (should-error (hellmacs-test-results-rerun-failures) :type 'user-error))))

(ert-deftest test-results/jump ()
  "RET goes to the failure's line in the test, or to the test method."
  (test-results--with-tree
      `(("target/surefire-reports/TEST-com.example.AppTest.xml" . ,test-results--surefire)
        ("src/test/java/com/example/AppTest.java" . ,(concat test-results--app-test (make-string 30 ?\n)))
        ("pom.xml" . "<project/>"))
    (with-current-buffer (hellmacs-test-results-show root)
      (goto-char (point-min))           ; testFail: its frame, AppTest.java:25
      (hellmacs-test-results-jump)
      (should (equal buffer-file-name (expand-file-name "src/test/java/com/example/AppTest.java" root)))
      (should (= (line-number-at-pos) 25)))
    (with-current-buffer "*hellmacs-tests*"
      (goto-char (point-min))
      (forward-line 2)                  ; testPassTwo: no frame, its declaration
      (should (equal (aref (tabulated-list-get-entry) 2) "testPassTwo"))
      (hellmacs-test-results-jump)
      (should (looking-at "    void testPassTwo")))))

(ert-deftest test-results/refreshed-after-a-test-run ()
  "A build that ran tests refreshes the view with the reports it wrote."
  (test-results--with-tree
      `(("target/surefire-reports/TEST-com.example.AppTest.xml" . ,test-results--surefire)
        ("pom.xml" . "<project/>"))
    (let ((report (expand-file-name "target/surefire-reports/TEST-com.example.AppTest.xml" root)))
      (set-file-times report (time-subtract nil 60))  ; an old report...
      (with-temp-buffer
        (setq default-directory root)
        (insert "[ERROR] Tests run: 3, Failures: 1, Errors: 0, Skipped: 0\n")
        (compilation-mode)
        (setq hellmacs-forge--started (- (float-time) 10))
        (hellmacs-test-results--after-build-h (current-buffer) "exited abnormally\n")
        (should-not (get-buffer "*hellmacs-tests*"))   ; ...isn't this run's
        (set-file-times report)
        (hellmacs-test-results--after-build-h (current-buffer) "exited abnormally\n")
        (should (get-buffer "*hellmacs-tests*"))
        (with-current-buffer "*hellmacs-tests*"
          (should (= (length tabulated-list-entries) 3)))))))

(ert-deftest test-results/watch-target ()
  "+watch: a saved test runs itself; a saved class, its FooTest if there is one."
  (test-results--with-tree '(("pom.xml" . "<project/>")
                             ("src/main/java/p/Foo.java" . "package p;\nclass Foo {}\n")
                             ("src/main/java/p/Bar.java" . "package p;\nclass Bar {}\n")
                             ("src/test/java/p/FooTest.java" . "package p;\nclass FooTest {}\n")
                             ("src/test/java/p/Helpers.java" . "package p;\nclass Helpers {}\n"))
    (cl-flet ((target (file) (with-current-buffer (find-file-noselect (expand-file-name file root))
                               (hellmacs-test-watch--target))))
      (should (equal (target "src/test/java/p/FooTest.java") "p.FooTest"))
      (should (equal (target "src/main/java/p/Foo.java") "p.FooTest"))
      (should-not (target "src/main/java/p/Bar.java"))     ; no BarTest
      (should (equal (target "src/test/java/p/Helpers.java") "p.Helpers")))))

(ert-deftest test-results/watch-runs-on-save ()
  (test-results--with-tree '(("pom.xml" . "<project/>")
                             ("src/test/java/p/FooTest.java" . "package p;\nclass FooTest {}\n")
                             ("src/main/java/p/Bar.java" . "package p;\nclass Bar {}\n"))
    (let (runs)
      (cl-letf (((symbol-function 'hellmacs-forge--run) (lambda (task test) (push (list task test) runs))))
        (with-current-buffer (find-file-noselect (expand-file-name "src/test/java/p/FooTest.java" root))
          (hellmacs-test-watch-mode)
          (insert " ")
          (save-buffer)
          (should (equal runs '((test "p.FooTest"))))
          (hellmacs-test-watch-mode -1)
          (insert " ")
          (save-buffer)
          (should (= (length runs) 1)))
        (with-current-buffer (find-file-noselect (expand-file-name "src/main/java/p/Bar.java" root))
          (hellmacs-test-watch-mode)
          (insert " ")
          (save-buffer)                 ; nothing to run: no BarTest
          (should (= (length runs) 1)))))))

(ert-deftest test-results/hint-in-the-damnation-message ()
  (should (string-match-p (regexp-quote "*hellmacs-tests*") hellmacs-forge-test-failures-hint)))

(provide 'test-results-view)
;;; test-results-view.el ends here
