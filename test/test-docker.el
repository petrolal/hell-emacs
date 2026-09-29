;;; test-docker.el --- Tests for the :tools docker module (Phase 12.6) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The module's live checks (a Docker daemon)
;; are in docs/roadmap.md, 12.6.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-cli)

(defmacro test-docker--with-programs (programs &rest body)
  "Run BODY with only PROGRAMS on `exec-path': (NAME . SCRIPT-BODY) fakes."
  (declare (indent 1))
  `(let* ((bin (make-temp-file "hellmacs-test-docker-bin" t))
          (exec-path (list bin))
          (process-environment (cons (concat "PATH=" bin) process-environment)))
     (unwind-protect
         (progn
           (dolist (p ,programs)
             (let ((file (expand-file-name (car p) bin)))
               (with-temp-file file (insert "#!/bin/sh\n" (cdr p) "\n"))
               (set-file-modes file #o755)))
           ,@body)
       (delete-directory bin t))))

(defun test-docker--doctor ()
  "The output of the module's doctor checks."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-cli--problems 0)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools docker))
    ;; `load' prints to the terminal, whatever `standard-output' is here.
    (let (lines)
      (cl-letf (((symbol-function 'hellmacs-cli--say)
                 (lambda (fmt &rest args) (push (apply #'format fmt args) lines))))
        (hellmacs-module--load '(:tools . docker) "doctor.el"))
      (string-join (nreverse lines) "\n"))))

(defun test-docker--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools docker))
    (hellmacs-module--load '(:tools . docker) "config.el")
    mode-specific-map))

(defun test-docker--packages ()
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:tools docker))
    (hellmacs-module--load '(:tools . docker) "packages.el")
    (sort (mapcar #'car hellmacs-packages) #'string<)))

(defvar docker-command)
(defvar docker-compose-command)
(defvar docker-container-tramp-method)

(ert-deftest test-docker/packages ()
  "docker.el, with its dependencies declared up front, once each."
  (should (equal (test-docker--packages) '(aio dash docker s tablist))))

(ert-deftest test-docker/key-and-entry-point ()
  "`C-c o d' opens docker.el's menu, which loads it on demand."
  (let ((map (test-docker--load-config)))
    (should (eq (keymap-lookup map "o d") 'docker)))
  (should (autoloadp (symbol-function 'docker))))

(ert-deftest test-docker/podman-when-no-docker ()
  "The CLI is docker's; podman's when only podman is installed, for the
commands, compose and container shells alike."
  (test-docker--load-config)
  (dolist (case '((("docker" "podman") . "docker") (("podman") . "podman")
                  (("docker") . "docker") (nil . "docker")))
    (test-docker--with-programs (mapcar (lambda (p) (cons p "exit 0")) (car case))
      (let ((docker-command "docker")
            (docker-compose-command "docker compose")
            (docker-container-tramp-method "docker"))
        (hellmacs-docker-use-installed-cli)
        (should (equal docker-command (cdr case)))
        (should (equal docker-compose-command (concat (cdr case) " compose")))
        (should (equal docker-container-tramp-method (cdr case)))))))

(ert-deftest test-docker/your-own-cli-setting-is-kept ()
  "A `docker-command' you set yourself is left alone."
  (test-docker--load-config)
  (test-docker--with-programs '(("podman" . "exit 0"))
    (let ((docker-command "/opt/bin/docker")
          (docker-compose-command "docker compose")
          (docker-container-tramp-method "docker"))
      (hellmacs-docker-use-installed-cli)
      (should (equal docker-command "/opt/bin/docker")))))

(ert-deftest test-docker/doctor ()
  "Doctor names the CLI and the context it uses, without needing a daemon."
  (test-docker--with-programs '(("docker" . "case \"$1\" in --version) echo 'Docker version 29.8.1';; context) echo work-cluster;; esac"))
    (let ((out (test-docker--doctor)))
      (should (string-match-p "✓ docker: Docker version 29\\.8\\.1" out))
      (should (string-match-p "· Docker context: work-cluster" out))))
  (test-docker--with-programs '(("podman" . "echo 'podman version 5.6.0'"))
    (should (string-match-p "✓ podman: podman version 5\\.6\\.0" (test-docker--doctor))))
  (test-docker--with-programs nil
    (should (string-match-p "! docker not found" (test-docker--doctor)))))

(provide 'test-docker)
;;; test-docker.el ends here
