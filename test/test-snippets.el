;;; test-snippets.el --- Tests for the :editor snippets module (Phase 10.4) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. tempel itself isn't installed in the test
;; environment: expanding each snippet is checked live (see docs/roadmap.md,
;; 10.4). These check the templates' shape, the helpers they call, the
;; completion setup and the keys.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)

(defvar tempel-path)
(defvar tempel-map)

(defun test-snippets--load (&optional file)
  "Load the module's FILE (config.el) with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:editor snippets))
    (hellmacs-module--load '(:editor . snippets) "autoload.el")
    (hellmacs-module--load '(:editor . snippets) (or file "config.el"))
    mode-specific-map))

(defun test-snippets--templates-dir ()
  (expand-file-name "templates/" (hellmacs-module-locate-path :editor 'snippets)))

(defun test-snippets--read (file)
  "FILE's templates, as tempel reads them: ((MODE . NAMES) ...)."
  (let ((data (with-temp-buffer
                (insert "(\n")
                (insert-file-contents file)
                (goto-char (point-max))
                (insert "\n)")
                (goto-char (point-min))
                (read (current-buffer))))
        result)
    (while data
      (let (modes names)
        (while (and (car data) (symbolp (car data)) (not (keywordp (car data))))
          (push (pop data) modes))
        (while (keywordp (car data)) (setq data (cddr data)))
        (while (consp (car data))
          (push (car (pop data)) names))
        (should modes)                  ; no templates without a mode
        (dolist (mode modes) (push (cons mode names) result))))
    result))

(ert-deftest test-snippets/packages ()
  "tempel, and nothing else (compat is core's)."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:editor snippets))
    (hellmacs-module--load '(:editor . snippets) "packages.el")
    (should (equal (mapcar #'car hellmacs-packages) '(tempel)))))

(ert-deftest test-snippets/jvm-snippets ()
  "The JVM snippets, each for its language's classic and tree-sitter modes."
  (let ((all (mapcan #'test-snippets--read
                     (directory-files (test-snippets--templates-dir) t "\\.eld\\'"))))
    (dolist (want '((java-mode . junit) (java-ts-mode . junit)
                    (java-mode . controller) (java-ts-mode . controller)
                    (kotlin-mode . dataclass) (kotlin-ts-mode . dataclass)
                    (clojure-mode . deftest) (clojure-ts-mode . deftest)
                    (scala-mode . munit) (scala-ts-mode . munit)))
      (should (equal (cons want (and (memq (cdr want) (cdr (assq (car want) all))) t))
                     (cons want t))))))

(ert-deftest test-snippets/package-from-path ()
  "A source file's package comes from its path under src/<set>/<language>/."
  (test-snippets--load)
  (dolist (case '(("/p/src/test/java/com/acme/shop/CartTest.java" . "com.acme.shop")
                  ("/p/app/src/main/kotlin/io/demo/User.kt" . "io.demo")
                  ("/p/src/androidTest/java/a/b/UiTest.java" . "a.b")
                  ("/p/src/test/scala/x/y/SuiteTest.scala" . "x.y")
                  ;; A nested src/: the innermost wins.
                  ("/w/src/tools/src/main/java/t/Tool.java" . "t")
                  ;; The default package, or not a Maven/Gradle layout: none.
                  ("/p/src/main/java/Main.java" . nil)
                  ("/tmp/Scratch.java" . nil)))
    (should (equal (cons (car case) (hellmacs-snippets-package (car case))) case))))

(ert-deftest test-snippets/package-line ()
  "The package line, when the file has none yet; nothing in the default package."
  (test-snippets--load)
  (with-temp-buffer
    (setq buffer-file-name "/p/src/test/java/com/acme/CartTest.java")
    (should (equal (hellmacs-snippets-package-line ";") '(l "package com.acme;" n n)))
    (should (equal (hellmacs-snippets-package-line "") '(l "package com.acme" n n)))
    (insert "package com.acme;\n")
    (should-not (hellmacs-snippets-package-line ";"))
    (setq buffer-file-name "/p/src/main/java/Main.java")
    (erase-buffer)
    (should-not (hellmacs-snippets-package-line ";"))
    (set-buffer-modified-p nil)))

(ert-deftest test-snippets/class-name ()
  "The class is named after the file, as Java and Kotlin expect."
  (test-snippets--load)
  (with-temp-buffer
    (setq buffer-file-name "/p/src/test/java/a/CartTest.java")
    (should (equal (hellmacs-snippets-class) "CartTest"))
    (setq buffer-file-name nil)
    (should (equal (hellmacs-snippets-class) "Main"))))

(ert-deftest test-snippets/where-templates-come-from ()
  "The module's templates, then your own in $HELLMACSDIR/templates/."
  (let ((tempel-path nil))
    (test-snippets--load)
    (should (member (expand-file-name "*.eld" (test-snippets--templates-dir)) tempel-path))
    (should (member (expand-file-name "templates/*.eld" hellmacs-user-dir) tempel-path))))

(ert-deftest test-snippets/offered-by-completion ()
  "In code, text and config files, a snippet's name completes first
(`C-M-i', the corfu popup), before the language server's: exact names
only, so the server's candidates aren't hidden while you type."
  (test-snippets--load)
  (dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
    (should (memq 'hellmacs-snippets--capf-h (symbol-value hook))))
  (with-temp-buffer
    (setq-local completion-at-point-functions (list #'ignore t))
    (hellmacs-snippets--capf-h)
    ;; lsp-mode adds its own at the front later; the snippet stays ahead.
    (add-hook 'completion-at-point-functions #'test-snippets--server nil t)
    (should (eq (car completion-at-point-functions) 'tempel-expand))
    (should (memq #'ignore completion-at-point-functions))))

(defun test-snippets--server () nil)

(ert-deftest test-snippets/field-keys-are-remaps ()
  "Inside a snippet, only stock commands' keys move between fields
(`M-}' next, `M-{' previous, `ESC ESC ESC' abort): tempel's own concrete
keys (`M-RET', `M-<up>', `M-<down>'...) are taken out."
  (test-snippets--load)
  (let ((tempel-map (define-keymap           ; tempel 1.14's, as shipped
                      "<remap> <beginning-of-buffer>" #'tempel-beginning
                      "<remap> <end-of-buffer>" #'tempel-end
                      "<remap> <kill-sentence>" #'tempel-kill
                      "<remap> <keyboard-escape-quit>" #'tempel-abort
                      "<remap> <backward-paragraph>" #'tempel-previous
                      "<remap> <forward-paragraph>" #'tempel-next
                      "M-RET" #'tempel-done
                      "M-{" #'tempel-previous
                      "M-}" #'tempel-next
                      "M-<up>" #'tempel-previous
                      "M-<down>" #'tempel-next)))
    (hellmacs-snippets--remaps-only)
    (map-keymap (lambda (event _) (should (eq event 'remap))) tempel-map)
    (should (eq (keymap-lookup tempel-map "<remap> <forward-paragraph>") 'tempel-next))
    (should (eq (keymap-lookup tempel-map "<remap> <backward-paragraph>") 'tempel-previous))
    (should (eq (keymap-lookup tempel-map "<remap> <keyboard-escape-quit>") 'tempel-abort))))

(ert-deftest test-snippets/tab-keeps-indenting ()
  "No keys of the module's own, and TAB is still Emacs' indent."
  (let ((tab-always-indent t))
    (should (equal (test-snippets--load) (make-sparse-keymap)))
    (should (eq tab-always-indent t))
    (should (eq (keymap-lookup global-map "TAB") 'indent-for-tab-command))))

(provide 'test-snippets)
;;; test-snippets.el ends here
