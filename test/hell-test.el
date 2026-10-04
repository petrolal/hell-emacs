;;; hell-test.el --- Tests for Hell Emacs' core -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; ERT tests for the engine in lisp/. Run them with `make test', which
;; loads early-init.el and hell-cli as bin/hell does, with HELLDIR and
;; the XDG directories in a throwaway directory.

;;; Code:

(require 'ert)
(require 'hell-cli)
(require 'hell-modules)
(eval-and-compile (hell-require 'hell-lib 'net))

(defmacro hell-test--with-modules (&rest body)
  "Run BODY with an empty module table, restored afterwards."
  (declare (indent 0))
  `(let ((hell-modules (make-hash-table :test #'equal))
         (hell-packages nil))
     ,@body))

;;; hell-lib ---------------------------------------------------------------

(ert-deftest hell-test-resolve-hooks ()
  (should (equal (hell--resolve-hooks 'prog-mode) '(prog-mode-hook)))
  (should (equal (hell--resolve-hooks '(text-mode prog-mode))
                 '(text-mode-hook prog-mode-hook)))
  (should (equal (hell--resolve-hooks ''after-init-hook) '(after-init-hook)))
  (should (equal (hell--resolve-hooks ''(a-hook b-hook)) '(a-hook b-hook))))

(ert-deftest hell-test-add-hook! ()
  (defvar hell-test--hook nil)
  (let ((hell-test--hook nil))
    (add-hook! 'hell-test--hook #'ignore)
    (should (memq #'ignore hell-test--hook))
    (remove-hook! 'hell-test--hook #'ignore)
    (should-not (memq #'ignore hell-test--hook))))

;;; hell-core --------------------------------------------------------------

(ert-deftest hell-test-state-file ()
  (should (equal (hell-state-file "foo") (expand-file-name "foo" hell-state-dir))))

;;; hell-modules -----------------------------------------------------------

(ert-deftest hell-test-module-key-string ()
  (should (equal (hell-module-key-string '(:ui . theme)) ":ui theme"))
  (should (equal (hell-module-key-string '(:hell)) ":hell")))

(ert-deftest hell-test-module-p ()
  (hell-test--with-modules
    (puthash '(:completion . corfu) '(:flags (+tab)) hell-modules)
    (should (hell-module-p :completion 'corfu))
    (should (hell-module-p :completion 'corfu '(+tab)))
    (should-not (hell-module-p :completion 'corfu '(-tab)))
    (should-not (hell-module-p :completion 'corfu '(+orderless)))
    (should-not (hell-module-p :completion 'vertico))))

(ert-deftest hell-test-package-disabled-p ()
  (hell-test--with-modules
    (setq hell-packages '((foo :disable t) (bar)))
    (should (hell-package-disabled-p 'foo))
    (should-not (hell-package-disabled-p 'bar))
    (should-not (hell-package-disabled-p 'baz))))

;;; hell-cli ---------------------------------------------------------------

(ert-deftest hell-test-cli-flag ()
  (should (eq (hell-cli--flag '("--color") "color") t))
  (should (eq (hell-cli--flag '("--no-color") "color") 'no))
  (should-not (hell-cli--flag '("--other") "color")))

(ert-deftest hell-test-cli-force-p ()
  (let ((process-environment (cons "HELL_FORCE" process-environment)))
    (should (hell-cli-force-p '("-!")))
    (should (hell-cli-force-p '("--force")))
    (should-not (hell-cli-force-p '("sync")))
    (should-not (hell-cli-force-p nil))
    (setenv "HELL_FORCE" "1")
    (should (hell-cli-force-p nil))))

;;; lib/net ----------------------------------------------------------------

(ert-deftest hell-test-net-rewrite ()
  (let ((hell-mirrors '(("https://github.com/" . "https://mirror.example/gh/"))))
    (should (equal (hell-net-rewrite "https://github.com/foo/bar")
                   "https://mirror.example/gh/foo/bar"))
    (should (equal (hell-net-rewrite "https://gitlab.com/foo")
                   "https://gitlab.com/foo"))))

(provide 'hell-test)
;;; hell-test.el ends here
