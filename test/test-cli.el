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

(defvar hellmacs-upgrade-channel)
(defvar hellmacs-upgrade-verify-tags)

(ert-deftest test-cli/run-all ()
  "Commands run concurrently; exit codes come back in order."
  (let ((hellmacs-cli-jobs 2))
    (should (equal (hellmacs-cli--run-all '(("sh" "-c" "exit 3") ("true") ("sh" "-c" "sleep 0.2; exit 1")
                                            ("hellmacs-no-such-program") ("false")))
                   '(3 0 1 127 1))))
  (should (equal (hellmacs-cli--run-all nil) nil)))

(ert-deftest test-cli/run-all-program-that-cannot-run ()
  "A program that's there but can't be run is exit code 126, not an error
that aborts the command."
  (let ((file (make-temp-file "hellmacs-test-noexec")))
    (unwind-protect
        (progn
          (set-file-modes file #o644)
          (should (equal (hellmacs-cli--run-all (list (list file) '("true")))
                         '(126 0))))
      (delete-file file))))

(ert-deftest test-cli/upgrade-self-short-revisions ()
  "A revision git prints shorter than 7 characters doesn't crash the report."
  (let ((heads (list "abc" "def")) said)
    (cl-letf (((symbol-function 'hellmacs-cli--run)
               (lambda (_program &rest args)
                 (pcase (member "rev-parse" args)
                   ((and `(,_ "HEAD") (guard t)) (cons 0 (pop heads)))
                   (`(,_ "--git-dir") '(0 . ".git"))
                   (`(,_ "--abbrev-ref" . ,_) '(0 . "origin/main"))
                   (_ '(0 . "")))))
              ((symbol-function 'hellmacs-cli--say)
               (lambda (fmt &rest args) (push (apply #'format fmt args) said))))
      (hellmacs-cli-upgrade-self "--channel" "main")
      (should (equal (car said) "Updated Hellmacs abc -> def")))))

(ert-deftest test-cli/env-keeps-secrets-out ()
  "`bin/hellmacs env' saves your shell's setup, not its secrets, readable by you only."
  (let* ((dir (make-temp-file "hellmacs-test-env" t))
         (hellmacs-env-file (expand-file-name "env" dir))
         (initial-environment '("PATH=/usr/bin" "JAVA_HOME=/opt/jdk"
                                "GITHUB_TOKEN=ghp_x" "AWS_SECRET_ACCESS_KEY=x" "OPENAI_API_KEY=x"
                                "DB_PASSWORD=x" "NPM_AUTH_TOKEN=x" "GPG_PASSPHRASE=x")))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-cli--say) #'ignore))
          (hellmacs-cli-env)
          (should (equal (hellmacs--read-env-file hellmacs-env-file)
                         '("JAVA_HOME=/opt/jdk" "PATH=/usr/bin")))
          (should (= (file-modes hellmacs-env-file) #o600)))
      (delete-directory dir t))))

;;; Releases and channels ----------------------------------------------------------

(ert-deftest test-cli/version ()
  "Hellmacs has a semantic version; `bin/hellmacs version' says it, with the
channel `upgrade' follows and the Emacs it runs on."
  (should (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\(?:-[0-9A-Za-z.]+\\)?\\'" hellmacs-version))
  (let (said)
    (cl-letf (((symbol-function 'hellmacs-cli--say)
               (lambda (fmt &rest args) (push (apply #'format fmt args) said))))
      (let ((hellmacs-upgrade-channel 'stable))
        (hellmacs-cli-version)))
    (let ((text (string-join (reverse said) "\n")))
      (should (string-search (concat "Hellmacs " hellmacs-version) text))
      (should (string-search "channel: stable" text))
      (should (string-search emacs-version text)))))

(ert-deftest test-cli/latest-release ()
  "The stable channel's release: the highest vMAJOR.MINOR.PATCH tag, by
version, not by name; pre-releases and other tags don't count."
  (should (equal (hellmacs-cli--latest-release
                  '("v0.9.0" "v0.10.0" "v0.9.12" "v1.0.0-rc.1" "nightly" "0.11.0"))
                 "v0.10.0"))
  (should-not (hellmacs-cli--latest-release '("nightly" "v1.0.0-rc.1"))))

(defun test-cli--git (dir &rest args)
  (with-temp-buffer
    (unless (zerop (apply #'call-process "git" nil t nil "-C" dir
                          "-c" "user.name=t" "-c" "user.email=t@t" "-c" "commit.gpgsign=false"
                          "-c" "tag.gpgsign=false" args))
      (error "git %s: %s" (string-join args " ") (buffer-string)))
    (string-trim (buffer-string))))

(defmacro test-cli--with-checkout (&rest body)
  "Run BODY with `upstream', a repository with releases v0.1.0 and v0.2.0 and a
later commit on main, and `hellmacs-dir' bound to a clone of it."
  (declare (indent 0))
  `(let* ((root (make-temp-file "hellmacs-test-upgrade" t))
          (upstream (expand-file-name "upstream" root))
          (clone (expand-file-name "clone" root)))
     (unwind-protect
         (progn
           (make-directory upstream)
           (test-cli--git upstream "init" "-q" "-b" "main")
           (dolist (step '(("one" "v0.1.0") ("two" "v0.2.0") ("three" nil)))
             (with-temp-file (expand-file-name "file" upstream) (insert (car step)))
             (test-cli--git upstream "add" "file")
             (test-cli--git upstream "commit" "-q" "-m" (car step))
             (when (cadr step) (test-cli--git upstream "tag" "-a" (cadr step) "-m" (cadr step))))
           (test-cli--git root "clone" "-q" upstream clone)
           (let ((hellmacs-dir (file-name-as-directory clone)))
             (cl-letf (((symbol-function 'hellmacs-cli--say) #'ignore))
               ,@body)))
       (delete-directory root t))))

(defun test-cli--content ()
  (with-temp-buffer (insert-file-contents (expand-file-name "file" hellmacs-dir)) (buffer-string)))

(ert-deftest test-cli/upgrade-self-channels ()
  "The stable channel checks out the latest release; main follows the branch,
as before; back on stable, the release again. Nothing moves with local
changes."
  (skip-unless (executable-find "git"))
  (test-cli--with-checkout
    (should (equal (test-cli--content) "three"))          ; a fresh clone is on main
    (hellmacs-cli-upgrade-self "--channel" "stable")
    (should (equal (test-cli--content) "two"))
    (should (equal (test-cli--git hellmacs-dir "describe" "--tags" "--exact-match") "v0.2.0"))
    ;; A new release upstream: the next stable upgrade takes it.
    (with-temp-file (expand-file-name "file" upstream) (insert "four"))
    (test-cli--git upstream "commit" "-q" "-am" "four")
    (test-cli--git upstream "tag" "-a" "v0.3.0" "-m" "v0.3.0")
    (hellmacs-cli-upgrade-self "--channel" "stable")
    (should (equal (test-cli--content) "four"))
    ;; Main, from a release: back on the branch, at its tip.
    (with-temp-file (expand-file-name "file" upstream) (insert "five"))
    (test-cli--git upstream "commit" "-q" "-am" "five")
    (hellmacs-cli-upgrade-self "--channel" "main")
    (should (equal (test-cli--content) "five"))
    (should (equal (test-cli--git hellmacs-dir "rev-parse" "--abbrev-ref" "HEAD") "main"))
    ;; Local changes: nothing moves.
    (with-temp-file (expand-file-name "file" hellmacs-dir) (insert "mine"))
    (hellmacs-cli-upgrade-self "--channel" "stable")
    (should (equal (test-cli--content) "mine"))))

(ert-deftest test-cli/upgrade-self-default-channel ()
  "Without --channel, `hellmacs-upgrade-channel' decides: stable by default."
  (skip-unless (executable-find "git"))
  (should (eq (default-value 'hellmacs-upgrade-channel) 'stable))
  (test-cli--with-checkout
    (let ((hellmacs-upgrade-channel 'stable))
      (hellmacs-cli-upgrade-self)
      (should (equal (test-cli--content) "two")))
    (let ((hellmacs-upgrade-channel 'main))
      (hellmacs-cli-upgrade-self)
      (should (equal (test-cli--content) "three"))))
  ;; A channel that isn't one is an error, before anything moves.
  (should-error (hellmacs-cli-upgrade-self "--channel" "nightly")))

(ert-deftest test-cli/upgrade-self-no-release-yet ()
  "The stable channel with no release to go to stays where it is and says so."
  (skip-unless (executable-find "git"))
  (test-cli--with-checkout
    (dolist (tag '("v0.1.0" "v0.2.0"))
      (test-cli--git upstream "tag" "-d" tag)
      (test-cli--git hellmacs-dir "tag" "-d" tag))
    (let (said)
      (cl-letf (((symbol-function 'hellmacs-cli--say)
                 (lambda (fmt &rest args) (push (apply #'format fmt args) said))))
        (hellmacs-cli-upgrade-self "--channel" "stable"))
      (should (equal (test-cli--content) "three"))
      (should (string-match-p "no release" (car said))))))

(ert-deftest test-cli/upgrade-self-verifies-tags ()
  "With `hellmacs-upgrade-verify-tags', an unsigned (or badly signed) release
isn't checked out."
  (skip-unless (executable-find "git"))
  (test-cli--with-checkout
    (let ((hellmacs-upgrade-verify-tags t))
      (should-error (hellmacs-cli-upgrade-self "--channel" "stable"))
      (should (equal (test-cli--content) "three")))))

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
