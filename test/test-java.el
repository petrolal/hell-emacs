;;; test-java.el --- Tests for the :lang java module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. These cover the module's own logic; its
;; behavior against a real JDTLS is checked by the Phase 6.2 probes (see
;; docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'hellmacs-modules)
(require 'hellmacs-ux (expand-file-name "hellmacs/+ux" hellmacs-modules-dir))                  ; `hellmacs-ux-enable', bound below

(defvar hellmacs-lsp-status--sessions)  ; defined by core; bound below
(defvar hellmacs-lsp-status--servers)
(defvar hellmacs-jvm-lombok-jar)
(defvar hellmacs-jvm--default-lombok-jar)
(defvar hellmacs-jvm-lombok-sha256)

(defvar test-java--loaded nil)

(defun test-java--load ()
  "Load :lang java's config.el and autoload.el, once."
  (unless test-java--loaded
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:tools lsp build :lang java))
      (hellmacs-module--load '(:tools . lsp) "autoload.el") ; `hellmacs-lsp-install-pinned'
      (hellmacs-module--load '(:tools . build) "autoload.el") ; finding the test at point
      (hellmacs-module--load '(:lang . java) "autoload.el")
      (hellmacs-module--load '(:lang . java) "config.el"))
    (setq test-java--loaded t)))

(ert-deftest test-java/registered-with-its-wording ()
  (test-java--load)
  (should (plist-get (alist-get 'jdtls hellmacs-lsp-status--servers) :on-log))
  (let ((hellmacs-ux-enable t))
    (should (equal (hellmacs-lsp-status-announce 'ignited "JDTLS" "~/proj")
                   "[FORGE IGNITED] JDTLS bound to ~/proj")))
  (let ((hellmacs-ux-enable nil))
    (should (equal (hellmacs-lsp-status-announce 'ready "~/proj" 3.04)
                   "~/proj indexed in 3.0s"))))

(ert-deftest test-java/failed-import-is-not-ready ()
  "A failed import says so, and JDTLS's ServiceReady doesn't hide it."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-ux-enable t)
         (shown nil)
         (toolchain "Sep 23 Synchronize project demo failed due to an error connecting to the Gradle build.
org.gradle...
Caused by: ToolchainProvisioningException: Cannot find a Java installation on your machine (Linux) matching: {languageVersion=17, vendor=any vendor}"))
    (unwind-protect
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) shown))))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (setq shown nil)
          (hellmacs-jvm--note-log root "Some unrelated log line")
          (should (eq (hellmacs-jvm-state root) 'igniting))
          ;; Not ready while importing, whatever the project status says.
          (hellmacs-jvm--note-notification root "language/status" '(:type "ProjectStatus" :message "OK"))
          (should (eq (hellmacs-jvm-state root) 'igniting))
          (hellmacs-jvm--note-log root toolchain)
          (should (eq (hellmacs-jvm-state root) 'failed))
          (should (string-match-p "BYTECODE PURGATORY.*needs a JDK 17" (car shown)))
          ;; Announced once, even if JDTLS repeats itself.
          (hellmacs-jvm--note-log root toolchain)
          (should (= (length shown) 1))
          ;; ServiceReady arrives anyway: still failed, no [DAEMON READY].
          (hellmacs-jvm--note-notification root "language/status" '(:type "ServiceReady" :message "ServiceReady"))
          (should (eq (hellmacs-jvm-state root) 'failed))
          (should (= (length shown) 1))
          ;; After the cause is fixed, an OK project status recovers.
          (hellmacs-jvm--note-notification root "language/status" '(:type "ProjectStatus" :message "OK"))
          (should (eq (hellmacs-jvm-state root) 'ready))
          (should (string-match-p "DAEMON READY" (car shown))))
      (delete-directory root t))))

;; What JDTLS logs when a Gradle 9 multi-project build rejects its
;; annotation-processing init script (Spring Framework 7.0.9, Gradle 9.7).
(defconst test-java--gradle9-apt-log
  "Sep 29, 2026, 4:38:33 PM Could not fetch model of type 'Map' using connection to Gradle distribution 'https://services.gradle.org/distributions/gradle-9.7.0-bin.zip'.
org.gradle.tooling.BuildException: Could not fetch model of type 'Map' using connection to Gradle distribution 'https://services.gradle.org/distributions/gradle-9.7.0-bin.zip'.
	at org.eclipse.jdt.ls.core.internal.managers.GradleBuildSupport.syncAnnotationProcessingConfiguration(GradleBuildSupport.java:197)
Caused by: org.gradle.internal.exceptions.LocationAwareException: Initialization script '/x/init.gradle' line: 12
Resolution of the configuration ':framework-docs:annotationProcessor' was attempted without an exclusive lock. This is unsafe and not allowed.")

(defvar lsp-java-import-gradle-annotation-processing-enabled)
(defvar lsp--cur-workspace)

(ert-deftest test-java/gradle-model-failure-is-a-failed-import ()
  "A Gradle model JDTLS couldn't fetch while importing is a failed import,
announced at once (not after waiting for a ServiceReady that doesn't help)."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-jvm--reimported nil)
         (shown nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) shown))))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-jvm--note-log root "Sep 29, 2026 Could not fetch model of type 'GradleBuild' using connection to Gradle distribution 'x'.
Caused by: Could not resolve all dependencies for configuration ':compileClasspath'.")
          (should (eq (hellmacs-jvm-state root) 'failed))
          (should (string-match-p "Gradle sync failed" (car shown)))
          (should (hellmacs-jvm-import-settled-p root)))
      (delete-directory root t))))

(ert-deftest test-java/gradle9-annotation-processing-reimports-without-it ()
  "Gradle 9 refusing JDTLS's annotation-processing script: annotation processing
is turned off, JDTLS is told, and the workspace imported again in place, once.
The import isn't settled until that second import reports."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-jvm--reimported nil)
         (lsp-java-import-gradle-annotation-processing-enabled t)
         (sent nil)
         (shown nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) shown)))
                  ((symbol-function 'run-at-time)
                   (lambda (_time _repeat fn &rest args) (apply fn args)))
                  ((symbol-function 'lsp-find-workspace)
                   (lambda (server dir) (and (eq server 'jdtls) (list 'workspace dir))))
                  ((symbol-function 'lsp-configuration-section)
                   (lambda (section)
                     (list section lsp-java-import-gradle-annotation-processing-enabled)))
                  ((symbol-function 'lsp--set-configuration)
                   (lambda (settings) (push (list 'configuration settings lsp--cur-workspace) sent)))
                  ((symbol-function 'lsp-request-async)
                   (lambda (method params _callback &rest _)
                     (push (list method params lsp--cur-workspace) sent))))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-jvm--note-log root test-java--gradle9-apt-log)
          (should-not lsp-java-import-gradle-annotation-processing-enabled)
          (should (string-match-p "annotation processing" (car shown)))
          ;; The new setting first, then the import, both to JDTLS for ROOT.
          (should (equal (reverse sent)
                         `((configuration ("java" nil) (workspace ,root))
                           ("workspace/executeCommand" (:command "java.project.import") (workspace ,root)))))
          (should (eq (hellmacs-jvm-state root) 'failed))
          (should-not (hellmacs-jvm-import-settled-p root))
          ;; JDTLS repeating itself doesn't import again.
          (hellmacs-jvm--note-log root test-java--gradle9-apt-log)
          (should (= (length sent) 2))
          ;; The second import succeeds: JDTLS's project status says OK.
          (hellmacs-jvm--note-notification root "language/status" '(:type "ProjectStatus" :message "OK"))
          (should (eq (hellmacs-jvm-state root) 'ready))
          (should (hellmacs-jvm-import-settled-p root)))
      (delete-directory root t))))

(ert-deftest test-java/recovered-reimport-is-forgotten ()
  "Once the import without annotation processing succeeds, the project is no
longer being imported again: a later failure (a new session, the same
Gradle 9 refusal) is announced and settles, instead of being taken for
the retry's repeat forever."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-jvm--reimported (list root))
         (lsp-java-import-gradle-annotation-processing-enabled nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message) #'ignore))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-lsp-status-fail 'jdtls root "first attempt")
          (hellmacs-jvm--note-notification root "language/status" '(:type "ProjectStatus" :message "OK"))
          (should (eq (hellmacs-jvm-state root) 'ready))
          (should-not (member root hellmacs-jvm--reimported))
          ;; The server restarts, and the same refusal comes back.
          (hellmacs-lsp-status-banish 'jdtls root)
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-jvm--note-log root test-java--gradle9-apt-log)
          (should (eq (hellmacs-jvm-state root) 'failed))
          (should (hellmacs-jvm-import-settled-p root)))
      (delete-directory root t))))

(ert-deftest test-java/reimport-that-fails-again-is-settled ()
  "If the import without annotation processing fails too, that's the verdict."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-jvm--reimported (list root))
         (lsp-java-import-gradle-annotation-processing-enabled nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message) #'ignore))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-lsp-status-fail 'jdtls root "first attempt")
          (should-not (hellmacs-jvm-import-settled-p root))
          (hellmacs-jvm--note-log root "Sep 29 Synchronize project demo failed due to an error.
Caused by: Could not resolve org.acme:missing:1.0")
          (should (hellmacs-jvm-import-settled-p root)))
      (delete-directory root t))))

(ert-deftest test-java/spring-client-commands-always-answered ()
  "JDTLS's Spring extension asks the client to start or stop the Spring server
(`vscode-spring-boot.ls.start', no arguments) and waits for the answer: its
import can't finish until then. Hellmacs runs that server itself, so these
are answered at once; anything else is lsp-java's to forward, and if that
fails JDTLS still gets an answer."
  (test-java--load)
  (let ((forwarded nil))
    (cl-flet ((orig (workspace params) (push (list workspace params) forwarded) 'forwarded)
              (broken (_workspace _params) (signal 'args-out-of-range '([] 2))))
      (dolist (command '("vscode-spring-boot.ls.start" "vscode-spring-boot.ls.stop"))
        (should-not (hellmacs-jvm--spring-client-command-a
                     #'orig 'jdtls (list :command command :arguments []))))
      (should-not forwarded)
      (should (eq (hellmacs-jvm--spring-client-command-a
                   #'orig 'jdtls '(:command "sts.java.addClasspathListener" :arguments ["a" "b" t]))
                  'forwarded))
      (should (= (length forwarded) 1))
      (cl-letf (((symbol-function 'message) #'ignore))
        (should-not (hellmacs-jvm--spring-client-command-a
                     #'broken 'jdtls '(:command "sts.java.addClasspathListener" :arguments [])))))))

(ert-deftest test-java/service-ready-means-ready ()
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal)))
    (unwind-protect
        (cl-letf (((symbol-function 'message) #'ignore))
          (hellmacs-lsp-status-ignite 'jdtls root)
          (hellmacs-jvm--note-notification root "language/progressReport" '(:status "Importing"))
          (should (eq (hellmacs-jvm-state root) 'igniting))
          (hellmacs-jvm--note-notification root "language/status" '(:type "ServiceReady" :message "ServiceReady"))
          (should (eq (hellmacs-jvm-state root) 'ready)))
      (delete-directory root t))))

(ert-deftest test-java/keys-in-hellmacs-own-mode ()
  "C-c l j is in a Hellmacs minor mode Java buffers turn on, not in
cc-mode's or java-ts-mode's map: `C-c letter' is the user's, not a package's."
  (test-java--load)
  (require 'cc-mode)
  (should (memq #'hellmacs-jvm-keys-mode java-mode-hook))
  (should (memq #'hellmacs-jvm-keys-mode java-ts-mode-hook))
  ;; Unbound there: nil, or the length of the prefix that is bound.
  (should (natnump (or (keymap-lookup java-mode-map "C-c l j") 0)))
  (with-temp-buffer
    (hellmacs-jvm-keys-mode 1)
    (should (eq (key-binding (kbd "C-c l j o")) #'lsp-java-organize-imports))
    (should (eq (key-binding (kbd "C-c l j t")) #'hellmacs-jvm-test-at-point))))

(ert-deftest test-java/test-method ()
  "The test at point is the test method (JUnit 4 or 5) point is in, or nil:
not a helper, a setup method, or the test above either."
  (test-java--load)
  (with-temp-buffer
    (insert "package dev.x;

class GreeterTest {
    @BeforeEach
    void setUp() {
        greeter = new Greeter(); // SETUP
    }

    @Test
    void greets() {
        assertTrue(true); // GREETS
    }

    private void helper(String s) {
        check(s); // HELPER
    }

    @Test(expected = IllegalStateException.class)
    public void junit4Style() throws Exception {
        fail(); // JUNIT4
    }

    @ParameterizedTest
    @DisplayName(\"with {braces} and (parens)\")
    @ValueSource(ints = {1, 2})
    void manyInputs(int n) {
        if (n > 0) { run(n); } // MANY
    }

    @Test void oneLiner() { run(); } // ONELINER
}
")
    (dolist (case '(("GREETS" . "greets") ("JUNIT4" . "junit4Style") ("MANY" . "manyInputs")
                    ("ONELINER" . "oneLiner") ("@ValueSource" . "manyInputs")
                    ("SETUP") ("HELPER") ("package")))
      (goto-char (point-min)) (search-forward (car case))
      (should (equal (cons (car case) (hellmacs-jvm-test-method)) case)))))

(ert-deftest test-java/imports-left-alone-on-save ()
  "Saving doesn't reorganize imports (lsp-java's default); `C-c l j o' does it.
The module's lsp-java settings are recorded, for when it loads, in the
`use-package' theme."
  (test-java--load)
  (should (assq 'use-package (get 'lsp-java-content-provider-preferred 'theme-value)))
  (should-not (assq 'use-package (get 'lsp-java-save-actions-organize-imports 'theme-value))))

(ert-deftest test-java/reference-code-lenses-off ()
  "References and implementations code lenses are off, as in VS Code.
On a big class they fill JDTLS's request threads with workspace searches:
on Spring Framework the import answered symbol search after 183s with
them, 63s without (docs/roadmap.md, 12.7 Tuning). Your config.el can
turn them back on."
  (test-java--load)
  (dolist (var '(lsp-java-references-code-lens-enabled
                 lsp-java-implementations-code-lens-enabled))
    (let ((setting (assq 'use-package (get var 'theme-value))))
      (should setting)
      (should-not (eval (cadr setting) t)))))

(defvar c-basic-offset)

(ert-deftest test-java/format-tab-size-from-any-buffer ()
  "JDTLS's tab size is a number whichever buffer is current when a server asks
for its settings. lsp-java's own reads `c-basic-offset' there: from a Kotlin
buffer that's cc-mode's `set-from-style', the reply fails to encode as JSON,
and it's never sent (found by telemetry-e2e, 12.9)."
  (test-java--load)
  (let ((setting (assq 'use-package (get 'lsp-java-format-tab-size 'theme-value))))
    (should setting)
    (should (eq (eval (cadr setting) t) #'hellmacs-jvm-format-tab-size)))
  (require 'cc-mode)
  (let ((java (generate-new-buffer "Tab.java")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (should (eq (default-value 'c-basic-offset) 'set-from-style))
            (should (integerp (hellmacs-jvm-format-tab-size))))
          (with-current-buffer java
            (delay-mode-hooks (java-mode)) ; not lsp-java's hooks
            (setq-local c-basic-offset 2)
            (should (= (hellmacs-jvm-format-tab-size) 2)))
          ;; From another buffer: the Java buffer's.
          (with-temp-buffer
            (should (= (hellmacs-jvm-format-tab-size) 2))))
      (kill-buffer java))))

(defvar lsp-clients)

(ert-deftest test-java/spring-client-setup-warns-instead-of-failing ()
  "+spring: if lsp-java-boot's client isn't there as expected, a warning says so,
rather than an error in the middle of loading lsp-java."
  (test-java--load)
  (let ((lsp-clients (make-hash-table)) warnings)
    (cl-letf (((symbol-function 'display-warning) (lambda (_ msg &rest _) (push msg warnings))))
      (should-not (hellmacs-jvm--spring-client-use-stdio)) ; no boot-ls client
      (puthash 'boot-ls (make-vector 3 nil) lsp-clients)
      (should-not (hellmacs-jvm--spring-client-use-stdio)) ; no such slots
      (should (= 2 (length warnings)))
      (should (string-match-p "+spring" (car warnings))))))

(ert-deftest test-java/reload-hot-swaps-debug-sessions ()
  "`C-c h r' in Java hot-swaps into a debug session, and only then."
  (test-java--load)
  (let (swapped)
    (cl-letf (((symbol-function 'hellmacs-debug-hot-swap) (lambda () (setq swapped t)))
              ((symbol-function 'dap--cur-session) #'ignore))
      (should-error (hellmacs-jvm-reload) :type 'user-error)
      (should-not swapped)
      (cl-letf (((symbol-function 'dap--cur-session) (lambda () 'session)))
        (hellmacs-jvm-reload))
      (should swapped))))

(defvar hellmacs-jvm-jdtls-url)
(defvar hellmacs-jvm-jdtls-sha256)
(defvar hellmacs-jvm-jdtls-dir)

(ert-deftest test-java/jdtls-install-is-pinned ()
  "JDTLS is installed only from a download matching the pin, replacing the old one."
  (skip-unless (executable-find "tar"))
  (require 'hellmacs-sync)
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang java))
    (hellmacs-module--load '(:lang . java) "cli.el"))
  (let* ((root (make-temp-file "hellmacs-test-jdtls" t))
         (src (expand-file-name "src" root))
         (tarball (expand-file-name "jdtls.tar.gz" root))
         (hellmacs-jvm-jdtls-dir (expand-file-name "lsp/eclipse.jdt.ls/" root))
         (hellmacs-jvm-jdtls-url "https://example.invalid/jdtls.tar.gz"))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "plugins" src) t)
          (with-temp-file (expand-file-name "plugins/org.eclipse.equinox.launcher_1.0.jar" src) (insert "jar"))
          (should (zerop (call-process "tar" nil nil nil "-czf" tarball "-C" src ".")))
          ;; An older install, lsp-java's say, with a file of its own.
          (make-directory hellmacs-jvm-jdtls-dir t)
          (with-temp-file (expand-file-name "old.txt" hellmacs-jvm-jdtls-dir) (insert "old"))
          (cl-letf (((symbol-function 'hellmacs-net-download) (lambda (_url file &rest _) (copy-file tarball file t))))
            (let ((hellmacs-jvm-jdtls-sha256 (make-string 64 ?0)))
              (should-error (hellmacs-jvm--install-jdtls))
              ;; Refused: the old install is untouched.
              (should (file-exists-p (expand-file-name "old.txt" hellmacs-jvm-jdtls-dir)))
              (should-not (hellmacs-jvm-jdtls-installed-p)))
            (let ((hellmacs-jvm-jdtls-sha256 (hellmacs-file-sha256 tarball)))
              (hellmacs-jvm--install-jdtls)
              (should (hellmacs-jvm-jdtls-installed-p))
              (should-not (file-exists-p (expand-file-name "old.txt" hellmacs-jvm-jdtls-dir)))
              (should (file-directory-p (expand-file-name "bundles" hellmacs-jvm-jdtls-dir)))))
          ;; Nothing left in staging.
          (should (equal (directory-files (expand-file-name "lsp" root) nil "stage") nil)))
      (delete-directory root t))))

(ert-deftest test-java/jdtls-installs-at-once-dont-collide ()
  "Two installs at once (bin/hellmacs sync, and Emacs installing on first use):
the one that puts its copy in place second finds the pinned JDTLS there,
complete with its marker, and leaves it."
  (skip-unless (executable-find "tar"))
  (require 'hellmacs-sync)
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang java))
    (hellmacs-module--load '(:lang . java) "cli.el"))
  (let* ((root (make-temp-file "hellmacs-test-jdtls" t))
         (src (expand-file-name "src" root))
         (tarball (expand-file-name "jdtls.tar.gz" root))
         (hellmacs-jvm-jdtls-dir (expand-file-name "lsp/eclipse.jdt.ls/" root))
         (hellmacs-jvm-jdtls-url "https://example.invalid/jdtls.tar.gz")
         (real-rename (symbol-function 'rename-file)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "plugins" src) t)
          (with-temp-file (expand-file-name "plugins/org.eclipse.equinox.launcher_1.0.jar" src) (insert "jar"))
          (should (zerop (call-process "tar" nil nil nil "-czf" tarball "-C" src ".")))
          (let ((hellmacs-jvm-jdtls-sha256 (hellmacs-file-sha256 tarball)))
            (cl-letf (((symbol-function 'hellmacs-net-download) (lambda (_url file &rest _) (copy-file tarball file t)))
                      ;; The other install gets its copy in place first.
                      ((symbol-function 'rename-file)
                       (lambda (from to &rest args)
                         (when (equal (directory-file-name to) (directory-file-name hellmacs-jvm-jdtls-dir))
                           (copy-directory from to nil t t))
                         (apply real-rename from to args))))
              (hellmacs-jvm--install-jdtls))
            (should (hellmacs-jvm-jdtls-installed-p))
            (should (equal (directory-files (expand-file-name "lsp" root) nil "stage") nil))))
      (delete-directory root t))))

(ert-deftest test-java/update-project-configuration-finds-build-file ()
  "From a source file, the nearest pom.xml or build.gradle is re-imported."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-java" t))
         (src (expand-file-name "src/main/java/A.java" root))
         called-in)
    (unwind-protect
        (progn
          (make-directory (file-name-directory src) t)
          (with-temp-file src (insert "class A {}"))
          (with-temp-file (expand-file-name "build.gradle" root) (insert ""))
          (cl-letf (((symbol-function 'lsp-java-update-project-configuration)
                     (lambda () (setq called-in (buffer-file-name)))))
            (with-current-buffer (find-file-noselect src)
              (hellmacs-jvm-update-project-configuration)
              (kill-buffer)))
          (should (equal called-in (expand-file-name "build.gradle" root)))
          (when-let* ((b (get-file-buffer (expand-file-name "build.gradle" root)))) (kill-buffer b)))
      (delete-directory root t))))

(defmacro test-java--with-temp-lombok (&rest body)
  "Run BODY with the pinned Lombok jar path inside a temporary directory."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "hellmacs-test-lombok" t))
          (jar (expand-file-name "jvm/lombok-test.jar" dir))
          (hellmacs-jvm-lombok-jar jar)
          (hellmacs-jvm--default-lombok-jar jar))
     (unwind-protect (progn ,@body)
       (delete-directory dir t))))

(ert-deftest test-java/vmargs-lombok-agent ()
  "+lombok adds the jar as a javaagent, but only once it exists."
  (test-java--load)
  (test-java--with-temp-lombok
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:lang (java +lombok)))
      (hellmacs-module--load '(:lang . java) "config.el")
      (should-not (seq-some (lambda (a) (string-prefix-p "-javaagent:" a)) (hellmacs-jvm--vmargs)))
      (make-directory (file-name-directory jar) t)
      (with-temp-file jar (insert "jar"))
      (should (member (concat "-javaagent:" jar) (hellmacs-jvm--vmargs)))
      (should (member "-Xmx2G" (hellmacs-jvm--vmargs)))
      ;; Without the flag, never.
      (hellmacs--enable-modules '(:lang java))
      (hellmacs-module--load '(:lang . java) "config.el")
      (should-not (seq-some (lambda (a) (string-prefix-p "-javaagent:" a)) (hellmacs-jvm--vmargs))))))

(ert-deftest test-java/lombok-download-checksum ()
  "A download is installed only if its SHA-256 matches the pin."
  (require 'hellmacs-sync)
  (let ((hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:lang (java +lombok)))
    (hellmacs-module--load '(:lang . java) "cli.el"))
  (test-java--with-temp-lombok
    (cl-letf (((symbol-function 'hellmacs-net-download)
               (lambda (_url file &rest _) (with-temp-file file (insert "jar bytes"))))
              ((symbol-function 'hellmacs-sync--log) #'ignore))
      ;; A pin that doesn't match: nothing is installed, no leftovers.
      (let ((hellmacs-jvm-lombok-sha256 "0000"))
        (should-error (hellmacs-jvm-sync-install-lombok))
        (should-not (file-exists-p jar))
        (should-not (file-exists-p (concat jar ".part"))))
      ;; A pin that matches: installed, then left alone.
      (let ((hellmacs-jvm-lombok-sha256 (secure-hash 'sha256 "jar bytes")))
        (hellmacs-jvm-sync-install-lombok)
        (should (file-exists-p jar))
        (should (hellmacs-jvm-lombok-jar-valid-p))
        (cl-letf (((symbol-function 'hellmacs-net-download) (lambda (&rest _) (error "Shouldn't download"))))
          (hellmacs-jvm-sync-install-lombok))))))

(defvar lsp-java-configuration-runtimes)
(defvar hellmacs-jdks)
(defvar hellmacs-jdk-file)
(defvar hellmacs-sync-functions)
(defvar hellmacs-cli--problems)

(ert-deftest test-java/jdks-become-runtimes ()
  "The JDKs sync found become JDTLS's runtimes, JDTLS's own JDK the default;
yours (`hellmacs-jdks', or runtimes you set) win."
  (test-java--load)
  (let ((hellmacs-jdk-file (make-temp-file "hellmacs-test-jdks" nil ".eld"))
        (hellmacs-jvm-java-home "/j/21")
        (hellmacs-jdks nil)
        (lsp-java-configuration-runtimes []))
    (unwind-protect
        (progn
          (hellmacs-jdk-write '(("JavaSE-1.8" . "/j/8") ("JavaSE-21" . "/j/21") ("JavaSE-25" . "/j/25")))
          (hellmacs-jvm-apply-jdks)
          (should (equal (mapcar (lambda (r) (plist-get r :name)) lsp-java-configuration-runtimes)
                         '("JavaSE-1.8" "JavaSE-21" "JavaSE-25")))
          (should (eq (plist-get (aref lsp-java-configuration-runtimes 1) :default) t))
          ;; Yours: `hellmacs-jdks' instead of what sync found.
          (let ((hellmacs-jdks '(("JavaSE-11" . "/mine/11"))))
            (hellmacs-jvm-apply-jdks)
            (should (equal (plist-get (aref lsp-java-configuration-runtimes 0) :path) "/mine/11")))
          ;; Runtimes you set yourself are left alone.
          (let ((lsp-java-configuration-runtimes [(:name "JavaSE-17" :path "/x")]))
            (hellmacs-jvm-apply-jdks)
            (should (equal lsp-java-configuration-runtimes [(:name "JavaSE-17" :path "/x")]))))
      (delete-file hellmacs-jdk-file))))

(ert-deftest test-java/runtimes-only-releases-jdtls-knows ()
  "A JDK newer than JDTLS knows isn't offered as a runtime: JDTLS rejects it
(\"not compatible with the 'JavaSE-27' environment\")."
  (test-java--load)
  (let ((hellmacs-jdk-file (make-temp-file "hellmacs-test-jdks" nil ".eld"))
        (hellmacs-jvm-java-home "/j/21")
        (hellmacs-jvm-jdtls-java-max 25)
        (hellmacs-jdks nil)
        (lsp-java-configuration-runtimes []))
    (unwind-protect
        (progn
          (hellmacs-jdk-write '(("JavaSE-1.8" . "/j/8") ("JavaSE-21" . "/j/21")
                                ("JavaSE-25" . "/j/25") ("JavaSE-27" . "/j/27")))
          (hellmacs-jvm-apply-jdks)
          (should (equal (mapcar (lambda (r) (plist-get r :name)) lsp-java-configuration-runtimes)
                         '("JavaSE-1.8" "JavaSE-21" "JavaSE-25"))))
      (delete-file hellmacs-jdk-file))))

(defun test-java--load-cli ()
  (require 'hellmacs-cli)
  (hellmacs-require 'hellmacs-lib 'jdk)               ; loaded now, so its functions can be stubbed
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang java))
    (hellmacs-module--load '(:lang . java) "cli.el")))

(ert-deftest test-java/sync-stores-jdks ()
  "Sync stores the JDKs it finds, and says which."
  (test-java--load-cli)
  (should (memq 'hellmacs-jvm-sync-detect-jdks hellmacs-sync-functions))
  (let ((hellmacs-jdk-file (make-temp-file "hellmacs-test-jdks" nil ".eld"))
        (logged nil))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-jdk-detect)
                   (lambda () '(("JavaSE-1.8" . "/j/8") ("JavaSE-21" . "/j/21"))))
                  ((symbol-function 'hellmacs-sync--log)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) logged))))
          (hellmacs-jvm-sync-detect-jdks)
          (should (equal (hellmacs-jdk-read) '(("JavaSE-1.8" . "/j/8") ("JavaSE-21" . "/j/21"))))
          (should (string-match-p "JDKs for projects: 1\\.8, 21" (car logged))))
      (delete-file hellmacs-jdk-file))))

(ert-deftest test-java/doctor-lists-jdks ()
  "Doctor lists each JDK, marks JDTLS's default, and says when sync hasn't seen them."
  (test-java--load-cli)
  (let ((hellmacs-jdk-file (make-temp-file "hellmacs-test-jdks" nil ".eld"))
        (hellmacs-jvm-java-home "/j/21")
        (hellmacs-jdks nil)
        (hellmacs-cli--problems 0)
        (found '(("JavaSE-1.8" . "/j/8") ("JavaSE-21" . "/j/21"))))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-jdk-detect) (lambda () found)))
          (hellmacs-jdk-write found)
          (let ((out (with-output-to-string (hellmacs-jvm-doctor-jdks))))
            (should (string-match-p "✓ JDK JavaSE-1\\.8: /j/8$" out))
            (should (string-match-p "✓ JDK JavaSE-21: /j/21 (the default)" out))
            (should-not (string-match-p "sync" out)))
          ;; Newer than JDTLS knows: listed, but not offered to it.
          (let ((before found)
                (hellmacs-jvm-jdtls-java-max 25))
            (setq found (append found '(("JavaSE-27" . "/j/27")))) ; the stub sees this `found'
            (hellmacs-jdk-write found)
            (should (string-match-p "· JDK JavaSE-27: /j/27 (newer than JDTLS .* knows; not offered to it)"
                                    (with-output-to-string (hellmacs-jvm-doctor-jdks))))
            (setq found before)
            (hellmacs-jdk-write found))
          ;; A JDK installed since the last sync.
          (setq found (append found '(("JavaSE-25" . "/j/25"))))
          (should (string-match-p "! .*JavaSE-25.*`bin/hellmacs sync'"
                                  (with-output-to-string (hellmacs-jvm-doctor-jdks))))
          ;; Yours: each must be a JDK of the release it's named for.
          (let ((hellmacs-jdks '(("JavaSE-17" . "/nowhere/17"))))
            (should (string-match-p "✗ .*JavaSE-17.*/nowhere/17"
                                    (with-output-to-string (hellmacs-jvm-doctor-jdks))))
            (should (= hellmacs-cli--problems 1))))
      (delete-file hellmacs-jdk-file))))

(defvar hellmacs-jvm-jdtls-java-max)
(defvar hellmacs-jdk-roots)

(defmacro test-java--with-jdks (&rest body)
  "Run BODY with fake JDK homes `j21', `j25' and `j27', all stored by sync,
no JAVA_HOME, and no java on the PATH."
  (declare (indent 0))
  `(let* ((root (make-temp-file "hellmacs-test-jdks" t))
          (j21 (expand-file-name "j21" root))
          (j25 (expand-file-name "j25" root))
          (j27 (expand-file-name "j27" root))
          (hellmacs-jdk-file (expand-file-name "jdks.eld" root))
          (hellmacs-jvm-java-home nil)
          (hellmacs-jvm-jdtls-java-max 25)
          (hellmacs-jdk-roots (list root))  ; live detection sees only these
          (exec-path nil)
          (process-environment (cons "JAVA_HOME" process-environment)))
     (unwind-protect
         (progn
           (dolist (jdk (list (cons j21 "21.0.1") (cons j25 "25.0.4") (cons j27 "27")))
             (make-directory (car jdk) t)
             (with-temp-file (expand-file-name "release" (car jdk))
               (insert (format "JAVA_VERSION=\"%s\"\n" (cdr jdk)))))
           (hellmacs-jdk-write (list (cons "JavaSE-21" j21) (cons "JavaSE-25" j25) (cons "JavaSE-27" j27)))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-java/jdtls-runs-on-a-jdk-it-supports ()
  "JDTLS's JDK: yours if set; else JAVA_HOME's or the PATH's when JDTLS runs
on it, else the newest JDK sync found that it runs on."
  (test-java--load)
  (test-java--with-jdks
    (should (equal (hellmacs-jvm-jdtls-java-home) j25)) ; newest in range, not 27
    (should (equal (hellmacs-jvm-java-executable) (expand-file-name "bin/java" j25)))
    (let ((process-environment (cons (concat "JAVA_HOME=" j21) process-environment)))
      (should (equal (hellmacs-jvm-jdtls-java-home) j21)))
    (let ((process-environment (cons (concat "JAVA_HOME=" j27) process-environment)))
      (should (equal (hellmacs-jvm-jdtls-java-home) j25)))
    (let ((hellmacs-jvm-java-home j27))  ; yours, even if JDTLS can't run on it
      (should (equal (hellmacs-jvm-jdtls-java-home) j27)))
    (hellmacs-jdk-write (list (cons "JavaSE-27" j27)))
    (should-not (hellmacs-jvm-jdtls-java-home))
    (should (equal (hellmacs-jvm-java-executable) "java"))))

(ert-deftest test-java/doctor-checks-jdtls-jdk ()
  "Doctor names JDTLS's JDK, why another was passed over, and what to do when none fits."
  (test-java--load-cli)
  (test-java--with-jdks
    (let ((hellmacs-cli--problems 0)
          (process-environment (cons (concat "JAVA_HOME=" j27) process-environment)))
      (let ((out (with-output-to-string (hellmacs-jvm-doctor-jdtls-jdk))))
        (should (string-match-p (concat "✓ JDK 25 for JDTLS: " (regexp-quote (abbreviate-file-name j25))) out))
        (should (string-match-p "JAVA_HOME's JDK 27 can't run JDTLS .* (it runs on 21 to 25)" out)))
      (should (zerop hellmacs-cli--problems))
      (let ((hellmacs-jvm-java-home j27))
        (should (string-match-p "✗ `hellmacs-jvm-java-home' is JDK 27; JDTLS .* runs on 21 to 25"
                                (with-output-to-string (hellmacs-jvm-doctor-jdtls-jdk)))))
      (hellmacs-jdk-write (list (cons "JavaSE-27" j27)))
      (should (string-match-p "✗ No JDK 21 to 25 to run JDTLS"
                              (with-output-to-string (hellmacs-jvm-doctor-jdtls-jdk))))
      (should (= hellmacs-cli--problems 2)))))

(ert-deftest test-java/debug-launch-on-the-project-jdk ()
  "A launch runs the program on its project's JDK, as JDTLS resolves it;
a :javaExec you gave is kept, and without an answer java-debug decides."
  (test-java--load)
  (cl-letf (((symbol-function 'hellmacs-jvm--resolve-java-executable)
             (lambda (main project)
               (and (equal main "a.Main") (equal project "p") "/jdk8/bin/java"))))
    (should (equal (plist-get (hellmacs-jvm--launch-on-project-jdk-a
                               (list :mainClass "a.Main" :projectName "p"))
                              :javaExec)
                   "/jdk8/bin/java"))
    (should (equal (plist-get (hellmacs-jvm--launch-on-project-jdk-a
                               (list :mainClass "a.Main" :projectName "p" :javaExec "/mine/java"))
                              :javaExec)
                   "/mine/java"))
    (should-not (plist-get (hellmacs-jvm--launch-on-project-jdk-a
                            (list :mainClass "b.Other" :projectName "p"))
                           :javaExec))
    (should-not (plist-get (hellmacs-jvm--launch-on-project-jdk-a (list :request "attach"))
                           :javaExec))))

(defvar hellmacs-jvm-maven-toolchains)
(defvar hellmacs-bundle-functions)
(defvar hellmacs--loaded-cli-files)

(defun test-java--doctor-toolchains (dir)
  "What `hellmacs-jvm-doctor-toolchains' reports for DIR."
  (with-output-to-string (hellmacs-jvm-doctor-toolchains dir)))

(ert-deftest test-java/doctor-gradle-toolchain ()
  "A Gradle toolchain's JDK: found, missing (named with where it's asked for), or downloaded."
  (test-java--load-cli)
  (test-java--with-jdks
    (let* ((proj (expand-file-name "proj/" root))
           (hellmacs-cli--problems 0)
           (hellmacs-jvm-maven-toolchains (expand-file-name "none.xml" root))
           (process-environment (cons (concat "GRADLE_USER_HOME=" (expand-file-name "gh" root))
                                      process-environment)))
      (make-directory proj t)
      (with-temp-file (expand-file-name "build.gradle" proj)
        (insert "plugins { id 'java' }\njava {\n  toolchain {\n    languageVersion = JavaLanguageVersion.of(11)\n  }\n}\n"))
      (let ((out (test-java--doctor-toolchains proj)))
        (should (string-match-p "✗ build.gradle:4 asks for a JDK 11 toolchain, and none is installed" out))
        (should (= hellmacs-cli--problems 1)))
      ;; Listed for Gradle in org.gradle.java.installations.paths.
      (let ((j11 (expand-file-name "elsewhere/j11" root))) ; not where JDKs are looked for
        (make-directory j11 t)
        (with-temp-file (expand-file-name "release" j11) (insert "JAVA_VERSION=\"11.0.2\"\n"))
        (with-temp-file (expand-file-name "gradle.properties" proj)
          (insert "org.gradle.java.installations.paths=" j11 "\n"))
        (should (string-match-p (concat "✓ build.gradle:4 asks for a JDK 11 toolchain: "
                                        (regexp-quote (abbreviate-file-name j11)))
                                (test-java--doctor-toolchains proj)))
        (delete-file (expand-file-name "gradle.properties" proj)))
      ;; A toolchain resolver: Gradle downloads it.
      (with-temp-file (expand-file-name "settings.gradle" proj)
        (insert "plugins { id 'org.gradle.toolchains.foojay-resolver-convention' version '1.0.0' }\n"))
      (let ((hellmacs-cli--problems 0))
        (should (string-match-p "· build.gradle:4 asks for a JDK 11 toolchain; none is installed, so Gradle downloads one"
                                (test-java--doctor-toolchains proj)))
        (should (zerop hellmacs-cli--problems))))))

(ert-deftest test-java/doctor-maven-toolchains ()
  "Maven's toolchains.xml: each JDK it lists must be there; the build's request must be listed."
  (test-java--load-cli)
  (test-java--with-jdks
    (let ((proj (expand-file-name "mproj/" root))
          (hellmacs-jvm-maven-toolchains (expand-file-name "toolchains.xml" root))
          (hellmacs-cli--problems 0))
      (make-directory proj t)
      (with-temp-file (expand-file-name "pom.xml" proj)
        (insert "<project><build><plugins><plugin>\n<artifactId>maven-toolchains-plugin</artifactId>\n"
                "<configuration><toolchains><jdk>\n<version>25</version>\n</jdk></toolchains></configuration>\n"
                "</plugin></plugins></build></project>\n"))
      (with-temp-file hellmacs-jvm-maven-toolchains
        (insert (format "<toolchains>
<toolchain><type>jdk</type><provides><version>21</version></provides><configuration><jdkHome>%s</jdkHome></configuration></toolchain>
<toolchain><type>jdk</type><provides><version>17</version></provides><configuration><jdkHome>/nowhere/17</jdkHome></configuration></toolchain>
</toolchains>" j21)))
      (let ((out (test-java--doctor-toolchains proj)))
        (should (string-match-p (concat "✓ Maven toolchain JDK 21: " (regexp-quote (abbreviate-file-name j21))) out))
        (should (string-match-p "✗ .*toolchains.xml gives /nowhere/17 for JDK 17, which isn't a JDK" out))
        (should (string-match-p "✗ pom.xml:4 asks for a JDK 25 toolchain, and .*toolchains.xml has none" out))
        (should (= hellmacs-cli--problems 2)))
      (with-temp-file hellmacs-jvm-maven-toolchains
        (insert (format "<toolchains><toolchain><type>jdk</type><provides><version>25</version></provides><configuration><jdkHome>%s</jdkHome></configuration></toolchain></toolchains>" j25)))
      (let ((hellmacs-cli--problems 0))
        (should (string-match-p (concat "✓ pom.xml:4 asks for a JDK 25 toolchain: " (regexp-quote (abbreviate-file-name j25)))
                                (test-java--doctor-toolchains proj)))
        (should (zerop hellmacs-cli--problems)))
      ;; Outside any build: only toolchains.xml is checked.
      (should-not (string-match-p "asks for" (test-java--doctor-toolchains root))))))

(defvar hellmacs-jvm-spring-dir)
(defvar hellmacs-jvm-spring-sha256)
(defvar hellmacs-jvm-spring-url)

(defun test-java--fake-vsix (root)
  "A VSIX laid out like Spring Boot Tools', in ROOT; return its path."
  (let ((src (expand-file-name "vsix" root)))
    (dolist (file (append '("extension/language-server/spring-boot-language-server-9.9.9-exec.jar"
                            "extension/language-server/lib/spring-core.jar"
                            "extension/node_modules/junk.js")
                          (mapcar (lambda (jar) (concat "extension/jars/" jar))
                                  '("io.projectreactor.reactor-core.jar" "org.reactivestreams.reactive-streams.jar"
                                    "jdt-ls-commons.jar" "jdt-ls-extension.jar" "sts-gradle-tooling.jar"
                                    "xml-ls-extension.jar"))))
      (let ((path (expand-file-name file src)))
        (make-directory (file-name-directory path) t)
        (with-temp-file path (insert file))))
    (let ((default-directory (file-name-as-directory src)))
      (call-process "zip" nil nil nil "-q" "-r" "../boot.vsix" "extension"))
    (expand-file-name "boot.vsix" root)))

(ert-deftest test-java/spring-server-install-is-pinned ()
  "+spring: sync installs Spring Boot Tools' server and JDTLS extensions, only if the VSIX
matches its pin, and keeps only what's used."
  (skip-unless (and (executable-find "zip") (executable-find "unzip")))
  (test-java--load-cli)
  (let* ((root (make-temp-file "hellmacs-test-spring" t))
         (vsix (test-java--fake-vsix root))
         (hellmacs-jvm-spring-dir (expand-file-name "lsp/spring-boot/" root))
         (hellmacs-jvm-spring-url "https://example.invalid/boot.vsix"))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-net-download) (lambda (_url file &rest _) (copy-file vsix file t)))
                  ((symbol-function 'hellmacs-sync--log) #'ignore))
          (let ((hellmacs-jvm-spring-sha256 (make-string 64 ?0)))
            (should-error (hellmacs-jvm-sync-install-spring))
            (should-not (hellmacs-jvm-spring-installed-p)))
          (let ((hellmacs-jvm-spring-sha256 (hellmacs-file-sha256 vsix)))
            (hellmacs-jvm-sync-install-spring)
            (should (hellmacs-jvm-spring-installed-p))
            (should (equal (file-name-nondirectory (hellmacs-jvm-spring-server-jar))
                           "spring-boot-language-server-9.9.9-exec.jar"))
            (should (file-exists-p (expand-file-name "language-server/lib/spring-core.jar" hellmacs-jvm-spring-dir)))
            ;; The five jars VS Code gives JDTLS, in its order; nothing else.
            (should (equal (mapcar #'file-name-nondirectory (hellmacs-jvm-spring-extension-jars))
                           '("io.projectreactor.reactor-core.jar" "org.reactivestreams.reactive-streams.jar"
                             "jdt-ls-commons.jar" "jdt-ls-extension.jar" "sts-gradle-tooling.jar")))
            (should (seq-every-p #'file-exists-p (hellmacs-jvm-spring-extension-jars)))
            (should-not (file-exists-p (expand-file-name "node_modules" hellmacs-jvm-spring-dir)))))
      (delete-directory root t))))

(ert-deftest test-java/spring-server-command ()
  "The server runs as VS Code runs it: over stdio, its console log off (it would
corrupt the protocol), no web server of its own, on JDTLS's JDK."
  (test-java--load)
  (let* ((root (make-temp-file "hellmacs-test-spring" t))
         (hellmacs-jvm-spring-dir (file-name-as-directory root))
         (hellmacs-cache-dir (file-name-as-directory (expand-file-name "cache" root)))
         (jar (expand-file-name "language-server/spring-boot-language-server-9.9.9-exec.jar" root))
         (hellmacs-jvm-java-home "/j/21"))
    (unwind-protect
        (progn
          (make-directory (file-name-directory jar) t)
          (with-temp-file jar (insert "jar"))
          (let ((command (hellmacs-jvm-spring-ls-command)))
            (should (equal (car command) "/j/21/bin/java"))
            (dolist (arg '("-Xmx1024m" "-Dsts.lsp.client=vscode" "-Dlogging.pattern.console="
                           "-Dspring.main.web-application-type=NONE"
                           "-Dspring.config.location=classpath:/application.properties"))
              (should (member arg command)))
            (should-not (seq-some (lambda (a) (string-match-p "server\\.port\\|client-port" a)) command))
            (should (equal (last command 2) (list "-jar" jar)))
            ;; Its log files go to Hellmacs' cache, which exists by then.
            (should (file-directory-p (expand-file-name "spring-boot" hellmacs-cache-dir)))))
      (delete-directory root t))))

(ert-deftest test-java/spring-initialization-options ()
  "The server gets VS Code's initialization options; without them it fails to
initialize (a JsonNull cast in JdtLsProjectCache.initialize)."
  (test-java--load)
  (cl-letf (((symbol-function 'lsp--path-to-uri) (lambda (path) (concat "file://" path))))
    (should (equal (hellmacs-jvm-spring-initialization-options '("/p/a" "/p/b"))
                   '(:workspaceFolders ["file:///p/a" "file:///p/b"] :enableJdtClasspath :json-false)))
    (should (equal (hellmacs-jvm-spring-initialization-options nil)
                   '(:workspaceFolders [] :enableJdtClasspath :json-false)))))

(ert-deftest test-java/spring-flag-hooks ()
  "With +spring, sync installs the server and bundles carry it; without, neither."
  (require 'hellmacs-cli)
  (hellmacs-require 'hellmacs-lib 'jdk)
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-sync-functions nil)
        (hellmacs-bundle-functions nil)
        (hellmacs--loaded-cli-files nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang (java +spring)))
    (hellmacs-module--load '(:lang . java) "cli.el")
    (should (memq 'hellmacs-jvm-sync-install-spring hellmacs-sync-functions))
    (should (member hellmacs-jvm-spring-dir (hellmacs-jvm-bundle-paths))))
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-sync-functions nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang java))
    (hellmacs-module--load '(:lang . java) "cli.el")
    (should-not (memq 'hellmacs-jvm-sync-install-spring hellmacs-sync-functions))
    (should-not (member hellmacs-jvm-spring-dir (hellmacs-jvm-bundle-paths)))))

(provide 'test-java)
;;; test-java.el ends here
