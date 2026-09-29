;;; tools/build/autoload.el -*- lexical-binding: t; -*-

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


(defvar compilation-environment)        ; compile.el

;;; Build tool detection ---------------------------------------------------------

(defconst hellmacs-forge-build-markers
  '(("gradlew" gradle t) ("mvnw" maven t)
    ("settings.gradle" gradle nil) ("settings.gradle.kts" gradle nil)
    ("build.gradle" gradle nil) ("build.gradle.kts" gradle nil)
    ("pom.xml" maven nil))
  "Files that identify a build: (FILE TOOL WRAPPER-P), in order of preference.
A wrapper's directory is the build's root, so a module inside a
multi-module build still builds from the top.")

(defun hellmacs-forge--build-root-p (root tool)
  "Non-nil if directory ROOT holds a build file (not a wrapper) of TOOL.
A wrapper next to none of them (a leftover ./gradlew in a Maven
project) isn't that tool's build."
  (seq-some (pcase-lambda (`(,file ,marker-tool ,wrapper))
              (and (not wrapper) (eq marker-tool tool)
                   (file-exists-p (expand-file-name file root))))
            hellmacs-forge-build-markers))

;;;###autoload
(defun hellmacs-forge-build-tool (&optional dir)
  "Return (TOOL ROOT PROGRAM) for the build containing DIR, or nil.
TOOL is `gradle' or `maven'; ROOT the directory to run it in; PROGRAM
the wrapper (\"./gradlew\") if there is one, else the installed tool."
  (let ((dir (or dir default-directory)))
    (seq-some (pcase-lambda (`(,file ,tool ,wrapper))
                (when-let* ((root (locate-dominating-file dir file)))
                  (when (or (not wrapper) (hellmacs-forge--build-root-p root tool))
                    (list tool (file-name-as-directory (expand-file-name root))
                          (cond (wrapper (concat "./" file))
                                ((eq tool 'gradle) "gradle")
                                (t "mvn"))))))
              hellmacs-forge-build-markers)))

(defun hellmacs-forge--command (task &optional test build)
  "Return the shell command for TASK (`build' or `test') in the current build.
TEST narrows `test' to a class (\"pkg.Class\") or method (\"pkg.Class#method\"),
or a list of them. BUILD is the build's (TOOL ROOT PROGRAM), if already known."
  (pcase-let ((`(,tool ,_root ,program) (or build (hellmacs-forge-build-tool)
                                            (user-error "No Gradle or Maven build here")))
              (tests (ensure-list test)))
    (pcase (list tool task)
      ('(gradle build) (concat program " build --console=plain"))
      ('(maven build) (concat program " -B verify"))
      ('(gradle test)
       (concat program " test --console=plain"
               (mapconcat (lambda (test) (concat " --tests " (shell-quote-argument (string-replace "#" "." test))))
                          tests)))
      ('(maven test)
       (concat program " -B test"
               (when tests
                 ;; Surefire wants Class#method (simple class name works
                 ;; too), comma-separated; don't fail modules that have no
                 ;; such test.
                 (concat " -Dtest=" (mapconcat #'shell-quote-argument tests ",")
                         " -Dsurefire.failIfNoSpecifiedTests=false")))))))

;;;###autoload
(defun hellmacs-forge-setup-build-h ()
  "Make `compile-command' (and so `C-x p c') the build's own build command.
Builds started from this buffer get your proxy and CA
\(`hellmacs-net-jvm-options') in JAVA_TOOL_OPTIONS, which every JVM a
Gradle or Maven build starts reads: the client, the daemon, the tests."
  (when-let* ((command (ignore-errors (hellmacs-forge--command 'build))))
    (setq-local compile-command command))
  (when-let* ((options (hellmacs-net-jvm-options)))
    ;; compile.el may not be loaded yet (this runs as the file opens): the
    ;; buffer-local value then simply starts from its default, nil.
    (setq-local compilation-environment
                (cons (concat "JAVA_TOOL_OPTIONS="
                              (string-join (append (split-string (or (getenv "JAVA_TOOL_OPTIONS") "") " " t)
                                                   options)
                                           " "))
                      (bound-and-true-p compilation-environment)))))

;;; Running builds and tests -----------------------------------------------------

(defun hellmacs-forge--run (task &optional test)
  "Run TASK (and TEST) as `hellmacs-forge--command' with `compile', from the build's root."
  (let* ((build (or (hellmacs-forge-build-tool) (user-error "No Gradle or Maven build here")))
         (default-directory (nth 1 build)))
    (compile (hellmacs-forge--command task test build))))

(defvar-local hellmacs-forge-test-class-function #'hellmacs-forge-file-class
  "Function returning the fully qualified name of the buffer's test class.
Languages whose files don't follow the file-name rule set their own.")

(defvar-local hellmacs-forge-test-method-function nil
  "Function returning the name of the test method around point, or nil.
Set by each language (it knows what a test method looks like); without
one, `hellmacs-forge-test-at-point' runs the whole class.")

(defconst hellmacs-forge-test-annotation-regexp
  (concat "@\\(?:[[:alnum:]_]+\\.\\)*"
          (regexp-opt '("Test" "ParameterizedTest" "RepeatedTest" "TestFactory" "TestTemplate") t)
          "\\_>")
  "JUnit's (4 and 5) annotations of a test method, qualified or not.")

;;;###autoload
(defun hellmacs-forge-annotated-test-at-point (name-regexp)
  "The name of the JUnit test method point is in, or nil.
Point is in it from its annotations to its body's closing brace; in a
helper or setup method, or between methods, there is none. NAME-REGEXP
finds the method's name after its annotations, in group 1 or 2."
  (let ((pos (point)))
    (save-excursion
      (end-of-line)
      (when (re-search-backward hellmacs-forge-test-annotation-regexp nil t)
        (let ((start (line-beginning-position)) name)
          ;; Past its annotations, and their arguments.
          (while (looking-at "@[[:alnum:]_$.]+")
            (goto-char (match-end 0))
            (skip-chars-forward " \t\n")
            (when (eq (char-after) ?\()
              (forward-sexp)
              (skip-chars-forward " \t\n")))
          (when (re-search-forward name-regexp
                                   (save-excursion (and (re-search-forward "[{;]" nil t) (point)))
                                   t)
            (setq name (or (match-string-no-properties 1) (match-string-no-properties 2)))
            (goto-char (1- (match-end 0)))  ; its parameters' `('
            (let ((end (condition-case nil
                           (progn (forward-sexp)
                                  (skip-chars-forward "^{;")
                                  (if (eq (char-after) ?{)
                                      (progn (forward-sexp) (point))
                                    (line-end-position)))
                         ;; Unbalanced: still being written, around point.
                         (scan-error (point-max)))))
              (and (<= start pos end) name))))))))

;;;###autoload
(defun hellmacs-forge-package ()
  "The package the current buffer's file declares (\"dev.x\"), or nil.
The same line in Java, Kotlin, Groovy and Scala, with or without a `;'."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^[ \t]*package[ \t]+\\([a-zA-Z0-9_.]+\\)[ \t]*;?[ \t]*$" nil t)
      (match-string-no-properties 1))))

;;;###autoload
(defun hellmacs-forge-qualify (class)
  "CLASS, qualified with the current buffer's package."
  (if-let* ((package (hellmacs-forge-package))) (concat package "." class) class))

;;;###autoload
(defun hellmacs-forge-file-class ()
  "The class named after the current file, qualified: the JVM convention (Java's rule)."
  (hellmacs-forge-qualify
   (file-name-base (or buffer-file-name (user-error "Not visiting a file")))))

(defun hellmacs-forge--test-class ()
  (funcall hellmacs-forge-test-class-function))

;;;###autoload
(defun hellmacs-forge-build ()
  "Build the current project with its build tool (Gradle or Maven)."
  (interactive)
  (hellmacs-forge--run 'build))

;;;###autoload
(defun hellmacs-forge-test-at-point ()
  "Run the test method at point with the build tool (the whole class if none)."
  (interactive)
  (let ((method (and hellmacs-forge-test-method-function
                     (funcall hellmacs-forge-test-method-function))))
    (hellmacs-forge--run 'test (concat (hellmacs-forge--test-class)
                                       (and method (concat "#" method))))))

;;;###autoload
(defun hellmacs-forge-test-class ()
  "Run every test in the current class with the build tool."
  (interactive)
  (hellmacs-forge--run 'test (hellmacs-forge--test-class)))

;;; Clickable errors and test failures -------------------------------------------
;;
;; Stock Emacs already understands javac (`gnu') and Maven (`maven')
;; errors. What it gets wrong for JVM builds:
;; - stack frames name a file without its directory ("Foo.java:12"),
;;   so it can't find them -- and marks JDK/library frames as errors;
;; - Gradle's test failures ("...Error at FooTest.java:16") likewise;
;; - Gradle repeats compile errors, indented, in its failure summary.
;; These rules resolve file names inside the project, and simply don't
;; match frames whose file isn't there (a FILE function returning nil
;; makes compile.el ignore the match).

(defvar hellmacs-forge--source-indexes (make-hash-table :test #'equal)
  "Build root -> its source index (base name -> paths), kept across builds.")

(defvar hellmacs-forge--source-index-roots nil
  "The roots in `hellmacs-forge--source-indexes', most recently used first.")

(defvar hellmacs-forge-source-index-limit 8
  "How many build roots' source indexes are kept across builds.
Each holds the path of every source file in its project.")

(defun hellmacs-forge--cached-index (root)
  "ROOT's kept source index, or nil; it becomes the most recently used."
  (when-let* ((index (gethash root hellmacs-forge--source-indexes)))
    (setq hellmacs-forge--source-index-roots
          (cons root (delete root hellmacs-forge--source-index-roots)))
    index))

(defun hellmacs-forge--remember-index (root index)
  "Keep INDEX as ROOT's, dropping the least recently used beyond the limit.
Returns INDEX."
  (puthash root index hellmacs-forge--source-indexes)
  (setq hellmacs-forge--source-index-roots
        (cons root (delete root hellmacs-forge--source-index-roots)))
  (when-let* ((old (nthcdr hellmacs-forge-source-index-limit hellmacs-forge--source-index-roots)))
    (dolist (gone old) (remhash gone hellmacs-forge--source-indexes))
    (setq hellmacs-forge--source-index-roots
          (seq-take hellmacs-forge--source-index-roots hellmacs-forge-source-index-limit)))
  index)

(defvar-local hellmacs-forge--source-index nil
  "This compilation's source index: base name -> its paths in the project.")

(defvar-local hellmacs-forge--index-refreshed nil
  "Non-nil once this compilation has walked the project again for a missing file.")

(defvar-local hellmacs-forge--project-packages nil
  "This compilation's answers to \"has the project sources in package P?\".")

(defconst hellmacs-forge--ignored-dirs '("build" "target" "out" ".git" ".gradle" "node_modules")
  "Directories never searched for source files.")

(defconst hellmacs-forge-source-extensions '("java" "kt" "kts" "groovy" "scala")
  "Extensions of the JVM source files builds, stack traces and test failures name.")

(defconst hellmacs-forge--source-extension-regexp (regexp-opt hellmacs-forge-source-extensions)
  "Matches one of `hellmacs-forge-source-extensions' (without the dot).")

(defconst hellmacs-forge--source-regexp (concat "\\." hellmacs-forge--source-extension-regexp "\\'")
  "Names of the source files stack frames and test failures point at.")

(defun hellmacs-forge--source-root ()
  "The directory whose source files this compilation's links may point to.
The build's root (`hellmacs-forge-build-tool'), else the project's; nil
outside both, so a `compile' run in ~ never has all of ~ searched."
  (or (nth 1 (hellmacs-forge-build-tool))
      (when-let* ((project (project-current nil default-directory)))
        (project-root project))))

(defun hellmacs-forge--build-index (root)
  "Walk ROOT for source files; return base name -> paths."
  (let ((index (make-hash-table :test #'equal)))
    (dolist (path (directory-files-recursively
                   root hellmacs-forge--source-regexp nil
                   (lambda (dir) (not (member (file-name-nondirectory dir)
                                              hellmacs-forge--ignored-dirs)))))
      (push path (gethash (file-name-nondirectory path) index)))
    index))

(defun hellmacs-forge--source-index (&optional refresh)
  "The project's source index, from the last build of it, or walked now.
Kept per build root across builds, since a project's files rarely change
between them; REFRESH walks it again. Empty outside a build or project,
so a `compile' run in ~ never has all of ~ searched."
  (if (and hellmacs-forge--source-index (not refresh))
      hellmacs-forge--source-index
    (setq hellmacs-forge--source-index
          (if-let* ((root (hellmacs-forge--source-root)))
              (or (and (not refresh) (hellmacs-forge--cached-index root))
                  (hellmacs-forge--remember-index root (hellmacs-forge--build-index root)))
            (make-hash-table :test #'equal)))))

(defun hellmacs-forge--lookup (file suffix)
  (seq-find (lambda (path) (string-suffix-p suffix path))
            (gethash file (hellmacs-forge--source-index))))

(defun hellmacs-forge--project-package-p (package)
  "Non-nil if the project has sources in PACKAGE's directory (remembered)."
  (let ((dir (concat "/" (string-replace "." "/" package) "/")))
    (eq 'yes
        (with-memoization (alist-get package hellmacs-forge--project-packages nil nil #'equal)
          (catch 'found
            (maphash (lambda (_ paths)
                       (when (seq-some (lambda (path) (string-search dir path)) paths)
                         (throw 'found 'yes)))
                     (hellmacs-forge--source-index))
            'no)))))

(defun hellmacs-forge--find-source (file &optional package)
  "Find source FILE (a base name) in the project, under PACKAGE's directory.
PACKAGE is dotted (\"dev.hellmacs.demo\"); nil means any directory.
Returns a path or nil. A file the index doesn't have may be new since
it was made: the project is walked again, once per compilation, if the
file could be the project's (no package, or one the project has; not
a JDK or library frame)."
  (let ((suffix (concat "/" (if package (concat (string-replace "." "/" package) "/") "") file)))
    (or (hellmacs-forge--lookup file suffix)
        (when (and (not hellmacs-forge--index-refreshed)
                   (or (null package) (hellmacs-forge--project-package-p package)))
          (setq hellmacs-forge--index-refreshed t)
          (hellmacs-forge--source-index 'refresh)
          (hellmacs-forge--lookup file suffix)))))

(defun hellmacs-forge--frame-file ()
  "FILE function for `hellmacs-jvm-frame': the frame's file, if in the project.
Preserves the match data: compile.el reads the line number from it next."
  (let ((package (match-string-no-properties 1))
        (file (match-string-no-properties 2)))
    (save-match-data
      (hellmacs-forge--find-source file (and (not (string-empty-p package))
                                              (string-remove-suffix "." package))))))

(defun hellmacs-forge--uri-file ()
  "FILE function for the Kotlin compiler rules: the `file://' path, if it exists.
Gradle prints Kotlin errors as \"e: file:///abs/Foo.kt:6:22 message\", with
the path percent-encoded. Preserves the match data."
  (require 'url-util)
  (let ((path (match-string-no-properties 1)))
    (save-match-data
      (let ((file (url-unhex-string path)))
        (and (file-exists-p file) file)))))

(defun hellmacs-forge--basename-file ()
  "FILE function for `hellmacs-gradle-test': the named file, if in the project.
Preserves the match data: compile.el reads the line number from it next."
  (let ((file (match-string-no-properties 1)))
    (save-match-data (hellmacs-forge--find-source file))))

;;;###autoload
(defun hellmacs-forge--add-error-regexps ()
  "Register Hellmacs' JVM error rules with `compile'."
  (dolist (rule
           `((hellmacs-jvm-frame
              ;; "at pkg.Class.method(File.java:12)", optionally "java.base/pkg..."
              ,(concat "^[ \t]+at \\(?:[^ \t\n/(]+/\\)?"
                       "\\(\\(?:[a-zA-Z_$][a-zA-Z0-9_$]*\\.\\)*\\)"   ; 1: package (with dot)
                       "[a-zA-Z_$][a-zA-Z0-9_$]*\\.[^.(\n]+"          ; Class.method
                       "(\\([^():\n]+\\." hellmacs-forge--source-extension-regexp "\\):\\([0-9]+\\))")
              hellmacs-forge--frame-file 3)
             (hellmacs-gradle-test
              ;; "    org.opentest4j.AssertionFailedError at FooTest.java:16"
              ,(concat "^[ \t]+[^ \t\n]+ at \\([^ \t\n:/]+\\." hellmacs-forge--source-extension-regexp
                       "\\):\\([0-9]+\\)$")
              hellmacs-forge--basename-file 2)
             (hellmacs-kotlin-error
              ;; "e: file:///abs/Foo.kt:6:22 Unresolved reference 'x'."
              ,(concat "^e: file://\\(/[^:\n]+\\." hellmacs-forge--source-extension-regexp
                       "\\):\\([0-9]+\\):\\([0-9]+\\)")
              hellmacs-forge--uri-file 2 3 2)
             (hellmacs-kotlin-warning
              ,(concat "^w: file://\\(/[^:\n]+\\." hellmacs-forge--source-extension-regexp
                       "\\):\\([0-9]+\\):\\([0-9]+\\)")
              hellmacs-forge--uri-file 2 3 1)
             (hellmacs-gradle-summary
              ;; Gradle's indented repeat of javac errors: info, so M-g n skips it.
              ,(concat "^[ \t]+\\(/[^:\n]+\\." hellmacs-forge--source-extension-regexp
                       "\\):\\([0-9]+\\): \\(?:error\\|warning\\)")
              1 2 nil 0)))
    (setf (alist-get (car rule) compilation-error-regexp-alist-alist) (cdr rule))
    (add-to-list 'compilation-error-regexp-alist (car rule)))
  ;; Stock `java' also matches JVM frames (marking library frames as
  ;; errors); keep only its other job, Valgrind traces.
  (setf (alist-get 'java compilation-error-regexp-alist-alist)
        '("^==[0-9]+== +\\(?:at\\|b\\(y\\)\\).+(\\([^()\n]+\\):\\([0-9]+\\))$" 2 3 nil (1))))

;;; Announcing results -------------------------------------------------------------

(defcustom hellmacs-forge-messages
  '((tempered  success "[FORGE TEMPERED] Built in %.1fs"   "Build finished in %.1fs")
    (purgatory error   "[BYTECODE PURGATORY] %s"           "Build failed: %s")
    (damnation error   "[TEST DAMNATION] %s"               "Tests failed: %s"))
  "Build result messages: (EVENT FACE THEMED PLAIN).
The PLAIN wording is used when `hellmacs-ux-enable' is nil."
  :type '(repeat (list symbol face string string))
  :group 'hellmacs-forge)

(defvar hellmacs-forge-test-failures-hint nil
  "Text added to the failing tests' message, pointing to where to see them.
:tools test sets it to name its results view.")

(defvar-local hellmacs-forge--started nil
  "When this compilation started (`float-time').")

;;;###autoload
(defun hellmacs-forge--note-start-h (_process)
  "Remember when the compilation in the current buffer started."
  (setq hellmacs-forge--started (float-time)))

(defun hellmacs-forge-announce (event &rest args)
  "Show the message for EVENT (`hellmacs-forge-messages') with ARGS; return it."
  (apply #'hellmacs-announce hellmacs-forge-messages event args))

(defun hellmacs-forge--first-error ()
  "Return \"File:LINE\" for the first error in this compilation, or nil."
  (compilation--ensure-parse (point-max))
  (save-excursion
    (goto-char (point-min))
    (when-let* ((match (text-property-search-forward
                        'compilation-message nil
                        (lambda (_ msg) (and msg (= 2 (compilation--message->type msg)))))))
      (let* ((loc (compilation--message->loc (prop-match-value match)))
             (file (caar (compilation--loc->file-struct loc))))
        (format "%s:%s" (file-name-nondirectory file) (compilation--loc->line loc))))))

(defun hellmacs-forge--test-failures ()
  "Return \"F of N tests\" if this output reports failing tests, else nil."
  (save-excursion
    (goto-char (point-max))
    (cond ((re-search-backward "\\([0-9]+\\) tests? completed, \\([0-9]+\\) failed" nil t) ; Gradle
           (format "%s of %s tests" (match-string 2) (match-string 1)))
          ((re-search-backward ;; Maven's final summary line
            "^\\[ERROR\\] Tests run: \\([0-9]+\\), Failures: \\([0-9]+\\), Errors: \\([0-9]+\\)" nil t)
           (format "%d of %s tests"
                   (+ (string-to-number (match-string 2)) (string-to-number (match-string 3)))
                   (match-string 1))))))

(defun hellmacs-forge--build-problem ()
  "Return the build tool's own one-line reason for failing, or nil.
For failures with no source location: a missing toolchain, dependencies
that don't resolve, a plugin error. Gradle names it under \"What went
wrong\", Maven in its \"Failed to execute goal\" line."
  (save-excursion
    (goto-char (point-min))
    (let ((problem
           (cond ((re-search-forward "^\\* What went wrong:\n\\(\\(?:[^\n>].*\n\\)*?\\)> \\(.+\\)$" nil t)
                  (match-string 2))
                 ((re-search-forward "^\\* What went wrong:\n\\(.+\\)$" nil t)
                  (match-string 1))
                 ((re-search-forward "^\\[ERROR\\] Failed to execute goal .*on project [^ :]+: \\(.+\\)$" nil t)
                  (match-string 1)))))
      (when problem
        (truncate-string-to-width (string-trim problem) 110 nil nil t)))))

;;;###autoload
(defun hellmacs-forge--report-h (buffer status)
  "Announce how the build in BUFFER ended (STATUS from `compile').
For `compilation-finish-functions'. Only real compilations, not grep."
  (with-current-buffer buffer
    (when (eq major-mode 'compilation-mode)
      (let ((ok (string-prefix-p "finished" status))
            (elapsed (if hellmacs-forge--started (- (float-time) hellmacs-forge--started) 0.0)))
        (if ok
            (hellmacs-forge-announce 'tempered elapsed)
          (let ((where (hellmacs-forge--first-error)))
            (if-let* ((tests (hellmacs-forge--test-failures)))
                (hellmacs-forge-announce 'damnation (concat (if where (format "%s (%s)" tests where) tests)
                                                           hellmacs-forge-test-failures-hint))
              (hellmacs-forge-announce 'purgatory (or where (hellmacs-forge--build-problem)
                                                      (string-trim status))))))
        ;; The project's language servers show failed until the next good
        ;; build. (Loaded by any :lang module; without one there's no server.)
        (when (featurep 'hellmacs-lsp-status)
          (hellmacs-lsp-status-build-result default-directory ok))))))
