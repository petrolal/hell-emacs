;;; test-modules.el --- Tests for lisp/hellmacs-modules.el -*- lexical-binding: t; -*-

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
(require 'hellmacs-modules)

(defmacro test-modules--with-module-dir (spec &rest body)
  "Run BODY with a temporary private module tree ahead of Hellmacs' own.
SPEC is a list of (\"group/name/file.el\" . CONTENTS)."
  (declare (indent 1))
  `(let* ((root (make-temp-file "hellmacs-test-modules" t))
          (hellmacs-module-load-path (list root hellmacs-modules-dir))
          (hellmacs-modules (make-hash-table :test #'equal)))
     (unwind-protect
         (progn
           (pcase-dolist (`(,file . ,contents) ,spec)
             (let ((path (expand-file-name file root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert contents))))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-modules/hellmacs!-order-flags-depth ()
  (let ((hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:ui theme :completion vertico (corfu +tab)
                                :config (default :depth -10)))
    (should (equal (hellmacs-module-list)
                   '((:config . default) (:ui . theme)
                     (:completion . vertico) (:completion . corfu))))
    (should (modulep! :completion corfu +tab))
    (should-not (modulep! :completion corfu -tab))
    (should (modulep! :completion vertico -tab))
    (should-not (modulep! :lang java))))

;; Phase 16.2: core's own features are the `:hellmacs' module group, as
;; Doom v3's are `:doom' (modules/doom/): always on, loaded first.

(ert-deftest test-modules/core-module-like-doom ()
  "(:hellmacs . nil) is registered after your `hellmacs!' block, at depth -100,
so it's first; it's in modules/hellmacs/, and written `:hellmacs'."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-user-dir (make-temp-file "test-modules-user" t)))
    (unwind-protect
        (progn
          (hellmacs-modules-read-config)  ; no init.el: the defaults
          (should (hellmacs-module-p :hellmacs nil))
          (should (equal (car (hellmacs-module-list)) '(:hellmacs)))
          (should (= (hellmacs-module-get '(:hellmacs) :depth) -100))
          (should (file-equal-p (hellmacs-module-get '(:hellmacs) :path)
                                (expand-file-name "hellmacs/" hellmacs-modules-dir)))
          (should (equal (hellmacs-module-key-string '(:hellmacs)) ":hellmacs"))
          (should (equal (hellmacs-module-key-string '(:ui . theme)) ":ui theme"))
          (should (string-suffix-p "compiled/modules/hellmacs/init.elc"
                                   (hellmacs-module-compiled-file '(:hellmacs) "init.el"))))
      (delete-directory hellmacs-user-dir t))))

(ert-deftest test-modules/core-module-files ()
  "Core's packages (compat, gcmh), the Altar splash and the themed UX live in
the core module, as Doom's gcmh and nerd-icons live in modules/doom/; lisp/
keeps the engine."
  (let ((dir (expand-file-name "hellmacs/" hellmacs-modules-dir)))
    (dolist (file '("packages.el" "init.el" "+splash.el" "+ux.el"))
      (should (file-exists-p (expand-file-name file dir)))))
  (dolist (file '("hellmacs-splash.el" "hellmacs-ux.el"))
    (should-not (file-exists-p (expand-file-name file hellmacs-core-dir))))
  (with-temp-buffer
    (insert-file-contents (expand-file-name "packages.el" hellmacs-core-dir))
    (should-not (re-search-forward "^[^;\n]*(package! " nil t))))

(defvar test-modules--loaded nil)

(ert-deftest test-modules/compiled-file-needs-its-source ()
  "A module file compiled by sync loads while it's newer than its source,
and not at all once the source is deleted."
  (test-modules--with-module-dir
      '(("tools/probe/config.el" . "(setq test-modules--loaded 'source)\n"))
    (let ((hellmacs-compiled-dir (file-name-as-directory (make-temp-file "hellmacs-test-compiled" t)))
          (hellmacs--use-compiled t)
          (test-modules--loaded nil))
      (unwind-protect
          (let ((src (expand-file-name "tools/probe/config.el" root))
                (elc (hellmacs-module-compiled-file '(:tools . probe) "config.el")))
            (hellmacs-module-enable :tools 'probe)
            (make-directory (file-name-directory elc) t)
            (let ((other (expand-file-name "compiled-probe.el" hellmacs-compiled-dir))
                  (byte-compile-dest-file-function (lambda (_) elc))
                  (inhibit-message t))
              (with-temp-file other
                (insert ";;; -*- lexical-binding: t -*-\n(setq test-modules--loaded 'compiled)\n"))
              (byte-compile-file other))
            (set-file-times src (time-subtract nil 60))
            (hellmacs-module--load '(:tools . probe) "config.el")
            (should (eq test-modules--loaded 'compiled))
            (setq test-modules--loaded nil)
            (delete-file src)
            (hellmacs-module--load '(:tools . probe) "config.el")
            (should-not test-modules--loaded))
        (delete-directory hellmacs-compiled-dir t)))))

(ert-deftest test-modules/unknown-module-is-skipped ()
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:lang no-such-module :ui theme))
    (should (equal (hellmacs-module-list) '((:ui . theme))))))

(ert-deftest test-modules/private-module-overrides-and-modulep! ()
  "A private module wins over a built-in one; `modulep!' works inside it."
  (defvar test-modules--result nil)
  (test-modules--with-module-dir
      '(("ui/theme/config.el" . "(setq test-modules--result (list :x (modulep! +x) :not-y (modulep! -y)))"))
    (hellmacs--enable-modules '(:ui (theme +x)))
    (should-not (string-prefix-p hellmacs-modules-dir
                                 (hellmacs-module-get '(:ui . theme) :path)))
    (hellmacs-module--load '(:ui . theme) "config.el")
    (should (equal test-modules--result '(:x t :not-y t)))))

(ert-deftest test-modules/package!-declarations ()
  (let ((hellmacs-packages nil)
        (hellmacs--current-module nil))
    (package! a)
    (package! b :recipe (:host github :repo "x/b") :pin "abc")
    (package! which-key :built-in 'prefer)
    (package! c :disable t)
    (package! a :pin "v1")
    (should (equal (hellmacs-package--order 'a (alist-get 'a hellmacs-packages)) '(a :ref "v1")))
    (should (equal (hellmacs-package--order 'b (alist-get 'b hellmacs-packages))
                   '(b :host github :repo "x/b" :ref "abc")))
    (should-not (hellmacs-package--order 'which-key (alist-get 'which-key hellmacs-packages)))
    (should-not (hellmacs-package--order 'c (alist-get 'c hellmacs-packages)))
    (should (equal (plist-get (alist-get 'a hellmacs-packages) :modules) '(:user :user)))))

(ert-deftest test-modules/package!-disable-silences-use-package ()
  (let ((hellmacs-packages nil))
    (package! c :disable t)
    (should-not (macroexpand '(use-package c :demand t)))
    (should (macroexpand '(use-package d :demand t)))))

(ert-deftest test-modules/package!-env ()
  "A literal alist is accepted, and applied unless the package is disabled."
  (let ((hellmacs-packages nil)
        (process-environment (copy-sequence process-environment)))
    (package! envy :env (("HELLMACS_TEST_ENV" . "on")))
    (package! off :disable t :env (("HELLMACS_TEST_OFF" . "on")))
    (hellmacs-packages-apply-env)
    (should (equal (getenv "HELLMACS_TEST_ENV") "on"))
    (should-not (getenv "HELLMACS_TEST_OFF"))))

(ert-deftest test-modules/cli-files-load-once ()
  "Loading every cli.el twice in a session runs each only once."
  (defvar test-modules--cli-loads 0)
  (setq test-modules--cli-loads 0)
  (test-modules--with-module-dir
      '(("tools/probe/cli.el" . "(setq test-modules--cli-loads (1+ test-modules--cli-loads))"))
    (let ((hellmacs--loaded-cli-files nil))
      (hellmacs--enable-modules '(:tools probe))
      (hellmacs-modules-load-cli-files)
      (hellmacs-modules-load-cli-files)
      (should (= test-modules--cli-loads 1)))))

(ert-deftest test-modules/env-change-triggers-rebuild ()
  "Built packages whose :env differs from their last build are rebuilt."
  (defvar elpaca-builds-directory)
  (let* ((root (make-temp-file "hellmacs-test-env" t))
         (hellmacs-data-dir (file-name-as-directory root))
         (elpaca-builds-directory (expand-file-name "builds/" root))
         (hellmacs-packages nil))
    (unwind-protect
        (progn
          (dolist (pkg '(built-with-env built-plain not-built-yet))
            (unless (eq pkg 'not-built-yet)
              (make-directory (expand-file-name (symbol-name pkg) elpaca-builds-directory) t)))
          (package! built-with-env :env (("X" . "1")))
          (package! built-plain)
          (package! not-built-yet :env (("X" . "1")))
          ;; Never recorded: the built package with :env must be rebuilt.
          (should (equal (hellmacs-packages--env-changed) '(built-with-env)))
          (hellmacs-packages--write-env-stamps)
          (should-not (hellmacs-packages--env-changed))
          ;; Changing the value triggers a rebuild again...
          (package! built-with-env :env (("X" . "2")))
          (should (equal (hellmacs-packages--env-changed) '(built-with-env)))
          (hellmacs-packages--write-env-stamps)
          ;; ...and so does dropping :env from a package built with one.
          (setf (alist-get 'built-with-env hellmacs-packages) (list :modules '(:user)))
          (should (equal (hellmacs-packages--env-changed) '(built-with-env)))
          (hellmacs-packages--write-env-stamps)
          (should-not (file-exists-p (hellmacs-packages--env-stamp-file 'built-with-env))))
      (delete-directory root t))))

(ert-deftest test-modules/depends-on! ()
  "Dependencies are recorded, read first, read once, and reported when missing."
  (test-modules--with-module-dir
      '(("test/base/packages.el" . "(package! test-base-pkg)")
        ("test/user/packages.el" . "(depends-on! :test base)\n(package! test-user-pkg)")
        ("test/other/packages.el" . "(depends-on! :test base)")
        ("test/needy/packages.el" . "(depends-on! :test absent)\n(depends-on! :test base +x)"))
    (let ((hellmacs-packages nil)
          (hellmacs-module-dependencies nil)
          (warnings nil))
      ;; `user' is listed before `base', which it needs.
      (hellmacs--enable-modules '(:test user other base needy))
      (hellmacs-modules-read-packages)
      (let ((order (mapcar #'car (reverse hellmacs-packages))))
        (should (< (seq-position order 'test-base-pkg) (seq-position order 'test-user-pkg))))
      ;; Read once, though two modules need it and it's enabled itself.
      (should (equal (plist-get (alist-get 'test-base-pkg hellmacs-packages) :modules)
                     '((:test . base))))
      (should-not (hellmacs-module-missing-dependencies '(:test . user)))
      (should (equal (hellmacs-module-missing-dependencies '(:test . needy))
                     '((:test absent) (:test base +x))))
      (should (equal (hellmacs-module-dependency-string '(:test base +x)) ":test base +x"))
      (cl-letf (((symbol-function 'display-warning)
                 (lambda (_type message &rest _) (push message warnings))))
        (hellmacs-modules-check-dependencies))
      (should (equal (reverse warnings)
                     '("Module :test needy needs :test absent; add it to your hellmacs! block"
                       "Module :test needy needs :test base +x; add it to your hellmacs! block"))))))

(ert-deftest test-modules/depends-on!-outside-a-module ()
  (let ((hellmacs--current-module nil))
    (should-error (depends-on! :tools lsp))))

(provide 'test-modules)
;;; test-modules.el ends here
