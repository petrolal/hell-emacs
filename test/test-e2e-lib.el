;;; test-e2e-lib.el --- Tests for the end-to-end harness -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The end-to-end scripts need real servers;
;; the harness they share (test/integration/e2e-lib.el) doesn't.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load (expand-file-name "integration/e2e-lib"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defvar e2e--failures)
(defvar e2e--skipped)
(defvar e2e--not-run)
(defvar e2e--results)
(defvar e2e-deadline)
(defvar e2e-output)

(defmacro test-e2e--with (&rest body)
  "Run BODY with fresh counters and no deadline; what's said goes to `said'."
  (declare (indent 0))
  `(let* ((said nil)
          (e2e-output (lambda (c) (push c said)))
          (process-environment (cons "HELLMACS_E2E_OUT" process-environment))
          (e2e--failures 0) (e2e--skipped 0) (e2e--not-run 0) (e2e--results nil)
          (e2e-deadline nil))
     (cl-flet ((output () (concat (reverse said))))
       ,@body)))

(ert-deftest test-e2e-lib/checks-as-before ()
  "A check without keywords passes or fails on its body's value, as it did."
  (test-e2e--with
    (should (e2e-check "yes" t))
    (should-not (e2e-check "no" nil))
    (should-not (e2e-check "boom" (error "Boom")))
    (should (= e2e--failures 2))
    (should (string-match-p "PASS  yes" (output)))
    (should (string-match-p "FAIL  no" (output)))))

(ert-deftest test-e2e-lib/needs-skips-without-waiting ()
  "A check whose `:needs' failed (or was skipped) is skipped, its body never run:
a server that didn't start doesn't make every later check wait it out."
  (test-e2e--with
    (let ((ran nil))
      (e2e-check "server starts" :name server nil)
      (e2e-check "definition" :needs server (setq ran t))
      (e2e-check "hover" :name hover :needs (server) (setq ran t))
      (e2e-check "after hover" :needs hover (setq ran t))
      (should-not ran)
      (should (= e2e--failures 1))
      (should (= e2e--not-run 3))
      (should (string-match-p "SKIP  definition (needs: server starts)" (output)))
      (should (string-match-p "SKIP  after hover (needs: hover)" (output))))
    ;; Met: it runs.
    (let ((ran nil))
      (e2e-check "builds" :name build t)
      (e2e-check "tests" :needs build (setq ran t))
      (should ran))))

(ert-deftest test-e2e-lib/deadline ()
  "Past the script's deadline no wait goes on, and the checks left are skipped."
  (test-e2e--with
    (setq e2e-deadline (+ (float-time) 0.3))
    (let ((start (float-time)))
      (should-not (e2e--wait #'ignore 30))
      (should (< (- (float-time) start) 2)))
    (let ((ran nil))
      (e2e-check "late" (setq ran t))
      (should-not ran)
      (should (string-match-p "SKIP  late (out of time" (output))))))

(ert-deftest test-e2e-lib/backstop ()
  "If something hangs past the deadline anyway, the backstop reports and exits."
  (test-e2e--with
    (let ((exit nil))
      (e2e-check "done" :name done t)
      (e2e-check "hung" nil)
      (cl-letf (((symbol-function 'kill-emacs) (lambda (&optional code) (setq exit code))))
        (e2e--backstop))
      (should (eql exit 1))
      (should (string-match-p "Stopped: past the deadline" (output)))
      (should (string-match-p "1 FAILED" (output))))))

(ert-deftest test-e2e-lib/finish ()
  "The summary line and the exit code."
  (test-e2e--with
    (let ((exit nil))
      (cl-letf (((symbol-function 'kill-emacs) (lambda (&optional code) (setq exit code))))
        (e2e-check "ok" t)
        (e2e-finish)
        (should (eql exit 0))
        (should (string-match-p "ALL PASSED" (output)))
        (e2e-check "no" nil)
        (e2e-check "later" :needs nothing-that-ran t)
        (e2e-finish)
        (should (eql exit 1))
        (should (string-match-p "1 FAILED, 1 NOT RUN" (output)))
        ;; A skip for what the machine lacks doesn't fail the run.
        (setq e2e--failures 0 e2e--not-run 0)
        (e2e-skip "needs Docker" "no docker")
        (e2e-finish)
        (should (eql exit 0))
        (should (string-match-p "ALL PASSED (1 skipped)" (output)))))))

(provide 'test-e2e-lib)
;;; test-e2e-lib.el ends here
