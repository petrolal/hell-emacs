;;; test-lib.el --- Tests for core/hellmacs-lib.el -*- lexical-binding: t; -*-

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
(require 'hellmacs-lib)

(defvar test-lib--log nil)
(defvar test-lib--hook nil)
(defvar test-lib--setq-hook nil)
(defvar test-lib--var 1)
(defvar test-lib--errors-hook nil)
(defvar test-lib--trigger-hook nil)
(defvar test-lib--once-hook nil)

(ert-deftest test-lib/add-hook!-forms ()
  "Forms, `defun's and function symbols; :append; `remove-hook!'."
  (setq test-lib--hook nil test-lib--log nil)
  (add-hook! 'test-lib--hook (push 'a test-lib--log))
  (add-hook! 'test-lib--hook (defun test-lib--fn-h () (push 'b test-lib--log)))
  (add-hook! 'test-lib--hook :append #'ignore)
  (run-hooks 'test-lib--hook)
  (should (equal (sort test-lib--log #'string<) '(a b)))
  (remove-hook! 'test-lib--hook #'test-lib--fn-h)
  (should-not (memq 'test-lib--fn-h test-lib--hook))
  (should (eq (car (last test-lib--hook)) 'ignore)))

(ert-deftest test-lib/add-hook!-unquoted-modes ()
  "An unquoted mode name means that mode's hook."
  (defvar test-lib-foo-mode-hook nil)
  (defvar test-lib-bar-mode-hook nil)
  (add-hook! (test-lib-foo-mode test-lib-bar-mode) #'ignore)
  (should (memq 'ignore test-lib-foo-mode-hook))
  (should (memq 'ignore test-lib-bar-mode-hook)))

(ert-deftest test-lib/setq-hook! ()
  "Sets buffer-locally; re-evaluating doesn't add a second function."
  (setq test-lib--setq-hook nil)
  (setq-hook! 'test-lib--setq-hook test-lib--var 5)
  (setq-hook! 'test-lib--setq-hook test-lib--var 5)
  (should (= 1 (length test-lib--setq-hook)))
  (with-temp-buffer
    (run-hooks 'test-lib--setq-hook)
    (should (= test-lib--var 5)))
  (should (= test-lib--var 1)))

(ert-deftest test-lib/after!-several-features ()
  "Runs only once every listed feature is loaded."
  (setq test-lib--log nil)
  (after! (test-lib-feat-a test-lib-feat-b) (push 'done test-lib--log))
  (provide 'test-lib-feat-a)
  (should-not test-lib--log)
  (provide 'test-lib-feat-b)
  (should (equal test-lib--log '(done))))

(ert-deftest test-lib/defadvice! ()
  "Defines the advice (with its docstring) and adds it."
  (defun test-lib--target () 1)
  (defadvice! test-lib--target-a (fn) "Add one." :around #'test-lib--target (1+ (funcall fn)))
  (should (= (test-lib--target) 2))
  (should (equal (documentation 'test-lib--target-a) "Add one.")))

(ert-deftest test-lib/cmd! ()
  (should (commandp (cmd! 1))))

(ert-deftest test-lib/context ()
  (should-not (hellmacs-context-p 'reload))
  (with-hellmacs-context 'reload
    (should (hellmacs-context-p 'reload)))
  (should-not (hellmacs-context-p 'reload))
  (should-error (hellmacs-context-push 'bogus)))

(ert-deftest test-lib/context-pop-leaves-the-outer-value ()
  "Popping inside `with-hellmacs-context' doesn't change the outer list."
  (let ((hellmacs-context (list 'emacs 'startup t)))
    (with-hellmacs-context 'module
      (hellmacs-context-pop 'startup)
      (should-not (hellmacs-context-p 'startup)))
    (should (equal hellmacs-context '(emacs startup t)))))

(ert-deftest test-lib/run-hooks-isolates-errors ()
  "One failing function doesn't stop the others."
  (setq test-lib--errors-hook nil test-lib--log nil)
  (add-hook 'test-lib--errors-hook (lambda () (error "Boom")))
  (add-hook 'test-lib--errors-hook (lambda () (push 'ok test-lib--log)) 90)
  (let ((debug-on-error nil)
        (warning-minimum-log-level :emergency))
    (hellmacs-run-hooks 'test-lib--errors-hook))
  (should (equal test-lib--log '(ok))))

(ert-deftest test-lib/run-hook-on ()
  "Fires once, only after startup, then clears itself."
  (setq test-lib--trigger-hook nil test-lib--once-hook nil test-lib--log nil)
  (add-hook 'test-lib--once-hook (lambda () (push 'fired test-lib--log)))
  (hellmacs-run-hook-on 'test-lib--once-hook '(test-lib--trigger-hook))
  (let ((hellmacs-init-time nil))
    (run-hooks 'test-lib--trigger-hook))
  (should-not test-lib--log)
  (let ((hellmacs-init-time 1.0))
    (run-hooks 'test-lib--trigger-hook)
    (run-hooks 'test-lib--trigger-hook))
  (should (equal test-lib--log '(fired)))
  (should-not test-lib--trigger-hook)
  (should-not test-lib--once-hook))

(ert-deftest test-lib/nerd-font-check-is-kept-per-frame ()
  "The frame is asked once, and again after a font change."
  (let ((asked 0))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'char-displayable-p) (lambda (_) (cl-incf asked) t)))
      (unwind-protect
          (progn
            (set-frame-parameter nil 'hellmacs--nerd-font nil)
            (dotimes (_ 3) (should (hellmacs-nerd-font-p)))
            (should (= asked 1))
            (run-hooks 'after-setting-font-hook)
            (should (hellmacs-nerd-font-p))
            (should (= asked 2)))
        (set-frame-parameter nil 'hellmacs--nerd-font nil)))))

(ert-deftest test-lib/platform ()
  "This machine as release assets name it: OS and CPU."
  (let ((system-type 'gnu/linux) (system-configuration "x86_64-pc-linux-gnu"))
    (should (equal (hellmacs-platform) "linux-x86_64")))
  (let ((system-type 'darwin) (system-configuration "aarch64-apple-darwin23.4.0"))
    (should (equal (hellmacs-platform) "darwin-aarch64")))
  (let ((system-type 'darwin) (system-configuration "arm64-apple-darwin23"))
    (should (equal (hellmacs-platform) "darwin-aarch64")))
  (let ((system-type 'windows-nt) (system-configuration "x86_64-w64-mingw32"))
    (should (equal (hellmacs-platform) "windows-x86_64")))
  (let ((system-type 'berkeley-unix) (system-configuration "x86_64-unknown-freebsd14"))
    (should-not (hellmacs-platform))))

(ert-deftest test-lib/build-output-regexp ()
  "Build output anywhere in a build under ROOT, but not a package named so under src/.
ROOT is matched as given, so a project kept under ~/src is no exception."
  (let ((re (hellmacs-build-output-regexp "/home/u/src/app/")))
    (dolist (dir '("build" "core/build" "core/bin" "core/out" "target" ".gradle"
                   "srcx/build" "buildSrc/build"))
      (should (string-match-p re (concat "/home/u/src/app/" dir))))
    (dolist (dir '("buildSrc" "core/binaries" "core/src/main/java/org/acme/build"
                   "core/src/test/resources/bin" "build/tmp"))
      (should-not (string-match-p re (concat "/home/u/src/app/" dir))))
    ;; Only under ROOT.
    (should-not (string-match-p re "/home/u/src/other/build")))
  (should (string-match-p (hellmacs-build-output-regexp "c:/work/app") "c:/work/app/build")))

(provide 'test-lib)
;;; test-lib.el ends here
