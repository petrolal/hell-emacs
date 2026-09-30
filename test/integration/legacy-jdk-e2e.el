;;; legacy-jdk-e2e.el --- End-to-end check of legacy JDK 8/11 projects -*- lexical-binding: t; -*-

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

;; Phase 12.3's legacy targets: a Java 8 Maven project and a Java 11
;; Gradle one import, build, test and debug against their own JDK, while
;; JDTLS itself runs on a newer one.
;;
;; It needs a synced profile with :lang java, :tools build and :tools
;; debugger, and the project's JDK among the JDKs sync found (check with
;; `bin/hellmacs doctor'; `hellmacs-jdk-roots' adds places to look).
;; Network access on the first run: the build fetches its tools and
;; dependencies.
;;
;;   HELLMACS_E2E_FIXTURE=legacy-8 JAVA_HOME=/path/to/jdk8 \
;;     emacs --batch -l early-init.el -f hellmacs-start \
;;           -l test/integration/legacy-jdk-e2e.el
;;
;;   HELLMACS_E2E_FIXTURE=legacy-11-gradle \
;;     emacs --batch -l early-init.el -f hellmacs-start \
;;           -l test/integration/legacy-jdk-e2e.el
;;
;; The command-line build runs on the JDK your shell gives it, as in a
;; terminal: for Maven, JAVA_HOME must be the project's JDK 8; Gradle picks
;; the JDK 11 its toolchain asks for itself (it must find one: install it
;; where Gradle looks, or list it in org.gradle.java.installations.paths).
;; The fixture is copied to a temporary directory first (HELLMACS_E2E_KEEP=1
;; keeps the copy). Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar e2e--fixture (or (getenv "HELLMACS_E2E_FIXTURE") "legacy-8"))

(defconst e2e--legacy-fixtures
  '(("legacy-8"
     :release "JavaSE-1.8" :java-version "1.8." :class-version 52
     :source "src/main/java/com/example/legacy/LegacyApp.java"
     :test "src/test/java/com/example/legacy/LegacyAppTest.java"
     :class "target/classes/com/example/legacy/LegacyApp.class"
     :newer-api "boolean blank = \"x\".isBlank(); // Java 11\n"
     :success "BUILD SUCCESS")
    ("legacy-11-gradle"
     :release "JavaSE-11" :java-version "11." :class-version 55
     :source "src/main/java/com/example/legacy11/Legacy11App.java"
     :test "src/test/java/com/example/legacy11/Legacy11AppTest.java"
     :class "build/classes/java/main/com/example/legacy11/Legacy11App.class"
     :newer-api "String formatted = \"%s\".formatted(\"x\"); // Java 15\n"
     :success "BUILD SUCCESSFUL"))
  "Each fixture: its release, what it compiles to, and a call its JDK lacks.")

(defun e2e--class-version (file)
  "The class file version (52 for Java 8) of the compiled class FILE, or nil."
  (when (file-exists-p file)
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally file nil 0 8)
      (+ (* 256 (aref (buffer-string) 6)) (aref (buffer-string) 7)))))

(defun e2e--errors ()
  "The flymake errors in this buffer."
  (cl-remove-if-not (lambda (d) (eq (flymake-diagnostic-type d) :error)) (flymake-diagnostics)))

(defun e2e--legacy-checks (proj spec)
  (let* ((jdk (cdr (assoc (plist-get spec :release) (or hellmacs-jdks (hellmacs-jdk-read)))))
         (source (expand-file-name (plist-get spec :source) proj))
         (buf (find-file-noselect source)))
    (switch-to-buffer buf)
    (e2e--say "\n== 12.3 import (%s, %s)" e2e--fixture (plist-get spec :release))
    (unless (e2e-check (format "a %s JDK is among the JDKs sync found" (plist-get spec :release))
              jdk)
      (e2e--say "     install one, or add where it is to `hellmacs-jdk-roots', then sync")
      (e2e--say "\n1 FAILED")
      (kill-emacs 1))
    (e2e-check "JDTLS starts and imports the project"
      (e2e-add-project proj)
      (lsp)
      (e2e--wait (lambda () (eq (hellmacs-jvm-state proj) 'ready)) 400))
    (e2e-check "JDTLS runs on a JDK it supports, not the project's"
      (let ((major (hellmacs-jdk-home-major (hellmacs-jvm-jdtls-java-home))))
        (e2e--say "    JDTLS's JDK: %s" major)
        (and major (>= major hellmacs-jvm-jdtls-java-min))))
    (e2e-check (format "the project compiles against its own JDK (%s)" (abbreviate-file-name jdk))
      (let* ((key "org.eclipse.jdt.ls.core.vm.location")
             (settings (lsp-send-execute-command "java.project.getSettings"
                                                 (vector (lsp--path-to-uri proj) (vector key))))
             (vm (if (hash-table-p settings) (gethash key settings)
                   (plist-get settings (intern (concat ":" key))))))
        (e2e--say "    project JDK: %s" vm)
        (and vm (equal (file-truename (directory-file-name vm))
                       (file-truename (directory-file-name jdk))))))
    (with-current-buffer buf
      (e2e-check "no errors in the project's own code"
        (e2e--wait (lambda () (flymake-running-backends)) 30)
        (accept-process-output nil 5)
        (null (e2e--errors)))
      (e2e-check "a call its JDK doesn't have is an error"
        (e2e--position-after "greet(String name) {\n")
        (insert (plist-get spec :newer-api))
        (save-buffer)
        (prog1 (e2e--wait (lambda () (e2e--errors)) 60)
          (revert-buffer t t t)
          (goto-char (point-min))
          (search-forward (plist-get spec :newer-api))
          (replace-match "")
          (save-buffer)
          (e2e--wait (lambda () (null (e2e--errors))) 60))))

    (e2e--say "\n== build and test")
    (with-current-buffer buf
      (e2e-check "compile-command is the project's wrapper"
        (string-match-p "\\./\\(mvnw\\|gradlew\\)" compile-command))
      (e2e-check "the build passes"
        (let ((msg (e2e--compile-and-wait proj)))
          (and msg (string-match-p "finished" msg))))
      (e2e-check (format "it compiled for its release (class file version %d)" (plist-get spec :class-version))
        (let ((version (e2e--class-version (expand-file-name (plist-get spec :class) proj))))
          (e2e--say "    class file version: %s" version)
          (eql version (plist-get spec :class-version)))))
    (with-current-buffer (find-file-noselect (expand-file-name (plist-get spec :test) proj))
      (e2e-check "the test at point runs and passes"
        (e2e--position-after "@Test")
        (forward-line 1)
        (hellmacs-forge-test-at-point)
        (e2e--wait (lambda () (not (get-buffer-process (compilation-find-buffer)))) 300)
        (with-current-buffer (compilation-find-buffer)
          (save-excursion (goto-char (point-min))
                          (re-search-forward (regexp-quote (plist-get spec :success)) nil t)))))

    (e2e--say "\n== debug")
    (switch-to-buffer buf)
    (goto-char (point-min)) (search-forward "System.out.println") (beginning-of-line)
    (let ((line (line-number-at-pos)))
      (dap-breakpoint-add)
      (e2e-check "a launch stops at the breakpoint"
        (call-interactively #'dap-java-debug)
        (e2e--wait (lambda () (let ((s (dap--cur-session)))
                                (and s (dap--debug-session-active-frame s))))
                   120)
        (= line (gethash "line" (dap--debug-session-active-frame (dap--cur-session)))))
      (e2e-check (format "the program runs on its own JDK (java.version %s...)" (plist-get spec :java-version))
        (let* ((s (dap--cur-session)) result)
          (dap--send-message
           (dap--make-request "evaluate"
                              (list :expression "System.getProperty(\"java.version\")" :context "repl"
                                    :frameId (gethash "id" (dap--debug-session-active-frame s))))
           (lambda (resp) (setq result (gethash "result" (gethash "body" resp))))
           s)
          (e2e--wait (lambda () result) 30)
          (e2e--say "    java.version: %s" result)
          (and result (string-prefix-p (plist-get spec :java-version) (string-trim result "\"" "\"")))))
      (e2e-check "it runs to the end"
        (call-interactively #'hellmacs-debug-continue)
        (e2e--wait (lambda () (not (dap--session-running (dap--cur-session)))) 60)
        t)
      (dap-breakpoint-delete-all))))

(let ((spec (cdr (assoc e2e--fixture e2e--legacy-fixtures))))
  (unless spec
    (e2e--say "HELLMACS_E2E_FIXTURE must be one of: %s"
              (mapconcat #'car e2e--legacy-fixtures ", "))
    (kill-emacs 1))
  (let ((proj (e2e-copy-fixture (concat "java/" e2e--fixture))))
    (e2e--say "Hellmacs legacy JDK end-to-end, fixture %s in %s" e2e--fixture proj)
    (e2e--legacy-checks proj spec)))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

(provide 'legacy-jdk-e2e)
;;; legacy-jdk-e2e.el ends here
