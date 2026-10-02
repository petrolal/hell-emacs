;;; editor/file-templates/config.el -*- lexical-binding: t; -*-

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

;; File templates (Phase 10.4): a new, empty file is filled from a tempel
;; template, through Emacs' own `auto-insert', which asks first:
;;   FooTest.java, FooTests.java, FooIT.java   package, JUnit 5 imports, test class
;;   Foo.java                                  package and class
;;   FooTest.kt / Foo.kt                       the same in Kotlin (kotlin.test)
;;   src/shop/cart.clj                         (ns shop.cart)
;;   test/shop/cart_test.clj                   the test ns, requiring shop.cart
;; The package and namespace come from the path (src/test/java/com/acme/
;; is com.acme). Files that exist, even empty ones, are never touched, and
;; only these templates are switched on, not Emacs' own (`auto-insert-alist'
;; stays as `M-x auto-insert' uses it). `M-x auto-insert' fills an empty
;; buffer by hand.
;;
;; The templates are in the module's templates/ (__class, __test, __ns);
;; a template's language module (:lang java, kotlin, clojure) must be on.
;; Keys: none. Once filled, `M-}' and `M-{' move between the fields, as in
;; any snippet.

(defvar auto-insert-alist)
(defvar tempel-path)
(declare-function tempel--templates "tempel")
(declare-function tempel-insert "tempel")
(declare-function hell-file-templates-clojure-ns "autoload")

(defvar hell-file-templates-alist
  '(("/[[:upper:]][[:alnum:]_]*\\(?:Tests?\\|IT\\)\\.java\\'" "JUnit test class" __test)
    ("/[[:upper:]][[:alnum:]_]*\\.java\\'" "Java class" __class)
    ("/[[:upper:]][[:alnum:]_]*Tests?\\.kt\\'" "Kotlin test class" __test)
    ("/[[:upper:]][[:alnum:]_]*\\.kt\\'" "Kotlin class" __class)
    (hell-file-templates--clojure-test-p "Clojure test namespace" __test)
    (hell-file-templates--clojure-p "Clojure namespace" __ns))
  "Which template a new file gets: (MATCH DESCRIPTION TEMPLATE) entries.
MATCH is a regexp (case matters) or a function, called with the file's
name. The first that matches wins; TEMPLATE is a tempel template's
name, looked up in the buffer's major mode.")

(defun hell-file-templates--clojure-p (file)
  "Non-nil if FILE is a Clojure source file with a namespace."
  (and (string-match-p "\\.clj[cs]?\\'" file)
       (hell-file-templates-clojure-ns file)))

(defun hell-file-templates--clojure-test-p (file)
  "Non-nil if FILE is a Clojure test namespace."
  (and (string-match-p "_test\\.clj[cs]?\\'" file)
       (hell-file-templates--clojure-p file)))

(defun hell-file-templates-template (file)
  "The template for FILE, as (NAME . DESCRIPTION), or nil."
  (let ((case-fold-search nil))
    (seq-some (pcase-lambda (`(,match ,description ,name))
                (and (if (stringp match) (string-match-p match file) (funcall match file))
                     (cons name description)))
              hell-file-templates-alist)))

(defun hell-file-templates--available-p (name)
  "Non-nil if tempel has a template NAME for the buffer's major mode."
  (require 'tempel nil t)
  (and (fboundp 'tempel--templates)
       (alist-get name (tempel--templates))))

(defun hell-file-templates-insert ()
  "Fill the buffer from its file's template. The action `auto-insert' runs."
  (when-let* ((template (and buffer-file-name
                             (hell-file-templates-template buffer-file-name))))
    (tempel-insert (car template))))

(defun hell-file-templates--h ()
  "Offer to fill a new, empty file from its template."
  (when-let* (((and buffer-file-name (bobp) (eobp) (not buffer-read-only)
                    (not (file-exists-p buffer-file-name))))
              (template (hell-file-templates-template buffer-file-name))
              ((hell-file-templates--available-p (car template)))
              ((require 'autoinsert)))
    ;; This one template only: Emacs' own (C headers, Emacs Lisp headers...)
    ;; stay off, as they are without `auto-insert-mode'.
    (let ((auto-insert-alist
           `((("" . ,(cdr template)) . hell-file-templates-insert))))
      (auto-insert))))

(add-hook 'find-file-hook #'hell-file-templates--h)

(with-eval-after-load 'autoinsert
  (add-to-list 'auto-insert-alist
               '(("\\.\\(?:java\\|kt\\|clj[cs]?\\)\\'" . "JVM file template")
                 . hell-file-templates-insert)))

;; After :editor snippets' own `tempel-path' (set in its config.el).
(let ((templates (expand-file-name
                  "templates/*.eld"
                  (hell-module-get '(:editor . file-templates) :path))))
  (with-eval-after-load 'tempel
    (add-to-list 'tempel-path templates t)))
