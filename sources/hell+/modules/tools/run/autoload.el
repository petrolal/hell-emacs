;;; tools/run/autoload.el -*- lexical-binding: t; -*-

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


;; Run configurations: reading them, and running or debugging one.
;;
;; A configuration is a plist:
;;   :name      what the list shows
;;   :main      a main class, run on the classpath JDTLS resolves, or
;;   :task      a build task or goal ("bootRun", "spring-boot:run"), run
;;              through the project's own build (:tools build)
;;   :args      the program's arguments        :jvm-args  JVM options
;;   :env       (("NAME" . "value") ...)       :profiles  Spring profiles
;;   :cwd       working directory              :project   JDTLS project name
;;   :build-args  extra arguments for the build tool itself (tasks)
;;   :source    where it was read from, relative to the project
;;
;; `.hell-emacs/run.eld' holds a list of them, as written above. IntelliJ's
;; `.run/*.run.xml' (Application, Spring Boot, Gradle and Maven types) and
;; Eclipse's `.launch' files (Java application, Spring Boot) are read as
;; they are; other types (JUnit...) are skipped: tests run through :tools
;; build.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'comint)
(require 'compile)

(declare-function hell-forge-build-tool "../build/autoload")
(declare-function hell-spring-discover-profiles "../../lang/java/autoload")
(declare-function hell-jvm--resolve-java-executable "../../lang/java/config")
(declare-function lsp-find-workspace "ext:lsp-mode")
(declare-function lsp--workspace-buffers "ext:lsp-mode")
(declare-function lsp-send-execute-command "ext:lsp-mode")
(declare-function lsp-get "ext:lsp-protocol")
(declare-function dap-debug "ext:dap-mode")
(defvar xml-entity-alist)

(defvar hell-run-debug-port 5005
  "The port a build task's application listens on for the debugger.")

(defconst hell-run--skipped-dirs
  (append hell-ignored-dirs hell-build-output-dirs)
  "Directories never searched for `.launch' files: build output, VCS, IDE state.")

;;; Reading them ---------------------------------------------------------------------

(defun hell-run--split (string)
  "STRING, a command line's arguments, as a list; nil for nil or blank."
  (and string (not (string-blank-p string)) (split-string-shell-command string)))

(defun hell-run--xml (file)
  "The root element of the XML FILE, or nil."
  (require 'xml)
  (car (ignore-errors (xml-parse-file file))))

(defun hell-run--child (node &rest path)
  "The element under NODE at PATH, a list of element names."
  (dolist (name path node)
    (setq node (and node (car (xml-get-children node name))))))

(defun hell-run--expand (value root macros)
  "VALUE with each of MACROS (regexps for the project directory) replaced by ROOT."
  (when value
    (let ((dir (directory-file-name root)))
      (dolist (macro macros)
        (setq value (replace-regexp-in-string macro dir value t t)))
      (expand-file-name value root))))

(defun hell-run--clean (plist)
  "PLIST without its nil values."
  (cl-loop for (key value) on plist by #'cddr
           when value append (list key value)))

;;;###autoload
(defun hell-run-parse-eld (file)
  "The run configurations in FILE, a `.hell-emacs/run.eld'."
  (when (file-readable-p file)
    (let ((root (file-name-directory (directory-file-name (file-name-directory file))))
          (data (with-temp-buffer (insert-file-contents file) (ignore-errors (read (current-buffer))))))
      (mapcar (lambda (config)
                (let ((config (copy-sequence config)))
                  (unless (plist-get config :name)
                    (setq config (plist-put config :name (or (plist-get config :task)
                                                             (car (last (split-string (plist-get config :main) "\\.")))))))
                  (when (plist-get config :cwd)
                    (setq config (plist-put config :cwd (expand-file-name (plist-get config :cwd) root))))
                  config))
              (seq-filter (lambda (c) (and (plistp c) (or (plist-get c :main) (plist-get c :task))))
                          (and (listp data) data))))))

(defconst hell-run--intellij-macros
  '("\\$PROJECT_DIR\\$" "\\$MODULE_DIR\\$" "\\$MODULE_WORKING_DIR\\$")
  "IntelliJ's names for the project directory in run configurations.")

(defun hell-run--intellij-option (node name)
  "The value of NODE's <option name=NAME value=...>."
  (seq-some (lambda (option) (and (equal (xml-get-attribute-or-nil option 'name) name)
                                  (xml-get-attribute-or-nil option 'value)))
            (xml-get-children node 'option)))

(defun hell-run--intellij-list (node name)
  "The values of NODE's <option name=NAME><list><option value=.../>."
  (let ((option (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) name))
                          (xml-get-children node 'option))))
    (delq nil (mapcar (lambda (o) (xml-get-attribute-or-nil o 'value))
                      (xml-get-children (hell-run--child option 'list) 'option)))))

(defun hell-run--intellij-config (config root)
  "One IntelliJ <configuration>, as a run configuration; nil for a type not run here."
  (let ((type (xml-get-attribute-or-nil config 'type))
        (name (xml-get-attribute-or-nil config 'name))
        (env (mapcar (lambda (e) (cons (xml-get-attribute e 'name) (xml-get-attribute e 'value)))
                     (xml-get-children (hell-run--child config 'envs) 'env))))
    (pcase type
      ((or "Application" "SpringBootApplicationConfigurationType")
       (let ((main (or (hell-run--intellij-option config "MAIN_CLASS_NAME")
                       (hell-run--intellij-option config "SPRING_BOOT_MAIN_CLASS"))))
         (when main
           (hell-run--clean
            (list :name name :main main
                  :project (xml-get-attribute-or-nil (hell-run--child config 'module) 'name)
                  :args (hell-run--split (hell-run--intellij-option config "PROGRAM_PARAMETERS"))
                  :jvm-args (hell-run--split (hell-run--intellij-option config "VM_PARAMETERS"))
                  :profiles (let ((p (hell-run--intellij-option config "ACTIVE_PROFILES")))
                              (and p (split-string p "[ \t]*,[ \t]*" t)))
                  :env env
                  :cwd (hell-run--expand (hell-run--intellij-option config "WORKING_DIRECTORY")
                                         root hell-run--intellij-macros))))))
      ("GradleRunConfiguration"
       (let* ((settings (hell-run--child config 'ExternalSystemSettings))
              (tasks (hell-run--intellij-list settings "taskNames")))
         (when tasks
           (hell-run--clean
            (list :name name :task (string-join tasks " ")
                  :build-args (hell-run--split (hell-run--intellij-option settings "scriptParameters"))
                  :env (append env
                               (mapcar (lambda (e) (cons (xml-get-attribute e 'key) (xml-get-attribute e 'value)))
                                       (xml-get-children
                                        (hell-run--child
                                         (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) "env"))
                                                   (xml-get-children settings 'option))
                                         'map)
                                        'entry))))))))
      ("MavenRunConfiguration"
       (let* ((params (hell-run--child
                       (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) "myRunnerParameters"))
                                 (xml-get-children (hell-run--child config 'MavenSettings) 'option))
                       'MavenRunnerParameters))
              (goals (hell-run--intellij-list params "goals")))
         (when goals
           (hell-run--clean
            (list :name name :task (string-join goals " ") :env env
                  :cwd (hell-run--expand (hell-run--intellij-option params "workingDirPath")
                                         root hell-run--intellij-macros)))))))))

;;;###autoload
(defun hell-run-parse-intellij (file)
  "The run configurations in FILE, an IntelliJ `.run/NAME.run.xml'."
  (when-let* ((root-node (hell-run--xml file)))
    (let ((root (file-name-directory (directory-file-name (file-name-directory file)))))
      (delq nil (mapcar (lambda (config) (hell-run--intellij-config config root))
                        (if (eq (xml-node-name root-node) 'configuration)
                            (list root-node)
                          (xml-get-children root-node 'configuration)))))))

(defconst hell-run--eclipse-types
  '("org.eclipse.jdt.launching.localJavaApplication"
    "org.springframework.ide.eclipse.boot.launch")
  "Eclipse launch types run here: a Java application, Spring Tools' Boot app.")

(defconst hell-run--eclipse-macros
  '("\\${\\(?:workspace\\|project\\)_loc\\(?::[^}]*\\)?}")
  "Eclipse's names for the project directory in launch files.")

(defun hell-run--project-root (dir)
  "The build or project root around DIR, else DIR."
  (file-name-as-directory
   (expand-file-name
    (or (locate-dominating-file
         dir (lambda (d) (seq-some (lambda (f) (file-exists-p (expand-file-name f d)))
                                   '("pom.xml" "settings.gradle" "settings.gradle.kts" "build.gradle"
                                     "build.gradle.kts" ".project" ".git"))))
        dir))))

;;;###autoload
(defun hell-run-parse-eclipse (file)
  "The run configuration in FILE, an Eclipse `.launch' file, as a list (or nil)."
  (when-let* ((node (hell-run--xml file)))
    (when (member (xml-get-attribute-or-nil node 'type) hell-run--eclipse-types)
      (let* ((root (hell-run--project-root (file-name-directory file)))
             (attr (lambda (key)
                     (seq-some (lambda (a) (and (equal (xml-get-attribute-or-nil a 'key)
                                                       (concat "org.eclipse.jdt.launching." key))
                                                (xml-get-attribute-or-nil a 'value)))
                               (xml-get-children node 'stringAttribute))))
             (env-map (seq-find (lambda (m) (equal (xml-get-attribute-or-nil m 'key)
                                                   "org.eclipse.debug.core.environmentVariables"))
                                (xml-get-children node 'mapAttribute)))
             (main (funcall attr "MAIN_TYPE")))
        (when main
          (list (hell-run--clean
                 (list :name (file-name-base file) :main main
                       :project (funcall attr "PROJECT_ATTR")
                       :args (hell-run--split (funcall attr "PROGRAM_ARGUMENTS"))
                       :jvm-args (hell-run--split (funcall attr "VM_ARGUMENTS"))
                       :env (mapcar (lambda (e) (cons (xml-get-attribute e 'key) (xml-get-attribute e 'value)))
                                    (xml-get-children env-map 'mapEntry))
                       :cwd (hell-run--expand (funcall attr "WORKING_DIRECTORY")
                                              root hell-run--eclipse-macros)))))))))

(defun hell-run--launch-files (root &optional depth)
  "The `.launch' files in ROOT and its subdirectories, DEPTH levels down (2)."
  (let ((depth (or depth 2)))
    (append (directory-files root t "\\.launch\\'")
            (when (> depth 0)
              (mapcan (lambda (dir) (hell-run--launch-files dir (1- depth)))
                      (seq-filter (lambda (d) (and (file-directory-p d) (not (file-symlink-p d))
                                                   (not (member (file-name-nondirectory d) hell-run--skipped-dirs))))
                                  (directory-files root t directory-files-no-dot-files-regexp)))))))

(defun hell-run--root (&optional dir)
  "The root of the project around DIR (the current directory)."
  (let ((dir (or dir default-directory)))
    (file-name-as-directory
     (or (nth 1 (ignore-errors (hell-forge-build-tool dir)))
         (hell-run--project-root dir)))))

;;;###autoload
(defun hell-run-configurations (&optional root)
  "The project's run configurations: `.hell-emacs/run.eld', `.run/*.run.xml', `.launch'.
In that order; a name that comes again is dropped. ROOT is the project's
root (the current one's by default)."
  (let* ((root (file-name-as-directory (expand-file-name (or root (hell-run--root)))))
         (sources (append
                   (list (cons #'hell-run-parse-eld (expand-file-name ".hell-emacs/run.eld" root)))
                   (mapcar (lambda (f) (cons #'hell-run-parse-intellij f))
                           (let ((dir (expand-file-name ".run" root)))
                             (and (file-directory-p dir) (directory-files dir t "\\.run\\.xml\\'"))))
                   (mapcar (lambda (f) (cons #'hell-run-parse-eclipse f))
                           (hell-run--launch-files root))))
         (seen nil)
         (configs (cl-loop for (parse . file) in sources
                           append (cl-loop for config in (funcall parse file)
                                           for name = (plist-get config :name)
                                           unless (member name seen)
                                           collect (progn (push name seen)
                                                          (plist-put (copy-sequence config) :source
                                                                     (file-relative-name file root)))))))
    (hell-run--with-profiles
     configs (and (fboundp 'hell-spring-discover-profiles)
                  (seq-some #'hell-run--starts-app-p configs)
                  (hell-spring-discover-profiles root)))))

(defun hell-run--starts-app-p (config)
  "Non-nil if CONFIG starts the application: a main class, or a task that runs it."
  (or (plist-get config :main)
      (when-let* ((task (plist-get config :task)))
        (or (hell-run--runnable-task-p task 'gradle)
            (hell-run--runnable-task-p task 'maven)))))

(defun hell-run--with-profiles (configs profiles)
  "CONFIGS, each that starts the application followed by one per Spring PROFILES.
\"App [dev]\" runs App with the dev profile; a configuration that already
chooses its profiles is left alone."
  (mapcan (lambda (config)
            (cons config
                  (and (hell-run--starts-app-p config)
                       (not (plist-get config :profiles))
                       (mapcar (lambda (profile)
                                 (plist-put (plist-put (copy-sequence config) :name
                                                       (format "%s [%s]" (plist-get config :name) profile))
                                            :profiles (list profile)))
                               profiles))))
          configs))

;;; Command lines -----------------------------------------------------------------

(defun hell-run--profiles-jvm-arg (config)
  (when-let* ((profiles (plist-get config :profiles)))
    (concat "-Dspring.profiles.active=" (string-join profiles ","))))

(defun hell-run--java-command (config java classpath)
  "The command line running CONFIG's main class with JAVA on CLASSPATH (a list)."
  `(,java ,@(plist-get config :jvm-args)
          ,@(delq nil (list (hell-run--profiles-jvm-arg config)))
          "-cp" ,(string-join classpath path-separator)
          ,(plist-get config :main)
          ,@(plist-get config :args)))

(defun hell-run--runnable-task-p (task tool)
  "Non-nil if TASK (for TOOL) starts the application, so it takes its arguments."
  (let ((last (car (last (split-string task "[: ]" t)))))
    (pcase tool
      ('gradle (member last '("run" "bootRun")))
      ('maven (string-match-p "\\`spring-boot:run\\'" (car (last (split-string task " " t))))))))

(defun hell-run--jdwp (port)
  (format "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=%d" port))

(defun hell-run--task-command (config build &optional debug)
  "The command line running CONFIG's task with BUILD, (TOOL ROOT PROGRAM).
With DEBUG, the application waits for a debugger on `hell-run-debug-port'."
  (pcase-let* ((`(,tool ,_root ,program) build)
               (task (plist-get config :task))
               (runnable (hell-run--runnable-task-p task tool))
               (app-args (append (and (plist-get config :profiles)
                                      (list (concat "--spring.profiles.active="
                                                    (string-join (plist-get config :profiles) ","))))
                                 (plist-get config :args))))
    (when (and debug (not runnable))
      (user-error "Can't debug `%s': only run and bootRun (Gradle) or spring-boot:run (Maven) start the application"
                  task))
    (pcase tool
      ('gradle
       `(,program ,@(split-string task " " t) "--console=plain"
                  ,@(and debug '("--debug-jvm"))
                  ,@(and runnable app-args (list (concat "--args=" (combine-and-quote-strings app-args))))
                  ,@(plist-get config :build-args)))
      ('maven
       (let ((jvm (append (plist-get config :jvm-args)
                          (and debug (list (hell-run--jdwp hell-run-debug-port))))))
         `(,program "-B" ,@(split-string task " " t)
                    ,@(when runnable
                        (delq nil
                              (list (and (plist-get config :profiles)
                                         (concat "-Dspring-boot.run.profiles="
                                                 (string-join (plist-get config :profiles) ",")))
                                    (and (plist-get config :args)
                                         (concat "-Dspring-boot.run.arguments="
                                                 (combine-and-quote-strings (plist-get config :args))))
                                    (and jvm (concat "-Dspring-boot.run.jvmArguments="
                                                     (string-join jvm " "))))))
                    ,@(plist-get config :build-args)))))))

;;; Running -------------------------------------------------------------------------

(defvar hell-run--last nil
  "(CONFIG ROOT DEBUG) of the last run, for `hell-run-last'.")

(defun hell-run--jdtls ()
  "JDTLS's workspace for this project, or nil."
  (and (fboundp 'lsp-find-workspace) (lsp-find-workspace 'jdtls)))

(defmacro hell-run--with-jdtls (name &rest body)
  "Run BODY in a buffer JDTLS manages; NAME says what needs it."
  (declare (indent 1))
  `(let ((ws (hell-run--jdtls)))
     (unless ws
       (user-error "Running %s needs JDTLS: open one of the project's Java files first" ,name))
     (with-current-buffer (car (lsp--workspace-buffers ws))
       ,@body)))

(defun hell-run--project-name (main)
  "The JDTLS project MAIN (a class) belongs to, or nil."
  (seq-some (lambda (found) (and (equal (lsp-get found :mainClass) main) (lsp-get found :projectName)))
            (append (ignore-errors (lsp-send-execute-command "vscode.java.resolveMainClass")) nil)))

(defun hell-run--start (name command dir env)
  "Run COMMAND (a list) in DIR with ENV (a `process-environment'), in `*run: NAME*'.
A run still going there is stopped first. Returns the buffer."
  (let ((buffer (get-buffer-create (format "*run: %s*" name))))
    (when-let* ((proc (get-buffer-process buffer)))
      (delete-process proc))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)) (erase-buffer))
      (unless (derived-mode-p 'comint-mode) (comint-mode))
      ;; A debug run that died before listening mustn't attach to this one.
      (hell-run--forget-attach)
      (setq default-directory (file-name-as-directory dir))
      ;; comint starts the process from here: the environment must be here
      ;; too, not just in the buffer the run was asked from (envrc's).
      (setq-local process-environment env)
      (compilation-shell-minor-mode 1)
      (insert (format "%s\n\n" (combine-and-quote-strings command)))
      (comint-exec buffer (format "run: %s" name) (car command) nil (cdr command)))
    (display-buffer buffer)
    buffer))

(defun hell-run--environment (config &optional extra)
  "The environment CONFIG runs with: its :env over EXTRA over this buffer's.
EXTRA is a list of \"VAR=value\" strings."
  (append (mapcar (lambda (e) (concat (car e) "=" (cdr e))) (plist-get config :env))
          extra
          process-environment))

(defvar-local hell-run--pending-attach nil
  "(NAME PORT . SEARCHED): attach the debugger to PORT once this run listens.
SEARCHED marks how far the output has been looked through.")

(defun hell-run--attach (name port)
  "Attach the debugger to the JVM run NAME listening on PORT."
  (require 'dap-java)
  (dap-debug (list :type "java" :request "attach" :name (concat name " (attach)")
                   :hostName "localhost" :port port)))

(defun hell-run--forget-attach ()
  "Stop waiting to attach the debugger in this buffer."
  (remove-hook 'comint-output-filter-functions #'hell-run--attach-h t)
  (when-let* ((searched (cddr hell-run--pending-attach)))
    (set-marker searched nil))
  (setq hell-run--pending-attach nil))

(defun hell-run--attach-h (_output)
  "Attach the debugger once the output says the JVM listens (`hell-run--pending-attach').
Only the output not yet looked through is searched, plus a line's worth
before it, in case the line came in two pieces."
  (pcase-let* ((`(,name ,port . ,searched) hell-run--pending-attach)
               (line (format "Listening for transport dt_socket at address: %d" port)))
    (when (save-excursion
            (goto-char (max (point-min) (- searched (length line))))
            (set-marker searched (point-max))
            (search-forward line nil t))
      (hell-run--forget-attach)
      (hell-run--attach name port))))

(defun hell-run--attach-when-listening (buffer name port)
  "Attach the debugger to PORT once BUFFER's output says the JVM listens on it.
Replaces any earlier wait in BUFFER."
  (with-current-buffer buffer
    (hell-run--forget-attach)
    (setq hell-run--pending-attach (cons name (cons port (copy-marker (point-min)))))
    (add-hook 'comint-output-filter-functions #'hell-run--attach-h nil t)))

;;;###autoload
(defun hell-run-config (config &optional debug)
  "Run CONFIG (a run configuration plist); with DEBUG, under the debugger.
Returns the output buffer (for a main class debugged through dap-java,
dap's own)."
  (let* ((root (hell-run--root))
         (name (plist-get config :name))
         (dir (or (plist-get config :cwd) root))
         (env (hell-run--environment config)))
    (setq hell-run--last (list config root debug))
    (cond
     ((plist-get config :task)
      (let* ((build (or (hell-forge-build-tool root)
                        (user-error "No Gradle or Maven build in %s" (abbreviate-file-name root))))
             ;; Gradle on a JDK its release runs on (docs/roadmap.md, 12.7).
             (env (if (eq (car build) 'gradle)
                      (hell-run--environment config (hell-jdk-gradle-environment (nth 1 build)))
                    env))
             (buffer (hell-run--start name (hell-run--task-command config build debug)
                                      (or (plist-get config :cwd) (nth 1 build)) env)))
        (when debug
          (hell-run--attach-when-listening buffer name hell-run-debug-port))
        buffer))
     (debug
      (hell-run--with-jdtls name
        (require 'dap-java)
        (let ((main (plist-get config :main)))
          (dap-debug
           (hell-run--clean
            (list :type "java" :request "launch" :name name :mainClass main
                  :projectName (or (plist-get config :project) (hell-run--project-name main))
                  :args (combine-and-quote-strings (plist-get config :args))
                  :vmArgs (combine-and-quote-strings
                           (append (plist-get config :jvm-args)
                                   (delq nil (list (hell-run--profiles-jvm-arg config)))))
                  :cwd dir
                  :env (let ((table (make-hash-table :test #'equal)))
                         (pcase-dolist (`(,k . ,v) (plist-get config :env)) (puthash k v table))
                         table)))))))
     (t
      (let ((command
             (hell-run--with-jdtls name
               (let* ((main (plist-get config :main))
                      (project (or (plist-get config :project) (hell-run--project-name main)))
                      (paths (lsp-send-execute-command "vscode.java.resolveClasspath" (vector main project)))
                      (classpath (append (elt paths 0) (elt paths 1) nil)))
                 (unless classpath
                   (user-error "JDTLS found no classpath for %s; is it a main class of this project?" main))
                 (hell-run--java-command
                  config (or (and (fboundp 'hell-jvm--resolve-java-executable)
                                  (hell-jvm--resolve-java-executable main project))
                             "java")
                  classpath)))))
        (hell-run--start name command dir env))))))

(defun hell-run--read (prompt)
  "Read a run configuration of this project, with PROMPT."
  (let* ((configs (or (hell-run-configurations)
                      (user-error "No run configurations in %s: add .hell-emacs/run.eld, or IntelliJ's .run/ or Eclipse .launch files"
                                  (abbreviate-file-name (hell-run--root)))))
         (names (mapcar (lambda (c) (plist-get c :name)) configs))
         (completion-extra-properties
          `(:annotation-function
            ,(lambda (name)
               (let ((c (seq-find (lambda (c) (equal (plist-get c :name) name)) configs)))
                 (format "  %s  (%s)" (or (plist-get c :main) (plist-get c :task)) (plist-get c :source)))))))
    (let ((name (completing-read prompt names nil t)))
      (seq-find (lambda (c) (equal (plist-get c :name) name)) configs))))

;;;###autoload
(defun hell-run (config)
  "Run a run configuration of this project (CONFIG, read with completion)."
  (interactive (list (hell-run--read "Run: ")))
  (hell-run-config config))

;;;###autoload
(defun hell-run-debug (config)
  "Debug a run configuration of this project (CONFIG, read with completion)."
  (interactive (list (hell-run--read "Debug: ")))
  (hell-run-config config 'debug))

;;;###autoload
(defun hell-run-last ()
  "Run the last run configuration again, the same way (run or debug)."
  (interactive)
  (pcase-let ((`(,config ,root ,debug) (or hell-run--last (user-error "Nothing has run yet"))))
    (let ((default-directory root))
      (hell-run-config config debug))))
