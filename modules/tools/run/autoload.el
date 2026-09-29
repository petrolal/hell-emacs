;;; tools/run/autoload.el -*- lexical-binding: t; -*-

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
;; `.hellmacs/run.eld' holds a list of them, as written above. IntelliJ's
;; `.run/*.run.xml' (Application, Spring Boot, Gradle and Maven types) and
;; Eclipse's `.launch' files (Java application, Spring Boot) are read as
;; they are; other types (JUnit...) are skipped: tests run through :tools
;; build.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'comint)
(require 'compile)

(declare-function hellmacs-forge-build-tool "../build/autoload")
(declare-function hellmacs-spring-discover-profiles "../../lang/java/autoload")
(declare-function hellmacs-jvm--resolve-java-executable "../../lang/java/config")
(declare-function lsp-find-workspace "ext:lsp-mode")
(declare-function lsp--workspace-buffers "ext:lsp-mode")
(declare-function lsp-send-execute-command "ext:lsp-mode")
(declare-function lsp-get "ext:lsp-protocol")
(declare-function dap-debug "ext:dap-mode")
(defvar xml-entity-alist)

(defvar hellmacs-run-debug-port 5005
  "The port a build task's application listens on for the debugger.")

(defconst hellmacs-run--skipped-dirs
  '(".git" ".hg" ".svn" "build" "target" "out" "bin" ".gradle" ".idea" "node_modules")
  "Directories never searched for `.launch' files: build output, VCS, IDE state.")

;;; Reading them ---------------------------------------------------------------------

(defun hellmacs-run--split (string)
  "STRING, a command line's arguments, as a list; nil for nil or blank."
  (and string (not (string-blank-p string)) (split-string-shell-command string)))

(defun hellmacs-run--xml (file)
  "The root element of the XML FILE, or nil."
  (require 'xml)
  (car (ignore-errors (xml-parse-file file))))

(defun hellmacs-run--child (node &rest path)
  "The element under NODE at PATH, a list of element names."
  (dolist (name path node)
    (setq node (and node (car (xml-get-children node name))))))

(defun hellmacs-run--expand (value root macros)
  "VALUE with each of MACROS (regexps for the project directory) replaced by ROOT."
  (when value
    (let ((dir (directory-file-name root)))
      (dolist (macro macros)
        (setq value (replace-regexp-in-string macro dir value t t)))
      (expand-file-name value root))))

(defun hellmacs-run--clean (plist)
  "PLIST without its nil values."
  (cl-loop for (key value) on plist by #'cddr
           when value append (list key value)))

;;;###autoload
(defun hellmacs-run-parse-eld (file)
  "The run configurations in FILE, a `.hellmacs/run.eld'."
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

(defconst hellmacs-run--intellij-macros
  '("\\$PROJECT_DIR\\$" "\\$MODULE_DIR\\$" "\\$MODULE_WORKING_DIR\\$")
  "IntelliJ's names for the project directory in run configurations.")

(defun hellmacs-run--intellij-option (node name)
  "The value of NODE's <option name=NAME value=...>."
  (seq-some (lambda (option) (and (equal (xml-get-attribute-or-nil option 'name) name)
                                  (xml-get-attribute-or-nil option 'value)))
            (xml-get-children node 'option)))

(defun hellmacs-run--intellij-list (node name)
  "The values of NODE's <option name=NAME><list><option value=.../>."
  (let ((option (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) name))
                          (xml-get-children node 'option))))
    (delq nil (mapcar (lambda (o) (xml-get-attribute-or-nil o 'value))
                      (xml-get-children (hellmacs-run--child option 'list) 'option)))))

(defun hellmacs-run--intellij-config (config root)
  "One IntelliJ <configuration>, as a run configuration; nil for a type not run here."
  (let ((type (xml-get-attribute-or-nil config 'type))
        (name (xml-get-attribute-or-nil config 'name))
        (env (mapcar (lambda (e) (cons (xml-get-attribute e 'name) (xml-get-attribute e 'value)))
                     (xml-get-children (hellmacs-run--child config 'envs) 'env))))
    (pcase type
      ((or "Application" "SpringBootApplicationConfigurationType")
       (let ((main (or (hellmacs-run--intellij-option config "MAIN_CLASS_NAME")
                       (hellmacs-run--intellij-option config "SPRING_BOOT_MAIN_CLASS"))))
         (when main
           (hellmacs-run--clean
            (list :name name :main main
                  :project (xml-get-attribute-or-nil (hellmacs-run--child config 'module) 'name)
                  :args (hellmacs-run--split (hellmacs-run--intellij-option config "PROGRAM_PARAMETERS"))
                  :jvm-args (hellmacs-run--split (hellmacs-run--intellij-option config "VM_PARAMETERS"))
                  :profiles (let ((p (hellmacs-run--intellij-option config "ACTIVE_PROFILES")))
                              (and p (split-string p "[ \t]*,[ \t]*" t)))
                  :env env
                  :cwd (hellmacs-run--expand (hellmacs-run--intellij-option config "WORKING_DIRECTORY")
                                             root hellmacs-run--intellij-macros))))))
      ("GradleRunConfiguration"
       (let* ((settings (hellmacs-run--child config 'ExternalSystemSettings))
              (tasks (hellmacs-run--intellij-list settings "taskNames")))
         (when tasks
           (hellmacs-run--clean
            (list :name name :task (string-join tasks " ")
                  :build-args (hellmacs-run--split (hellmacs-run--intellij-option settings "scriptParameters"))
                  :env (append env
                               (mapcar (lambda (e) (cons (xml-get-attribute e 'key) (xml-get-attribute e 'value)))
                                       (xml-get-children
                                        (hellmacs-run--child
                                         (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) "env"))
                                                   (xml-get-children settings 'option))
                                         'map)
                                        'entry))))))))
      ("MavenRunConfiguration"
       (let* ((params (hellmacs-run--child
                       (seq-find (lambda (o) (equal (xml-get-attribute-or-nil o 'name) "myRunnerParameters"))
                                 (xml-get-children (hellmacs-run--child config 'MavenSettings) 'option))
                       'MavenRunnerParameters))
              (goals (hellmacs-run--intellij-list params "goals")))
         (when goals
           (hellmacs-run--clean
            (list :name name :task (string-join goals " ") :env env
                  :cwd (hellmacs-run--expand (hellmacs-run--intellij-option params "workingDirPath")
                                             root hellmacs-run--intellij-macros)))))))))

;;;###autoload
(defun hellmacs-run-parse-intellij (file)
  "The run configurations in FILE, an IntelliJ `.run/NAME.run.xml'."
  (when-let* ((root-node (hellmacs-run--xml file)))
    (let ((root (file-name-directory (directory-file-name (file-name-directory file)))))
      (delq nil (mapcar (lambda (config) (hellmacs-run--intellij-config config root))
                        (if (eq (xml-node-name root-node) 'configuration)
                            (list root-node)
                          (xml-get-children root-node 'configuration)))))))

(defconst hellmacs-run--eclipse-types
  '("org.eclipse.jdt.launching.localJavaApplication"
    "org.springframework.ide.eclipse.boot.launch")
  "Eclipse launch types run here: a Java application, Spring Tools' Boot app.")

(defconst hellmacs-run--eclipse-macros
  '("\\${\\(?:workspace\\|project\\)_loc\\(?::[^}]*\\)?}")
  "Eclipse's names for the project directory in launch files.")

(defun hellmacs-run--project-root (dir)
  "The build or project root around DIR, else DIR."
  (file-name-as-directory
   (expand-file-name
    (or (locate-dominating-file
         dir (lambda (d) (seq-some (lambda (f) (file-exists-p (expand-file-name f d)))
                                   '("pom.xml" "settings.gradle" "settings.gradle.kts" "build.gradle"
                                     "build.gradle.kts" ".project" ".git"))))
        dir))))

;;;###autoload
(defun hellmacs-run-parse-eclipse (file)
  "The run configuration in FILE, an Eclipse `.launch' file, as a list (or nil)."
  (when-let* ((node (hellmacs-run--xml file)))
    (when (member (xml-get-attribute-or-nil node 'type) hellmacs-run--eclipse-types)
      (let* ((root (hellmacs-run--project-root (file-name-directory file)))
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
          (list (hellmacs-run--clean
                 (list :name (file-name-base file) :main main
                       :project (funcall attr "PROJECT_ATTR")
                       :args (hellmacs-run--split (funcall attr "PROGRAM_ARGUMENTS"))
                       :jvm-args (hellmacs-run--split (funcall attr "VM_ARGUMENTS"))
                       :env (mapcar (lambda (e) (cons (xml-get-attribute e 'key) (xml-get-attribute e 'value)))
                                    (xml-get-children env-map 'mapEntry))
                       :cwd (hellmacs-run--expand (funcall attr "WORKING_DIRECTORY")
                                                  root hellmacs-run--eclipse-macros)))))))))

(defun hellmacs-run--launch-files (root &optional depth)
  "The `.launch' files in ROOT and its subdirectories, DEPTH levels down (2)."
  (let ((depth (or depth 2)))
    (append (directory-files root t "\\.launch\\'")
            (when (> depth 0)
              (mapcan (lambda (dir) (hellmacs-run--launch-files dir (1- depth)))
                      (seq-filter (lambda (d) (and (file-directory-p d) (not (file-symlink-p d))
                                                   (not (member (file-name-nondirectory d) hellmacs-run--skipped-dirs))))
                                  (directory-files root t directory-files-no-dot-files-regexp)))))))

(defun hellmacs-run--root (&optional dir)
  "The root of the project around DIR (the current directory)."
  (let ((dir (or dir default-directory)))
    (file-name-as-directory
     (or (nth 1 (ignore-errors (hellmacs-forge-build-tool dir)))
         (hellmacs-run--project-root dir)))))

;;;###autoload
(defun hellmacs-run-configurations (&optional root)
  "The project's run configurations: `.hellmacs/run.eld', `.run/*.run.xml', `.launch'.
In that order; a name that comes again is dropped. ROOT is the project's
root (the current one's by default)."
  (let* ((root (file-name-as-directory (expand-file-name (or root (hellmacs-run--root)))))
         (sources (append
                   (list (cons #'hellmacs-run-parse-eld (expand-file-name ".hellmacs/run.eld" root)))
                   (mapcar (lambda (f) (cons #'hellmacs-run-parse-intellij f))
                           (let ((dir (expand-file-name ".run" root)))
                             (and (file-directory-p dir) (directory-files dir t "\\.run\\.xml\\'"))))
                   (mapcar (lambda (f) (cons #'hellmacs-run-parse-eclipse f))
                           (hellmacs-run--launch-files root))))
         (seen nil)
         (configs (cl-loop for (parse . file) in sources
                           append (cl-loop for config in (funcall parse file)
                                           for name = (plist-get config :name)
                                           unless (member name seen)
                                           collect (progn (push name seen)
                                                          (plist-put (copy-sequence config) :source
                                                                     (file-relative-name file root)))))))
    (hellmacs-run--with-profiles
     configs (and (fboundp 'hellmacs-spring-discover-profiles)
                  (seq-some #'hellmacs-run--starts-app-p configs)
                  (hellmacs-spring-discover-profiles root)))))

(defun hellmacs-run--starts-app-p (config)
  "Non-nil if CONFIG starts the application: a main class, or a task that runs it."
  (or (plist-get config :main)
      (when-let* ((task (plist-get config :task)))
        (or (hellmacs-run--runnable-task-p task 'gradle)
            (hellmacs-run--runnable-task-p task 'maven)))))

(defun hellmacs-run--with-profiles (configs profiles)
  "CONFIGS, each that starts the application followed by one per Spring PROFILES.
\"App [dev]\" runs App with the dev profile; a configuration that already
chooses its profiles is left alone."
  (mapcan (lambda (config)
            (cons config
                  (and (hellmacs-run--starts-app-p config)
                       (not (plist-get config :profiles))
                       (mapcar (lambda (profile)
                                 (plist-put (plist-put (copy-sequence config) :name
                                                       (format "%s [%s]" (plist-get config :name) profile))
                                            :profiles (list profile)))
                               profiles))))
          configs))

;;; Command lines -----------------------------------------------------------------

(defun hellmacs-run--profiles-jvm-arg (config)
  (when-let* ((profiles (plist-get config :profiles)))
    (concat "-Dspring.profiles.active=" (string-join profiles ","))))

(defun hellmacs-run--java-command (config java classpath)
  "The command line running CONFIG's main class with JAVA on CLASSPATH (a list)."
  `(,java ,@(plist-get config :jvm-args)
          ,@(delq nil (list (hellmacs-run--profiles-jvm-arg config)))
          "-cp" ,(string-join classpath path-separator)
          ,(plist-get config :main)
          ,@(plist-get config :args)))

(defun hellmacs-run--runnable-task-p (task tool)
  "Non-nil if TASK (for TOOL) starts the application, so it takes its arguments."
  (let ((last (car (last (split-string task "[: ]" t)))))
    (pcase tool
      ('gradle (member last '("run" "bootRun")))
      ('maven (string-match-p "\\`spring-boot:run\\'" (car (last (split-string task " " t))))))))

(defun hellmacs-run--jdwp (port)
  (format "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=%d" port))

(defun hellmacs-run--task-command (config build &optional debug)
  "The command line running CONFIG's task with BUILD, (TOOL ROOT PROGRAM).
With DEBUG, the application waits for a debugger on `hellmacs-run-debug-port'."
  (pcase-let* ((`(,tool ,_root ,program) build)
               (task (plist-get config :task))
               (runnable (hellmacs-run--runnable-task-p task tool))
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
                          (and debug (list (hellmacs-run--jdwp hellmacs-run-debug-port))))))
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

(defvar hellmacs-run--last nil
  "(CONFIG ROOT DEBUG) of the last run, for `hellmacs-run-last'.")

(defun hellmacs-run--jdtls ()
  "JDTLS's workspace for this project, or nil."
  (and (fboundp 'lsp-find-workspace) (lsp-find-workspace 'jdtls)))

(defmacro hellmacs-run--with-jdtls (name &rest body)
  "Run BODY in a buffer JDTLS manages; NAME says what needs it."
  (declare (indent 1))
  `(let ((ws (hellmacs-run--jdtls)))
     (unless ws
       (user-error "Running %s needs JDTLS: open one of the project's Java files first" ,name))
     (with-current-buffer (car (lsp--workspace-buffers ws))
       ,@body)))

(defun hellmacs-run--project-name (main)
  "The JDTLS project MAIN (a class) belongs to, or nil."
  (seq-some (lambda (found) (and (equal (lsp-get found :mainClass) main) (lsp-get found :projectName)))
            (append (ignore-errors (lsp-send-execute-command "vscode.java.resolveMainClass")) nil)))

(defun hellmacs-run--start (name command dir env)
  "Run COMMAND (a list) in DIR with ENV (a `process-environment'), in `*run: NAME*'.
A run still going there is stopped first. Returns the buffer."
  (let ((buffer (get-buffer-create (format "*run: %s*" name))))
    (when-let* ((proc (get-buffer-process buffer)))
      (delete-process proc))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)) (erase-buffer))
      (unless (derived-mode-p 'comint-mode) (comint-mode))
      ;; A debug run that died before listening mustn't attach to this one.
      (hellmacs-run--forget-attach)
      (setq default-directory (file-name-as-directory dir))
      ;; comint starts the process from here: the environment must be here
      ;; too, not just in the buffer the run was asked from (envrc's).
      (setq-local process-environment env)
      (compilation-shell-minor-mode 1)
      (insert (format "%s\n\n" (combine-and-quote-strings command)))
      (comint-exec buffer (format "run: %s" name) (car command) nil (cdr command)))
    (display-buffer buffer)
    buffer))

(defun hellmacs-run--environment (config)
  "The environment CONFIG runs with: its :env over this buffer's."
  (append (mapcar (lambda (e) (concat (car e) "=" (cdr e))) (plist-get config :env))
          process-environment))

(defvar-local hellmacs-run--pending-attach nil
  "(NAME PORT . SEARCHED): attach the debugger to PORT once this run listens.
SEARCHED marks how far the output has been looked through.")

(defun hellmacs-run--attach (name port)
  "Attach the debugger to the JVM run NAME listening on PORT."
  (require 'dap-java)
  (dap-debug (list :type "java" :request "attach" :name (concat name " (attach)")
                   :hostName "localhost" :port port)))

(defun hellmacs-run--forget-attach ()
  "Stop waiting to attach the debugger in this buffer."
  (remove-hook 'comint-output-filter-functions #'hellmacs-run--attach-h t)
  (when-let* ((searched (cddr hellmacs-run--pending-attach)))
    (set-marker searched nil))
  (setq hellmacs-run--pending-attach nil))

(defun hellmacs-run--attach-h (_output)
  "Attach the debugger once the output says the JVM listens (`hellmacs-run--pending-attach').
Only the output not yet looked through is searched, plus a line's worth
before it, in case the line came in two pieces."
  (pcase-let* ((`(,name ,port . ,searched) hellmacs-run--pending-attach)
               (line (format "Listening for transport dt_socket at address: %d" port)))
    (when (save-excursion
            (goto-char (max (point-min) (- searched (length line))))
            (set-marker searched (point-max))
            (search-forward line nil t))
      (hellmacs-run--forget-attach)
      (hellmacs-run--attach name port))))

(defun hellmacs-run--attach-when-listening (buffer name port)
  "Attach the debugger to PORT once BUFFER's output says the JVM listens on it.
Replaces any earlier wait in BUFFER."
  (with-current-buffer buffer
    (hellmacs-run--forget-attach)
    (setq hellmacs-run--pending-attach (cons name (cons port (copy-marker (point-min)))))
    (add-hook 'comint-output-filter-functions #'hellmacs-run--attach-h nil t)))

;;;###autoload
(defun hellmacs-run-config (config &optional debug)
  "Run CONFIG (a run configuration plist); with DEBUG, under the debugger.
Returns the output buffer (for a main class debugged through dap-java,
dap's own)."
  (let* ((root (hellmacs-run--root))
         (name (plist-get config :name))
         (dir (or (plist-get config :cwd) root))
         (env (hellmacs-run--environment config)))
    (setq hellmacs-run--last (list config root debug))
    (cond
     ((plist-get config :task)
      (let* ((build (or (hellmacs-forge-build-tool root)
                        (user-error "No Gradle or Maven build in %s" (abbreviate-file-name root))))
             (buffer (hellmacs-run--start name (hellmacs-run--task-command config build debug)
                                          (or (plist-get config :cwd) (nth 1 build)) env)))
        (when debug
          (hellmacs-run--attach-when-listening buffer name hellmacs-run-debug-port))
        buffer))
     (debug
      (hellmacs-run--with-jdtls name
        (require 'dap-java)
        (let ((main (plist-get config :main)))
          (dap-debug
           (hellmacs-run--clean
            (list :type "java" :request "launch" :name name :mainClass main
                  :projectName (or (plist-get config :project) (hellmacs-run--project-name main))
                  :args (combine-and-quote-strings (plist-get config :args))
                  :vmArgs (combine-and-quote-strings
                           (append (plist-get config :jvm-args)
                                   (delq nil (list (hellmacs-run--profiles-jvm-arg config)))))
                  :cwd dir
                  :env (let ((table (make-hash-table :test #'equal)))
                         (pcase-dolist (`(,k . ,v) (plist-get config :env)) (puthash k v table))
                         table)))))))
     (t
      (let ((command
             (hellmacs-run--with-jdtls name
               (let* ((main (plist-get config :main))
                      (project (or (plist-get config :project) (hellmacs-run--project-name main)))
                      (paths (lsp-send-execute-command "vscode.java.resolveClasspath" (vector main project)))
                      (classpath (append (elt paths 0) (elt paths 1) nil)))
                 (unless classpath
                   (user-error "JDTLS found no classpath for %s; is it a main class of this project?" main))
                 (hellmacs-run--java-command
                  config (or (and (fboundp 'hellmacs-jvm--resolve-java-executable)
                                  (hellmacs-jvm--resolve-java-executable main project))
                             "java")
                  classpath)))))
        (hellmacs-run--start name command dir env))))))

(defun hellmacs-run--read (prompt)
  "Read a run configuration of this project, with PROMPT."
  (let* ((configs (or (hellmacs-run-configurations)
                      (user-error "No run configurations in %s: add .hellmacs/run.eld, or IntelliJ's .run/ or Eclipse .launch files"
                                  (abbreviate-file-name (hellmacs-run--root)))))
         (names (mapcar (lambda (c) (plist-get c :name)) configs))
         (completion-extra-properties
          `(:annotation-function
            ,(lambda (name)
               (let ((c (seq-find (lambda (c) (equal (plist-get c :name) name)) configs)))
                 (format "  %s  (%s)" (or (plist-get c :main) (plist-get c :task)) (plist-get c :source)))))))
    (seq-find (lambda (c) (equal (plist-get c :name) (completing-read prompt names nil t)))
              configs)))

;;;###autoload
(defun hellmacs-run (config)
  "Run a run configuration of this project (CONFIG, read with completion)."
  (interactive (list (hellmacs-run--read "Run: ")))
  (hellmacs-run-config config))

;;;###autoload
(defun hellmacs-run-debug (config)
  "Debug a run configuration of this project (CONFIG, read with completion)."
  (interactive (list (hellmacs-run--read "Debug: ")))
  (hellmacs-run-config config 'debug))

;;;###autoload
(defun hellmacs-run-last ()
  "Run the last run configuration again, the same way (run or debug)."
  (interactive)
  (pcase-let ((`(,config ,root ,debug) (or hellmacs-run--last (user-error "Nothing has run yet"))))
    (let ((default-directory root))
      (hellmacs-run-config config debug))))
