;;; lang/groovy/autoload.el -*- lexical-binding: t; -*-

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


(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar hell-cache-dir)
(declare-function hell-forge-annotated-test-at-point "../../tools/build/autoload")
(declare-function hell-jdk-gradle-environment "../../../lisp/lib/jdk")
(declare-function hell-net-jvm-options "../../../lisp/lib/net")

;;; Files --------------------------------------------------------------------------

(defconst hell-groovy-file-regexps
  '("\\.\\(?:groovy\\|gradle\\|gant\\)\\'"      ; groovy-mode's own
    "\\(?:\\`\\|/\\)Jenkinsfile\\'"
    "\\.jenkinsfile\\'"                        ; pipeline.jenkinsfile
    "\\(?:\\`\\|/\\)Jenkinsfile\\.[^./]+\\'")  ; Jenkinsfile.release
  "Names of Groovy files: sources, Gradle's Groovy scripts, Jenkins pipelines.")

;;;###autoload
(defun hell-groovy-file-p (file)
  "Non-nil if FILE is Groovy: a source, a Gradle Groovy script or a Jenkinsfile.
Not documentation named after a pipeline (Jenkinsfile.md)."
  (and (seq-some (lambda (re) (string-match-p re file)) hell-groovy-file-regexps)
       (not (string-match-p "\\.\\(?:md\\|txt\\|adoc\\|rst\\|org\\)\\'" file))))

;;; Tests --------------------------------------------------------------------------

(defun hell-groovy--spock-feature-at-point ()
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
(defun hell-groovy-test-method ()
  "The name of the test point is in, or nil: a JUnit method (by its @Test),
or a Spock feature (by its quoted name)."
  (or (and (fboundp 'hell-forge-annotated-test-at-point)
           (hell-forge-annotated-test-at-point "\\_<\\([[:alpha:]_$][[:alnum:]_$]*\\)[ \t\n]*("))
      (hell-groovy--spock-feature-at-point)))

;;; The project's classpath --------------------------------------------------------
;;
;; groovy-language-server compiles the project itself, and knows its
;; libraries only from the `groovy.classpath' setting: without them every
;; import of one is an error. The build is asked for them (the test
;; runtime classpath, which holds the main one), once per project until
;; a build file changes.

(defconst hell-groovy-maven-dependency-plugin
  "org.apache.maven.plugins:maven-dependency-plugin:3.8.1"
  "The Maven dependency plugin release a Maven build's classpath is asked with.")

(defconst hell-groovy--gradle-init-script
  "// Written by Hell Emacs (:lang groovy): prints each project's test runtime
// classpath, for groovy-language-server. The build files stay as they are.
allprojects {
    tasks.register('hellClasspath') {
        def classpath = project.configurations.findByName('testRuntimeClasspath')
        doLast {
            classpath?.files?.each { println \"hell-classpath: ${it}\" }
        }
    }
}
"
  "The Gradle init script that prints a build's classpath.")

(defvar hell-groovy--classpaths (make-hash-table :test #'equal)
  "Project root -> (STAMP . CLASSPATH): what its build said, and when.")

(defvar hell-groovy--classpath-error nil
  "Why the last classpath asked of a build couldn't be had.")

(defconst hell-groovy--build-files
  '("settings.gradle" "settings.gradle.kts" "build.gradle" "build.gradle.kts" "pom.xml"
    "gradle/libs.versions.toml")
  "The files whose change means the classpath is asked again.")

(defun hell-groovy--stamp (root)
  (mapcar (lambda (file)
            (file-attribute-modification-time (file-attributes (expand-file-name file root))))
          hell-groovy--build-files))

(defun hell-groovy--init-script ()
  "The init script's file, written if it isn't there or has changed."
  (let ((file (expand-file-name "hell/groovy-classpath.gradle" hell-cache-dir)))
    (unless (and (file-exists-p file)
                 (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                        hell-groovy--gradle-init-script))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert hell-groovy--gradle-init-script)))
    file))

;;;###autoload
(defun hell-groovy--classpath-command (root out)
  "The command asking the build at ROOT for its classpath, or nil if there's none.
Maven writes it to OUT; Gradle prints it."
  (let ((has (lambda (&rest files) (seq-some (lambda (f) (file-exists-p (expand-file-name f root))) files)))
        (program (lambda (wrapper tool)
                   (let ((path (expand-file-name wrapper root)))
                     (if (file-executable-p path) path tool)))))
    (cond ((funcall has "settings.gradle" "settings.gradle.kts" "build.gradle" "build.gradle.kts")
           (list (funcall program "gradlew" "gradle") "-q" "--console=plain"
                 "--init-script" (hell-groovy--init-script) "hellClasspath"))
          ((funcall has "pom.xml")
           (list (funcall program "mvnw" "mvn") "-q" "-B"
                 (concat hell-groovy-maven-dependency-plugin ":build-classpath")
                 "-Dmdep.includeScope=test" "-Dmdep.appendOutput=true"
                 (concat "-Dmdep.outputFile=" out))))))

(defun hell-groovy--parse-classpath (output out)
  "The classpath in Gradle's OUTPUT, or else in Maven's file OUT."
  (delete-dups
   (or (cl-loop for line in (split-string output "\n" t)
                when (string-match "\\`hell-classpath: \\(.+\\)\\'" line)
                collect (match-string 1 line))
       (and (file-exists-p out)
            (split-string (with-temp-buffer (insert-file-contents out) (buffer-string))
                          (concat "[\n" path-separator "]") t "[ \t\r]+")))))

(defun hell-groovy--failure-reason (output program status)
  "The build's own one-line reason for failing, from its OUTPUT.
Gradle's line under \"What went wrong:\", Maven's first [ERROR]; else
the last line, or PROGRAM's exit STATUS."
  (let ((lines (split-string (string-trim output) "\n" t "[ \t]+")))
    (or (cadr (member "* What went wrong:" lines))
        (seq-find (lambda (l) (string-prefix-p "[ERROR]" l)) lines)
        (car (last lines))
        (format "%s exited with %d" (file-name-nondirectory program) status))))

;;;###autoload
(defun hell-groovy-fetch-classpath (root callback)
  "Ask the build at ROOT for its classpath; call CALLBACK with it when known.
With a list of paths, nil for a project without a build, or `failed'
\(`hell-groovy--classpath-error' says why). Runs in the background;
kept per project until one of its build files changes."
  (let* ((root (file-name-as-directory (expand-file-name root)))
         (stamp (hell-groovy--stamp root))
         (cached (gethash root hell-groovy--classpaths))
         (out (make-temp-file "hell-groovy-classpath"))
         (command (hell-groovy--classpath-command root out)))
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
                           (hell-jdk-gradle-environment root))
                      (when-let* ((options (hell-net-jvm-options)))
                        (list (concat "JAVA_TOOL_OPTIONS=" (string-join options " "))))
                      process-environment))
             (buffer (generate-new-buffer " *hell-groovy-classpath*")))
        (make-process
         :name "hell-groovy-classpath" :buffer buffer :command command
         :connection-type 'pipe :noquery t
         :sentinel
         (lambda (proc _event)
           (unless (process-live-p proc)
             (let ((output (with-current-buffer buffer (buffer-string))))
               (kill-buffer buffer)
               (if (zerop (process-exit-status proc))
                   (let ((classpath (hell-groovy--parse-classpath output out)))
                     (puthash root (cons stamp classpath) hell-groovy--classpaths)
                     (delete-file out)
                     (funcall callback classpath))
                 (delete-file out)
                 (setq hell-groovy--classpath-error
                       (hell-groovy--failure-reason output (car command) (process-exit-status proc)))
                 (funcall callback 'failed)))))))))))

;;; lang/groovy/autoload.el ends here
