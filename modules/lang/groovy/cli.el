;;; lang/groovy/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Extends bin/hellmacs: `sync' builds groovy-language-server from its
;; pinned commit (see +paths.el), so the first Groovy file has a server.

(hellmacs-module-load "+paths")

(defvar hellmacs-groovy-build-server-on-sync t
  "Whether `bin/hellmacs sync' builds groovy-language-server when it isn't built.")

(defun hellmacs-groovy--build-java-home ()
  "A JDK the pinned Gradle runs on: JAVA_HOME's, else the newest sync found."
  (let ((range (hellmacs-jdk-gradle-daemon-range hellmacs-groovy-gradle-version)))
    (or (hellmacs-jdk-pick (delq nil (cons (let ((home (getenv "JAVA_HOME")))
                                             (and home (not (string-empty-p home)) home))
                                           (reverse (mapcar #'cdr (or (hellmacs-jdk-read) (hellmacs-jdk-detect))))))
                           (car range) (cdr range))
        (error "Building groovy-language-server needs a JDK %d to %d, for Gradle %s; none found"
               (car range) (cdr range) hellmacs-groovy-gradle-version))))

(defun hellmacs-groovy--gradle ()
  "The pinned Gradle's launcher, unpacked (checked by SHA-256) if it isn't yet."
  (let* ((spec (hellmacs-groovy-server-spec))
         (version (plist-get spec :gradle-version))
         (sha256 (plist-get spec :gradle-sha256))
         (marker (expand-file-name ".hellmacs-sha256" hellmacs-groovy-gradle-dir))
         (gradle (expand-file-name (format "gradle-%s/bin/gradle" version) hellmacs-groovy-gradle-dir)))
    (unless (and (file-executable-p gradle) (hellmacs-marker-current-p marker sha256))
      (hellmacs-sync--log "Downloading Gradle %s, to build groovy-language-server with..." version)
      (make-directory hellmacs-groovy-gradle-dir t)
      (hellmacs-sync-install-zip
       "Gradle" hellmacs-groovy-gradle-url sha256 hellmacs-groovy-gradle-dir marker
       (lambda (stage)
         (let ((dest (expand-file-name (format "gradle-%s" version) hellmacs-groovy-gradle-dir)))
           (when (file-directory-p dest) (delete-directory dest t))
           (rename-file (expand-file-name (format "gradle-%s" version) stage) dest))))
      (unless (file-executable-p gradle)
        (error "Gradle %s was unpacked, but %s isn't there" version (abbreviate-file-name gradle))))
    gradle))

(defun hellmacs-groovy--run (dir program &rest args)
  "Run PROGRAM with ARGS in DIR; return its output, or signal an error with it."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory dir)))
      (unless (zerop (apply #'call-process program nil t nil args))
        (error "`%s %s' failed: %s" (file-name-nondirectory program) (string-join args " ")
               (string-trim (buffer-string))))
      (string-trim (buffer-string)))))

(defun hellmacs-groovy--fetch-source (commit dir)
  "Fetch the server's source at COMMIT into DIR, and check it's that commit."
  (unless (executable-find "git") (error "git is needed to fetch groovy-language-server"))
  (make-directory dir t)
  (hellmacs-groovy--run dir "git" "init" "--quiet")
  (hellmacs-groovy--run dir "git" "remote" "add" "origin" hellmacs-groovy-server-url)
  (hellmacs-groovy--run dir "git" "fetch" "--quiet" "--depth" "1" "origin" commit)
  (hellmacs-groovy--run dir "git" "checkout" "--quiet" "FETCH_HEAD")
  (let ((head (hellmacs-groovy--run dir "git" "rev-parse" "HEAD")))
    (unless (equal head commit)
      (error "groovy-language-server fetched %s, not the pinned %s; not built" head commit))))

(defun hellmacs-groovy--mirror-init-script (dir)
  "An init script in DIR sending the build's repositories to their mirrors, or nil.
Only when `hellmacs-mirrors' has one for Maven Central or the plugin portal."
  (let* ((central "https://repo.maven.apache.org/maven2/")
         (portal "https://plugins.gradle.org/m2/")
         (rewrites (seq-filter (lambda (r) (not (equal (car r) (cdr r))))
                               (list (cons central (hellmacs-net-rewrite central))
                                     (cons portal (hellmacs-net-rewrite portal))))))
    (when rewrites
      (let ((file (expand-file-name "hellmacs-mirrors.gradle" dir))
            (swap (mapconcat (pcase-lambda (`(,from . ,to))
                               (format "        if (repo instanceof MavenArtifactRepository && repo.url.toString() == '%s') { repo.url = '%s' }\n"
                                       from to))
                             rewrites "")))
        (with-temp-file file
          (insert "// Written by Hellmacs: the build's repositories, through `hellmacs-mirrors'.\n"
                  "def mirror = { repos -> repos.configureEach { repo ->\n" swap "    } }\n"
                  "beforeSettings { settings -> mirror(settings.pluginManagement.repositories) }\n"
                  "allprojects { mirror(repositories) }\n"))
        file))))

(defun hellmacs-groovy--build (src)
  "Build the server in SRC with the pinned Gradle; return the built jar."
  (let* ((gradle (hellmacs-groovy--gradle))
         (init (hellmacs-groovy--mirror-init-script src))
         (process-environment
          (append (list (concat "JAVA_HOME=" (hellmacs-groovy--build-java-home))
                        ;; Its own: none of your init scripts or properties.
                        (concat "GRADLE_USER_HOME=" (expand-file-name "groovy-gradle/" hellmacs-cache-dir))
                        (concat "GRADLE_OPTS=" (string-join (hellmacs-net-jvm-options) " ")))
                  process-environment)))
    (make-directory (expand-file-name "gradle" src) t)
    (copy-file (plist-get (hellmacs-groovy-server-spec) :verification-metadata)
               (expand-file-name "gradle/verification-metadata.xml" src) t)
    (apply #'hellmacs-groovy--run src gradle
           `("--no-daemon" "--console=plain" "-q" ,@(and init (list "--init-script" init)) "shadowJar"))
    (or (car (file-expand-wildcards (expand-file-name "build/libs/*-all.jar" src)))
        (error "The groovy-language-server build made no jar"))))

(defun hellmacs-groovy-sync-install-server ()
  "Build and install groovy-language-server, unless the pinned commit's is.
For `hellmacs-sync-functions'."
  (when hellmacs-groovy-build-server-on-sync
    (let ((commit (plist-get (hellmacs-groovy-server-spec) :commit)))
      (if (hellmacs-groovy-server-installed-p)
          (hellmacs-sync--log "groovy-language-server %s is built" (substring commit 0 7))
        (when hellmacs-net-offline
          (error "Offline install: groovy-language-server isn't built, and the bundle doesn't carry it"))
        (hellmacs-sync--log "Building groovy-language-server %s (a few minutes, the first time)..."
                            (substring commit 0 7))
        (let ((tmp (make-temp-file "hellmacs-groovy" t)))
          (unwind-protect
              (with-hellmacs-network
                ;; Named so: the jar is named after the checkout's directory.
                (let ((src (expand-file-name "groovy-language-server" tmp)))
                  (hellmacs-groovy--fetch-source commit src)
                  (let ((jar (hellmacs-groovy--build src))
                        (part (concat hellmacs-groovy-server-jar ".part")))
                    (make-directory hellmacs-groovy-server-dir t)
                    (copy-file jar part t)
                    (rename-file part hellmacs-groovy-server-jar t)
                    ;; Written last: without it the jar isn't taken for the pinned one.
                    (hellmacs-marker-write (hellmacs-groovy--server-marker) commit))))
            (delete-directory tmp t)))
        (hellmacs-sync--log "groovy-language-server %s built (commit and dependencies checked)"
                            (substring commit 0 7))))))

(add-hook 'hellmacs-sync-functions #'hellmacs-groovy-sync-install-server)

;; Builds, and the classpath the server gets, run on a JDK their Gradle
;; runs on, chosen among the JDKs sync found (`hellmacs-jdk-gradle-environment').
;; :lang java finds them; without it, this module does.
(defun hellmacs-groovy-sync-detect-jdks ()
  "Find the JDKs on this machine and store them. For `hellmacs-sync-functions'."
  (let ((jdks (hellmacs-jdk-detect)))
    (hellmacs-jdk-write jdks)
    (hellmacs-sync--log "JDKs found: %s"
                        (if jdks (mapconcat #'car jdks ", ") "none (set JAVA_HOME)"))))

(unless (modulep! :lang java)
  (add-hook 'hellmacs-sync-functions #'hellmacs-groovy-sync-detect-jdks -10))

(defun hellmacs-groovy-bundle-paths ()
  "The built server (not the Gradle it was built with). For `hellmacs-bundle-functions'."
  (list hellmacs-groovy-server-jar (hellmacs-groovy--server-marker)))

(add-hook 'hellmacs-bundle-functions #'hellmacs-groovy-bundle-paths)

;;; lang/groovy/cli.el ends here
