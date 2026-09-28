;;; test-cli.el --- Tests for core/hellmacs-cli.el -*- lexical-binding: t; -*-

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
(require 'hellmacs-cli)

(ert-deftest test-cli/run-all ()
  "Commands run concurrently; exit codes come back in order."
  (let ((hellmacs-cli-jobs 2))
    (should (equal (hellmacs-cli--run-all '(("sh" "-c" "exit 3") ("true") ("sh" "-c" "sleep 0.2; exit 1")
                                            ("hellmacs-no-such-program") ("false")))
                   '(3 0 1 127 1))))
  (should (equal (hellmacs-cli--run-all nil) nil)))

(ert-deftest test-cli/doctor-reachable ()
  "Each way a host can't be reached gets its own advice; nothing is probed unless asked."
  (let ((hellmacs-proxy nil) (hellmacs-no-proxy nil) (hellmacs-mirrors nil) (hellmacs-ca-bundle nil)
        (process-environment (seq-remove (lambda (e) (string-match-p "\\`[Hh][Tt][Tt][Pp][Ss]?_[Pp][Rr][Oo][Xx][Yy]=" e))
                                         process-environment))
        (hellmacs-cli--problems 0)
        (hellmacs-cli--probed nil)
        (result nil)
        (probes 0))
    (cl-letf (((symbol-function 'hellmacs-net-probe) (lambda (_) (cl-incf probes) result)))
      (let ((hellmacs-cli--probe-network nil))
        (should (equal (with-output-to-string (hellmacs-doctor-reachable "https://a.example/" "x")) ""))
        (should (zerop probes)))
      (let ((hellmacs-cli--probe-network t))
        (should (string-match-p "✓ Reaches a.example (x)"
                                (with-output-to-string (hellmacs-doctor-reachable "https://a.example/" "x"))))
        ;; Probed once per run.
        (with-output-to-string (hellmacs-doctor-reachable "https://a.example/" "y"))
        (should (= probes 1))
        (setq result '(tls . "certificate signer was not found"))
        (should (string-match-p "set `hellmacs-ca-bundle'"
                                (with-output-to-string (hellmacs-doctor-reachable "https://b.example/" "x"))))
        (let ((hellmacs-ca-bundle "/corp/ca.pem"))
          (should (string-match-p "missing from `hellmacs-ca-bundle'"
                                  (with-output-to-string (hellmacs-doctor-reachable "https://c.example/" "x")))))
        (setq result '(proxy . "it refused the tunnel (HTTP 407)"))
        (let ((hellmacs-proxy "http://me:secret@proxy.example:3128"))
          (let ((out (with-output-to-string (hellmacs-doctor-reachable "https://d.example/" "x"))))
            (should (string-match-p "through the proxy http://me:\\*\\*\\*@proxy.example:3128" out))
            (should-not (string-search "secret" out))))
        (setq result '(connect . "d.example: no such host (DNS)"))
        (should (string-match-p "set `hellmacs-proxy'"
                                (with-output-to-string (hellmacs-doctor-reachable "https://e.example/" "x"))))
        (should (= hellmacs-cli--problems 4))))))

(ert-deftest test-cli/detached-checkouts ()
  "Only checkouts on a detached HEAD are picked; others, and non-repos, aren't."
  (skip-unless (executable-find "git"))
  (let ((root (make-temp-file "hellmacs-test-cli" t)))
    (unwind-protect
        (let ((git (lambda (dir &rest args)
                     (apply #'call-process "git" nil nil nil "-C" dir
                            "-c" "user.name=t" "-c" "user.email=t@example.invalid" args))))
          (dolist (name '("on-branch" "detached"))
            (let ((dir (expand-file-name name root)))
              (make-directory dir)
              (funcall git dir "init" "-q")
              (funcall git dir "commit" "-q" "--allow-empty" "-m" "x")))
          (funcall git (expand-file-name "detached" root) "checkout" "-q" "--detach")
          (make-directory (expand-file-name "not-a-repo" root))
          (cl-letf (((symbol-function 'elpaca<-source-dir) (lambda (e) (expand-file-name e root))))
            (should (equal (hellmacs-cli--detached '("on-branch" "detached" "not-a-repo" "missing"))
                           '("detached")))))
      (delete-directory root t))))

(ert-deftest test-cli/platform-checks ()
  "Platform checks report WSL, macOS, or standard Linux correctly."
  (let ((hellmacs-cli--problems 0))
    ;; Mocking WSL
    (cl-letf (((symbol-function 'hellmacs-cli--wsl-p) (lambda () t)))
      (let ((hellmacs-dir "/home/user/.config/emacs")
            (hellmacs-user-dir "/home/user/.config/hellmacs"))
        (should (string-match-p "Windows WSL2"
                                (with-output-to-string (hellmacs-cli--doctor-platform)))))
      (let ((hellmacs-dir "/mnt/c/Users/user/hellmacs")
            (hellmacs-user-dir "/home/user/.config/hellmacs"))
        (should (string-match-p "Windows mount"
                                (with-output-to-string (hellmacs-cli--doctor-platform))))))
    ;; Mocking Darwin
    (cl-letf (((symbol-function 'hellmacs-cli--wsl-p) (lambda () nil)))
      (let ((system-type 'darwin)
            (hellmacs-env-file (make-temp-name "/tmp/nonexistent-env")))
        (should (string-match-p "macOS"
                                (with-output-to-string (hellmacs-cli--doctor-platform))))))))

(ert-deftest test-cli/doctor-node ()
  "Node is checked for the npm servers: missing, too old, or fine."
  (let ((hellmacs-cli--problems 0))
    (cl-letf (((symbol-function 'executable-find) #'ignore))
      (should (string-match-p "node not found -- the YAML server"
                              (with-output-to-string (hellmacs-doctor-node "the YAML server" 20))))
      (should (= hellmacs-cli--problems 1)))
    (cl-letf (((symbol-function 'executable-find) (lambda (p) (concat "/usr/bin/" p)))
              ((symbol-function 'hellmacs-cli--version) (lambda (&rest _) "v18.19.0")))
      (should (string-match-p (regexp-quote "Node v18.19.0 is too old for the Bash server (it needs 20+)")
                              (with-output-to-string (hellmacs-doctor-node "the Bash server" 20))))
      (should (= hellmacs-cli--problems 2)))
    (cl-letf (((symbol-function 'executable-find) (lambda (p) (concat "/usr/bin/" p)))
              ((symbol-function 'hellmacs-cli--version) (lambda (&rest _) "v26.10.0")))
      (should (string-match-p "node: v26.10.0"
                              (with-output-to-string (hellmacs-doctor-node "the Bash server" 20))))
      (should (= hellmacs-cli--problems 2)))))

(provide 'test-cli)
;;; test-cli.el ends here
