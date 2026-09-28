;;; lang/java/cli.el -*- lexical-binding: t; -*-

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


;; Extends bin/hellmacs: `sync' also installs JDTLS (with its java-debug
;; bundle and JUnit runner), so the first Java file doesn't wait for a
;; download, and with +lombok, the pinned Lombok jar.

;; Paths and the pinned Lombok release, once, now: after your init.el (so
;; your settings win) and before any sync step runs.
(hellmacs-module-load "+paths")


(defvar hellmacs-jvm-install-server-on-sync t
  "Whether `bin/hellmacs sync' installs JDTLS when it's missing.")

(defun hellmacs-jvm--install-jdtls ()
  "Install the pinned JDTLS into `hellmacs-jvm-jdtls-dir', replacing what's there.
Downloaded and checked (`hellmacs-sync-download-verified'), unpacked next
to the install (the same file system, so it moves into place whole), and
only then swapped in; the marker is written last. Whatever else lived in
the directory (java-debug, the test runner) is installed again after."
  (unless (executable-find "tar") (error "tar is needed to install JDTLS"))
  (let* ((dir (directory-file-name hellmacs-jvm-jdtls-dir))
         (stage (progn (make-directory (file-name-directory dir) t)
                       (make-temp-file (concat dir "-stage") t)))
         (tarball (expand-file-name "jdtls.tar.gz" stage))
         (server (expand-file-name "server" stage)))
    (unwind-protect
        (progn
          (hellmacs-sync-download-verified hellmacs-jvm-jdtls-url tarball
                                           hellmacs-jvm-jdtls-sha256 "JDTLS")
          (make-directory server)
          (with-temp-buffer
            (unless (zerop (call-process "tar" nil t nil "-xzf" tarball "-C" server))
              (error "Unpacking JDTLS failed: %s" (buffer-string))))
          (make-directory (expand-file-name "bundles" server)) ; java-debug goes here
          (when (file-directory-p dir) (delete-directory dir t))
          (rename-file server dir)
          (hellmacs-marker-write (hellmacs-jvm--jdtls-marker) hellmacs-jvm-jdtls-sha256))
      (delete-directory stage t))))

(defun hellmacs-jvm-sync-install-server ()
  "Install the pinned JDTLS and JUnit runner if they aren't. For `hellmacs-sync-functions'."
  (when hellmacs-jvm-install-server-on-sync
    (if (hellmacs-jvm-jdtls-installed-p)
        (hellmacs-sync--log "JDTLS %s is installed" hellmacs-jvm-jdtls-version)
      (hellmacs-sync--log "Downloading JDTLS %s (49MB)..." hellmacs-jvm-jdtls-version)
      (hellmacs-jvm--install-jdtls)
      (hellmacs-sync--log "JDTLS %s installed (SHA-256 verified)" hellmacs-jvm-jdtls-version))
    (unless (hellmacs-jvm-junit-runner-valid-p)
      (hellmacs-sync-download-verified hellmacs-jvm-junit-runner-url dap-java-test-runner
                                       hellmacs-jvm-junit-runner-sha256 "The JUnit runner")
      (hellmacs-sync--log "JUnit runner %s installed (SHA-256 verified)"
                          hellmacs-jvm-junit-runner-version))
    (when (modulep! :tools debugger)
      (hellmacs-jvm-sync-install-java-debug))))

(add-hook 'hellmacs-sync-functions #'hellmacs-jvm-sync-install-server)

(defun hellmacs-jvm--java-major (home)
  "The major release of the JDK in HOME: its release file's, else `java -version''s."
  (or (hellmacs-jdk-home-major home)
      (let ((java (expand-file-name "bin/java" home)))
        (when (file-executable-p java)
          (with-temp-buffer
            (when (ignore-errors (zerop (call-process java nil t nil "-version")))
              (goto-char (point-min))
              (when (re-search-forward "version \"\\([0-9.]+\\)" nil t)
                (hellmacs-jdk--major (match-string 1)))))))))

(defun hellmacs-jvm-doctor-jdtls-jdk ()
  "Check the JDK that runs JDTLS. For doctor.el.
Says which it is, and why JAVA_HOME's or the PATH's was passed over."
  (let* ((range (format "%d to %d" hellmacs-jvm-jdtls-java-min hellmacs-jvm-jdtls-java-max))
         (fits (lambda (major) (and major (<= hellmacs-jvm-jdtls-java-min major hellmacs-jvm-jdtls-java-max))))
         (home (hellmacs-jvm-jdtls-java-home))
         (major (and home (hellmacs-jvm--java-major home))))
    (cond
     (hellmacs-jvm-java-home
      (if (funcall fits major)
          (hellmacs-doctor-ok "JDK %d for JDTLS: %s (`hellmacs-jvm-java-home')" major (abbreviate-file-name home))
        (hellmacs-doctor-error "`hellmacs-jvm-java-home' is %s; JDTLS %s runs on %s"
                               (if major (format "JDK %d" major) (format "%s, not a JDK" (abbreviate-file-name home)))
                               hellmacs-jvm-jdtls-version range)))
     ((null home)
      (hellmacs-doctor-error "No JDK %s to run JDTLS %s; install one (then `bin/hellmacs sync'), or set `hellmacs-jvm-java-home'"
                             range hellmacs-jvm-jdtls-version))
     (t
      (hellmacs-doctor-ok "JDK %d for JDTLS: %s" major (abbreviate-file-name home))
      (pcase-dolist (`(,label . ,other)
                     (list (cons "JAVA_HOME's" (let ((h (getenv "JAVA_HOME"))) (and h (not (string-empty-p h)) h)))
                           (cons "The PATH's" (hellmacs-jvm--path-java-home))))
        (when (and other (not (equal (file-truename (directory-file-name (expand-file-name other)))
                                     (file-truename home))))
          (let ((other-major (hellmacs-jvm--java-major other)))
            (unless (funcall fits other-major)
              (hellmacs-doctor-info "%s JDK %s can't run JDTLS %s (it runs on %s); using JDK %d instead"
                                    label (or other-major "(unknown release)") hellmacs-jvm-jdtls-version range major))))))))
  (unless (getenv "JAVA_HOME")
    (hellmacs-doctor-info "JAVA_HOME isn't set")))

;;; JDKs for projects (Phase 12.3) ---------------------------------------------

(defun hellmacs-jvm-sync-detect-jdks ()
  "Find the JDKs on this machine and store them for JDTLS. For `hellmacs-sync-functions'.
Stored rather than looked for at startup, which would cost startup time;
config.el reads them when lsp-java loads."
  (let ((jdks (hellmacs-jdk-detect)))
    (hellmacs-jdk-write jdks)
    (hellmacs-sync--log "JDKs for projects: %s"
                        (if jdks
                            (mapconcat (lambda (jdk) (replace-regexp-in-string "\\`[A-Za-z0-9]+-" "" (car jdk)))
                                       jdks ", ")
                          "none found (set `hellmacs-jdks' if yours are elsewhere)"))))

(add-hook 'hellmacs-sync-functions #'hellmacs-jvm-sync-detect-jdks)

(defun hellmacs-jvm-doctor-jdks ()
  "Report the JDKs projects compile against. For doctor.el.
Yours (`hellmacs-jdks') must each be a JDK of the release they're named
for; found ones are compared with what the last sync stored."
  (let* ((yours (bound-and-true-p hellmacs-jdks))
         (jdks (or yours (hellmacs-jdk-detect)))
         (default-home (hellmacs-jvm-jdtls-java-home))
         (runtimes (append (hellmacs-jdk-lsp-runtimes jdks default-home) nil)))
    (when yours
      (hellmacs-doctor-info "Using your `hellmacs-jdks'"))
    (dolist (runtime runtimes)
      (let* ((name (plist-get runtime :name))
             (home (plist-get runtime :path))
             (actual (hellmacs-jdk-home-release home)))
        (if (and yours (not (equal actual name)))
            (hellmacs-doctor-error "`hellmacs-jdks' names %s for %s, which %s" name (abbreviate-file-name home)
                                   (if actual (format "is a %s" actual) "isn't a JDK (no release file)"))
          (hellmacs-doctor-ok "JDK %s: %s%s" name (abbreviate-file-name home)
                              (if (eq (plist-get runtime :default) t) " (the default)" "")))))
    (if (null jdks)
        (hellmacs-doctor-info "No JDKs found for projects; set `hellmacs-jdks' if yours are elsewhere")
      (unless yours
        (when-let* ((unseen (seq-remove (lambda (jdk) (member jdk (hellmacs-jdk-read))) jdks)))
          (hellmacs-doctor-warn "%s not known to JDTLS yet; `bin/hellmacs sync' stores them"
                                (mapconcat #'car unseen ", ")))))))

(defun hellmacs-jvm-bundle-paths ()
  "JDTLS (with java-debug and the JUnit runner) and, with +lombok, the
pinned Lombok jar. For `hellmacs-bundle-functions'."
  (list hellmacs-jvm-jdtls-dir
        (when (and (modulep! +lombok)
                   (equal hellmacs-jvm-lombok-jar hellmacs-jvm--default-lombok-jar))
          hellmacs-jvm-lombok-jar)))

(add-hook 'hellmacs-bundle-functions #'hellmacs-jvm-bundle-paths)

;;; Lombok (+lombok) -----------------------------------------------------------

(defun hellmacs-jvm-sync-install-lombok ()
  "Download the pinned Lombok jar if it's missing or corrupt, and check it.
For `hellmacs-sync-functions'. A jar of your own
\(`hellmacs-jvm-lombok-jar') is only checked for existence."
  (cond
   ((hellmacs-jvm-lombok-jar-valid-p)
    (hellmacs-sync--log "Lombok %s is installed"
                        (if (equal hellmacs-jvm-lombok-jar hellmacs-jvm--default-lombok-jar)
                            hellmacs-jvm-lombok-version
                          (abbreviate-file-name hellmacs-jvm-lombok-jar))))
   ((not (equal hellmacs-jvm-lombok-jar hellmacs-jvm--default-lombok-jar))
    (error "+lombok: `hellmacs-jvm-lombok-jar' is %s, which doesn't exist"
           (abbreviate-file-name hellmacs-jvm-lombok-jar)))
   (t
    (hellmacs-sync--log "Downloading Lombok %s..." hellmacs-jvm-lombok-version)
    (hellmacs-sync-download-verified hellmacs-jvm-lombok-url hellmacs-jvm-lombok-jar
                                     hellmacs-jvm-lombok-sha256 "Lombok")
    (hellmacs-sync--log "Lombok %s installed (SHA-256 verified)" hellmacs-jvm-lombok-version))))

(when (modulep! +lombok)
  (add-hook 'hellmacs-sync-functions #'hellmacs-jvm-sync-install-lombok))

;;; java-debug (:tools debugger) -------------------------------------------------

(defun hellmacs-jvm-sync-install-java-debug ()
  "Install the pinned java-debug bundle into JDTLS, if it isn't there.
Runs after JDTLS's install. It is safe to run every sync: it only
downloads when the bundle isn't the pinned release."
  (cond
   ((hellmacs-jvm-java-debug-jar-valid-p)
    (hellmacs-sync--log "java-debug %s is installed" hellmacs-jvm-java-debug-version))
   ((not (file-directory-p (file-name-directory hellmacs-jvm-java-debug-jar)))
    (error "JDTLS's bundle directory %s doesn't exist; is JDTLS installed?"
           (abbreviate-file-name (file-name-directory hellmacs-jvm-java-debug-jar))))
   (t
    (hellmacs-sync--log "Installing java-debug %s..."
                        hellmacs-jvm-java-debug-version)
    (hellmacs-sync-download-verified hellmacs-jvm-java-debug-url hellmacs-jvm-java-debug-jar
                                     hellmacs-jvm-java-debug-sha256 "java-debug")
    (hellmacs-sync--log "java-debug %s installed (SHA-256 verified)" hellmacs-jvm-java-debug-version))))
