;;; lang/java/autoload.el -*- lexical-binding: t; -*-

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


(declare-function dap-java-run-test-method "ext:dap-java")
(declare-function dap-java-run-test-class "ext:dap-java")

;;;###autoload
(defun hell-jvm-run-test (what)
  "Run the JUnit test WHAT (`method' at point, or `class') with dap-java's runner.
Java's `hell-forge-test-run-function' under `:tools debugger'."
  (require 'dap-java)
  (call-interactively (if (eq what 'method) #'dap-java-run-test-method #'dap-java-run-test-class)))

(declare-function lsp-java-update-project-configuration "ext:lsp-java")

(defconst hell-jvm-build-files '("pom.xml" "build.gradle" "build.gradle.kts")
  "Files that define a Maven or Gradle project, nearest first.")

;;;###autoload
(defun hell-jvm-update-project-configuration ()
  "Re-import the build file (pom.xml, build.gradle) of the current project.
Works from any file in the project: lsp-java's own command only works
from the build file's buffer. JDTLS also does this by itself when a
build file is saved; this is for changes it missed."
  (interactive)
  (let* ((file (or buffer-file-name (user-error "Not visiting a file")))
         (build (if (member (file-name-nondirectory file) hell-jvm-build-files)
                    file
                  (seq-some (lambda (name)
                              (when-let* ((dir (locate-dominating-file file name)))
                                (expand-file-name name dir)))
                            hell-jvm-build-files))))
    (unless build
      (user-error "No pom.xml or build.gradle above %s" (abbreviate-file-name file)))
    (with-current-buffer (find-file-noselect build)
      (lsp-java-update-project-configuration))
    (message "Re-importing %s" (abbreviate-file-name build))))

;;; Spring Boot (+spring) ------------------------------------------------------------

;;;###autoload
(defconst hell-spring-language-ids
  '(("/\\(?:application\\|bootstrap\\)[^/]*\\.ya?ml\\'" . "spring-boot-properties-yaml")
    ("/\\(?:application\\|bootstrap\\)[^/]*\\.properties\\'" . "spring-boot-properties"))
  "Spring Boot's config files, as lsp-mode's (FILE-REGEXP . LANGUAGE-ID).
The Spring Boot server completes and checks properties in documents of
these language ids (VS Code's), not plain yaml or properties.")

;;;###autoload
(defun hell-spring-language-id (file)
  "The Spring Boot server's language id for FILE, or nil if FILE isn't a Spring config."
  (let ((path (concat "/" (file-name-nondirectory file))))
    (cdr (seq-find (lambda (entry) (string-match-p (car entry) path)) hell-spring-language-ids))))

;;;###autoload
(defun hell-spring-config-file-p (file)
  "Non-nil if FILE is a Spring Boot config: application*.yml/.yaml/.properties, bootstrap*."
  (and (hell-spring-language-id file) t))

(defconst hell-spring-ignored-notifications '("spring/index/updated")
  "Notifications the Spring Boot server sends for VS Code's own views.
spring/index/updated refreshes its Spring explorer; Emacs has none, and
lsp-mode would warn \"Unknown notification\" each time a file opens.")

;;;###autoload
(defun hell-spring-ignore-notifications (handlers)
  "Handle `hell-spring-ignored-notifications' in HANDLERS by doing nothing.
HANDLERS is an lsp-mode client's notification-handlers table; the ones
it has already are kept. Returns HANDLERS."
  (dolist (method hell-spring-ignored-notifications)
    (unless (gethash method handlers)
      (puthash method #'ignore handlers)))
  handlers)

(defconst hell-spring--skipped-dirs
  (append hell-ignored-dirs hell-build-output-dirs '("test"))
  "Directories never searched for profiles: build output, VCS, IDE state, and
test sources (src/test/resources isn't on the application's classpath).")

;; The run list asks for the profiles every time it opens: remembered per
;; project, with the time of each directory walked. Adding, removing or
;; renaming a file changes its directory's time, so while none changed
;; the answer holds, and checking takes a `stat' per directory, not a walk.

(defvar hell-spring--profile-cache (make-hash-table :test #'equal)
  "Project root -> (DIR-TIMES . PROFILES): its profiles, and the times of the
directories they were looked for in.")

(defvar hell-spring--profile-roots nil
  "The roots in `hell-spring--profile-cache', most recently used first.")

(defvar hell-spring-profile-cache-limit 16
  "How many projects' profiles are remembered.")

(defconst hell-spring--profile-file-regexp "\\`application-.+\\.\\(?:ya?ml\\|properties\\)\\'"
  "A profile's config file: application-NAME.yml, .yaml or .properties.")

(defun hell-spring--dir-time (dir)
  (file-attribute-modification-time (file-attributes dir)))

(defun hell-spring--walk-profiles (root)
  "(DIR-TIMES . PROFILE-FILES) under ROOT, skipping `hell-spring--skipped-dirs'.
Links to directories aren't followed."
  (let (times files)
    (cl-labels ((walk (dir)
                  (push (cons dir (hell-spring--dir-time dir)) times)
                  (dolist (entry (directory-files dir nil directory-files-no-dot-files-regexp t))
                    (let ((path (expand-file-name entry dir)))
                      (cond ((file-symlink-p path))
                            ((file-directory-p path)
                             (unless (member entry hell-spring--skipped-dirs)
                               (walk path)))
                            ((string-match-p hell-spring--profile-file-regexp entry)
                             (push entry files)))))))
      (walk (directory-file-name (expand-file-name root))))
    (cons times files)))

;;;###autoload
(defun hell-spring-discover-profiles (root)
  "The Spring profiles the project at ROOT has a config for, sorted.
From its application-NAME.yml/.yaml/.properties, in any module; `default'
is left out: it's active when no other profile is. Remembered until a
directory in the project changes (`hell-spring--profile-cache')."
  (let* ((root (directory-file-name (expand-file-name root)))
         (cached (gethash root hell-spring--profile-cache)))
    (setq hell-spring--profile-roots (cons root (delete root hell-spring--profile-roots)))
    (dolist (gone (nthcdr hell-spring-profile-cache-limit hell-spring--profile-roots))
      (remhash gone hell-spring--profile-cache))
    (setq hell-spring--profile-roots
          (seq-take hell-spring--profile-roots hell-spring-profile-cache-limit))
    (if (and cached
             (seq-every-p (pcase-lambda (`(,dir . ,time)) (equal (hell-spring--dir-time dir) time))
                          (car cached)))
        (copy-sequence (cdr cached))
      (pcase-let* ((`(,times . ,files) (hell-spring--walk-profiles root))
                   (profiles (sort (delete "default"
                                           (delete-dups
                                            (mapcar (lambda (file)
                                                      (substring (file-name-base file) (length "application-")))
                                                    files)))
                                   #'string<)))
        (puthash root (cons times profiles) hell-spring--profile-cache)
        (copy-sequence profiles)))))
