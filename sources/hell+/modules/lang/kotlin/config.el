;;; lang/kotlin/config.el -*- lexical-binding: t; -*-

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


;; Kotlin, through kotlin-language-server (fwcd's, over lsp-mode). Flags:
;;   +tree-sitter  Use `kotlin-ts-mode' (`bin/hell sync' builds the
;;                 pinned Kotlin grammar)
;;
;; The server is unpacked by `bin/hell sync' (a pinned release, checked
;; by SHA-256) into the data directory. It runs on JAVA_HOME's JDK, like
;; the Gradle build. Completion, navigation, diagnostics, rename and code
;; actions come from `:tools lsp' (`C-c c', `M-.', `C-c ! n'). With
;; `:tools build', `C-c c c' builds (Gradle, wrapper first) and `C-c l t t'
;; / `C-c l t T' run the test at point (backticked names too) / the test
;; class; compile errors are clickable (`e: file:///...Foo.kt:12:5'
;; lines) and a failed build shows `[BYTECODE PURGATORY]'.

(hell-module-load "+paths")

;;; Server settings --------------------------------------------------------------

(defvar hell-kotlin-jvm-target "21"
  "The JVM target the server assumes for Kotlin code. Match your projects.")

;; Set before lsp-kotlin loads (a defcustom keeps a value that's already set).
(setq lsp-kotlin-compiler-jvm-target hell-kotlin-jvm-target
      lsp-kotlin-debug-adapter-enabled nil) ; the debugger is Java's (:tools debugger)

;; lsp-mode finds this before anything on the PATH; it's the pinned release.
(setq lsp-clients-kotlin-server-executable hell-kotlin-ls-executable)
;; ...and installs it with sync's installer, not its own, if it's missing.
(hell-lsp-pin-installer 'kotlin-language-server '(:lang . kotlin)
                        'hell-kotlin-sync-install-server)

;; The server is a JVM program whose heap is otherwise uncapped (a quarter
;; of RAM): 2.6GB on a real Spring project. The launcher script reads its
;; options from KOTLIN_LANGUAGE_SERVER_OPTS; one you set yourself wins.
(defvar hell-kotlin-vmargs '("-Xmx2G" "-Xms128m")
  "JVM options for kotlin-language-server (unless KOTLIN_LANGUAGE_SERVER_OPTS is set).")

(defun hell-kotlin--server-environment ()
  "The server's environment: its JVM options, unless KOTLIN_LANGUAGE_SERVER_OPTS is set.
Given to its process alone, not to every process Emacs starts."
  (unless (getenv "KOTLIN_LANGUAGE_SERVER_OPTS")
    ;; With your proxy and CA: it resolves the project's Gradle dependencies.
    `(("KOTLIN_LANGUAGE_SERVER_OPTS"
       . ,(string-join (append hell-kotlin-vmargs (hell-net-jvm-options)) " ")))))

(defvar lsp-clients)

(with-eval-after-load 'lsp-kotlin
  ;; Its slot looked up by name, now: no `setf' of lsp-mode's struct can
  ;; be expanded where this file is compiled, before lsp-mode loads.
  (condition-case err
      (aset (or (gethash 'kotlin-ls lsp-clients) (error "lsp-kotlin registered no `kotlin-ls' client"))
            (cl-struct-slot-offset 'lsp--client 'environment-fn)
            #'hell-kotlin--server-environment)
    (error (display-warning 'hell (format "Kotlin server options not set (%s); lsp-mode may have changed"
                                          (error-message-string err))))))

(add-hook! (kotlin-mode kotlin-ts-mode) #'lsp-deferred)

;; `C-x p c' proposes the project's own Gradle build, and tests run
;; through it (:tools build).
(defun hell-kotlin-test-class ()
  "The fully qualified name of the current buffer's (first) class.
A Kotlin file may hold several classes, or none named after it."
  (hell-forge-qualify
   (save-excursion
     (goto-char (point-min))
     (if (re-search-forward
          "^[ \t]*\\(?:\\(?:public\\|internal\\|private\\|open\\|abstract\\|data\\|sealed\\)[ \t]+\\)*class[ \t]+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
          nil t)
         (match-string-no-properties 1)
       (file-name-base (or buffer-file-name (user-error "Not visiting a file")))))))

(declare-function hell-forge-annotated-test-at-point "../../tools/build/autoload")

(defun hell-kotlin-test-method ()
  "The name of the @Test function point is in, or nil; backticked names
included (`fun `greets by name`()'). Not a helper: see
`hell-forge-annotated-test-at-point'."
  (hell-forge-annotated-test-at-point
   "fun[ \t]+\\(?:`\\([^`\n]+\\)`\\|\\([[:alpha:]_][[:alnum:]_]*\\)\\)[ \t]*("))

(defun hell-kotlin--setup-build-h ()
  "Use the project's build, and Kotlin's test classes and functions, in this buffer."
  (hell-forge-setup-build-h)
  (setq-local hell-forge-test-class-function #'hell-kotlin-test-class
              hell-forge-test-method-function #'hell-kotlin-test-method))

(when (modulep! :tools build)
  (add-hook! (kotlin-mode kotlin-ts-mode) #'hell-kotlin--setup-build-h))

;;; Status: echo-area announcements and the mode-line segment ----------------------
;;
;; kotlin-language-server has no "ready" notification, so its log is the
;; signal: a Gradle task failing means the project didn't import, and the
;; full symbol index being built means search and navigation work. The
;; messages are in lisp/lib/lsp-status.el.

(hell-require 'hell-lib 'lsp-status)

(defun hell-kotlin-state (root)
  "The state of the Kotlin server for project ROOT: igniting, ready, failed or nil."
  (hell-lsp-status-state 'kotlin-ls root))

(defun hell-kotlin--note-log (root message)
  "React to the server's log MESSAGE for project ROOT."
  (cond
   ((string-match "Gradle task failed: \\(.*\\)" message)
    (hell-lsp-status-fail 'kotlin-ls root
                          (replace-regexp-in-string "file://" "" (match-string 1 message))))
   ((string-match-p "Updated full symbol index in" message)
    (hell-lsp-status-ready 'kotlin-ls root))))

(hell-lsp-status-register 'kotlin-ls
  :label "Kotlin server"
  :on-log #'hell-kotlin--note-log)

