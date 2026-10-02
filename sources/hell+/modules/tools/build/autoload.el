;;; tools/build/autoload.el -*- lexical-binding: t; -*-

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


(defvar compilation-environment)        ; compile.el

;;; Build tool detection ---------------------------------------------------------

(defconst hell-forge-build-markers
  '(("gradlew" gradle t) ("mvnw" maven t)
    ("settings.gradle" gradle nil) ("settings.gradle.kts" gradle nil)
    ("build.gradle" gradle nil) ("build.gradle.kts" gradle nil)
    ("pom.xml" maven nil))
  "Files that identify a build: (FILE TOOL WRAPPER-P), in order of preference.
A wrapper's directory is the build's root, so a module inside a
multi-module build still builds from the top.")

(defun hell-forge--build-root-p (root tool)
  "Non-nil if directory ROOT holds a build file (not a wrapper) of TOOL.
A wrapper next to none of them (a leftover ./gradlew in a Maven
project) isn't that tool's build."
  (seq-some (pcase-lambda (`(,file ,marker-tool ,wrapper))
              (and (not wrapper) (eq marker-tool tool)
                   (file-exists-p (expand-file-name file root))))
            hell-forge-build-markers))

;;;###autoload
(defun hell-forge-build-tool (&optional dir)
  "Return (TOOL ROOT PROGRAM) for the build containing DIR, or nil.
TOOL is `gradle' or `maven'; ROOT the directory to run it in; PROGRAM
the wrapper (\"./gradlew\") if there is one, else the installed tool."
  (let ((dir (or dir default-directory)))
    (seq-some (pcase-lambda (`(,file ,tool ,wrapper))
                (when-let* ((root (locate-dominating-file dir file)))
                  (when (or (not wrapper) (hell-forge--build-root-p root tool))
                    (list tool (file-name-as-directory (expand-file-name root))
                          (cond (wrapper (concat "./" file))
                                ((eq tool 'gradle) "gradle")
                                (t "mvn"))))))
              hell-forge-build-markers)))

(defun hell-forge--command (task &optional test build)
  "Return the shell command for TASK (`build' or `test') in the current build.
TEST narrows `test' to a class (\"pkg.Class\") or method (\"pkg.Class#method\"),
or a list of them. BUILD is the build's (TOOL ROOT PROGRAM), if already known."
  (pcase-let ((`(,tool ,_root ,program) (or build (hell-forge-build-tool)
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

(defvar-local hell-forge--added-environment nil
  "The entries `hell-forge-setup-build-h' put in `compilation-environment'.")

;;;###autoload
(define-minor-mode hell-forge-mode
  "This buffer builds and tests with its project's build tool.
Turned on by `hell-forge-setup-build-h'; it gives the buffer the
tests' `C-c l t' group."
  :lighter nil)

;;;###autoload
(defun hell-forge-setup-build-h ()
  "Make `compile-command' (and so `C-x p c') the build's own build command.
Builds started from this buffer get your proxy and CA
\(`hell-net-jvm-options') in JAVA_TOOL_OPTIONS, which every JVM a
Gradle or Maven build starts reads: the client, the daemon, the tests.
Gradle builds run on a JDK their Gradle release runs on
\(`hell-jdk-gradle-environment')."
  ;; What an earlier run set goes first: the hook runs again on a revert
  ;; or a mode change, and must replace it, not add to it.
  (when hell-forge--added-environment
    (setq-local compilation-environment
                (seq-remove (lambda (e) (member e hell-forge--added-environment))
                            compilation-environment)))
  (let ((build (hell-forge-build-tool))
        added)
    (when-let* ((command (and build (ignore-errors (hell-forge--command 'build build)))))
      (setq-local compile-command command))
    (when-let* ((env (and (eq (car build) 'gradle) (hell-jdk-gradle-environment (nth 1 build)))))
      (setq added (append env added)))
    (when-let* ((options (hell-net-jvm-options)))
      (push (concat "JAVA_TOOL_OPTIONS="
                    (string-join (append (split-string (or (getenv "JAVA_TOOL_OPTIONS") "") " " t)
                                         options)
                                 " "))
            added))
    (when added
      ;; compile.el may not be loaded yet (this runs as the file opens): the
      ;; buffer-local value then simply starts from its default, nil.
      (setq-local compilation-environment (append added (bound-and-true-p compilation-environment))))
    (setq-local hell-forge--added-environment added))
  (hell-forge-mode 1))

;;; Running builds and tests -----------------------------------------------------

(defun hell-forge--run (task &optional test)
  "Run TASK (and TEST) as `hell-forge--command' with `compile', from the build's root."
  (let* ((build (or (hell-forge-build-tool) (user-error "No Gradle or Maven build here")))
         (default-directory (nth 1 build)))
    (compile (hell-forge--command task test build))))

(defvar-local hell-forge-test-class-function #'hell-forge-file-class
  "Function returning the fully qualified name of the buffer's test class.
Languages whose files don't follow the file-name rule set their own.")

(defvar-local hell-forge-test-run-function nil
  "Function running this buffer's tests instead of the build tool, or nil.
Called with `method' (the test at point) or `class'. Java's, under
`:tools debugger', runs them through dap-java.")

(defvar-local hell-forge-test-method-function nil
  "Function returning the name of the test method around point, or nil.
Set by each language (it knows what a test method looks like); without
one, `hell-forge-test-at-point' runs the whole class.")

(defconst hell-forge-test-annotation-regexp
  (concat "@\\(?:[[:alnum:]_]+\\.\\)*"
          (regexp-opt '("Test" "ParameterizedTest" "RepeatedTest" "TestFactory" "TestTemplate") t)
          "\\_>")
  "JUnit's (4 and 5) annotations of a test method, qualified or not.")

;;;###autoload
(defun hell-forge-annotated-test-at-point (name-regexp)
  "The name of the JUnit test method point is in, or nil.
Point is in it from its annotations to its body's closing brace; in a
helper or setup method, or between methods, there is none. NAME-REGEXP
finds the method's name after its annotations, in group 1 or 2."
  (let ((pos (point)))
    (save-excursion
      (end-of-line)
      (when (re-search-backward hell-forge-test-annotation-regexp nil t)
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
(defun hell-forge-package ()
  "The package the current buffer's file declares (\"dev.x\"), or nil.
The same line in Java, Kotlin, Groovy and Scala, with or without a `;'."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^[ \t]*package[ \t]+\\([a-zA-Z0-9_.]+\\)[ \t]*;?[ \t]*$" nil t)
      (match-string-no-properties 1))))

;;;###autoload
(defun hell-forge-qualify (class)
  "CLASS, qualified with the current buffer's package."
  (if-let* ((package (hell-forge-package))) (concat package "." class) class))

;;;###autoload
(defun hell-forge-file-class ()
  "The class named after the current file, qualified: the JVM convention (Java's rule)."
  (hell-forge-qualify
   (file-name-base (or buffer-file-name (user-error "Not visiting a file")))))

(defun hell-forge--test-class ()
  (funcall hell-forge-test-class-function))

;;;###autoload
(defun hell-forge-build ()
  "Build the current project with its build tool (Gradle or Maven)."
  (interactive)
  (hell-forge--run 'build))

;;;###autoload
(defun hell-forge-test-at-point ()
  "Run the test method at point with the build tool (the whole class if none).
Or with `hell-forge-test-run-function', when the language sets one."
  (interactive)
  (if hell-forge-test-run-function
      (funcall hell-forge-test-run-function 'method)
    (let ((method (and hell-forge-test-method-function
                     (funcall hell-forge-test-method-function))))
      (hell-forge--run 'test (concat (hell-forge--test-class)
                                     (and method (concat "#" method)))))))

;;;###autoload
(defun hell-forge-test-class ()
  "Run every test in the current class with the build tool.
Or with `hell-forge-test-run-function', when the language sets one."
  (interactive)
  (if hell-forge-test-run-function
      (funcall hell-forge-test-run-function 'class)
    (hell-forge--run 'test (hell-forge--test-class))))

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

(defvar hell-forge--source-indexes (make-hash-table :test #'equal)
  "Build root -> its source index (base name -> paths), kept across builds.")

(defvar hell-forge--source-index-roots nil
  "The roots in `hell-forge--source-indexes', most recently used first.")

(defvar hell-forge-source-index-limit 8
  "How many build roots' source indexes are kept across builds.
Each holds the path of every source file in its project.")

(defun hell-forge--cached-index (root)
  "ROOT's kept source index, or nil; it becomes the most recently used."
  (when-let* ((index (gethash root hell-forge--source-indexes)))
    (setq hell-forge--source-index-roots
          (cons root (delete root hell-forge--source-index-roots)))
    index))

(defun hell-forge--remember-index (root index)
  "Keep INDEX as ROOT's, dropping the least recently used beyond the limit.
Returns INDEX."
  (puthash root index hell-forge--source-indexes)
  (setq hell-forge--source-index-roots
        (cons root (delete root hell-forge--source-index-roots)))
  (when-let* ((old (nthcdr hell-forge-source-index-limit hell-forge--source-index-roots)))
    (dolist (gone old) (remhash gone hell-forge--source-indexes))
    (setq hell-forge--source-index-roots
          (seq-take hell-forge--source-index-roots hell-forge-source-index-limit)))
  index)

(defvar-local hell-forge--source-index nil
  "This compilation's source index: base name -> its paths in the project.")

(defvar-local hell-forge--index-refreshed nil
  "Non-nil once this compilation has walked the project again for a missing file.")

(defvar-local hell-forge--project-packages nil
  "This compilation's answers to \"has the project sources in package P?\".")

(defconst hell-forge--ignored-dirs hell-ignored-dirs
  "Directories never searched for source files, besides build output.")

(defconst hell-forge-source-extensions '("java" "kt" "kts" "groovy" "scala")
  "Extensions of the JVM source files builds, stack traces and test failures name.")

(defconst hell-forge--source-extension-regexp (regexp-opt hell-forge-source-extensions)
  "Matches one of `hell-forge-source-extensions' (without the dot).")

(defconst hell-forge--source-regexp (concat "\\." hell-forge--source-extension-regexp "\\'")
  "Names of the source files stack frames and test failures point at.")

(defun hell-forge--source-root ()
  "The directory whose source files this compilation's links may point to.
The build's root (`hell-forge-build-tool'), else the project's; nil
outside both, so a `compile' run in ~ never has all of ~ searched."
  (or (nth 1 (hell-forge-build-tool))
      (when-let* ((project (project-current nil default-directory)))
        (project-root project))))

(defun hell-forge--build-index (root)
  "Walk ROOT for source files; return base name -> paths."
  (let ((index (make-hash-table :test #'equal))
        (output (hell-build-output-regexp root)))
    (dolist (path (directory-files-recursively
                   root hell-forge--source-regexp nil
                   (lambda (dir) (not (or (member (file-name-nondirectory dir)
                                                  hell-forge--ignored-dirs)
                                          (string-match-p output dir))))))
      (push path (gethash (file-name-nondirectory path) index)))
    index))

(defun hell-forge--source-index (&optional refresh)
  "The project's source index, from the last build of it, or walked now.
Kept per build root across builds, since a project's files rarely change
between them; REFRESH walks it again. Empty outside a build or project,
so a `compile' run in ~ never has all of ~ searched."
  (if (and hell-forge--source-index (not refresh))
      hell-forge--source-index
    (setq hell-forge--source-index
          (if-let* ((root (hell-forge--source-root)))
              (or (and (not refresh) (hell-forge--cached-index root))
                  (hell-forge--remember-index root (hell-forge--build-index root)))
            (make-hash-table :test #'equal)))))

(defun hell-forge--lookup (file suffix)
  (seq-find (lambda (path) (string-suffix-p suffix path))
            (gethash file (hell-forge--source-index))))

(defun hell-forge--project-package-p (package)
  "Non-nil if the project has sources in PACKAGE's directory (remembered)."
  (let ((dir (concat "/" (string-replace "." "/" package) "/")))
    (eq 'yes
        (with-memoization (alist-get package hell-forge--project-packages nil nil #'equal)
          (catch 'found
            (maphash (lambda (_ paths)
                       (when (seq-some (lambda (path) (string-search dir path)) paths)
                         (throw 'found 'yes)))
                     (hell-forge--source-index))
            'no)))))

(defun hell-forge--find-source (file &optional package)
  "Find source FILE (a base name) in the project, under PACKAGE's directory.
PACKAGE is dotted (\"dev.hell-emacs.demo\"); nil means any directory.
Returns a path or nil. A file the index doesn't have may be new since
it was made: the project is walked again, once per compilation, if the
file could be the project's (no package, or one the project has; not
a JDK or library frame)."
  (let ((suffix (concat "/" (if package (concat (string-replace "." "/" package) "/") "") file)))
    (or (hell-forge--lookup file suffix)
        (when (and (not hell-forge--index-refreshed)
                   (or (null package) (hell-forge--project-package-p package)))
          (setq hell-forge--index-refreshed t)
          (hell-forge--source-index 'refresh)
          (hell-forge--lookup file suffix)))))

(defun hell-forge--frame-file ()
  "FILE function for `hell-jvm-frame': the frame's file, if in the project.
Preserves the match data: compile.el reads the line number from it next."
  (let ((package (match-string-no-properties 1))
        (file (match-string-no-properties 2)))
    (save-match-data
      (hell-forge--find-source file (and (not (string-empty-p package))
                                              (string-remove-suffix "." package))))))

(defun hell-forge--uri-file ()
  "FILE function for the Kotlin compiler rules: the `file://' path, if it exists.
Gradle prints Kotlin errors as \"e: file:///abs/Foo.kt:6:22 message\", with
the path percent-encoded. Preserves the match data."
  (require 'url-util)
  (let ((path (match-string-no-properties 1)))
    (save-match-data
      (let ((file (url-unhex-string path)))
        (and (file-exists-p file) file)))))

(defun hell-forge--basename-file ()
  "FILE function for `hell-gradle-test': the named file, if in the project.
Preserves the match data: compile.el reads the line number from it next."
  (let ((file (match-string-no-properties 1)))
    (save-match-data (hell-forge--find-source file))))

;;;###autoload
(defun hell-forge--add-error-regexps ()
  "Register Hell Emacs' JVM error rules with `compile'."
  (dolist (rule
           `((hell-jvm-frame
              ;; "at pkg.Class.method(File.java:12)", optionally "java.base/pkg..."
              ,(concat "^[ \t]+at \\(?:[^ \t\n/(]+/\\)?"
                       "\\(\\(?:[a-zA-Z_$][a-zA-Z0-9_$]*\\.\\)*\\)"   ; 1: package (with dot)
                       "[a-zA-Z_$][a-zA-Z0-9_$]*\\.[^.(\n]+"          ; Class.method
                       "(\\([^():\n]+\\." hell-forge--source-extension-regexp "\\):\\([0-9]+\\))")
              hell-forge--frame-file 3)
             (hell-gradle-test
              ;; "    org.opentest4j.AssertionFailedError at FooTest.java:16"
              ,(concat "^[ \t]+[^ \t\n]+ at \\([^ \t\n:/]+\\." hell-forge--source-extension-regexp
                       "\\):\\([0-9]+\\)$")
              hell-forge--basename-file 2)
             (hell-kotlin-error
              ;; "e: file:///abs/Foo.kt:6:22 Unresolved reference 'x'."
              ,(concat "^e: file://\\(/[^:\n]+\\." hell-forge--source-extension-regexp
                       "\\):\\([0-9]+\\):\\([0-9]+\\)")
              hell-forge--uri-file 2 3 2)
             (hell-kotlin-warning
              ,(concat "^w: file://\\(/[^:\n]+\\." hell-forge--source-extension-regexp
                       "\\):\\([0-9]+\\):\\([0-9]+\\)")
              hell-forge--uri-file 2 3 1)
             (hell-gradle-summary
              ;; Gradle's indented repeat of javac errors: info, so M-g n skips it.
              ,(concat "^[ \t]+\\(/[^:\n]+\\." hell-forge--source-extension-regexp
                       "\\):\\([0-9]+\\): \\(?:error\\|warning\\)")
              1 2 nil 0)))
    (setf (alist-get (car rule) compilation-error-regexp-alist-alist) (cdr rule))
    (add-to-list 'compilation-error-regexp-alist (car rule)))
  ;; Stock `java' also matches JVM frames (marking library frames as
  ;; errors); keep only its other job, Valgrind traces.
  (setf (alist-get 'java compilation-error-regexp-alist-alist)
        '("^==[0-9]+== +\\(?:at\\|b\\(y\\)\\).+(\\([^()\n]+\\):\\([0-9]+\\))$" 2 3 nil (1))))

;;; Announcing results -------------------------------------------------------------

(defcustom hell-forge-messages
  '((tempered  success "[FORGE TEMPERED] Built in %.1fs"   "Build finished in %.1fs")
    (purgatory error   "[BYTECODE PURGATORY] %s"           "Build failed: %s")
    (damnation error   "[TEST DAMNATION] %s"               "Tests failed: %s"))
  "Build result messages: (EVENT FACE THEMED PLAIN).
The PLAIN wording is used when `hell-ux-enable' is nil."
  :type '(repeat (list symbol face string string))
  :group 'hell-forge)

(defvar hell-forge-test-failures-hint nil
  "Text added to the failing tests' message, pointing to where to see them.
:tools test sets it to name its results view.")

(defvar-local hell-forge--started nil
  "When this compilation started (`float-time').")

;;;###autoload
(defun hell-forge--note-start-h (_process)
  "Remember when the compilation in the current buffer started."
  (setq hell-forge--started (float-time)))

(defun hell-forge-announce (event &rest args)
  "Show the message for EVENT (`hell-forge-messages') with ARGS; return it."
  (apply #'hell-announce hell-forge-messages event args))

(defun hell-forge--first-error ()
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

(defun hell-forge--test-failures ()
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

(defun hell-forge--build-problem ()
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
(defun hell-forge--report-h (buffer status)
  "Announce how the build in BUFFER ended (STATUS from `compile').
For `compilation-finish-functions'. Only real compilations, not grep."
  (with-current-buffer buffer
    (when (eq major-mode 'compilation-mode)
      (let ((ok (string-prefix-p "finished" status))
            (elapsed (if hell-forge--started (- (float-time) hell-forge--started) 0.0)))
        (if ok
            (hell-forge-announce 'tempered elapsed)
          (let ((where (hell-forge--first-error)))
            (if-let* ((tests (hell-forge--test-failures)))
                (hell-forge-announce 'damnation (concat (if where (format "%s (%s)" tests where) tests)
                                                           hell-forge-test-failures-hint))
              (hell-forge-announce 'purgatory (or where (hell-forge--build-problem)
                                                  (string-trim status))))))
        ;; The project's language servers show failed until the next good
        ;; build. (Loaded by any :lang module; without one there's no server.)
        (when (hell-featurep 'hell-lib 'lsp-status)
          (hell-lsp-status-build-result default-directory ok))))))
