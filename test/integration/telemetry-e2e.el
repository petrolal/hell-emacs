;;; telemetry-e2e.el --- An editing session looks up no host but its build's -*- lexical-binding: t; -*-

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

;; The live check of 12.9's "no telemetry": during a normal editing
;; session (a file of each enabled language open, its language server
;; started, a hover, a save, a pause), nothing looks up a host other than
;; the repositories builds name and your mirrors. It runs in a network
;; namespace whose only nameserver is dns-log.el, which records every
;; name and answers "no such host": nothing is reached, and whatever tried
;; to phone home is named. Linux only (user namespaces). Run it through
;; its wrapper, on a synced profile:
;;
;;   test/integration/telemetry-check.sh
;;
;; Exits 1 if a name outside the allowed ones was looked up, 2 if it isn't
;; running inside the wrapper's namespace.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)
(load (expand-file-name "dns-log" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar tel--seconds (string-to-number (or (getenv "HELLMACS_TELEMETRY_SECONDS") "90"))
  "How long each server gets to start, and the session pauses at the end.")

(defconst tel--files
  '(((:lang . java)    "java/maven-demo"    "src/main/java/dev/hellmacs/demo/Greeter.java")
    ((:lang . kotlin)  "kotlin/gradle-demo" "src/main/kotlin/dev/hellmacs/demo/Greeter.kt")
    ((:lang . clojure) "clojure/deps-demo"  "src/demo/core.clj")
    ((:lang . groovy)  "groovy/gradle-demo" "src/main/groovy/dev/hellmacs/demo/Greeter.groovy"))
  "For each language module: a fixture, and the file of it opened.")

(defconst tel--scratch-files
  '(((:lang . docker)   "Dockerfile"      "FROM alpine:3.20\nRUN echo hi\n")
    ((:lang . yaml)     "config.yaml"     "name: demo\nitems:\n  - one\n")
    ((:lang . json)     "data.json"       "{\"name\": \"demo\"}\n")
    ((:lang . markdown) "README.md"       "# Demo\n\nSome *text*.\n")
    ((:lang . sh)       "run.sh"          "#!/bin/sh\necho hi\n")
    ((:lang . data)     "pom.xml"         "<project><modelVersion>4.0.0</modelVersion></project>\n"))
  "For the other language modules: a file written for the session.")

(defun tel--in-namespace-p ()
  "Non-nil if lookups go to this Emacs: the wrapper's namespace."
  (with-temp-buffer
    (ignore-errors (insert-file-contents "/etc/resolv.conf"))
    (string-match-p "^nameserver 127\\.0\\.0\\.1$" (buffer-string))))

(defun tel--lookup (name)
  "Look NAME up the way programs do (glibc's getaddrinfo), without blocking Emacs."
  (let ((proc (make-process :name "tel-lookup" :command (list "getent" "hosts" name)
                            :buffer nil :noquery t)))
    (e2e--wait (lambda () (not (process-live-p proc))) 10)))

(defun tel--enabled ()
  "The language modules this session checks: those enabled, in order."
  (seq-filter (lambda (key) (hellmacs-module-p (car key) (cdr key)))
              (mapcar #'car (append tel--files tel--scratch-files))))

(defun tel--session (dir)
  "Open a file of each enabled language (fixtures copied into DIR), start its
server, hover, save; return the modules whose server started."
  (let (started)
    (pcase-dolist (`(,key ,fixture ,file) tel--files)
      (when (hellmacs-module-p (car key) (cdr key))
        (let* ((proj (e2e-copy-fixture fixture))
               (path (expand-file-name file proj)))
          (with-current-buffer (find-file-noselect path)
            (switch-to-buffer (current-buffer))
            (e2e-add-project proj)
            (ignore-errors (lsp))
            (if (e2e--wait (lambda () (seq-some (lambda (ws) (eq (lsp--workspace-status ws) 'initialized))
                                                (lsp-workspaces)))
                           tel--seconds)
                (progn (push key started) (e2e--say "  ·  %s %s: server started" (car key) (cdr key)))
              (e2e--say "  ·  %s %s: no server started in %ds" (car key) (cdr key) tel--seconds))
            (goto-char (/ (point-max) 2))
            (ignore-errors (lsp-request "textDocument/hover" (lsp--text-document-position-params)))
            (goto-char (point-max))
            (insert "\n")
            (save-buffer)))))
    (pcase-dolist (`(,key ,name ,text) tel--scratch-files)
      (when (hellmacs-module-p (car key) (cdr key))
        (let ((path (expand-file-name name dir)))
          (with-temp-file path (insert text))
          (with-current-buffer (find-file-noselect path)
            (ignore-errors (lsp))
            (if (e2e--wait (lambda () (lsp-workspaces)) tel--seconds)
                (progn (push key started) (e2e--say "  ·  %s %s: server started" (car key) (cdr key)))
              (e2e--say "  ·  %s %s: no server started in %ds" (car key) (cdr key) tel--seconds))
            (goto-char (point-max))
            (insert "\n")
            (save-buffer)))))
    started))

(defun tel--run ()
  (unless (tel--in-namespace-p)
    (e2e--say "Run it through test/integration/telemetry-check.sh: lookups must reach this Emacs.")
    (kill-emacs 2))
  (require 'lsp-mode)
  (dns-log-start)
  (let ((dir (make-temp-file "hellmacs-telemetry" t))
        (allowed (dns-log-allowed-hosts (bound-and-true-p hellmacs-mirrors))))
    (e2e--say "Hellmacs telemetry check: an editing session, every lookup logged")
    (e2e-check "the log sees a program's lookup" :name log
      (tel--lookup "hellmacs-telemetry-self-test.invalid")
      (member "hellmacs-telemetry-self-test.invalid" dns-log-names))
    (e2e--say "\n== The session")
    (e2e-check "a file of each enabled language, its server started, a hover and a save" :name session :needs log
      (let ((missing (dns-log-servers-missing (tel--enabled) (tel--session dir))))
        (when missing (e2e--say "  ·  not checked: %S" missing))
        (null missing)))
    (e2e--wait #'ignore tel--seconds)   ; idle: what would report does it now
    (e2e--say "\n== Looked up")
    (let ((names (seq-remove (lambda (n) (equal n "hellmacs-telemetry-self-test.invalid"))
                             (reverse dns-log-names))))
      (dolist (name names)
        (e2e--say "  ·  %s%s" name (if (dns-log-allowed-p name allowed) "" "   <- not a build repository or mirror")))
      (unless names (e2e--say "  ·  (nothing)"))
      (e2e-check "no host but the build repositories and your mirrors was looked up" :needs session
        (not (seq-remove (lambda (n) (dns-log-allowed-p n allowed)) names))))
    (delete-directory dir t))
  (e2e-finish))

(tel--run)

;;; telemetry-e2e.el ends here
