;;; test-static.el --- Tests for the :checkers static module (Phase 12.6) -*- lexical-binding: t; -*-

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
(require 'flymake)
(require 'compile)
(require 'hellmacs-modules)

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:checkers static))
  (hellmacs-module--load '(:checkers . static) "autoload.el"))

(defmacro test-static--with-tree (files &rest body)
  "Run BODY in a temporary project ROOT holding FILES (alist of path . content).
Content may name ROOT as @ROOT@."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (file-truename (make-temp-file "hellmacs-test-static" t))))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (string-replace "@ROOT@" root (cdr f))))))
           ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory root t))))

(defmacro test-static--both-readers (&rest body)
  "Run BODY with libxml, then with xml.el (Emacs without libxml)."
  `(dolist (libxml '(t nil))
     (cl-letf (((symbol-function 'libxml-available-p) (lambda () libxml)))
       ,@body)))

(defconst test-static--greeter
  "package dev.x;\n\nclass Greeter {\n    private int unused;\n\n    String greet(String s) {\n        String n = null;\n        return n.trim() + s;\n    }\n}\n")

(defconst test-static--checkstyle
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<checkstyle version=\"10.21.4\">
<file name=\"@ROOT@src/main/java/dev/x/Greeter.java\">
<error line=\"3\" column=\"1\" severity=\"warning\" message=\"Missing a Javadoc comment.\" source=\"com.puppycrawl.tools.checkstyle.checks.javadoc.MissingJavadocTypeCheck\"/>
<error line=\"6\" severity=\"error\" message=\"Method &apos;greet&apos; should be final.\" source=\"com.puppycrawl.tools.checkstyle.checks.design.DesignForExtensionCheck\"/>
<error line=\"7\" column=\"9\" severity=\"ignore\" message=\"Ignored.\" source=\"x.IgnoredCheck\"/>
</file>
<file name=\"@ROOT@src/main/java/dev/x/Clean.java\">
</file>
</checkstyle>")

(defconst test-static--pmd
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<pmd xmlns=\"http://pmd.sourceforge.net/report/2.0.0\" version=\"7.13.0\" timestamp=\"2026-09-29T10:00:00.000\">
<file name=\"@ROOT@src/main/java/dev/x/Greeter.java\">
<violation beginline=\"4\" endline=\"4\" begincolumn=\"17\" endcolumn=\"23\" rule=\"UnusedPrivateField\" ruleset=\"Best Practices\" package=\"dev.x\" class=\"Greeter\" priority=\"3\">
Avoid unused private fields such as 'unused'.
</violation>
<violation beginline=\"8\" endline=\"8\" begincolumn=\"16\" endcolumn=\"23\" rule=\"NullAssignment\" ruleset=\"Error Prone\" priority=\"1\">
Assigning an Object to null is a code smell.
</violation>
</file>
</pmd>")

(defconst test-static--spotbugs
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<BugCollection version=\"4.9.3\" sequence=\"0\" timestamp=\"1\" analysisTimestamp=\"1\" release=\"\">
<Project projectName=\"demo\">
<Jar>@ROOT@target/classes</Jar>
<SrcDir>@ROOT@src/main/java</SrcDir>
</Project>
<BugInstance type=\"NP_LOAD_OF_KNOWN_NULL_VALUE\" priority=\"1\" rank=\"5\" abbrev=\"NP\" category=\"CORRECTNESS\">
<Class classname=\"dev.x.Greeter\" primary=\"true\">
<SourceLine classname=\"dev.x.Greeter\" start=\"3\" end=\"10\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\"/>
</Class>
<Method classname=\"dev.x.Greeter\" name=\"greet\" signature=\"(Ljava/lang/String;)Ljava/lang/String;\" isStatic=\"false\" primary=\"true\">
<SourceLine classname=\"dev.x.Greeter\" start=\"7\" end=\"8\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\"/>
</Method>
<SourceLine classname=\"dev.x.Greeter\" primary=\"true\" start=\"8\" end=\"8\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\"/>
</BugInstance>
<BugInstance type=\"URF_UNREAD_FIELD\" priority=\"2\" rank=\"18\" abbrev=\"UrF\" category=\"PERFORMANCE\">
<ShortMessage>Unread field</ShortMessage>
<LongMessage>Unread field: dev.x.Greeter.unused</LongMessage>
<Class classname=\"dev.x.Greeter\" primary=\"true\">
<SourceLine classname=\"dev.x.Greeter\" start=\"3\" end=\"10\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\"/>
</Class>
<Field classname=\"dev.x.Greeter\" name=\"unused\" signature=\"I\" isStatic=\"false\" primary=\"true\">
<SourceLine classname=\"dev.x.Greeter\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\"/>
</Field>
<SourceLine classname=\"dev.x.Greeter\" sourcefile=\"Greeter.java\" sourcepath=\"dev/x/Greeter.java\" synthetic=\"true\"/>
</BugInstance>
<BugInstance type=\"SE_BAD_FIELD\" priority=\"3\" category=\"BAD_PRACTICE\">
<Class classname=\"dev.x.Gone\" primary=\"true\">
<SourceLine classname=\"dev.x.Gone\" start=\"1\" end=\"2\" sourcefile=\"Gone.java\" sourcepath=\"dev/x/Gone.java\"/>
</Class>
</BugInstance>
</BugCollection>")

(defun test-static--summary (findings)
  "FINDINGS as (FILE-BASE LINE COLUMN SEVERITY TOOL RULE), in order."
  (mapcar (lambda (f) (list (file-name-nondirectory (plist-get f :file)) (plist-get f :line)
                            (plist-get f :column) (plist-get f :severity)
                            (plist-get f :tool) (plist-get f :rule)))
          findings))

;;; Reading reports ------------------------------------------------------------------

(ert-deftest test-static/checkstyle-report ()
  "Checkstyle's own severities; `ignore' is left out; the rule is the check's name."
  (test-static--with-tree `(("target/checkstyle-result.xml" . ,test-static--checkstyle))
    (test-static--both-readers
     (let ((findings (hellmacs-static-parse-report (expand-file-name "target/checkstyle-result.xml" root))))
       (should (equal (test-static--summary findings)
                      '(("Greeter.java" 3 1 :warning "Checkstyle" "MissingJavadocType")
                        ("Greeter.java" 6 nil :error "Checkstyle" "DesignForExtension"))))
       (should (equal (plist-get (nth 1 findings) :message) "Method 'greet' should be final."))
       (should (equal (plist-get (car findings) :file)
                      (expand-file-name "src/main/java/dev/x/Greeter.java" root)))))))

(ert-deftest test-static/pmd-report ()
  "PMD's priorities: 1-2 errors, 3-4 warnings, 5 notes; the message is trimmed."
  (test-static--with-tree `(("target/pmd.xml" . ,test-static--pmd))
    (test-static--both-readers
     (let ((findings (hellmacs-static-parse-report (expand-file-name "target/pmd.xml" root))))
       (should (equal (test-static--summary findings)
                      '(("Greeter.java" 4 17 :warning "PMD" "UnusedPrivateField")
                        ("Greeter.java" 8 16 :error "PMD" "NullAssignment"))))
       (should (equal (plist-get (car findings) :message) "Avoid unused private fields such as 'unused'."))
       (should (equal (plist-get (car findings) :end-column) 23))))))

(ert-deftest test-static/spotbugs-report ()
  "SpotBugs: the bug's own line, its file under the project's source dirs, its
message when the report has messages, else its type and category. A field
has no line in class files (nor the report): its declaration is looked up."
  (test-static--with-tree `(("src/main/java/dev/x/Greeter.java" . ,test-static--greeter)
                            ("target/spotbugsXml.xml" . ,test-static--spotbugs))
    (test-static--both-readers
     (let ((findings (hellmacs-static-parse-report (expand-file-name "target/spotbugsXml.xml" root))))
       ;; A class whose source isn't there (generated, or gone) is left out.
       (should (equal (test-static--summary findings)
                      '(("Greeter.java" 8 nil :error "SpotBugs" "NP_LOAD_OF_KNOWN_NULL_VALUE")
                        ("Greeter.java" 4 nil :warning "SpotBugs" "URF_UNREAD_FIELD"))))
       (should (equal (plist-get (car findings) :message) "NP_LOAD_OF_KNOWN_NULL_VALUE (CORRECTNESS)"))
       (should (equal (plist-get (nth 1 findings) :message) "Unread field: dev.x.Greeter.unused"))
       (should (equal (plist-get (car findings) :file)
                      (expand-file-name "src/main/java/dev/x/Greeter.java" root)))))))

(ert-deftest test-static/unreadable-reports ()
  "A broken or unknown XML file gives no findings, and no error."
  (test-static--with-tree '(("target/pmd.xml" . "<pmd><file name=")
                            ("target/checkstyle-result.xml" . "<project/>"))
    (should-not (hellmacs-static-parse-report (expand-file-name "target/pmd.xml" root)))
    (should-not (hellmacs-static-parse-report (expand-file-name "target/checkstyle-result.xml" root)))))

(ert-deftest test-static/report-files ()
  "Maven's and Gradle's report locations, in every module; nothing else."
  (test-static--with-tree '(("pom.xml" . "<project/>")
                            ("target/checkstyle-result.xml" . "<checkstyle/>")
                            ("core/target/pmd.xml" . "<pmd/>")
                            ("core/target/spotbugsXml.xml" . "<BugCollection/>")
                            ("app/build/reports/checkstyle/main.xml" . "<checkstyle/>")
                            ("app/build/reports/pmd/test.xml" . "<pmd/>")
                            ("app/build/reports/spotbugs/main.xml" . "<BugCollection/>")
                            ("app/build/reports/spotbugs/main.html" . "<html/>")
                            ("app/build/test-results/test/TEST-x.xml" . "<testsuite/>")
                            ("target/surefire-reports/TEST-y.xml" . "<testsuite/>")
                            ("src/main/resources/pmd.xml" . "<ruleset/>"))
    (should (equal (sort (mapcar (lambda (f) (file-relative-name f root))
                                 (hellmacs-static-report-files root))
                         #'string<)
                   '("app/build/reports/checkstyle/main.xml" "app/build/reports/pmd/test.xml"
                     "app/build/reports/spotbugs/main.xml" "core/target/pmd.xml"
                     "core/target/spotbugsXml.xml" "target/checkstyle-result.xml")))))

;;; Showing them -----------------------------------------------------------------------

(defun test-static--diagnostics (file)
  "Run the flymake backend in FILE's buffer; return (LINE TYPE TEXT) per diagnostic."
  (with-current-buffer (find-file-noselect file)
    (let (reported)
      (hellmacs-static-flymake (lambda (diags &rest _) (setq reported diags)))
      (mapcar (lambda (d) (list (line-number-at-pos (flymake-diagnostic-beg d))
                                (flymake-diagnostic-type d)
                                (flymake-diagnostic-text d)))
              reported))))

(ert-deftest test-static/flymake-diagnostics ()
  "The buffer's findings, from every tool, as flymake diagnostics."
  (test-static--with-tree `(("pom.xml" . "<project/>")
                            ("src/main/java/dev/x/Greeter.java" . ,test-static--greeter)
                            ("src/main/java/dev/x/Other.java" . "package dev.x;\nclass Other {}\n"))
    ;; Reports written after the sources, as a build does.
    (sleep-for 0.01)
    (dolist (report `(("target/checkstyle-result.xml" . ,test-static--checkstyle)
                      ("target/pmd.xml" . ,test-static--pmd)))
      (let ((path (expand-file-name (car report) root)))
        (make-directory (file-name-directory path) t)
        (with-temp-file path (insert (string-replace "@ROOT@" root (cdr report))))))
    (let ((hellmacs-static--cache (make-hash-table :test #'equal)))
      (should (equal (test-static--diagnostics (expand-file-name "src/main/java/dev/x/Greeter.java" root))
                     '((3 :warning "Checkstyle: Missing a Javadoc comment. [MissingJavadocType]")
                       (4 :warning "PMD: Avoid unused private fields such as 'unused'. [UnusedPrivateField]")
                       (6 :error "Checkstyle: Method 'greet' should be final. [DesignForExtension]")
                       (8 :error "PMD: Assigning an Object to null is a code smell. [NullAssignment]"))))
      (should-not (test-static--diagnostics (expand-file-name "src/main/java/dev/x/Other.java" root))))))

(ert-deftest test-static/stale-findings-are-dropped ()
  "A file saved since its report was written has moved on: its findings aren't shown."
  (test-static--with-tree `(("pom.xml" . "<project/>")
                            ("target/pmd.xml" . ,test-static--pmd))
    (sleep-for 0.01)
    (let ((file (expand-file-name "src/main/java/dev/x/Greeter.java" root))
          (hellmacs-static--cache (make-hash-table :test #'equal)))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert test-static--greeter)) ; saved after the build
      (should-not (test-static--diagnostics file)))))

(ert-deftest test-static/findings-list ()
  "The project's findings in a compilation buffer: `M-g n' visits each one."
  (test-static--with-tree `(("pom.xml" . "<project/>")
                            ("src/main/java/dev/x/Greeter.java" . ,test-static--greeter))
    (sleep-for 0.01)
    (let ((path (expand-file-name "target/pmd.xml" root)))
      (make-directory (file-name-directory path) t)
      (with-temp-file path (insert (string-replace "@ROOT@" root test-static--pmd))))
    (let ((hellmacs-static--cache (make-hash-table :test #'equal)))
      (save-window-excursion
        (let ((buffer (hellmacs-static-findings root)))
          (with-current-buffer buffer
            (should (derived-mode-p 'compilation-mode))
            (should (string-match-p "src/main/java/dev/x/Greeter\\.java:4:17: warning: PMD: Avoid unused"
                                    (buffer-string)))
            (should (string-match-p "2 findings" (buffer-string))))
          (let ((next-error-last-buffer buffer))
            (next-error 1)
            ;; In batch the file's buffer isn't selected; its point moved.
            (let ((visited (get-file-buffer (expand-file-name "src/main/java/dev/x/Greeter.java" root))))
              (should visited)
              (should (= (with-current-buffer visited (line-number-at-pos)) 4))))
          (kill-buffer buffer))))))

(ert-deftest test-static/build-reads-reports-again ()
  "A finished build reads the reports again, and checks the project's buffers anew."
  (test-static--with-tree `(("pom.xml" . "<project/>")
                            ("target/pmd.xml" . ,test-static--pmd))
    (let ((hellmacs-static--cache (make-hash-table :test #'equal))
          (reads 0))
      (cl-letf* ((read (symbol-function 'hellmacs-static-parse-report))
                 ((symbol-function 'hellmacs-static-parse-report)
                  (lambda (file) (cl-incf reads) (funcall read file))))
        (hellmacs-static-project-findings root)
        (hellmacs-static-project-findings root)
        (should (= reads 1))
        (with-temp-buffer
          (setq default-directory root)
          (hellmacs-static--after-build-h (current-buffer) "finished\n"))
        (hellmacs-static-project-findings root)
        (should (= reads 2))))))

(ert-deftest test-static/backend-in-jvm-buffers ()
  "The backend joins the buffer's own (lsp-mode's), rather than replacing it."
  (with-temp-buffer
    (setq-local flymake-diagnostic-functions (list #'ignore))
    (hellmacs-static-setup-h)
    (should (memq #'hellmacs-static-flymake flymake-diagnostic-functions))
    (should (memq #'ignore flymake-diagnostic-functions))))

(ert-deftest test-static/wired-into-jvm-buffers-and-builds ()
  "Java and Kotlin buffers get the backend; a finished build refreshes it. No keys."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (java-mode-hook nil) (java-ts-mode-hook nil) (kotlin-mode-hook nil) (kotlin-ts-mode-hook nil)
        (compilation-finish-functions nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:checkers static))
    (hellmacs-module--load '(:checkers . static) "config.el")
    (dolist (hook '(java-mode-hook java-ts-mode-hook kotlin-mode-hook kotlin-ts-mode-hook))
      (should (memq #'hellmacs-static-setup-h (symbol-value hook))))
    (should (memq #'hellmacs-static--after-build-h compilation-finish-functions))
    (should (equal mode-specific-map (make-sparse-keymap)))))

;;; +sonarlint -------------------------------------------------------------------------

(defvar lsp-sonarlint-download-dir)
(defvar lsp-sonarlint-modes-enabled)
(defvar lsp-sonarlint-use-system-jre)
(defvar lsp-sonarlint-enabled-analyzers)
(defvar lsp-sonarlint-disable-telemetry)
(defvar lsp-sonarlint-auto-download)
(defvar hellmacs-static-sonarlint-dir)
(defvar hellmacs-static-sonarlint-marker)
(defvar hellmacs-lsp-status-ready-functions)

(defun test-static--load-sonarlint (&optional file)
  "Load FILE (default config.el) of :checkers (static +sonarlint)."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :checkers (static +sonarlint)))
    (hellmacs-module--load '(:checkers . static) (or file "config.el"))))

(ert-deftest test-static/sonarlint-packages ()
  "lsp-sonarlint only with +sonarlint, which needs :tools lsp."
  (dolist (flags '(nil (+sonarlint)))
    (let ((hellmacs-packages nil)
          (hellmacs-module-dependencies nil)
          (hellmacs-modules (make-hash-table :test #'equal)))
      (hellmacs--enable-modules `(:tools lsp :checkers (static ,@flags)))
      (hellmacs-module--load '(:checkers . static) "packages.el")
      (should (eq (and (assq 'lsp-sonarlint hellmacs-packages) t) (and flags t)))
      (should (eq (and (alist-get '(:checkers . static) hellmacs-module-dependencies nil nil #'equal) t)
                  (and flags t))))))

(ert-deftest test-static/sonarlint-pin ()
  "SonarLint for VS Code 4.6.0 (lsp-sonarlint's), pinned, installed in the data dir."
  (test-static--load-sonarlint "+paths.el")
  (should (equal hellmacs-static-sonarlint-version "4.6.0"))
  (should (string-match-p "\\`https://github\\.com/SonarSource/sonarlint-vscode/releases/download/4\\.6\\.0%2B76435/sonarlint-vscode-4\\.6\\.0\\.vsix\\'"
                          hellmacs-static-sonarlint-url))
  (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" hellmacs-static-sonarlint-sha256))
  (should (file-in-directory-p hellmacs-static-sonarlint-dir hellmacs-data-dir)))

(ert-deftest test-static/sonarlint-sync-installs-it ()
  "Sync unpacks the pinned VSIX's server and analyzers; once installed, never again."
  (let* ((work (make-temp-file "hellmacs-test-sonar" t))
         (vsix (expand-file-name "sonarlint.vsix" work))
         (downloads 0))
    (unwind-protect
        (progn
          (let ((default-directory (file-name-as-directory work)))
            (dolist (f '("extension/server/sonarlint-ls.jar" "extension/analyzers/sonarjava.jar"
                         "extension/node_modules/big.js" "extension.vsixmanifest"))
              (make-directory (file-name-directory (expand-file-name f)) t)
              (with-temp-file f (insert "x")))
            (should (zerop (call-process "zip" nil nil nil "-qr" vsix "extension" "extension.vsixmanifest"))))
          (test-static--load-sonarlint "cli.el")
          (let ((hellmacs-static-sonarlint-dir (expand-file-name "installed/" work))
                (hellmacs-static-sonarlint-marker (expand-file-name "installed/.hellmacs-pin" work)))
            (cl-letf (((symbol-function 'hellmacs-sync-download-verified)
                       (lambda (url dest sha256 _label)
                         (should (equal url hellmacs-static-sonarlint-url))
                         (should (equal sha256 hellmacs-static-sonarlint-sha256))
                         (cl-incf downloads)
                         (make-directory (file-name-directory dest) t)
                         (copy-file vsix dest t)))
                      ((symbol-function 'hellmacs-sync--log) #'ignore))
              (hellmacs-static-sync-install-sonarlint)
              (should (hellmacs-static-sonarlint-installed-p))
              (should (file-exists-p (expand-file-name "extension/server/sonarlint-ls.jar" hellmacs-static-sonarlint-dir)))
              (should (file-exists-p (expand-file-name "extension/analyzers/sonarjava.jar" hellmacs-static-sonarlint-dir)))
              ;; Only what lsp-sonarlint runs.
              (should-not (file-exists-p (expand-file-name "extension/node_modules" hellmacs-static-sonarlint-dir)))
              (hellmacs-static-sync-install-sonarlint)
              (should (= downloads 1)))))
      (delete-directory work t))))

(ert-deftest test-static/sonarlint-settings ()
  "Set before lsp-sonarlint loads: the pinned install, Java's modes (tree-sitter's
too), a JDK Hellmacs picks, the JVM analyzers, no telemetry, no download of its own."
  (test-static--load-sonarlint "+paths.el")
  (let ((dir (make-temp-file "hellmacs-test-sonar" t)))
    (unwind-protect
        ;; Installed, as sync leaves it.
        (let ((hellmacs-static-sonarlint-dir (file-name-as-directory dir))
              (hellmacs-static-sonarlint-marker (expand-file-name ".hellmacs-pin" dir)))
          (make-directory (expand-file-name "extension/server/" dir) t)
          (with-temp-file (expand-file-name "extension/server/sonarlint-ls.jar" dir) (insert "x"))
          (hellmacs-marker-write hellmacs-static-sonarlint-marker hellmacs-static-sonarlint-sha256)
          (progn
            (test-static--load-sonarlint)
            (should (equal (file-name-as-directory lsp-sonarlint-download-dir) (file-name-as-directory dir)))
            (should (memq 'java-mode lsp-sonarlint-modes-enabled))
            (should (memq 'java-ts-mode lsp-sonarlint-modes-enabled))
            (should (memq 'nxml-mode lsp-sonarlint-modes-enabled))
            (should lsp-sonarlint-use-system-jre)
            (should (member "java" lsp-sonarlint-enabled-analyzers))
            (should (member "text" lsp-sonarlint-enabled-analyzers))
            (should lsp-sonarlint-disable-telemetry)
            (should-not lsp-sonarlint-auto-download)))
      (delete-directory dir t))))

(ert-deftest test-static/sonarlint-not-installed ()
  "Not installed: SonarLint doesn't start (no 227 MB download on opening a file),
and a warning says `bin/hellmacs sync' installs it."
  (test-static--load-sonarlint "+paths.el")
  (let (warnings)
    (cl-letf (((symbol-function 'display-warning) (lambda (_ msg &rest _) (push msg warnings))))
      (let ((lsp-sonarlint-modes-enabled '(java-mode))
            (hellmacs-static-sonarlint-dir (make-temp-file "hellmacs-test-sonar-none" t)))
        (test-static--load-sonarlint)
        (should-not lsp-sonarlint-modes-enabled)
        (should (= (length warnings) 1))
        (should (string-match-p "bin/hellmacs sync" (car warnings)))))))

(ert-deftest test-static/sonarlint-runs-on-a-jdk-17 ()
  "SonarLint's server runs on a java of release 17 or later that Hellmacs picks."
  (test-static--load-sonarlint)
  (cl-letf (((symbol-function 'hellmacs-jdk-java-executable)
             (lambda (min) (should (= min 17)) "/jdks/21/bin/java")))
    (should (equal (hellmacs-static--sonarlint-command-a '("java" "-jar" "/s/sonarlint-ls.jar" "-stdio"))
                   '("/jdks/21/bin/java" "-jar" "/s/sonarlint-ls.jar" "-stdio")))))

(ert-deftest test-static/sonarlint-java-config-from-jdtls ()
  "The Java analyzer gets the project's classpath, source level and JDK from JDTLS,
as VS Code gives it from its Java extension; nil when JDTLS can't say."
  (test-static--load-sonarlint)
  (let (asked answer)
    (cl-letf (((symbol-function 'hellmacs-static--jdtls-execute)
               (lambda (uri command arguments callback)
                 (push command asked)
                 (should (equal uri "file:///p/src/test/java/dev/x/GreeterTest.java"))
                 (funcall callback
                          (pcase command
                            ("java.project.isTestFile" t)
                            ("java.project.getSettings"
                             (should (equal (aref arguments 1)
                                            ["org.eclipse.jdt.core.compiler.compliance"
                                             "org.eclipse.jdt.ls.core.vm.location"]))
                             '(:org.eclipse.jdt.core.compiler.compliance "21"
                               :org.eclipse.jdt.ls.core.vm.location "/jdks/21"))
                            ("java.project.getClasspaths"
                             (should (equal (aref arguments 1) "{\"scope\":\"test\"}"))
                             '(:projectRoot "/p" :classpaths ["/p/target/classes" "/m2/junit.jar"])))))))
      ;; SonarLint sends the URI in an array, as a live run showed.
      (hellmacs-static-sonarlint-java-config nil ["file:///p/src/test/java/dev/x/GreeterTest.java"]
                                             (lambda (result) (setq answer result)))
      (should (equal (plist-get answer :projectRoot) "/p"))
      (should (equal (plist-get answer :sourceLevel) "21"))
      (should (equal (plist-get answer :classpath) ["/p/target/classes" "/m2/junit.jar"]))
      (should (eq (plist-get answer :isTest) t))
      (should (equal (plist-get answer :vmLocation) "/jdks/21"))
      (should (= (length asked) 3)))
    ;; No JDTLS for the file: SonarLint analyzes without it.
    (cl-letf (((symbol-function 'hellmacs-static--jdtls-execute)
               (lambda (_uri _command _arguments callback) (funcall callback nil))))
      (setq answer 'unset)
      (hellmacs-static-sonarlint-java-config nil "file:///elsewhere/A.java" (lambda (result) (setq answer result)))
      (should-not answer))))

(defvar lsp--cur-workspace)

(ert-deftest test-static/sonarlint-java-config-while-jdtls-starts ()
  "SonarLint always gets an answer: nil while JDTLS can't run commands yet
(still starting, it signals rather than calling back), in JDTLS's workspace."
  (test-static--load-sonarlint)
  (let (answers bound)
    (cl-letf (((symbol-function 'lsp--uri-to-path) (lambda (uri) (string-remove-prefix "file://" uri)))
              ((symbol-function 'lsp-find-workspace) (lambda (server _path) (and (eq server 'jdtls) 'jdtls-ws)))
              ((symbol-function 'lsp-request-async)
               (lambda (&rest _)
                 (setq bound lsp--cur-workspace)
                 (error "The connected server(s) does not support method workspace/executeCommand"))))
      (hellmacs-static-sonarlint-java-config nil ["file:///p/src/main/java/A.java"]
                                             (lambda (result) (push result answers)))
      (should (equal answers '(nil)))
      (should (eq bound 'jdtls-ws)))))

(ert-deftest test-static/sonarlint-told-when-the-classpath-is-known ()
  "When JDTLS has imported a project, SonarLint is told its classpath changed."
  (test-static--load-sonarlint)
  (should (memq #'hellmacs-static--sonarlint-classpath-h hellmacs-lsp-status-ready-functions))
  (let (sent)
    (cl-letf (((symbol-function 'hellmacs-static--sonarlint-notify)
               (lambda (method params) (push (cons method params) sent))))
      (hellmacs-static--sonarlint-classpath-h 'jdtls "/p/")
      (hellmacs-static--sonarlint-classpath-h 'kotlin-ls "/p/") ; not a Java classpath
      (should (equal sent '(("sonarlint/didClasspathUpdate" :projectUri "file:///p")))))))

(provide 'test-static)
;;; test-static.el ends here
