;;; scala.eld --- Hellmacs' Scala snippets (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hellmacs.

scala-mode scala-ts-mode

;; A munit test suite, named after the file, in the file's package.
(munit (hellmacs-snippets-package-line "")
       "class " (p (hellmacs-snippets-class) class) " extends munit.FunSuite {" n>
       "test(\"" (p "it works") "\") {" n>
       (r "assertEquals(obtained, expected)") n
       "}" > n
       "}" > n)
