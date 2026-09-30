;;; test-groovy.el --- Tests for :lang groovy (Phase 8.4) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. groovy-mode, lsp-mode and the server
;; aren't installed here: what reaches them is stubbed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-sync)

(defvar hellmacs-groovy-map)
(defvar hellmacs-groovy-keys-mode-map)
(defvar hellmacs-groovy-server-url)
(defvar hellmacs-groovy-server-dir)
(defvar hellmacs-groovy-server-jar)
(defvar hellmacs-groovy-gradle-dir)
(defvar hellmacs-groovy--classpaths)
(defvar hellmacs-groovy--classpath-error)
(defvar lsp-groovy-classpath)
(defvar lsp-groovy-server-file)
(defvar lsp--cur-workspace)

(defvar test-groovy--loaded nil)

(defun test-groovy--load ()
  "Load :lang groovy's files, once, with :tools build and lsp on."
  (unless test-groovy--loaded
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:tools build lsp :lang groovy))
      (hellmacs-module--load '(:tools . build) "autoload.el")
      (hellmacs-module--load '(:lang . groovy) "autoload.el")
      (hellmacs-module--load '(:lang . groovy) "config.el")
      (hellmacs-module--load '(:lang . groovy) "cli.el"))
    (setq test-groovy--loaded t)))

(defmacro test-groovy--with-tree (files &rest body)
  "Run BODY in a temporary directory ROOT holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-groovy" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (delete-directory root t))))

;;; Files ----------------------------------------------------------------------

(ert-deftest test-groovy/file-associations ()
  "Groovy sources, Gradle's Groovy scripts and Jenkinsfiles are Groovy; Gradle's
Kotlin scripts and Java aren't."
  (test-groovy--load)
  (dolist (f '("App.groovy" "build.gradle" "settings.gradle" "Jenkinsfile" "ci/Jenkinsfile"
               "pipeline.jenkinsfile" "Jenkinsfile.release"))
    (should (hellmacs-groovy-file-p f)))
  (dolist (f '("build.gradle.kts" "App.java" "Jenkinsfile.md"))
    (should-not (hellmacs-groovy-file-p f)))
  ;; The ones groovy-mode doesn't claim itself open in it too.
  (dolist (f '("/p/pipeline.jenkinsfile" "/p/Jenkinsfile.release"))
    (should (eq (assoc-default f auto-mode-alist #'string-match-p) 'groovy-mode))))

;;; The pinned server, built from source ---------------------------------------

(ert-deftest test-groovy/pinned-server ()
  "groovy-language-server publishes no releases: it's built from a pinned commit,
with a pinned Gradle, its dependencies checked against the module's
verification metadata. Everything downloaded is declared for the SBOM."
  (test-groovy--load)
  (let ((spec (hellmacs-groovy-server-spec)))
    (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" (plist-get spec :commit)))
    (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" (plist-get spec :gradle-sha256)))
    (should (plist-get spec :gradle-version))
    (should (file-readable-p (plist-get spec :verification-metadata))))
  (dolist (name '("groovy-language-server" "gradle"))
    (should (seq-find (lambda (c) (equal (plist-get c :name) name)) hellmacs-components)))
  ;; lsp-groovy starts the server Hellmacs installs.
  (should (equal lsp-groovy-server-file hellmacs-groovy-server-jar)))

(defun test-groovy--source-repo (dir)
  "A git repository in DIR standing in for groovy-language-server; return its HEAD."
  (make-directory dir t)
  (let ((default-directory (file-name-as-directory dir)))
    (with-temp-file "build.gradle" (insert "// the server's build\n"))
    (make-directory "gradle" t)
    (dolist (args '(("init" "-q") ("add" ".")
                    ("-c" "user.name=t" "-c" "user.email=t@t" "commit" "-q" "-m" "server")))
      (should (zerop (apply #'call-process "git" nil nil nil args))))
    (car (process-lines "git" "rev-parse" "HEAD"))))

(defun test-groovy--gradle-zip (root version log)
  "A zip of a fake Gradle VERSION under ROOT, whose gradle records into LOG and
builds the jar; return its path."
  (let* ((stage (expand-file-name "stage" root))
         (bin (expand-file-name (format "gradle-%s/bin" version) stage))
         (zip (expand-file-name "gradle.zip" root)))
    (make-directory bin t)
    (with-temp-file (expand-file-name "gradle" bin)
      (insert "#!/bin/sh\n"
              "{ echo \"args: $*\"; echo \"JAVA_HOME=$JAVA_HOME\"; echo \"GRADLE_USER_HOME=$GRADLE_USER_HOME\";\n"
              "  echo \"pwd=$(basename \"$PWD\")\"; [ -f gradle/verification-metadata.xml ] && echo verified; } >> "
              (shell-quote-argument log) "\n"
              "mkdir -p build/libs && echo jar > build/libs/groovy-language-server-all.jar\n"))
    (set-file-modes (expand-file-name "gradle" bin) #o755)
    (let ((default-directory (file-name-as-directory stage)))
      (should (zerop (call-process "zip" nil nil nil "-qr" zip "."))))
    zip))

(ert-deftest test-groovy/server-built-at-the-pinned-commit ()
  "Sync fetches exactly the pinned commit, builds it with the pinned Gradle on a
JDK that Gradle runs on, in Hellmacs' own Gradle home, with dependency
verification; then puts the jar in place and records the commit. A
different commit is refused."
  (skip-unless (and (executable-find "git") (executable-find "zip") (executable-find "unzip")))
  (test-groovy--load)
  (let* ((root (make-temp-file "hellmacs-test-groovy" t))
         (log (expand-file-name "gradle.log" root))
         (commit (test-groovy--source-repo (expand-file-name "upstream" root)))
         (spec (hellmacs-groovy-server-spec))
         (zip (test-groovy--gradle-zip root (plist-get spec :gradle-version) log))
         (hellmacs-groovy-server-url (concat "file://" (expand-file-name "upstream" root)))
         (hellmacs-groovy-server-dir (file-name-as-directory (expand-file-name "lsp/groovy" root)))
         (hellmacs-groovy-server-jar (expand-file-name "groovy-language-server-all.jar" hellmacs-groovy-server-dir))
         (hellmacs-groovy-gradle-dir (file-name-as-directory (expand-file-name "gradle" root))))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-sync--log) #'ignore)
                  ((symbol-function 'hellmacs-groovy--build-java-home) (lambda () "/jdk/21"))
                  ((symbol-function 'hellmacs-net-download) (lambda (_url file) (copy-file zip file t))))
          (cl-letf (((symbol-function 'hellmacs-groovy-server-spec)
                     (lambda () (plist-put (copy-sequence spec) :commit (make-string 40 ?a)))))
            (should-error (hellmacs-groovy-sync-install-server))
            (should-not (file-exists-p hellmacs-groovy-server-jar)))
          (cl-letf (((symbol-function 'hellmacs-groovy-server-spec)
                     (lambda () (plist-put (plist-put (copy-sequence spec) :commit commit)
                                           :gradle-sha256 (hellmacs-file-sha256 zip)))))
            (hellmacs-groovy-sync-install-server)
            (should (hellmacs-groovy-server-installed-p))
            (let ((built (with-temp-buffer (insert-file-contents log) (buffer-string))))
              (should (string-match-p "args: .*--no-daemon.*shadowJar" built))
              (should (string-match-p "JAVA_HOME=/jdk/21" built))
              (should (string-match-p (concat "GRADLE_USER_HOME=" (regexp-quote hellmacs-cache-dir)) built))
              (should (string-match-p "pwd=groovy-language-server" built))
              (should (string-match-p "^verified$" built)))
            ;; Installed: nothing is built again.
            (delete-file log)
            (hellmacs-groovy-sync-install-server)
            (should-not (file-exists-p log))))
      (delete-directory root t))))

(ert-deftest test-groovy/sync-finds-the-jdks-without-java ()
  "Builds (and the classpath request) run on a JDK their Gradle runs on, which
needs the JDKs sync finds; :lang java finds them, and without it this
module does."
  (test-groovy--load)
  (should (memq #'hellmacs-groovy-sync-detect-jdks hellmacs-sync-functions))
  (let ((written nil))
    (cl-letf (((symbol-function 'hellmacs-jdk-detect) (lambda () '(("JavaSE-21" . "/jdk/21"))))
              ((symbol-function 'hellmacs-jdk-write) (lambda (jdks) (setq written jdks)))
              ((symbol-function 'hellmacs-sync--log) #'ignore))
      (hellmacs-groovy-sync-detect-jdks))
    (should (equal written '(("JavaSE-21" . "/jdk/21"))))))

(ert-deftest test-groovy/server-build-through-the-mirrors ()
  "The server's build fetches its dependencies through `hellmacs-mirrors' too:
an init script points Maven Central and the plugin portal at theirs."
  (test-groovy--load)
  (let ((dir (make-temp-file "hellmacs-test-groovy" t)))
    (unwind-protect
        (progn
          (let ((hellmacs-mirrors nil))
            (should-not (hellmacs-groovy--mirror-init-script dir)))
          (let* ((hellmacs-mirrors '(("https://repo.maven.apache.org/maven2/" . "https://art.corp/central/")))
                 (script (with-temp-buffer
                           (insert-file-contents (hellmacs-groovy--mirror-init-script dir))
                           (buffer-string))))
            (should (string-search "'https://repo.maven.apache.org/maven2/') { repo.url = 'https://art.corp/central/' }"
                                   script))
            (should-not (string-search "plugins.gradle.org" script))
            (should (string-search "pluginManagement.repositories" script))))
      (delete-directory dir t))))

;;; The project's classpath -----------------------------------------------------

(ert-deftest test-groovy/classpath-from-the-build ()
  "The server only knows the project's libraries from `groovy.classpath': it's
asked of the build (Gradle through an init script, Maven through the
pinned dependency plugin), then sent to the server, which is then ready."
  (test-groovy--load)
  (test-groovy--with-tree
      '(("settings.gradle" . "rootProject.name = 'p'\n")
        ("gradlew" . "#!/bin/sh\necho \"args: $*\" >&2\necho 'hellmacs-classpath: /c/junit.jar'\necho noise\necho 'hellmacs-classpath: /c/groovy.jar'\n"))
    (set-file-modes (expand-file-name "gradlew" root) #o755)
    (let ((hellmacs-groovy--classpaths (make-hash-table :test #'equal))
          (got :none))
      (hellmacs-groovy-fetch-classpath root (lambda (classpath) (setq got classpath)))
      (with-timeout (10) (while (eq got :none) (accept-process-output nil 0.1)))
      (should (equal got '("/c/junit.jar" "/c/groovy.jar")))
      ;; Kept for the project until a build file changes.
      (setq got :none)
      (cl-letf (((symbol-function 'make-process) (lambda (&rest _) (error "Asked again"))))
        (hellmacs-groovy-fetch-classpath root (lambda (classpath) (setq got classpath))))
      (should (equal got '("/c/junit.jar" "/c/groovy.jar")))))
  ;; A failing build: nil, and not kept.
  (test-groovy--with-tree
      '(("settings.gradle" . "") ("gradlew" . "#!/bin/sh\nprintf '\\nFAILURE: Build failed.\\n\\n* What went wrong:\\nUnsupported class file major version 71\\n\\n* Try:\\n> Run with --stacktrace\\n' >&2\nexit 1\n"))
    (set-file-modes (expand-file-name "gradlew" root) #o755)
    (let ((hellmacs-groovy--classpaths (make-hash-table :test #'equal))
          (got :none))
      (hellmacs-groovy-fetch-classpath root (lambda (classpath) (setq got classpath)))
      (with-timeout (10) (while (eq got :none) (accept-process-output nil 0.1)))
      (should (eq got 'failed))
      ;; Why, as Gradle says it.
      (should (equal hellmacs-groovy--classpath-error "Unsupported class file major version 71"))
      (should (zerop (hash-table-count hellmacs-groovy--classpaths)))))
  ;; Maven's, with the pinned plugin.
  (test-groovy--with-tree '(("pom.xml" . "<project/>\n"))
    (let ((command (hellmacs-groovy--classpath-command root "/tmp/cp.txt")))
      (should (equal (car command) "mvn"))
      (should (seq-some (lambda (a) (string-match-p "\\`org.apache.maven.plugins:maven-dependency-plugin:[0-9.]+:build-classpath\\'" a))
                        command))
      (should (member "-Dmdep.outputFile=/tmp/cp.txt" command))))
  ;; No build: nothing to ask.
  (test-groovy--with-tree '(("script.groovy" . "println 1\n"))
    (should-not (hellmacs-groovy--classpath-command root "/tmp/cp.txt"))))

(ert-deftest test-groovy/classpath-sent-then-ready ()
  "Once the server started, its project's classpath goes to it, and the status
says ready; a build that can't say fails the import, saying why."
  (test-groovy--load)
  (let ((hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
        (root (make-temp-file "hellmacs-test-groovy" t))
        (sent nil) (answer nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message) #'ignore)
                  ((symbol-function 'hellmacs-lsp-status--server) (lambda (_) 'groovy-ls))
                  ((symbol-function 'hellmacs-lsp-status--root) (lambda (_) root))
                  ((symbol-function 'hellmacs-groovy-fetch-classpath)
                   (lambda (_root callback) (funcall callback answer)))
                  ((symbol-function 'lsp-configuration-section)
                   (lambda (section) (list section lsp-groovy-classpath)))
                  ((symbol-function 'lsp--set-configuration)
                   (lambda (settings) (push (list settings lsp--cur-workspace) sent))))
          (setq answer '("/c/junit.jar"))
          (let ((lsp--cur-workspace 'ws))
            (hellmacs-lsp-status--ignited-h)
            (hellmacs-groovy--initialized-h))
          (should (equal sent '((("groovy" ["/c/junit.jar"]) ws))))
          (should (eq (hellmacs-lsp-status-state 'groovy-ls root) 'ready))
          (hellmacs-lsp-status-banish 'groovy-ls root)
          (setq answer 'failed sent nil)
          (let ((lsp--cur-workspace 'ws))
            (hellmacs-lsp-status--ignited-h)
            (hellmacs-groovy--initialized-h))
          (should-not sent)
          (should (eq (hellmacs-lsp-status-state 'groovy-ls root) 'failed)))
      (delete-directory root t))))

;;; Tests and keys ---------------------------------------------------------------

(ert-deftest test-groovy/test-method-at-point ()
  "A JUnit test method by its annotation, a Spock feature by its quoted name."
  (test-groovy--load)
  (with-temp-buffer
    (insert "class GreeterTest {\n    @Test\n    void greetsByName() {\n        assert true\n    }\n\n"
            "    def \"greets someone by name\"() {\n        expect:\n        true\n    }\n\n"
            "    private helper() { }\n}\n")
    (goto-char (point-min))
    (search-forward "assert true")
    (should (equal (hellmacs-groovy-test-method) "greetsByName"))
    (search-forward "expect:")
    (should (equal (hellmacs-groovy-test-method) "greets someone by name"))
    (search-forward "helper")
    (should-not (hellmacs-groovy-test-method))))

(ert-deftest test-groovy/keys ()
  "`C-c l g' holds the Groovy commands, in Hellmacs' own minor mode."
  (test-groovy--load)
  (should (eq (keymap-lookup hellmacs-groovy-map "b") #'hellmacs-forge-build))
  (should (eq (keymap-lookup hellmacs-groovy-map "t") #'hellmacs-forge-test-at-point))
  (should (eq (keymap-lookup hellmacs-groovy-map "T") #'hellmacs-forge-test-class))
  (should (eq (keymap-lookup hellmacs-groovy-map "c") #'hellmacs-groovy-refresh-classpath))
  (should (eq (keymap-lookup hellmacs-groovy-keys-mode-map "C-c l g") hellmacs-groovy-map)))

(ert-deftest test-groovy/server-runs-on-a-found-jdk ()
  "lsp-groovy runs `java' from the PATH; Hellmacs gives it a JDK it found."
  (test-groovy--load)
  (cl-letf (((symbol-function 'hellmacs-jdk-java-executable) (lambda (_min) "/jdk/21/bin/java")))
    (should (equal (car (hellmacs-groovy--server-command)) "/jdk/21/bin/java"))
    (should (equal (car (last (hellmacs-groovy--server-command))) hellmacs-groovy-server-jar))))

(provide 'test-groovy)
;;; test-groovy.el ends here
