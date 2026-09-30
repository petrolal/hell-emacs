;;; run-e2e.el --- End-to-end check of run configurations -*- lexical-binding: t; -*-

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

;; Phase 12.4's run configurations (:tools run), against a real JDTLS and
;; java-debug. The fixture's copy gets a Probe class (it prints what it
;; was given, then a stack trace) and one configuration of each kind for
;; it: .hellmacs/run.eld, IntelliJ's .run/Probe.run.xml, Eclipse's
;; Probe.launch. Each must reach the program with its arguments, JVM
;; options and environment. The Gradle fixture also runs and debugs its
;; application plugin's `run' task (without a daemon, which would outlive the
;; run and write into the copy after it's deleted).
;;
;; It needs a synced profile with :lang java, :tools build, debugger and
;; run, and network access on the first run:
;;
;;   HELLMACS_E2E_FIXTURE=maven-demo \
;;     emacs --batch -l early-init.el -f hellmacs-start -l test/integration/run-e2e.el
;;
;; HELLMACS_E2E_FIXTURE is maven-demo (default) or gradle-demo. The copy
;; is deleted at exit (HELLMACS_E2E_KEEP=1 keeps it). Exits 1 if any
;; check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar e2e--fixture (or (getenv "HELLMACS_E2E_FIXTURE") "maven-demo"))

(defconst e2e--probe "package dev.hellmacs.demo;

public class Probe {
    public static void main(String[] args) {
        String report = \"args=\" + String.join(\" \", args)
            + \" env=\" + System.getenv(\"HELLMACS_RUN\")
            + \" prop=\" + System.getProperty(\"hellmacs.probe\")
            + \" cwd=\" + System.getProperty(\"user.dir\")
            + \" java=\" + System.getProperty(\"java.version\");
        System.out.println(report);
        new IllegalStateException(\"probe trace\").printStackTrace();
    }
}
")

(defun e2e--write (file content)
  (make-directory (file-name-directory file) t)
  (with-temp-file file (insert content)))

(defun e2e--add-configurations (proj)
  "The Probe class, and a configuration of each kind for it."
  (e2e--write (expand-file-name "src/main/java/dev/hellmacs/demo/Probe.java" proj) e2e--probe)
  (e2e--write (expand-file-name ".hellmacs/run.eld" proj)
              (concat "((:name \"Probe (eld)\" :main \"dev.hellmacs.demo.Probe\" :args (\"--from\" \"eld\")\n"
                      "  :jvm-args (\"-Dhellmacs.probe=eld\") :env ((\"HELLMACS_RUN\" . \"eld\")))"
                      (if (equal e2e--fixture "gradle-demo")
                          "\n (:name \"gradle run\" :task \"run\" :build-args (\"--no-daemon\")))\n"
                        ")\n")))
  (e2e--write (expand-file-name ".run/Probe.run.xml" proj)
              "<component name=\"ProjectRunConfigurationManager\">
  <configuration default=\"false\" name=\"Probe (IntelliJ)\" type=\"Application\" factoryName=\"Application\">
    <option name=\"MAIN_CLASS_NAME\" value=\"dev.hellmacs.demo.Probe\" />
    <option name=\"PROGRAM_PARAMETERS\" value=\"--from &quot;intellij xml&quot;\" />
    <option name=\"VM_PARAMETERS\" value=\"-Dhellmacs.probe=intellij\" />
    <option name=\"WORKING_DIRECTORY\" value=\"$PROJECT_DIR$/src\" />
    <envs><env name=\"HELLMACS_RUN\" value=\"intellij\" /></envs>
  </configuration>
</component>
")
  (e2e--write (expand-file-name "Probe.launch" proj)
              "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<launchConfiguration type=\"org.eclipse.jdt.launching.localJavaApplication\">
    <mapAttribute key=\"org.eclipse.debug.core.environmentVariables\">
        <mapEntry key=\"HELLMACS_RUN\" value=\"eclipse\"/>
    </mapAttribute>
    <stringAttribute key=\"org.eclipse.jdt.launching.MAIN_TYPE\" value=\"dev.hellmacs.demo.Probe\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.PROGRAM_ARGUMENTS\" value=\"--from eclipse\"/>
    <stringAttribute key=\"org.eclipse.jdt.launching.VM_ARGUMENTS\" value=\"-Dhellmacs.probe=eclipse\"/>
</launchConfiguration>
"))

(defun e2e--project-jdk-major (proj)
  "The major release of the JDK JDTLS says PROJ compiles against.
Maven's release picks it among the runtimes; a Gradle build without a
toolchain gets the JVM that runs Gradle."
  (let* ((key "org.eclipse.jdt.ls.core.vm.location")
         (settings (lsp-send-execute-command "java.project.getSettings"
                                             (vector (lsp--path-to-uri proj) (vector key))))
         (vm (if (hash-table-p settings) (gethash key settings)
               (plist-get settings (intern (concat ":" key))))))
    (and vm (hellmacs-jdk-home-major vm))))

(defun e2e--config (name)
  (or (seq-find (lambda (c) (equal (plist-get c :name) name)) (hellmacs-run-configurations))
      (error "No configuration %s" name)))

(defun e2e--finished (buffer)
  "BUFFER's output, once its process is done."
  (e2e--wait (lambda () (not (process-live-p (get-buffer-process buffer)))) 120)
  (with-current-buffer buffer (buffer-string)))

(defun e2e--stopped-line ()
  "The line the debugger stopped at, once it has."
  (e2e--wait (lambda () (let ((s (dap--cur-session))) (and s (dap--debug-session-active-frame s)))) 180)
  (gethash "line" (dap--debug-session-active-frame (dap--cur-session))))

(defun e2e--evaluate (expr)
  (let* ((s (dap--cur-session)) result)
    (dap--send-message
     (dap--make-request "evaluate"
                        (list :expression expr :context "repl"
                              :frameId (gethash "id" (dap--debug-session-active-frame s))))
     (lambda (resp) (setq result (gethash "result" (gethash "body" resp))))
     s)
    (e2e--wait (lambda () result) 30)
    result))

(defun e2e--finish-session ()
  (call-interactively #'hellmacs-debug-continue)
  (e2e--wait (lambda () (not (dap--session-running (dap--cur-session)))) 60)
  (dap-breakpoint-delete-all))

(defun e2e--run-checks (proj)
  (let* ((probe (expand-file-name "src/main/java/dev/hellmacs/demo/Probe.java" proj))
         (app (expand-file-name "src/main/java/dev/hellmacs/demo/App.java" proj))
         (major nil))                   ; the project's JDK, once JDTLS has imported it
    (switch-to-buffer (find-file-noselect probe))
    (e2e--say "\n== 12.4 :tools run (%s)" e2e--fixture)
    (e2e-check "C-c r r, C-c r d, C-c r l are bound"
      (and (eq (key-binding (kbd "C-c r r")) 'hellmacs-run)
           (eq (key-binding (kbd "C-c r d")) 'hellmacs-run-debug)
           (eq (key-binding (kbd "C-c r l")) 'hellmacs-run-last)))
    (e2e-check "the configurations are found, Hellmacs' own first, then IntelliJ's, then Eclipse's"
      (let ((names (mapcar (lambda (c) (plist-get c :name)) (hellmacs-run-configurations))))
        (e2e--say "    %S" names)
        (equal (seq-filter (lambda (n) (string-prefix-p "Probe" n)) names)
               '("Probe (eld)" "Probe (IntelliJ)" "Probe"))))
    (e2e-check "JDTLS starts and imports the project"
      (e2e-add-project proj)
      (lsp)
      (e2e--wait (lambda () (eq (hellmacs-jvm-state proj) 'ready)) 400))
    (setq major (e2e--project-jdk-major proj))
    (e2e--say "    the project's JDK, as JDTLS says: %s" major)

    (pcase-dolist (`(,name ,expect) `(("Probe (eld)" "args=--from eld env=eld prop=eld")
                                      ("Probe (IntelliJ)" "args=--from intellij xml env=intellij prop=intellij")
                                      ("Probe" "args=--from eclipse env=eclipse prop=eclipse")))
      (e2e-check (format "%s runs with its arguments, JVM options and environment" name)
        (let ((out (e2e--finished (hellmacs-run-config (e2e--config name)))))
          (e2e--say "    %s" (car (seq-filter (lambda (l) (string-prefix-p "args=" l)) (split-string out "\n"))))
          (string-match-p (regexp-quote expect) out))))
    (e2e-check "a working directory is honoured (IntelliJ's $PROJECT_DIR$/src)"
      (string-match-p (regexp-quote (concat "cwd=" (directory-file-name (expand-file-name "src" proj))))
                      (with-current-buffer "*run: Probe (IntelliJ)*" (buffer-string))))
    (e2e-check "it runs on the project's JDK, as JDTLS resolves it"
      (and major (string-match-p (format "java=%d\\_>" major)
                                 (with-current-buffer "*run: Probe (IntelliJ)*" (buffer-string)))))
    (e2e-check "its exception is highlighted, and M-g n goes to the stack frame in Probe.java"
      (with-current-buffer "*run: Probe (IntelliJ)*"
        (and (bound-and-true-p compilation-shell-minor-mode)
             (progn (goto-char (point-min))
                    (let ((next-error-last-buffer (current-buffer)))
                      (next-error 1 t))
                    (string-suffix-p "Probe.java" (or (buffer-file-name (window-buffer (selected-window))) ""))))))
    (e2e-check "C-c r l runs the last one again"
      (with-current-buffer "*run: Probe*" (let ((inhibit-read-only t)) (erase-buffer)))
      (switch-to-buffer (find-file-noselect probe))
      (string-match-p "env=eclipse" (e2e--finished (hellmacs-run-last))))

    (e2e--say "\n== debugging")
    (switch-to-buffer (find-file-noselect probe))
    (goto-char (point-min)) (search-forward "System.out.println(report)") (beginning-of-line)
    (let ((line (line-number-at-pos)))
      (dap-breakpoint-add)
      (e2e-check "C-c r d stops at a breakpoint in the program"
        (hellmacs-run-config (e2e--config "Probe (IntelliJ)") 'debug)
        (eql (e2e--stopped-line) line))
      (e2e-check "the debugged program has its environment and runs on the project's JDK"
        (let ((env (e2e--evaluate "System.getenv(\"HELLMACS_RUN\")"))
              (java (e2e--evaluate "System.getProperty(\"java.version\")")))
          (e2e--say "    HELLMACS_RUN=%s java.version=%s" env java)
          (and (string-match-p "intellij" (or env "")) (string-match-p (format "\\`\"?%d\\_>" major) (or java "")))))
      (e2e-check "and runs to the end"
        (e2e--finish-session)
        t))

    (when (equal e2e--fixture "gradle-demo")
      (e2e--say "\n== a build task (Gradle's application `run')")
      (e2e-check "the task runs through the project's gradlew"
        (let ((out (e2e--finished (hellmacs-run-config (e2e--config "gradle run")))))
          (and (string-match-p "\\./gradlew run --console=plain" out)
               (string-match-p "Hello, Doomguy" out))))
      (switch-to-buffer (find-file-noselect app))
      (goto-char (point-min)) (search-forward "String greeting") (beginning-of-line)
      (let ((line (line-number-at-pos)))
        (dap-breakpoint-add)
        (e2e-check "debugging it waits for the debugger, attaches, and stops at the breakpoint"
          (hellmacs-run-config (e2e--config "gradle run") 'debug)
          (and (eql (e2e--stopped-line) line)
               (string-match-p "Listening for transport dt_socket at address: 5005"
                               (with-current-buffer "*run: gradle run*" (buffer-string)))))
        (e2e-check "and runs to the end"
          (e2e--finish-session)
          t)))))

(let ((proj (e2e-copy-fixture (concat "java/" e2e--fixture))))
  (e2e--add-configurations proj)
  (e2e--say "Hellmacs run configurations end-to-end, fixture %s in %s" e2e--fixture proj)
  (let ((default-directory (file-name-as-directory proj)))
    (e2e--run-checks proj))
  (unless (getenv "HELLMACS_E2E_KEEP")
    (delete-directory (file-name-directory (directory-file-name proj)) t)))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; run-e2e.el ends here
