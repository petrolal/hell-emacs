;;; test-file-templates.el --- Tests for the :editor file-templates module (Phase 10.4) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. tempel isn't installed in the test
;; environment: its two entry points are stood in for here, and filling a
;; real file is checked live (see docs/roadmap.md, 10.4). These check
;; which template a new file gets, the helpers the templates call, the
;; templates' shape, and that only new, empty files are filled.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'autoinsert)
(require 'hellmacs-modules)

(defvar tempel-path)
(defvar hellmacs-module-dependencies)
;; The .eld reader test-snippets.el defines; `bin/hellmacs test' loads
;; every test file.
(declare-function test-snippets--read "test-snippets")

(defun test-file-templates--load ()
  "Load the module (and the snippets module it builds on) with a scratch `C-c' map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:editor snippets file-templates))
    (hellmacs-module--load '(:editor . snippets) "autoload.el")
    (hellmacs-module--load '(:editor . file-templates) "autoload.el")
    (hellmacs-module--load '(:editor . file-templates) "config.el")
    mode-specific-map))

(defun test-file-templates--dir ()
  (expand-file-name "templates/" (hellmacs-module-locate-path :editor 'file-templates)))

(defmacro test-file-templates--with-project (files &rest body)
  "Run BODY in a temporary directory `root' holding FILES (relative names)."
  (declare (indent 1))
  `(let ((root (file-name-as-directory (make-temp-file "hellmacs-ft" t))))
     (unwind-protect
         (progn
           (dolist (file ,files)
             (let ((path (expand-file-name file root)))
               (make-directory (file-name-directory path) t)
               (write-region "" nil path)))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-file-templates/packages ()
  "No packages of its own: it builds on :editor snippets (tempel)."
  (let ((hellmacs-packages nil)
        (hellmacs-module-dependencies nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:editor file-templates))
    (hellmacs-module--load '(:editor . file-templates) "packages.el")
    (should-not hellmacs-packages)
    (should (equal (hellmacs-module-missing-dependencies '(:editor . file-templates))
                   '((:editor snippets))))))

(ert-deftest test-file-templates/which-template ()
  "A new file's template comes from its name (and, for Clojure, where it sits)."
  (test-file-templates--load)
  (dolist (case '(("/p/src/test/java/com/acme/CartTest.java" . __test)
                  ("/p/src/test/java/com/acme/CartTests.java" . __test)
                  ("/p/src/test/java/com/acme/CartIT.java" . __test)
                  ("/p/src/main/java/com/acme/Cart.java" . __class)
                  ("/p/src/test/kotlin/io/demo/UserTest.kt" . __test)
                  ("/p/src/main/kotlin/io/demo/User.kt" . __class)
                  ("/p/src/shop/cart.clj" . __ns)
                  ("/p/test/shop/cart_test.clj" . __test)
                  ("/p/src/main/clojure/shop/ui.cljs" . __ns)
                  ;; Not a class: Java's package and module descriptors,
                  ;; Kotlin files named in lower case, Kotlin scripts.
                  ("/p/src/main/java/com/acme/package-info.java" . nil)
                  ("/p/src/main/java/module-info.java" . nil)
                  ("/p/src/main/kotlin/io/demo/extensions.kt" . nil)
                  ("/p/build.gradle.kts" . nil)
                  ;; Not a namespace: Clojure outside a source directory.
                  ("/p/project.clj" . nil)
                  ("/p/build.clj" . nil)
                  ("/tmp/notes.txt" . nil)))
    (should (equal (cons (car case) (car (hellmacs-file-templates-template (car case))))
                   case))))

(ert-deftest test-file-templates/clojure-namespace ()
  "A Clojure file's namespace, from its path under the project's source roots."
  (test-file-templates--load)
  ;; In a project (deps.edn, project.clj...): relative to its root.
  (test-file-templates--with-project '("deps.edn")
    (dolist (case '(("src/shop/cart.clj" . "shop.cart")
                    ("src/my_app/core_util.cljc" . "my-app.core-util")
                    ("test/shop/cart_test.clj" . "shop.cart-test")
                    ("dev/user.clj" . "user")
                    ("src/main/clojure/shop/ui.cljs" . "shop.ui")
                    ("build.clj" . nil)))
      (should (equal (cons (car case)
                           (hellmacs-file-templates-clojure-ns
                            (expand-file-name (car case) root)))
                     case))))
  ;; A project inside a directory named src/ (~/src/shop/): its own root counts.
  (test-file-templates--with-project '("src/shop/project.clj")
    (should (equal (hellmacs-file-templates-clojure-ns
                    (expand-file-name "src/shop/test/shop/cart_test.clj" root))
                   "shop.cart-test")))
  ;; No project file: the innermost source directory.
  (should (equal (hellmacs-file-templates-clojure-ns "/nowhere/src/a/b.clj") "a.b"))
  (should (equal (hellmacs-file-templates-clojure-ns "/nowhere/src/main/clojure/a/b.clj")
                 "a.b"))
  (should-not (hellmacs-file-templates-clojure-ns "/nowhere/b.clj")))

(ert-deftest test-file-templates/clojure-tested-namespace ()
  "A test namespace names the one it tests."
  (test-file-templates--load)
  (with-temp-buffer
    (setq buffer-file-name "/nowhere/test/shop/cart_test.clj")
    (should (equal (hellmacs-file-templates-clojure-ns) "shop.cart-test"))
    (should (equal (hellmacs-file-templates-clojure-tested-ns) "shop.cart"))
    (set-buffer-modified-p nil)))

(ert-deftest test-file-templates/templates ()
  "Each language's file templates, for its classic and tree-sitter modes."
  (let ((all (mapcan #'test-snippets--read
                     (directory-files (test-file-templates--dir) t "\\.eld\\'"))))
    (dolist (want '((java-mode . __class) (java-ts-mode . __class)
                    (java-mode . __test) (java-ts-mode . __test)
                    (kotlin-mode . __class) (kotlin-ts-mode . __class)
                    (kotlin-mode . __test) (kotlin-ts-mode . __test)
                    (clojure-mode . __ns) (clojure-ts-mode . __ns)
                    (clojure-mode . __test) (clojure-ts-mode . __test)))
      (should (equal (cons want (and (memq (cdr want) (cdr (assq (car want) all))) t))
                     (cons want t))))))

(ert-deftest test-file-templates/where-templates-come-from ()
  "The module's templates join tempel's path once tempel loads, after the
snippets module has set it."
  (let ((tempel-path (list "/snippets/*.eld"))
        (after-load-alist after-load-alist)
        (features features))
    (test-file-templates--load)
    (setq tempel-path (list "/snippets/*.eld" "/user/*.eld")) ; :editor snippets' setq
    (provide 'tempel)
    (should (equal tempel-path
                   (list "/snippets/*.eld" "/user/*.eld"
                         (expand-file-name "*.eld" (test-file-templates--dir)))))))

(defmacro test-file-templates--with-tempel (templates &rest body)
  "Run BODY with tempel's lookup answering TEMPLATES, recording what's inserted.
`inserted' holds the names `tempel-insert' was given."
  (declare (indent 1))
  `(let ((inserted nil))
     (cl-letf (((symbol-function 'tempel--templates) (lambda () ,templates))
               ((symbol-function 'tempel-insert)
                (lambda (name) (push name inserted) (insert (format "<%s>" name)))))
       ,@body)))

(defun test-file-templates--visit (file &optional answer)
  "Run the module's hook in a buffer visiting FILE, answering its question with ANSWER.
Return (INSERTED-TEXT . ASKED)."
  (let ((asked nil))
    (with-temp-buffer
      (setq buffer-file-name file)
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (prompt) (setq asked prompt) answer)))
        (hellmacs-file-templates--h))
      (prog1 (cons (buffer-string) asked)
        (set-buffer-modified-p nil)))))

(ert-deftest test-file-templates/fills-new-files ()
  "A new, empty file is filled from its template through `auto-insert',
which asks first, and is left unmodified."
  (test-file-templates--load)
  (should (memq 'hellmacs-file-templates--h find-file-hook))
  (test-file-templates--with-tempel '((__test l "") (__class l ""))
    (test-file-templates--with-project '()
      (let* ((file (expand-file-name "src/test/java/a/CartTest.java" root))
             (result (test-file-templates--visit file t)))
        (should (equal (car result) "<__test>"))
        (should (string-match-p "JUnit" (cdr result)))
        (should (equal inserted '(__test))))
      ;; Declined: nothing inserted.
      (setq inserted nil)
      (should (equal (car (test-file-templates--visit
                           (expand-file-name "src/main/java/a/Cart.java" root) nil))
                     ""))
      (should-not inserted))))

(ert-deftest test-file-templates/never-touches-content ()
  "Files that exist, or have content, are left alone, without a question."
  (test-file-templates--load)
  (test-file-templates--with-tempel '((__test l "") (__class l ""))
    (test-file-templates--with-project '("src/main/java/a/Empty.java")
      ;; An existing file, even an empty one.
      (should (equal (test-file-templates--visit
                      (expand-file-name "src/main/java/a/Empty.java" root) t)
                     '("")))
      ;; A new buffer that already has text.
      (with-temp-buffer
        (setq buffer-file-name (expand-file-name "src/main/java/a/New.java" root))
        (insert "class New {}")
        (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) (error "Asked"))))
          (hellmacs-file-templates--h))
        (should (equal (buffer-string) "class New {}"))
        (set-buffer-modified-p nil))
      (should-not inserted))))

(ert-deftest test-file-templates/only-with-a-template ()
  "No question when the buffer's mode has no such template (its :lang
module is off), or the file isn't one the module knows."
  (test-file-templates--load)
  (test-file-templates--with-tempel '()
    (test-file-templates--with-project '()
      (should (equal (test-file-templates--visit
                      (expand-file-name "src/main/java/a/Cart.java" root) t)
                     '("")))
      (should (equal (test-file-templates--visit (expand-file-name "notes.txt" root) t)
                     '(""))))))

(ert-deftest test-file-templates/only-its-own-templates ()
  "Emacs' own `auto-insert-alist' (C headers, Emacs Lisp headers...) isn't
switched on by the module."
  (test-file-templates--load)
  (test-file-templates--with-tempel '((__class l ""))
    (test-file-templates--with-project '()
      (should (equal (test-file-templates--visit (expand-file-name "x.h" root) t) '("")))
      (should (equal (test-file-templates--visit (expand-file-name "x.el" root) t) '(""))))))

(ert-deftest test-file-templates/by-hand ()
  "`M-x auto-insert' in a JVM buffer fills it from its template too."
  (test-file-templates--load)
  (should (assoc "\\.\\(?:java\\|kt\\|clj[cs]?\\)\\'"
                 (mapcar (lambda (entry) (if (consp (car entry)) (car entry) entry))
                         auto-insert-alist)))
  (test-file-templates--with-tempel '((__class l ""))
    (with-temp-buffer
      (setq buffer-file-name "/p/src/main/java/a/Cart.java")
      (hellmacs-file-templates-insert)
      (should (equal (buffer-string) "<__class>"))
      (set-buffer-modified-p nil))))

(ert-deftest test-file-templates/no-keys ()
  "No keys of its own, and TAB is still Emacs' indent."
  (let ((tab-always-indent t))
    (should (equal (test-file-templates--load) (make-sparse-keymap)))
    (should (eq tab-always-indent t))
    (should (eq (keymap-lookup global-map "TAB") 'indent-for-tab-command))))

(provide 'test-file-templates)
;;; test-file-templates.el ends here
