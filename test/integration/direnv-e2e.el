;;; direnv-e2e.el --- End-to-end check of per-project environments -*- lexical-binding: t; -*-

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

;; Phase 12.3's per-project environments (:tools direnv). Two projects:
;; the legacy-8 fixture with an .envrc that sets JAVA_HOME to a JDK 8 and
;; MAVEN_OPTS, and maven-demo without one. What's started from each
;; project's buffers -- Maven, JDTLS -- must get that project's
;; environment, and switching buffers switches it.
;;
;; It needs direnv on the PATH, a synced profile with :lang java, :tools
;; build and :tools direnv, a JDK 8 among the JDKs sync found, and network
;; access on the first run (the Maven wrapper fetches Maven):
;;
;;   emacs --batch -l early-init.el -f hellmacs-start -l test/integration/direnv-e2e.el
;;
;; Run it inside a throwaway XDG_*_HOME, so `direnv allow' records the
;; fixture there. The fixtures are copied to temporary directories, deleted
;; at exit (HELLMACS_E2E_KEEP=1 keeps them). Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defun e2e--run (dir command)
  "Run shell COMMAND with `compile' from the current buffer, in DIR; return its output."
  (let ((default-directory dir) output)
    (let ((hook (lambda (buf _) (setq output (with-current-buffer buf (buffer-string))))))
      (add-hook 'compilation-finish-functions hook)
      (unwind-protect
          (progn (compile command)
                 (e2e--wait (lambda () output) 300)
                 output)
        (remove-hook 'compilation-finish-functions hook)))))

(defun e2e--maven-java (output)
  "The \"Java version\" `mvn -v' printed in OUTPUT, or nil."
  (and output (string-match "^Java version: \\([^,\n]+\\)" output) (match-string 1 output)))

;; `emacs --batch -f hellmacs-start' never runs `after-init-hook', so Hellmacs'
;; startup never ends and the first-file hooks (envrc's among them) never
;; arm. End it as a real session does.
(unless hellmacs-init-time
  (run-hooks 'after-init-hook))

(let* ((jdk8 (cdr (assoc "JavaSE-1.8" (hellmacs-jdk-read))))
       (legacy (e2e-copy-fixture "java/legacy-8"))
       (demo (e2e-copy-fixture "java/maven-demo"))
       (legacy-src (expand-file-name "src/main/java/com/example/legacy/LegacyApp.java" legacy))
       (demo-src (expand-file-name "src/main/java/dev/hellmacs/demo/App.java" demo)))
  (e2e--say "Hellmacs per-project environments end-to-end, in %s and %s" legacy demo)
  (unless (and jdk8 (executable-find "direnv"))
    (e2e--say "  FAIL  needs direnv on the PATH and a JDK 8 among the JDKs sync found")
    (kill-emacs 1))
  (with-temp-file (expand-file-name ".envrc" legacy)
    (insert (format "export JAVA_HOME=%s\nexport MAVEN_OPTS=-Dhellmacs.envrc=legacy-8\n" jdk8)))
  (let ((default-directory legacy))
    (call-process "direnv" nil nil nil "allow" "."))

  (e2e--say "\n== 12.3 :tools direnv")
  (let ((legacy-buf (find-file-noselect legacy-src))
        (demo-buf nil))
    (with-current-buffer legacy-buf
      (e2e-check "envrc is on in the project's buffer, from its .envrc"
        (and (bound-and-true-p envrc-mode)
             (e2e--wait (lambda () (equal (getenv "JAVA_HOME") jdk8)) 30)))
      (e2e-check "and only there: Emacs' own environment is unchanged"
        (not (equal (getenv-internal "JAVA_HOME" (default-value 'process-environment)) jdk8)))
      (e2e-check "Maven started from the Java 8 project runs on its JDK 8, with its MAVEN_OPTS"
        (let ((out (e2e--run legacy "echo \"MAVEN_OPTS=$MAVEN_OPTS\"; ./mvnw -B -v")))
          (e2e--say "    Maven's Java: %s" (e2e--maven-java out))
          (and (string-prefix-p "1.8" (or (e2e--maven-java out) ""))
               (string-match-p "^MAVEN_OPTS=-Dhellmacs.envrc=legacy-8$" out)))))

    (setq demo-buf (find-file-noselect demo-src))
    (with-current-buffer demo-buf
      (e2e-check "Maven started from the other project runs on another JDK, without that MAVEN_OPTS"
        (let ((out (e2e--run demo "echo \"MAVEN_OPTS=$MAVEN_OPTS\"; ./mvnw -B -v")))
          (e2e--say "    Maven's Java: %s" (e2e--maven-java out))
          (and (e2e--maven-java out)
               (not (string-prefix-p "1.8" (e2e--maven-java out)))
               (string-match-p "^MAVEN_OPTS=$" out)))))

    (with-current-buffer legacy-buf
      (e2e-check "back in the Java 8 project, Maven is on JDK 8 again"
        (string-prefix-p "1.8" (or (e2e--maven-java (e2e--run legacy "./mvnw -B -v")) "")))
      (e2e-check "its build (C-x p c) passes on JDK 8"
        (let ((msg (e2e--compile-and-wait legacy)))
          (and msg (string-match-p "finished" msg))))
      (e2e-check "JDTLS started from it still runs on a JDK it supports, not the project's 8"
        (e2e-add-project legacy)
        (lsp)
        (and (e2e--wait (lambda () (eq (hellmacs-jvm-state legacy) 'ready)) 400)
             (let* ((proc (lsp--workspace-proc (car (lsp-workspaces))))
                    (java (car (process-command proc)))
                    (major (hellmacs-jdk-home-major
                            (file-name-directory (directory-file-name (file-name-directory java))))))
               (e2e--say "    JDTLS's java: %s (JDK %s)" java major)
               (and major (<= hellmacs-jvm-jdtls-java-min major hellmacs-jvm-jdtls-java-max)))))))
  (unless (getenv "HELLMACS_E2E_KEEP")
    (dolist (dir (list legacy demo))
      (delete-directory (file-name-directory (directory-file-name dir)) t))))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; direnv-e2e.el ends here
