;;; test-direnv.el --- Tests for the :tools direnv module -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'compile)
(require 'hellmacs-modules)

(defvar hellmacs-module-dependencies)
(defvar hellmacs-treesit-declarations)
(defvar hellmacs-cli--problems)

(defmacro test-direnv--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-direnv" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-direnv/module-declaration ()
  "Module packages declaration registers envrc."
  (let ((hellmacs-packages nil))
    ;; Verify package registration structure for direnv
    (package! envrc)
    (should (assq 'envrc hellmacs-packages))))

(ert-deftest test-direnv/detect-envrc-file ()
  "Detects presence of .envrc in project root."
  (test-direnv--with-tree
      '((".envrc" . "export JAVA_HOME=/opt/jdks/jdk-11\nexport MAVEN_OPTS=\"-Xmx1024m\"\n")
        ("pom.xml" . "<project></project>\n"))
    (should (file-exists-p (expand-file-name ".envrc" root)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name ".envrc" root))
      (should (search-forward "JAVA_HOME" nil t)))))

(ert-deftest test-direnv/environment-isolation ()
  "Simulates buffer-local process-environment switching across projects."
  (let ((global-env process-environment)
        (proj1-env (cons "JAVA_HOME=/opt/jdk-8" process-environment))
        (proj2-env (cons "JAVA_HOME=/opt/jdk-17" process-environment)))
    (with-temp-buffer
      (setq-local process-environment proj1-env)
      (should (equal (getenv "JAVA_HOME") "/opt/jdk-8")))
    (with-temp-buffer
      (setq-local process-environment proj2-env)
      (should (equal (getenv "JAVA_HOME") "/opt/jdk-17")))
    (should (equal process-environment global-env))))

(defmacro test-direnv--with-module (&rest body)
  "Run BODY with :tools direnv (and :tools build) enabled."
  (declare (indent 0))
  `(let ((hellmacs-modules (make-hash-table :test #'equal))
         (warning-minimum-log-level :emergency))
     (hellmacs--enable-modules '(:tools build direnv))
     ,@body))

(ert-deftest test-direnv/the-module-declares-envrc ()
  ":tools direnv exists, declares envrc, and is on by default."
  (test-direnv--with-module
    (should (hellmacs-module-get '(:tools . direnv) :path))
    (let ((hellmacs-packages nil) (hellmacs-module-dependencies nil) (hellmacs-treesit-declarations nil))
      (hellmacs-modules-read-packages)
      (should (assq 'envrc hellmacs-packages))))
  (with-temp-buffer
    (insert-file-contents (expand-file-name "static/init.example.el" hellmacs-dir))
    (should (re-search-forward "^ +direnv +;" nil t))))

(ert-deftest test-direnv/on-with-the-first-file ()
  "envrc comes on with the first file, not at startup, and binds no keys."
  (test-direnv--with-module
    (let ((hellmacs-first-file-hook nil)
          (keys-before (copy-keymap global-map)))
      (hellmacs-module--load '(:tools . direnv) "config.el")
      (should (memq 'envrc-global-mode hellmacs-first-file-hook))
      (should-not (featurep 'envrc))
      (should (equal global-map keys-before)))))

(defun test-direnv--doctor ()
  "What :tools direnv's doctor.el reports, as one string.
Collected where doctor prints: `load' sends a file's output straight to
stdout, past `with-output-to-string'."
  (let ((lines nil))
    (cl-letf (((symbol-function 'hellmacs-cli--say)
               (lambda (fmt &rest args) (push (apply #'format fmt args) lines))))
      (hellmacs-module--load '(:tools . direnv) "doctor.el"))
    (string-join (nreverse lines) "\n")))

(ert-deftest test-direnv/doctor-checks-direnv ()
  "Doctor finds direnv, or says what's missing without it."
  (require 'hellmacs-cli)
  (let* ((bin (make-temp-file "hellmacs-test-direnv-bin" t))
         (fake (expand-file-name "direnv" bin))
         (hellmacs-cli--problems 0))
    (unwind-protect
        (test-direnv--with-module
          (let ((exec-path (list bin)))
            (should (string-match-p "! direnv not found -- per-project environments from .envrc"
                                    (test-direnv--doctor)))
            (with-temp-file fake (insert "#!/bin/sh\necho 2.37.1\n"))
            (set-file-modes fake #o755)
            (should (string-match-p "✓ direnv: 2.37.1" (test-direnv--doctor)))
            (should (zerop hellmacs-cli--problems))))
      (delete-directory bin t))))

(ert-deftest test-direnv/the-project-build-gets-the-buffer-environment ()
  "A build started from a buffer runs with that buffer's environment, as envrc sets it."
  (test-direnv--with-module
    (hellmacs-module--load '(:tools . build) "autoload.el")
    (test-direnv--with-tree
        '(("mvnw" . "#!/bin/sh\necho \"JAVA_HOME=$JAVA_HOME\"\n")
          ("pom.xml" . "<project></project>\n"))
      (set-file-modes (expand-file-name "mvnw" root) #o755)
      (let ((output nil))
        (with-temp-buffer
          (setq default-directory root)
          (setq-local process-environment (cons "JAVA_HOME=/project/jdk8" process-environment))
          (let ((hook (lambda (buf _) (setq output (with-current-buffer buf (buffer-string))))))
            (add-hook 'compilation-finish-functions hook)
            (unwind-protect
                (progn (hellmacs-forge-build)
                       (with-timeout (30) (while (not output) (accept-process-output nil 0.1))))
              (remove-hook 'compilation-finish-functions hook))))
        (should (string-match-p "^JAVA_HOME=/project/jdk8$" (or output "")))
        (should-not (equal (getenv "JAVA_HOME") "/project/jdk8"))))))

(provide 'test-direnv)
;;; test-direnv.el ends here
