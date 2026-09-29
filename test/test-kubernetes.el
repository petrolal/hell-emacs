;;; test-kubernetes.el --- Tests for the :tools kubernetes module (Phase 12.6) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The module's live checks (a kind cluster)
;; are in docs/roadmap.md, 12.6.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-cli)

(defmacro test-kubernetes--with-programs (programs &rest body)
  "Run BODY with only PROGRAMS on `exec-path': (NAME . SCRIPT-BODY) fakes."
  (declare (indent 1))
  `(let* ((bin (make-temp-file "hellmacs-test-kubernetes-bin" t))
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

(defun test-kubernetes--doctor ()
  "The output of the module's doctor checks."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-cli--problems 0)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools kubernetes))
    ;; `load' prints to the terminal, whatever `standard-output' is here.
    (let (lines)
      (cl-letf (((symbol-function 'hellmacs-cli--say)
                 (lambda (fmt &rest args) (push (apply #'format fmt args) lines))))
        (hellmacs-module--load '(:tools . kubernetes) "doctor.el"))
      (string-join (nreverse lines) "\n"))))

(defun test-kubernetes--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools kubernetes))
    (hellmacs-module--load '(:tools . kubernetes) "config.el")
    mode-specific-map))

(defun test-kubernetes--packages ()
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:tools kubernetes))
    (hellmacs-module--load '(:tools . kubernetes) "packages.el")
    (sort (mapcar #'car hellmacs-packages) #'string<)))

(ert-deftest test-kubernetes/packages ()
  "kubel, with its dependencies declared up front, once each."
  (should (equal (test-kubernetes--packages) '(dash kubel s yaml-mode))))

(ert-deftest test-kubernetes/key-and-entry-point ()
  "`C-c o k' opens kubel, which loads it on demand."
  (let ((map (test-kubernetes--load-config)))
    (should (eq (keymap-lookup map "o k") 'kubel)))
  (should (autoloadp (symbol-function 'kubel))))

(ert-deftest test-kubernetes/doctor ()
  "Doctor names kubectl and your current context, reading only local config."
  (test-kubernetes--with-programs
      '(("kubectl" . "case \"$1\" in version) echo 'Client Version: v1.37.0';; config) echo kind-dev;; *) exit 1;; esac"))
    (let ((out (test-kubernetes--doctor)))
      (should (string-match-p "✓ kubectl: Client Version: v1\\.37\\.0" out))
      (should (string-match-p "· Kubernetes context: kind-dev" out))))
  (test-kubernetes--with-programs
      '(("kubectl" . "case \"$1\" in version) echo 'Client Version: v1.37.0';; *) echo 'error: current-context is not set' >&2; exit 1;; esac"))
    (should (string-match-p "· No current Kubernetes context" (test-kubernetes--doctor))))
  (test-kubernetes--with-programs nil
    (should (string-match-p "! kubectl not found" (test-kubernetes--doctor)))))

(provide 'test-kubernetes)
;;; test-kubernetes.el ends here
