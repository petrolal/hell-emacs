;;; lang/kotlin/config.el -*- lexical-binding: t; -*-

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


;; Kotlin, through kotlin-language-server (fwcd's, over lsp-mode). Flags:
;;   +tree-sitter  Use `kotlin-ts-mode' (`bin/hellmacs sync' builds the
;;                 pinned Kotlin grammar)
;;
;; The server is unpacked by `bin/hellmacs sync' (a pinned release, checked
;; by SHA-256) into the data directory. It runs on JAVA_HOME's JDK, like
;; the Gradle build. Completion, navigation, diagnostics, rename and code
;; actions come from `:tools lsp' (`C-c l', `M-.', `C-c ! n'); this module
;; adds `C-c l k' in Kotlin buffers:
;;   b build the project (Gradle, wrapper first)
;;   t run the test at point (with backticked names)    T the test class
;; Both need `:tools build', which also makes compile errors clickable
;; (`e: file:///...Foo.kt:12:5' lines) and shows `[BYTECODE PURGATORY]' when
;; a build fails.

(hellmacs-module-load "+paths")

;;; Server settings --------------------------------------------------------------

(defvar hellmacs-kotlin-jvm-target "21"
  "The JVM target the server assumes for Kotlin code. Match your projects.")

;; Set before lsp-kotlin loads (a defcustom keeps a value that's already set).
(setq lsp-kotlin-compiler-jvm-target hellmacs-kotlin-jvm-target
      lsp-kotlin-debug-adapter-enabled nil) ; the debugger is Java's (:tools debugger)

;; lsp-mode finds this before anything on the PATH; it's the pinned release.
(setq lsp-clients-kotlin-server-executable hellmacs-kotlin-ls-executable)
;; ...and installs it with sync's installer, not its own, if it's missing.
(hellmacs-lsp-pin-installer 'kotlin-language-server '(:lang . kotlin)
                            'hellmacs-kotlin-sync-install-server)

;; The server is a JVM program whose heap is otherwise uncapped (a quarter
;; of RAM): 2.6GB on a real Spring project. The launcher script reads its
;; options from KOTLIN_LANGUAGE_SERVER_OPTS; one you set yourself wins.
(defvar hellmacs-kotlin-vmargs '("-Xmx2G" "-Xms128m")
  "JVM options for kotlin-language-server (unless KOTLIN_LANGUAGE_SERVER_OPTS is set).")

(unless (getenv "KOTLIN_LANGUAGE_SERVER_OPTS")
  (setenv "KOTLIN_LANGUAGE_SERVER_OPTS"
          ;; With your proxy and CA: it resolves the project's Gradle dependencies.
          (string-join (append hellmacs-kotlin-vmargs (hellmacs-net-jvm-options)) " ")))

(add-hook! (kotlin-mode kotlin-ts-mode) #'lsp-deferred)

;; `C-x p c' proposes the project's own Gradle build, and tests run
;; through it (:tools build).
(defun hellmacs-kotlin-test-class ()
  "The fully qualified name of the current buffer's (first) class.
A Kotlin file may hold several classes, or none named after it."
  (hellmacs-forge-qualify
   (save-excursion
     (goto-char (point-min))
     (if (re-search-forward
          "^[ \t]*\\(?:\\(?:public\\|internal\\|private\\|open\\|abstract\\|data\\|sealed\\)[ \t]+\\)*class[ \t]+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
          nil t)
         (match-string-no-properties 1)
       (file-name-base (or buffer-file-name (user-error "Not visiting a file")))))))

(defun hellmacs-kotlin-test-method ()
  "The name of the test function around point, or nil: the nearest `fun'
above point, backticked names included (`fun `greets by name`()')."
  (save-excursion
    (end-of-line)
    (when (re-search-backward
           (concat "^[ \t]*\\(?:\\(?:public\\|internal\\|private\\|override\\)[ \t]+\\)*"
                   "fun[ \t]+\\(?:`\\([^`\n]+\\)`\\|\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\)[ \t]*(")
           nil t)
      (or (match-string-no-properties 1) (match-string-no-properties 2)))))

(defun hellmacs-kotlin--setup-build-h ()
  "Use the project's build, and Kotlin's test classes and functions, in this buffer."
  (hellmacs-forge-setup-build-h)
  (setq-local hellmacs-forge-test-class-function #'hellmacs-kotlin-test-class
              hellmacs-forge-test-method-function #'hellmacs-kotlin-test-method))

(when (modulep! :tools build)
  (add-hook! (kotlin-mode kotlin-ts-mode) #'hellmacs-kotlin--setup-build-h))

;;; Status: echo-area announcements and the mode-line segment ----------------------
;;
;; kotlin-language-server has no "ready" notification, so its log is the
;; signal: a Gradle task failing means the project didn't import, and the
;; full symbol index being built means search and navigation work. The
;; messages are in core/hellmacs-lsp-status.el.

(require 'hellmacs-lsp-status)

(defun hellmacs-kotlin-state (root)
  "The state of the Kotlin server for project ROOT: igniting, ready, failed or nil."
  (hellmacs-lsp-status-state 'kotlin-ls root))

(defun hellmacs-kotlin--note-log (root message)
  "React to the server's log MESSAGE for project ROOT."
  (cond
   ((string-match "Gradle task failed: \\(.*\\)" message)
    (hellmacs-lsp-status-fail 'kotlin-ls root
                              (replace-regexp-in-string "file://" "" (match-string 1 message))))
   ((string-match-p "Updated full symbol index in" message)
    (hellmacs-lsp-status-ready 'kotlin-ls root))))

(hellmacs-lsp-status-register 'kotlin-ls
  :label "Kotlin server"
  :on-log #'hellmacs-kotlin--note-log)

;;; Keys: C-c l k --------------------------------------------------------------------

(when (modulep! :tools build)
  (defvar-keymap hellmacs-kotlin-map
    :doc "Kotlin commands, on `C-c l k' in Kotlin buffers."
    "b" (cons "build project" #'hellmacs-forge-build)
    "t" (cons "run test at point" #'hellmacs-forge-test-at-point)
    "T" (cons "run test class" #'hellmacs-forge-test-class))

  ;; In Hellmacs' own minor mode, not the Kotlin modes' maps (`C-c' and a
  ;; letter is the user's). lsp-mode's `C-c l' map has no `k', so the
  ;; full key reaches this one.
  (defvar-keymap hellmacs-kotlin-keys-mode-map
    "C-c l k" (cons "kotlin" hellmacs-kotlin-map))

  (define-minor-mode hellmacs-kotlin-keys-mode
    "Kotlin commands on `C-c l k' (`hellmacs-kotlin-map')."
    :keymap hellmacs-kotlin-keys-mode-map)

  (add-hook! (kotlin-mode kotlin-ts-mode) #'hellmacs-kotlin-keys-mode))
