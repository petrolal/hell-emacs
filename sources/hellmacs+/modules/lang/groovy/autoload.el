;;; lang/groovy/autoload.el -*- lexical-binding: t; -*-

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


(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar hellmacs-cache-dir)
(declare-function hellmacs-forge-annotated-test-at-point "../../tools/build/autoload")
(declare-function hellmacs-jdk-gradle-environment "../../../lisp/lib/jdk")
(declare-function hellmacs-net-jvm-options "../../../lisp/lib/net")

;;; Files --------------------------------------------------------------------------

(defconst hellmacs-groovy-file-regexps
  '("\\.\\(?:groovy\\|gradle\\|gant\\)\\'"      ; groovy-mode's own
    "\\(?:\\`\\|/\\)Jenkinsfile\\'"
    "\\.jenkinsfile\\'"                        ; pipeline.jenkinsfile
    "\\(?:\\`\\|/\\)Jenkinsfile\\.[^./]+\\'")  ; Jenkinsfile.release
  "Names of Groovy files: sources, Gradle's Groovy scripts, Jenkins pipelines.")

;;;###autoload
(defun hellmacs-groovy-file-p (file)
  "Non-nil if FILE is Groovy: a source, a Gradle Groovy script or a Jenkinsfile.
Not documentation named after a pipeline (Jenkinsfile.md)."
  (and (seq-some (lambda (re) (string-match-p re file)) hellmacs-groovy-file-regexps)
       (not (string-match-p "\\.\\(?:md\\|txt\\|adoc\\|rst\\|org\\)\\'" file))))

;;; Tests --------------------------------------------------------------------------

(defun hellmacs-groovy--spock-feature-at-point ()
  "The name of the Spock feature (`def \"it does\"()') point is in, or nil."
  (let ((pos (point)))
    (save-excursion
      (end-of-line)
      (when (re-search-backward "^[ \t]*def[ \t]+\\([\"']\\)\\(.+?\\)\\1[ \t]*(" nil t)
        (let ((start (line-beginning-position))
              (name (match-string-no-properties 2)))
          (goto-char (1- (match-end 0)))  ; its parameters' `('
          (let ((end (condition-case nil
                         (progn (forward-sexp)
                                (skip-chars-forward "^{")
                                (forward-sexp)
                                (point))
                       (scan-error (point-max)))))
            (and (<= start pos end) name)))))))

;;;###autoload
(defun hellmacs-groovy-test-method ()
  "The name of the test point is in, or nil: a JUnit method (by its @Test),
or a Spock feature (by its quoted name)."
  (or (and (fboundp 'hellmacs-forge-annotated-test-at-point)
           (hellmacs-forge-annotated-test-at-point "\\_<\\([[:alpha:]_$][[:alnum:]_$]*\\)[ \t\n]*("))
      (hellmacs-groovy--spock-feature-at-point)))

;;; The project's classpath --------------------------------------------------------
;;
;; groovy-language-server compiles the project itself, and knows its
;; libraries only from the `groovy.classpath' setting: without them every
;; import of one is an error. The build is asked for them (the test
;; runtime classpath, which holds the main one), once per project until
;; a build file changes.

(defconst hellmacs-groovy-maven-dependency-plugin
  "org.apache.maven.plugins:maven-dependency-plugin:3.8.1"
  "The Maven dependency plugin release a Maven build's classpath is asked with.")

(defconst hellmacs-groovy--gradle-init-script
  "// Written by Hellmacs (:lang groovy): prints each project's test runtime
// classpath, for groovy-language-server. The build files stay as they are.
allprojects {
    tasks.register('hellmacsClasspath') {
        def classpath = project.configurations.findByName('testRuntimeClasspath')
        doLast {
            classpath?.files?.each { println \"hellmacs-classpath: ${it}\" }
        }
    }
}
"
  "The Gradle init script that prints a build's classpath.")

(defvar hellmacs-groovy--classpaths (make-hash-table :test #'equal)
  "Project root -> (STAMP . CLASSPATH): what its build said, and when.")

(defvar hellmacs-groovy--classpath-error nil
  "Why the last classpath asked of a build couldn't be had.")

(defconst hellmacs-groovy--build-files
  '("settings.gradle" "settings.gradle.kts" "build.gradle" "build.gradle.kts" "pom.xml"
    "gradle/libs.versions.toml")
  "The files whose change means the classpath is asked again.")

(defun hellmacs-groovy--stamp (root)
  (mapcar (lambda (file)
            (file-attribute-modification-time (file-attributes (expand-file-name file root))))
          hellmacs-groovy--build-files))

(defun hellmacs-groovy--init-script ()
  "The init script's file, written if it isn't there or has changed."
  (let ((file (expand-file-name "hellmacs/groovy-classpath.gradle" hellmacs-cache-dir)))
    (unless (and (file-exists-p file)
                 (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                        hellmacs-groovy--gradle-init-script))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert hellmacs-groovy--gradle-init-script)))
    file))

;;;###autoload
(defun hellmacs-groovy--classpath-command (root out)
  "The command asking the build at ROOT for its classpath, or nil if there's none.
Maven writes it to OUT; Gradle prints it."
  (let ((has (lambda (&rest files) (seq-some (lambda (f) (file-exists-p (expand-file-name f root))) files)))
        (program (lambda (wrapper tool)
                   (let ((path (expand-file-name wrapper root)))
                     (if (file-executable-p path) path tool)))))
    (cond ((funcall has "settings.gradle" "settings.gradle.kts" "build.gradle" "build.gradle.kts")
           (list (funcall program "gradlew" "gradle") "-q" "--console=plain"
                 "--init-script" (hellmacs-groovy--init-script) "hellmacsClasspath"))
          ((funcall has "pom.xml")
           (list (funcall program "mvnw" "mvn") "-q" "-B"
                 (concat hellmacs-groovy-maven-dependency-plugin ":build-classpath")
                 "-Dmdep.includeScope=test" "-Dmdep.appendOutput=true"
                 (concat "-Dmdep.outputFile=" out))))))

(defun hellmacs-groovy--parse-classpath (output out)
  "The classpath in Gradle's OUTPUT, or else in Maven's file OUT."
  (delete-dups
   (or (cl-loop for line in (split-string output "\n" t)
                when (string-match "\\`hellmacs-classpath: \\(.+\\)\\'" line)
                collect (match-string 1 line))
       (and (file-exists-p out)
            (split-string (with-temp-buffer (insert-file-contents out) (buffer-string))
                          (concat "[\n" path-separator "]") t "[ \t\r]+")))))

(defun hellmacs-groovy--failure-reason (output program status)
  "The build's own one-line reason for failing, from its OUTPUT.
Gradle's line under \"What went wrong:\", Maven's first [ERROR]; else
the last line, or PROGRAM's exit STATUS."
  (let ((lines (split-string (string-trim output) "\n" t "[ \t]+")))
    (or (cadr (member "* What went wrong:" lines))
        (seq-find (lambda (l) (string-prefix-p "[ERROR]" l)) lines)
        (car (last lines))
        (format "%s exited with %d" (file-name-nondirectory program) status))))

;;;###autoload
(defun hellmacs-groovy-fetch-classpath (root callback)
  "Ask the build at ROOT for its classpath; call CALLBACK with it when known.
With a list of paths, nil for a project without a build, or `failed'
\(`hellmacs-groovy--classpath-error' says why). Runs in the background;
kept per project until one of its build files changes."
  (let* ((root (file-name-as-directory (expand-file-name root)))
         (stamp (hellmacs-groovy--stamp root))
         (cached (gethash root hellmacs-groovy--classpaths))
         (out (make-temp-file "hellmacs-groovy-classpath"))
         (command (hellmacs-groovy--classpath-command root out)))
    (cond
     ((and cached (equal (car cached) stamp))
      (delete-file out)
      (funcall callback (cdr cached)))
     ((null command)
      (delete-file out)
      (funcall callback nil))
     (t
      (let* ((default-directory root)
             (process-environment
              (append (and (string-match-p "gradle" (file-name-nondirectory (car command)))
                           (hellmacs-jdk-gradle-environment root))
                      (when-let* ((options (hellmacs-net-jvm-options)))
                        (list (concat "JAVA_TOOL_OPTIONS=" (string-join options " "))))
                      process-environment))
             (buffer (generate-new-buffer " *hellmacs-groovy-classpath*")))
        (make-process
         :name "hellmacs-groovy-classpath" :buffer buffer :command command
         :connection-type 'pipe :noquery t
         :sentinel
         (lambda (proc _event)
           (unless (process-live-p proc)
             (let ((output (with-current-buffer buffer (buffer-string))))
               (kill-buffer buffer)
               (if (zerop (process-exit-status proc))
                   (let ((classpath (hellmacs-groovy--parse-classpath output out)))
                     (puthash root (cons stamp classpath) hellmacs-groovy--classpaths)
                     (delete-file out)
                     (funcall callback classpath))
                 (delete-file out)
                 (setq hellmacs-groovy--classpath-error
                       (hellmacs-groovy--failure-reason output (car command) (process-exit-status proc)))
                 (funcall callback 'failed)))))))))))

;;; lang/groovy/autoload.el ends here
