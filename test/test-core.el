;;; test-core.el --- Tests for lisp/hellmacs-core.el and -packages.el -*- lexical-binding: t; -*-

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
(require 'hellmacs)
(require 'hellmacs-emacs)
(require 'hellmacs-packages)
(require 'hellmacs-modules)
(require 'hellmacs-ux (expand-file-name "hellmacs/+ux" hellmacs-modules-dir))

(defmacro test-core--with-features (features &rest body)
  "Run BODY with each of FEATURES loadable from a temporary directory."
  (declare (indent 1))
  `(let* ((dir (make-temp-file "hellmacs-test-features" t))
          (load-path (cons dir load-path)))
     (unwind-protect
         (progn
           (dolist (f ,features)
             (with-temp-file (expand-file-name (format "%s.el" f) dir)
               (insert (format "(provide '%s)\n" f))))
           ,@body)
       (delete-directory dir t))))

(ert-deftest test-core/incremental-loading ()
  "Queued in order without duplicates, loaded one per call."
  (test-core--with-features '(test-core-feat-a test-core-feat-b)
    (let ((hellmacs-incremental-packages nil))
      (hellmacs-load-incrementally '(test-core-feat-a test-core-feat-b test-core-feat-a))
      (should (equal hellmacs-incremental-packages '(test-core-feat-a test-core-feat-b)))
      (cl-letf (((symbol-function 'run-with-idle-timer) #'ignore))
        (hellmacs--load-next-incrementally)
        (should (featurep 'test-core-feat-a))
        (should-not (featurep 'test-core-feat-b))
        (hellmacs--load-next-incrementally))
      (should (featurep 'test-core-feat-b))
      (should-not hellmacs-incremental-packages))))

(ert-deftest test-core/incremental-skips-loaded ()
  (let ((hellmacs-incremental-packages nil))
    (hellmacs-load-incrementally '(hellmacs-lib))
    (should-not hellmacs-incremental-packages)))

(ert-deftest test-core/use-package-defer-incrementally ()
  (should (string-match-p "hellmacs-load-incrementally '(foo)"
                          (format "%S" (macroexpand-all '(use-package foo :defer-incrementally t)))))
  (should (string-match-p "hellmacs-load-incrementally '(clojure-mode sesman cider)"
                          (format "%S" (macroexpand-all
                                        '(use-package cider :defer-incrementally (clojure-mode sesman)))))))

(ert-deftest test-core/sync-discards-only-empty-checkouts ()
  "A failed clone that left just .git is removed; a real checkout is kept."
  (require 'hellmacs-sync)
  (let* ((root (make-temp-file "hellmacs-test-src" t))
         (empty (expand-file-name "empty" root))
         (full (expand-file-name "full" root)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name ".git" empty) t)
          (make-directory (expand-file-name ".git" full) t)
          (with-temp-file (expand-file-name "pkg.el" full) (insert ";; pkg"))
          (should (hellmacs-sync--discard-empty-checkout empty))
          (should-not (file-exists-p empty))
          (should-not (hellmacs-sync--discard-empty-checkout full))
          (should (file-exists-p (expand-file-name "pkg.el" full)))
          (should-not (hellmacs-sync--discard-empty-checkout (expand-file-name "missing" root))))
      (delete-directory root t))))

(ert-deftest test-core/recentf-skips-hellmacs-files ()
  "Hellmacs' state, cache and data files never count as recent files."
  (require 'recentf)
  (should-not (recentf-include-p (hellmacs-state-file "bookmarks")))
  (should-not (recentf-include-p (expand-file-name "eln/x.eln" hellmacs-cache-dir)))
  (should-not (recentf-include-p (expand-file-name "elpaca/repos/x/x.el" hellmacs-data-dir)))
  (should (recentf-include-p "/tmp/Foo.java")))

(ert-deftest test-core/own-files-are-not-the-first-file ()
  "A package visiting Hellmacs' own files doesn't fire the first-file hooks."
  (with-temp-buffer
    (setq buffer-file-name (hellmacs-state-file "bookmarks"))
    (should (hellmacs--own-file-p))
    (should-not (hellmacs--real-buffer-p))
    (setq buffer-file-name "/tmp/Foo.java")
    (should-not (hellmacs--own-file-p))
    (should (hellmacs--real-buffer-p))
    (setq buffer-file-name nil)))

(defvar test-core--log nil)

(ert-deftest test-core/packages-ready-survives-a-broken-function ()
  "An error in one function (a broken custom.el) doesn't skip the rest:
the GC reset and `hellmacs-finalize' come after `custom-file' is loaded."
  (let ((hellmacs--packages-ready-hook nil)
        (debug-on-error nil)
        (warning-minimum-log-level :emergency))
    (setq test-core--log nil)
    (add-hook 'hellmacs--packages-ready-hook (lambda () (push 'after test-core--log)) 90)
    (add-hook 'hellmacs--packages-ready-hook (lambda () (error "Broken custom.el")))
    (hellmacs--run-packages-ready-h)
    (should (equal test-core--log '(after)))))

(ert-deftest test-core/env-file ()
  "Saved variables win without piling up; a damaged file changes nothing."
  (let ((file (make-temp-file "hellmacs-test-env"))
        (process-environment (copy-sequence process-environment))
        (exec-path exec-path)
        (shell-file-name shell-file-name)
        (warning-minimum-log-level :emergency))
    (unwind-protect
        (progn
          (setenv "HELLMACS_TEST_VAR" "old")
          (with-temp-file file (insert "(\"HELLMACS_TEST_VAR=new\")\n"))
          (should (hellmacs-load-env-file file))
          (should (hellmacs-load-env-file file))
          (should (equal (getenv "HELLMACS_TEST_VAR") "new"))
          (should (= 1 (seq-count (lambda (e) (string-prefix-p "HELLMACS_TEST_VAR=" e))
                                  process-environment)))
          ;; Cut short while being written, or not a list of strings.
          (dolist (contents '("" "(\"A=1\"" "(1 2)"))
            (with-temp-file file (insert contents))
            (let ((before (copy-sequence process-environment)))
              (should-not (hellmacs-load-env-file file))
              (should (equal process-environment before)))))
      (delete-file file))))

(ert-deftest test-core/routine-errors-are-not-fatalities ()
  "Only real failures are reported as [CRITICAL FATALITY]."
  (dolist (data '((end-of-buffer) (beginning-of-buffer) (buffer-read-only nil)
                  (mark-inactive) (quit) (minibuffer-quit) (user-error "No")))
    (should (hellmacs-ux--routine-error-p data)))
  (define-error 'test-core--my-user-error "Mine" 'user-error)
  (should (hellmacs-ux--routine-error-p '(test-core--my-user-error)))
  (dolist (data '((error "Boom") (wrong-type-argument stringp 1) (void-function foo)))
    (should-not (hellmacs-ux--routine-error-p data))))

(ert-deftest test-core/lines-wrap-as-in-emacs ()
  "Long lines wrap by default, as in stock Emacs; modes that want otherwise say so."
  (should-not (default-value 'truncate-lines)))

(require 'hellmacs-splash (expand-file-name "hellmacs/+splash" hellmacs-modules-dir))

(ert-deftest test-core/splash-draws-once ()
  "`C-c h s' draws the Altar once, after it's in the window it centers in."
  (let ((draws 0))
    (cl-letf* ((render (symbol-function 'hellmacs-splash--render))
               ((symbol-function 'hellmacs-splash--render)
                (lambda () (cl-incf draws) (funcall render))))
      (save-window-excursion
        (hellmacs-splash)
        (should (eq (current-buffer) (get-buffer hellmacs-splash-buffer-name)))
        (should (derived-mode-p 'hellmacs-splash-mode))
        (should (= draws 1))
        (should (string-match-p "JVM FORGE IGNITED" (buffer-string)))))
    (kill-buffer hellmacs-splash-buffer-name)))

(provide 'test-core)
;;; test-core.el ends here
