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
(require 'hellmacs-ux)                  ; `hellmacs-ux-enable', bound below

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
      (hellmacs--enable-modules '(:tools lsp :lang java))
      (hellmacs-module--load '(:tools . lsp) "autoload.el") ; `hellmacs-lsp-install-pinned'
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

(ert-deftest test-java/test-method ()
  "The nearest void method above point is the test at point."
  (test-java--load)
  (with-temp-buffer
    (insert "package dev.x;\n\nclass GreeterTest {\n    @Test\n    void greets() {\n        assertTrue(true);\n    }\n}\n")
    (goto-char (point-min)) (search-forward "assertTrue")
    (should (equal (hellmacs-jvm-test-method) "greets"))
    (goto-char (point-min))
    (should-not (hellmacs-jvm-test-method))))

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
          (cl-letf (((symbol-function 'url-copy-file) (lambda (_url file &rest _) (copy-file tarball file t))))
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
    (cl-letf (((symbol-function 'url-copy-file)
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
        (cl-letf (((symbol-function 'url-copy-file) (lambda (&rest _) (error "Shouldn't download"))))
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

(defun test-java--load-cli ()
  (require 'hellmacs-cli)
  (require 'hellmacs-jdk)               ; loaded now, so its functions can be stubbed
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

(provide 'test-java)
;;; test-java.el ends here
