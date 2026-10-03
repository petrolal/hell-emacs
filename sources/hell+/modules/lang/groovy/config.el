;;; lang/groovy/config.el -*- lexical-binding: t; -*-

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


;; Groovy, through groovy-language-server (over lsp-mode): Groovy
;; sources, Gradle's Groovy build scripts and Jenkins pipelines open in
;; `groovy-mode'.
;;
;; The server has no releases: `bin/hell sync' builds it from a
;; pinned commit (see +paths.el). It only knows the project's libraries
;; from its classpath, which Hell Emacs asks the build for (Gradle or
;; Maven) once the server has started: it shows JVM:igniting until then,
;; JVM:ready once the server has it, JVM:failed if the build can't say.
;; Completion, navigation, diagnostics and rename come from `:tools lsp'
;; (`C-c c', `M-.', `C-c s e'); this module adds `C-c l c' in Groovy
;; buffers (ask the build for the classpath again). With `:tools build',
;; `C-x p c' builds (Gradle or Maven, wrapper first) and `C-c l t t' /
;; `C-c l t T' run the test at point (JUnit methods, Spock features) /
;; the test class.

(hell-module-load "+paths")

;; groovy-mode claims .groovy, .gradle and Jenkinsfile itself; these are
;; the pipelines named otherwise. Appended, so documentation named after
;; one (Jenkinsfile.md) stays in its own mode.
(add-to-list 'auto-mode-alist '("\\.jenkinsfile\\'" . groovy-mode) t)
(add-to-list 'auto-mode-alist '("/Jenkinsfile\\.[^./]+\\'" . groovy-mode) t)

;;; The server -----------------------------------------------------------------------

(defvar lsp-groovy-server-file)
(defvar lsp-groovy-classpath)
(defvar lsp--cur-workspace)
(defvar lsp--buffer-workspaces)
(declare-function lsp-configuration-section "ext:lsp-mode")
(declare-function lsp--set-configuration "ext:lsp-mode")

;; Before lsp-groovy loads: its own defaults are a jar it never installs,
;; and Homebrew's Groovy (the classpath comes from the build instead).
(setq lsp-groovy-server-file hell-groovy-server-jar
      lsp-groovy-classpath [])

(defun hell-groovy--server-command ()
  "The command starting the server: on a JDK sync found, not the PATH's java.
Replaces `lsp-groovy--lsp-command'."
  (list (hell-jdk-java-executable 11) "-jar" hell-groovy-server-jar))

(advice-add 'lsp-groovy--lsp-command :override #'hell-groovy--server-command)

(defvar hell-groovy--warned nil
  "Non-nil once a Groovy buffer said the server isn't built yet.")

(defun hell-groovy--lsp-h ()
  "Start the server for this buffer; if it isn't built, say how to build it, once."
  (if (hell-groovy-server-installed-p)
      (lsp-deferred)
    (unless hell-groovy--warned
      (setq hell-groovy--warned t)
      (display-warning 'hell "groovy-language-server isn't built yet; run `bin/hell sync'"))))

(add-hook! groovy-mode #'hell-groovy--lsp-h)

;;; Status, and the classpath ----------------------------------------------------------

(hell-require 'hell-lib 'lsp-status)

(hell-lsp-status-register 'groovy-ls :label "Groovy server")

(defun hell-groovy--send-classpath (workspace root)
  "Ask ROOT's build for its classpath and give it to WORKSPACE's server.
The project is ready once the server has it; failed if the build can't say."
  (hell-groovy-fetch-classpath
   root
   (lambda (classpath)
     (if (eq classpath 'failed)
         (hell-lsp-status-fail 'groovy-ls root
                               (format "the build didn't give its classpath: %s"
                                           hell-groovy--classpath-error))
       (with-demoted-errors "Hell Emacs: sending the Groovy classpath: %S"
         (let ((lsp--cur-workspace workspace)
               (lsp--buffer-workspaces (list workspace))
               (lsp-groovy-classpath (vconcat classpath)))
           (lsp--set-configuration (lsp-configuration-section "groovy"))))
       (hell-lsp-status-ready 'groovy-ls root)))))

(defun hell-groovy--initialized-h ()
  "The server started: send it its project's classpath. For `lsp-after-initialize-hook'."
  (when-let* ((workspace lsp--cur-workspace)
              ((eq (hell-lsp-status--server workspace) 'groovy-ls)))
    (hell-groovy--send-classpath workspace (hell-lsp-status--root workspace))))

;; After the status's own, which marks the server started (igniting).
(add-hook 'lsp-after-initialize-hook #'hell-groovy--initialized-h 90)

(declare-function lsp-find-workspace "ext:lsp-mode")
(declare-function lsp--workspace-root "ext:lsp-mode")

(defun hell-groovy-refresh-classpath ()
  "Ask the build for the classpath again, and give it to the server."
  (interactive)
  (let ((workspace (or (seq-find (lambda (ws) (eq (hell-lsp-status--server ws) 'groovy-ls))
                                 (bound-and-true-p lsp--buffer-workspaces))
                       (user-error "No Groovy server runs for this buffer"))))
    (remhash (file-name-as-directory (expand-file-name (hell-lsp-status--root workspace)))
             hell-groovy--classpaths)
    (message "Asking the build for the classpath...")
    (hell-groovy--send-classpath workspace (hell-lsp-status--root workspace))))

;;; Builds, tests and keys ---------------------------------------------------------------

(defun hell-groovy--setup-build-h ()
  "Use the project's build, and Groovy's test methods, in this buffer."
  (hell-forge-setup-build-h)
  (setq-local hell-forge-test-method-function #'hell-groovy-test-method))

(when (modulep! :tools build)
  (add-hook! groovy-mode #'hell-groovy--setup-build-h))

(hell-localleader-def 'groovy-mode
  "c" '("ask the build for the classpath" . hell-groovy-refresh-classpath))

;;; lang/groovy/config.el ends here
