;;; lang/java/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hell: `sync' also installs JDTLS (with its java-debug
;; bundle and JUnit runner), so the first Java file doesn't wait for a
;; download, and with +lombok, the pinned Lombok jar.

;; Paths and the pinned Lombok release, once, now: after your init.el (so
;; your settings win) and before any sync step runs.
(hell-module-load "+paths")


(defvar hell-jvm-install-server-on-sync t
  "Whether `bin/hell sync' installs JDTLS when it's missing.")

(defun hell-jvm--install-jdtls ()
  "Install the pinned JDTLS into `hell-jvm-jdtls-dir', replacing what's there.
Downloaded and checked (`hell-sync-download-verified'), unpacked next
to the install (the same file system, so it moves into place whole), and
only then swapped in; the marker is written last. Whatever else lived in
the directory (java-debug, the test runner) is installed again after."
  (unless (executable-find "tar") (error "tar is needed to install JDTLS"))
  (let* ((dir (directory-file-name hell-jvm-jdtls-dir))
         (stage (progn (make-directory (file-name-directory dir) t)
                       (make-temp-file (concat dir "-stage") t)))
         (tarball (expand-file-name "jdtls.tar.gz" stage))
         (server (expand-file-name "server" stage)))
    (unwind-protect
        (progn
          (hell-sync-download-verified hell-jvm-jdtls-url tarball
                                           hell-jvm-jdtls-sha256 "JDTLS")
          (make-directory server)
          (with-temp-buffer
            (unless (zerop (call-process "tar" nil t nil "-xzf" tarball "-C" server))
              (error "Unpacking JDTLS failed: %s" (buffer-string))))
          (make-directory (expand-file-name "bundles" server)) ; java-debug goes here
          ;; Marked before it moves into place: whatever's at DIR is either
          ;; complete and marked, or not taken for the pinned install.
          (hell-marker-write (expand-file-name (file-name-nondirectory (hell-jvm--jdtls-marker)) server)
                                 hell-jvm-jdtls-sha256)
          (when (file-directory-p dir) (delete-directory dir t))
          (condition-case err
              (rename-file server dir)
            ;; Another install (sync, or Emacs on first use) got there first.
            (file-already-exists
             (unless (hell-jvm-jdtls-installed-p)
               (signal (car err) (cdr err))))))
      (delete-directory stage t))))

(defun hell-jvm-sync-install-server ()
  "Install the pinned JDTLS and JUnit runner if they aren't. For `hell-sync-functions'."
  (when hell-jvm-install-server-on-sync
    (if (hell-jvm-jdtls-installed-p)
        (hell-sync--log "JDTLS %s is installed" hell-jvm-jdtls-version)
      (hell-sync--log "Downloading JDTLS %s (49MB)..." hell-jvm-jdtls-version)
      (hell-jvm--install-jdtls)
      (hell-sync--log "JDTLS %s installed (SHA-256 verified)" hell-jvm-jdtls-version))
    (unless (hell-jvm-junit-runner-valid-p)
      (hell-sync-download-verified hell-jvm-junit-runner-url dap-java-test-runner
                                       hell-jvm-junit-runner-sha256 "The JUnit runner")
      (hell-sync--log "JUnit runner %s installed (SHA-256 verified)"
                          hell-jvm-junit-runner-version))
    (when (modulep! :tools debugger)
      (hell-jvm-sync-install-java-debug))))

(add-hook 'hell-sync-functions #'hell-jvm-sync-install-server)

(defun hell-jvm--java-major (home)
  "The major release of the JDK in HOME: its release file's, else `java -version''s."
  (or (hell-jdk-home-major home)
      (let ((java (expand-file-name "bin/java" home)))
        (when (file-executable-p java)
          (with-temp-buffer
            (when (ignore-errors (zerop (call-process java nil t nil "-version")))
              (goto-char (point-min))
              (when (re-search-forward "version \"\\([0-9.]+\\)" nil t)
                (hell-jdk--major (match-string 1)))))))))

(defun hell-jvm-doctor-jdtls-jdk ()
  "Check the JDK that runs JDTLS. For doctor.el.
Says which it is, and why JAVA_HOME's or the PATH's was passed over."
  (let* ((range (format "%d to %d" hell-jvm-jdtls-java-min hell-jvm-jdtls-java-max))
         (fits (lambda (major) (and major (<= hell-jvm-jdtls-java-min major hell-jvm-jdtls-java-max))))
         (home (hell-jvm-jdtls-java-home))
         (major (and home (hell-jvm--java-major home))))
    (cond
     (hell-jvm-java-home
      (if (funcall fits major)
          (hell-doctor-ok "JDK %d for JDTLS: %s (`hell-jvm-java-home')" major (abbreviate-file-name home))
        (hell-doctor-error :topic 'jdk "`hell-jvm-java-home' is %s; JDTLS %s runs on %s"
                               (if major (format "JDK %d" major) (format "%s, not a JDK" (abbreviate-file-name home)))
                               hell-jvm-jdtls-version range)))
     ((null home)
      (hell-doctor-error :topic 'jdk "No JDK %s to run JDTLS %s; install one (then `bin/hell sync'), or set `hell-jvm-java-home'"
                             range hell-jvm-jdtls-version))
     (t
      (hell-doctor-ok "JDK %d for JDTLS: %s" major (abbreviate-file-name home))
      (pcase-dolist (`(,label . ,other)
                     (list (cons "JAVA_HOME's" (let ((h (getenv "JAVA_HOME"))) (and h (not (string-empty-p h)) h)))
                           (cons "The PATH's" (hell-jvm--path-java-home))))
        (when (and other (not (equal (file-truename (directory-file-name (expand-file-name other)))
                                     (file-truename home))))
          (let ((other-major (hell-jvm--java-major other)))
            (unless (funcall fits other-major)
              (hell-doctor-info "%s JDK %s can't run JDTLS %s (it runs on %s); using JDK %d instead"
                                    label (or other-major "(unknown release)") hell-jvm-jdtls-version range major))))))))
  (unless (getenv "JAVA_HOME")
    (hell-doctor-info "JAVA_HOME isn't set")))

(defun hell-jvm--major-string (release)
  "RELEASE (\"JavaSE-1.8\") as its major number (\"8\")."
  (number-to-string (hell-jdk--major (replace-regexp-in-string "\\`[A-Za-z0-9]+-" "" release))))

(defun hell-jvm-doctor-toolchains (dir)
  "Check the JDKs builds ask for: Maven's toolchains.xml, and the build around DIR.
Every JDK toolchains.xml lists must be there. A Gradle toolchain needs a
JDK of its release where Gradle looks (or a resolver to download one); a
Maven toolchain, an entry in toolchains.xml. Build files are only read."
  (let* ((xml (expand-file-name hell-jvm-maven-toolchains))
         (listed (hell-jdk-toolchains-xml-jdks xml))
         (request (hell-jdk-build-request dir)))
    (pcase-dolist (`(,release . ,home) listed)
      (let ((major (hell-jvm--major-string release))
            (actual (and home (hell-jdk-home-release home))))
        (cond ((null home)
               (hell-doctor-warn :topic 'toolchains "%s lists a JDK %s with no jdkHome" (abbreviate-file-name xml) major))
              ((equal actual release)
               (hell-doctor-ok "Maven toolchain JDK %s: %s" major (abbreviate-file-name home)))
              (t (hell-doctor-error :topic 'toolchains "%s gives %s for JDK %s, which %s" (abbreviate-file-name xml)
                                        (abbreviate-file-name home) major
                                        (if actual (format "is a JDK %s" (hell-jvm--major-string actual))
                                          "isn't a JDK"))))))
    (when request
      (let* ((release (plist-get request :release))
             (major (hell-jvm--major-string release))
             (where (format "%s:%d" (file-name-nondirectory (plist-get request :file)) (plist-get request :line)))
             (asks (format "%s asks for a JDK %s toolchain" where major)))
        (pcase (plist-get request :tool)
          ('gradle
           (let ((home (seq-find (lambda (home) (equal (hell-jdk-home-release home) release))
                                 (append (mapcar #'cdr (hell-jdk-detect))
                                         (hell-jdk-gradle-installation-paths dir)))))
             (cond (home (hell-doctor-ok "%s: %s" asks (abbreviate-file-name home)))
                   ((hell-jdk-gradle-provisions-p dir)
                    (hell-doctor-info "%s; none is installed, so Gradle downloads one (its toolchain resolver)" asks))
                   (t (hell-doctor-error :topic 'toolchains "%s, and none is installed. Install one (SDKMAN, your package manager), or list it in org.gradle.java.installations.paths (~/.gradle/gradle.properties)"
                                             asks)))))
          ('maven
           (let ((home (cdr (seq-find (lambda (jdk) (and (equal (car jdk) release) (cdr jdk)
                                                         (equal (hell-jdk-home-release (cdr jdk)) release)))
                                      listed))))
             (if home
                 (hell-doctor-ok "%s: %s" asks (abbreviate-file-name home))
               (hell-doctor-error :topic 'toolchains "%s, and %s %s. Add the JDK there (<toolchain> of type jdk, with its jdkHome)"
                                      asks (abbreviate-file-name xml)
                                      (if (file-exists-p xml) "has none" "doesn't exist"))))))))))

;;; JDKs for projects (Phase 12.3) ---------------------------------------------

(defun hell-jvm-sync-detect-jdks ()
  "Find the JDKs on this machine and store them for JDTLS. For `hell-sync-functions'.
Stored rather than looked for at startup, which would cost startup time;
config.el reads them when lsp-java loads."
  (let ((jdks (hell-jdk-detect)))
    (hell-jdk-write jdks)
    (hell-sync--log "JDKs for projects: %s"
                        (if jdks
                            (mapconcat (lambda (jdk) (replace-regexp-in-string "\\`[A-Za-z0-9]+-" "" (car jdk)))
                                       jdks ", ")
                          "none found (set `hell-jdks' if yours are elsewhere)"))))

(add-hook 'hell-sync-functions #'hell-jvm-sync-detect-jdks)

(defun hell-jvm-doctor-jdks ()
  "Report the JDKs projects compile against. For doctor.el.
Yours (`hell-jdks') must each be a JDK of the release they're named
for; found ones are compared with what the last sync stored."
  (let* ((yours (bound-and-true-p hell-jdks))
         (jdks (or yours (hell-jdk-detect)))
         (runtimes (append (hell-jvm-lsp-runtimes jdks) nil)))
    (when yours
      (hell-doctor-info "Using your `hell-jdks'"))
    (dolist (runtime runtimes)
      (let* ((name (plist-get runtime :name))
             (home (plist-get runtime :path))
             (actual (hell-jdk-home-release home)))
        (if (and yours (not (equal actual name)))
            (hell-doctor-error :topic 'jdk "`hell-jdks' names %s for %s, which %s" name (abbreviate-file-name home)
                                   (if actual (format "is a %s" actual) "isn't a JDK (no release file)"))
          (hell-doctor-ok "JDK %s: %s%s" name (abbreviate-file-name home)
                              (if (eq (plist-get runtime :default) t) " (the default)" "")))))
    (dolist (jdk (seq-difference jdks (hell-jvm-runtime-jdks jdks)))
      (hell-doctor-info "JDK %s: %s (newer than JDTLS %s knows; not offered to it)"
                            (car jdk) (abbreviate-file-name (cdr jdk)) hell-jvm-jdtls-version))
    (if (null jdks)
        (hell-doctor-info "No JDKs found for projects; set `hell-jdks' if yours are elsewhere")
      (unless yours
        (when-let* ((unseen (seq-remove (lambda (jdk) (member jdk (hell-jdk-read))) jdks)))
          (hell-doctor-warn :topic 'jdk "%s not known to JDTLS yet; `bin/hell sync' stores them"
                                (mapconcat #'car unseen ", ")))))))

;;; Spring Boot's language server (+spring) --------------------------------------

(defun hell-jvm-sync-install-spring ()
  "Install the pinned Spring Boot language server and its JDTLS extensions.
For `hell-sync-functions', with +spring. Only its language server
and the jars JDTLS loads are kept from the VSIX (83MB, mostly VS Code's)."
  (if (hell-jvm-spring-installed-p)
      (hell-sync--log "Spring Boot Tools %s is installed" hell-jvm-spring-version)
    (hell-sync--log "Downloading Spring Boot Tools %s (83MB)..." hell-jvm-spring-version)
    (make-directory hell-jvm-spring-dir t)
    (hell-sync-install-zip
     "Spring Boot Tools" hell-jvm-spring-url hell-jvm-spring-sha256
     hell-jvm-spring-dir (hell-jvm-spring--marker)
     (lambda (stage)
       (let ((server (expand-file-name "language-server" hell-jvm-spring-dir))
             (jars (expand-file-name "jars" hell-jvm-spring-dir)))
         (dolist (dir (list server jars))
           (when (file-directory-p dir) (delete-directory dir t)))
         (rename-file (expand-file-name "extension/language-server" stage) server)
         (make-directory jars)
         (dolist (jar hell-jvm-spring-extensions)
           (rename-file (expand-file-name (concat "extension/jars/" jar) stage)
                        (expand-file-name jar jars))))))
    (unless (hell-jvm-spring-installed-p)
      (error "Spring Boot Tools was unpacked, but its server or JDTLS extensions are missing from %s"
             (abbreviate-file-name hell-jvm-spring-dir)))
    (hell-sync--log "Spring Boot Tools %s installed (SHA-256 verified)" hell-jvm-spring-version)))

(when (modulep! +spring)
  (add-hook 'hell-sync-functions #'hell-jvm-sync-install-spring))

(defun hell-jvm-bundle-paths ()
  "JDTLS (with java-debug and the JUnit runner); with +spring, the Spring Boot
server; with +lombok, the
pinned Lombok jar. For `hell-bundle-functions'."
  (list hell-jvm-jdtls-dir
        (when (modulep! +spring) hell-jvm-spring-dir)
        (when (and (modulep! +lombok)
                   (equal hell-jvm-lombok-jar hell-jvm--default-lombok-jar))
          hell-jvm-lombok-jar)))

(add-hook 'hell-bundle-functions #'hell-jvm-bundle-paths)

;;; Lombok (+lombok) -----------------------------------------------------------

(defun hell-jvm-sync-install-lombok ()
  "Download the pinned Lombok jar if it's missing or corrupt, and check it.
For `hell-sync-functions'. A jar of your own
\(`hell-jvm-lombok-jar') is only checked for existence."
  (cond
   ((hell-jvm-lombok-jar-valid-p)
    (hell-sync--log "Lombok %s is installed"
                        (if (equal hell-jvm-lombok-jar hell-jvm--default-lombok-jar)
                            hell-jvm-lombok-version
                          (abbreviate-file-name hell-jvm-lombok-jar))))
   ((not (equal hell-jvm-lombok-jar hell-jvm--default-lombok-jar))
    (error "+lombok: `hell-jvm-lombok-jar' is %s, which doesn't exist"
           (abbreviate-file-name hell-jvm-lombok-jar)))
   (t
    (hell-sync--log "Downloading Lombok %s..." hell-jvm-lombok-version)
    (hell-sync-download-verified hell-jvm-lombok-url hell-jvm-lombok-jar
                                     hell-jvm-lombok-sha256 "Lombok")
    (hell-sync--log "Lombok %s installed (SHA-256 verified)" hell-jvm-lombok-version))))

(when (modulep! +lombok)
  (add-hook 'hell-sync-functions #'hell-jvm-sync-install-lombok))

;;; java-debug (:tools debugger) -------------------------------------------------

(defun hell-jvm-sync-install-java-debug ()
  "Install the pinned java-debug bundle into JDTLS, if it isn't there.
Runs after JDTLS's install. It is safe to run every sync: it only
downloads when the bundle isn't the pinned release."
  (cond
   ((hell-jvm-java-debug-jar-valid-p)
    (hell-sync--log "java-debug %s is installed" hell-jvm-java-debug-version))
   ((not (file-directory-p (file-name-directory hell-jvm-java-debug-jar)))
    (error "JDTLS's bundle directory %s doesn't exist; is JDTLS installed?"
           (abbreviate-file-name (file-name-directory hell-jvm-java-debug-jar))))
   (t
    (hell-sync--log "Installing java-debug %s..."
                        hell-jvm-java-debug-version)
    (hell-sync-download-verified hell-jvm-java-debug-url hell-jvm-java-debug-jar
                                     hell-jvm-java-debug-sha256 "java-debug")
    (hell-sync--log "java-debug %s installed (SHA-256 verified)" hell-jvm-java-debug-version))))
