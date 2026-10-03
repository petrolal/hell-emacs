;;; checkers/static/config.el -*- lexical-binding: t; -*-

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

;; Checkstyle, PMD and SpotBugs results (Phase 12.6), from the reports the
;; build tool writes with the rules the build configures: nothing is
;; configured or run twice in Emacs. Maven's (target/checkstyle-result.xml,
;; pmd.xml, spotbugsXml.xml) and Gradle's (build/reports/{checkstyle,pmd,
;; spotbugs}/*.xml, SpotBugs with its XML report on), in every module.
;;
;;   - In Java and Kotlin buffers they are flymake diagnostics, beside the
;;     language server's: `C-c s e' as usual. Only while the file is
;;     as the build saw it; after an edit they wait for the next build.
;;   - `M-x hell-static-findings' lists the project's, from every
;;     report, in a compilation buffer (`M-g n' / `M-g p').
;;
;; A finished build (`C-x p c', :tools build) reads the reports again.
;; No keys of its own.
;;
;; +sonarlint: SonarLint's analyzers as you type, through lsp-sonarlint
;; beside JDTLS, as flymake diagnostics too. The pinned release (+paths.el),
;; installed by `bin/hell sync', on a JDK 17+ Hell Emacs picks. Java's
;; analyzer gets the project's classpath from JDTLS (lsp-sonarlint gives
;; it nothing). Standalone: connected mode (SonarQube/SonarCloud rules) is
;; lsp-sonarlint's to add.

(add-hook! (java-mode java-ts-mode kotlin-mode kotlin-ts-mode) #'hell-static-setup-h)
(add-hook 'compilation-finish-functions #'hell-static--after-build-h)

;;; +sonarlint -----------------------------------------------------------------------

(when (modulep! +sonarlint)
  (hell-module-load "+paths")

  (defvar lsp-sonarlint-download-dir)
  (defvar lsp-sonarlint-modes-enabled)
  (defvar lsp-sonarlint-use-system-jre)
  (defvar lsp-sonarlint-enabled-analyzers)
  (defvar lsp-sonarlint-disable-telemetry)
  (defvar lsp-sonarlint-auto-download)
  (defvar lsp-client-packages)
  (defvar lsp-clients)
  (declare-function lsp-find-workspace "ext:lsp-mode")
  (declare-function lsp-request-async "ext:lsp-mode")
  (declare-function lsp-notify "ext:lsp-mode")
  (declare-function lsp-session "ext:lsp-mode")
  (declare-function lsp--session-workspaces "ext:lsp-mode")
  (declare-function lsp--workspace-client "ext:lsp-mode")
  (declare-function lsp--client-server-id "ext:lsp-mode")
  (declare-function lsp--client-request-handlers "ext:lsp-mode")
  (declare-function lsp--client-async-request-handlers "ext:lsp-mode")
  (declare-function lsp--uri-to-path "ext:lsp-mode")
  (declare-function lsp--path-to-uri "ext:lsp-mode")
  (declare-function hell-lsp-status-get "hell-lsp-status")
  (declare-function hell-jdk-java-executable "../../../lisp/lib/jdk")

  ;; Before lsp-sonarlint loads: it registers its client with these.
  (setq lsp-sonarlint-download-dir (directory-file-name hell-static-sonarlint-dir)
        lsp-sonarlint-auto-download nil
        lsp-sonarlint-use-system-jre t
        lsp-sonarlint-disable-telemetry t
        ;; Java, pom.xml and the like, secrets in any file, and Docker and
        ;; Kubernetes files (iac). Each analyzer is loaded into the server.
        lsp-sonarlint-enabled-analyzers '("java" "xml" "text" "iac"))
  (if (hell-static-sonarlint-installed-p)
      (setq lsp-sonarlint-modes-enabled '(java-mode java-ts-mode nxml-mode))
    ;; Never a 227 MB download on opening a file: sync does it.
    (setq lsp-sonarlint-modes-enabled nil)
    (display-warning 'hell "+sonarlint: SonarLint isn't installed; `bin/hell sync' installs it (227 MB)"))

  (defun hell-static--sonarlint-command-a (command)
    "COMMAND (lsp-sonarlint's) with a java of release 17 or later Hell Emacs picks."
    (hell-require 'hell-lib 'jdk)
    (cons (hell-jdk-java-executable 17) (cdr command)))

  (defun hell-static--sonarlint-download-a (&rest _)
    "Replaces lsp-sonarlint's own, unpinned, download."
    (user-error "SonarLint is installed, pinned, by `bin/hell sync'"))

  ;; What VS Code's SonarLint asks its Java extension, asked of JDTLS.
  ;; lsp-mode's `with-lsp-workspace' only binds `lsp--cur-workspace': bound
  ;; here directly, so this file compiles the same whether lsp-mode is
  ;; loaded or not.
  (defvar lsp--cur-workspace)

  (defun hell-static--jdtls-execute (uri command arguments callback)
    "Run JDTLS COMMAND with ARGUMENTS for the file at URI; CALLBACK gets the result.
Always called back: nil when JDTLS doesn't have the file's project, fails,
or can't run commands yet (still starting, lsp-mode signals rather than
calling the error handler)."
    (if-let* ((workspace (and (fboundp 'lsp-find-workspace)
                              (lsp-find-workspace 'jdtls (lsp--uri-to-path uri)))))
        (condition-case nil
            (let ((lsp--cur-workspace workspace))
              (lsp-request-async "workspace/executeCommand" (list :command command :arguments arguments)
                                 callback
                                 :error-handler (lambda (&rest _) (funcall callback nil))
                                 :mode 'detached))
          (error (funcall callback nil)))
      (funcall callback nil)))

  (defun hell-static-sonarlint-java-config (_workspace params callback)
    "Answer SonarLint's `sonarlint/getJavaConfig' for PARAMS through CALLBACK.
PARAMS is the file's URI, in an array. The project's root, classpath (the
test one for a test), source level and JDK, from JDTLS, as VS Code's
SonarLint gets them from its Java extension; nil when JDTLS can't say,
and SonarLint analyzes without."
    (let ((uri (if (vectorp params) (aref params 0) params))
          (compliance "org.eclipse.jdt.core.compiler.compliance")
          (vm "org.eclipse.jdt.ls.core.vm.location"))
      (hell-static--jdtls-execute
       uri "java.project.isTestFile" (vector uri)
       (lambda (test)
         (let ((test (eq test t)))
           (hell-static--jdtls-execute
            uri "java.project.getSettings" (vector uri (vector compliance vm))
            (lambda (settings)
              (hell-static--jdtls-execute
               uri "java.project.getClasspaths"
               (vector uri (if test "{\"scope\":\"test\"}" "{\"scope\":\"runtime\"}"))
               (lambda (classpaths)
                 (funcall callback
                          (when classpaths
                            (list :projectRoot (hell-lsp-status-get classpaths :projectRoot)
                                  :sourceLevel (and settings (hell-lsp-status-get settings (intern (concat ":" compliance))))
                                  :classpath (hell-lsp-status-get classpaths :classpaths)
                                  :isTest (if test t :json-false)
                                  :vmLocation (and settings (hell-lsp-status-get settings (intern (concat ":" vm))))))))))))))))

  (defun hell-static--sonarlint-notify (method params)
    "Send the notification METHOD with PARAMS to every SonarLint server running."
    (when (fboundp 'lsp-session)
      (dolist (workspace (lsp--session-workspaces (lsp-session)))
        (when (eq (lsp--client-server-id (lsp--workspace-client workspace)) 'sonarlint)
          (let ((lsp--cur-workspace workspace))
            (lsp-notify method params))))))

  (defun hell-static--sonarlint-classpath-h (server root)
    "JDTLS knows ROOT's classpath now: SonarLint asks for it again and reanalyzes."
    (when (eq server 'jdtls)
      (let ((dir (directory-file-name (expand-file-name root))))
        (hell-static--sonarlint-notify
         "sonarlint/didClasspathUpdate"
         (list :projectUri (if (fboundp 'lsp--path-to-uri)
                               (lsp--path-to-uri dir)
                             (concat "file://" (unless (string-prefix-p "/" dir) "/") dir)))))))

  (add-hook 'hell-lsp-status-ready-functions #'hell-static--sonarlint-classpath-h)

  (after! lsp-mode
    (add-to-list 'lsp-client-packages 'lsp-sonarlint))

  (after! lsp-sonarlint
    (advice-add 'lsp-sonarlint-server-start-fun :filter-return #'hell-static--sonarlint-command-a)
    (advice-add 'lsp-sonarlint-download :override #'hell-static--sonarlint-download-a)
    ;; lsp-sonarlint answers it with nothing, synchronously: answered later instead.
    (condition-case err
        (let ((client (gethash 'sonarlint lsp-clients)))
          (remhash "sonarlint/getJavaConfig" (lsp--client-request-handlers client))
          (puthash "sonarlint/getJavaConfig" #'hell-static-sonarlint-java-config
                   (lsp--client-async-request-handlers client)))
      (error
       (display-warning 'hell (format "+sonarlint: Java analysis gets no classpath (%s)"
                                      (error-message-string err)))))))
