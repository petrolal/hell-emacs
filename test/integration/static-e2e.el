;;; static-e2e.el --- End-to-end checks for :checkers static (Phase 12.6) -*- lexical-binding: t; -*-

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

;; Drives :checkers static against real Checkstyle, PMD and SpotBugs runs,
;; and with +sonarlint a real SonarLint beside a real JDTLS. Unlike
;; `bin/hellmacs test' it needs a synced profile with :checkers static and
;; (:lang java), a JDK 17+ for Gradle, and network access on the first run
;; (Gradle fetches the plugins).
;;
;;   bin/hellmacs sync        # with :tools lsp build, :lang java and
;;                            # (:checkers static +sonarlint) in your init.el
;;   JAVA_HOME=/path/to/jdk-21 \
;;     emacs --batch -l early-init.el -l init.el \
;;           -l test/integration/static-e2e.el
;;
;; test/fixtures/java/gradle-demo is copied to a temporary directory and
;; given the three Gradle plugins, a Checkstyle configuration and a class
;; with known problems; the copy is deleted at exit (HELLMACS_E2E_KEEP=1
;; keeps it). Run it inside a throwaway XDG_*_HOME/HELLMACSDIR to leave
;; your own setup alone. Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defconst e2e--static-plugins "plugins {
    id 'application'
    id 'checkstyle'
    id 'pmd'
    id 'com.github.spotbugs' version '6.5.12'
}

checkstyle { ignoreFailures = true }
pmd { ignoreFailures = true; ruleSets = ['category/java/bestpractices.xml', 'category/java/errorprone.xml'] }
spotbugs { ignoreFailures = true }
tasks.withType(com.github.spotbugs.snom.SpotBugsTask).configureEach {
    reports { xml { required = true }; html { required = false } }
}")

(defconst e2e--static-checkstyle "<?xml version=\"1.0\"?>
<!DOCTYPE module PUBLIC \"-//Checkstyle//DTD Checkstyle Configuration 1.3//EN\" \"https://checkstyle.org/dtds/configuration_1_3.dtd\">
<module name=\"Checker\">
  <module name=\"TreeWalker\">
    <module name=\"MissingJavadocType\"/>
    <module name=\"FinalParameters\"><property name=\"severity\" value=\"error\"/></module>
  </module>
</module>
")

(defconst e2e--static-smelly "package dev.hellmacs.demo;

public class Smelly {
    private int unused;

    public String trimmed(String s) {
        String n = null;
        if (s.isEmpty()) {
            return n.trim();
        }
        return s == \"x\" ? s : s.trim();
    }
}
")

(defun e2e--static-project ()
  "A copy of gradle-demo with the three plugins and a smelly class."
  (let ((proj (e2e-copy-fixture "java/gradle-demo")))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "build.gradle" proj))
      (goto-char (point-min))
      (re-search-forward "^plugins {\n    id 'application'\n}")
      (replace-match e2e--static-plugins t t)
      (write-region nil nil (expand-file-name "build.gradle" proj)))
    (make-directory (expand-file-name "config/checkstyle/" proj) t)
    (with-temp-file (expand-file-name "config/checkstyle/checkstyle.xml" proj)
      (insert e2e--static-checkstyle))
    (with-temp-file (expand-file-name "src/main/java/dev/hellmacs/demo/Smelly.java" proj)
      (insert e2e--static-smelly))
    proj))

(defun e2e--static-build (proj)
  "Run the three tools through PROJ's Gradle, as `C-x p c' would; return the finish message."
  (let ((default-directory (file-name-as-directory proj)))
    (setq compile-command "./gradlew --console=plain -q checkstyleMain pmdMain spotbugsMain")
    (e2e--compile-and-wait default-directory)))

(defun e2e--static-lines (diagnostics)
  "DIAGNOSTICS (flymake's) as (LINE . TEXT)."
  (mapcar (lambda (d) (cons (line-number-at-pos (flymake-diagnostic-beg d)) (flymake-diagnostic-text d)))
          diagnostics))

(defun e2e--static-report-checks (proj smelly)
  (e2e-check "the build ran"
    (string-match-p "finished" (or (e2e--static-build proj) "")))
  (e2e-check "Checkstyle's, PMD's and SpotBugs' reports are found"
    (= 3 (length (hellmacs-static-report-files proj))))
  (with-current-buffer (find-file-noselect smelly)
    (e2e-check "flymake is on in Java buffers, with the backend"
      (and flymake-mode (memq #'hellmacs-static-flymake flymake-diagnostic-functions)))
    ;; Flymake waits for a window to show the buffer, which batch never does.
    (flymake-start nil t)
    (let ((found (e2e--wait (lambda ()
                              (let ((lines (e2e--static-lines
                                            (seq-filter (lambda (d) (eq (flymake-diagnostic-backend d)
                                                                        #'hellmacs-static-flymake))
                                                        (flymake-diagnostics)))))
                                (and (>= (length lines) 8) lines)))
                            60)))
      (e2e-check "each tool's findings are on their lines"
        (and (assoc 3 found)                         ; Checkstyle: missing Javadoc
             (cl-some (lambda (l) (and (= (car l) 4) (string-prefix-p "PMD:" (cdr l)))) found)
             (cl-some (lambda (l) (and (= (car l) 4) (string-prefix-p "SpotBugs:" (cdr l)))) found)
             (cl-some (lambda (l) (and (= (car l) 9) (string-match-p "NP_ALWAYS_NULL" (cdr l)))) found))))
    (e2e-check "an edit hides them until the next build"
      (let ((text (buffer-string)) reported)
        (goto-char (point-min))
        (insert "// edited\n")
        (hellmacs-static-flymake (lambda (diags &rest _) (setq reported diags)))
        ;; Back to what's on disk.
        (erase-buffer)
        (insert text)
        (set-buffer-modified-p nil)
        (null reported))))
  (e2e-check "the project's findings list, for M-g n"
    (with-current-buffer (hellmacs-static-findings proj)
      (string-match-p "12 findings" (buffer-string)))))

(defvar e2e--static-java-configs nil
  "What `sonarlint/getJavaConfig' was answered, newest first.")

(defun e2e--static-record-config-a (fn workspace params callback)
  (funcall fn workspace params (lambda (result)
                                 (push (cons (if (vectorp params) (aref params 0) params) result)
                                       e2e--static-java-configs)
                                 (funcall callback result))))

(defun e2e--static-sonarlint-checks (proj smelly)
  (advice-add 'hellmacs-static-sonarlint-java-config :around #'e2e--static-record-config-a)
  (e2e-add-project proj)
  (with-current-buffer (find-file-noselect smelly)
    (lsp)
    (e2e-check "JDTLS imports the project"
      (e2e--wait (lambda () (eq (hellmacs-jvm-state proj) 'ready)) 400))
    (e2e-check "SonarLint runs beside JDTLS"
      (e2e--wait (lambda () (cl-some (lambda (ws) (eq (lsp--client-server-id (lsp--workspace-client ws)) 'sonarlint))
                                     (lsp-workspaces)))
                 60))
    (e2e-check "its Java analyzer is given the project's classpath, from JDTLS"
      (e2e--wait (lambda ()
                   (cl-some (lambda (entry)
                              (let ((config (cdr entry)))
                                (and config
                                     (string-suffix-p "Smelly.java" (car entry))
                                     (> (length (plist-get config :classpath)) 0)
                                     (plist-get config :sourceLevel))))
                            e2e--static-java-configs))
                 180))
    (let ((sonar (e2e--wait (lambda ()
                              (seq-filter (lambda (d) (equal (lsp-get d :source) "sonarlint"))
                                          (lsp--get-buffer-diagnostics)))
                            180)))
      (e2e-check "SonarLint reports on the file"
        sonar)
      (e2e-check "its null dereference is on its line, in the project's package"
        (and (cl-some (lambda (d) (and (= (lsp-get (lsp-get (lsp-get d :range) :start) :line) 8) ; line 9
                                       (string-match-p "NullPointerException" (lsp-get d :message))))
                      sonar)
             (not (cl-some (lambda (d) (string-match-p "named package" (lsp-get d :message))) sonar))))
      (e2e--say "     SonarLint: %s"
                (mapconcat (lambda (d) (format "%d: %s" (1+ (lsp-get (lsp-get (lsp-get d :range) :start) :line))
                                               (lsp-get d :message)))
                           sonar "; ")))))

(let* ((proj (e2e--static-project))
       (smelly (expand-file-name "src/main/java/dev/hellmacs/demo/Smelly.java" proj)))
  (e2e--say "Hellmacs :checkers static end-to-end, in %s" proj)
  (e2e--static-report-checks proj smelly)
  (if (and (modulep! :checkers static +sonarlint) (hellmacs-static-sonarlint-installed-p))
      (e2e--static-sonarlint-checks proj smelly)
    (e2e-skip "SonarLint" "needs (:checkers static +sonarlint), synced")))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; static-e2e.el ends here
