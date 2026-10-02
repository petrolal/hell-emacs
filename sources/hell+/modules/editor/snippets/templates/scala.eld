;;; scala.eld --- Hell Emacs' Scala snippets (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hell Emacs.

scala-mode scala-ts-mode

;; A munit test suite, named after the file, in the file's package.
(munit (hell-snippets-package-line "")
       "class " (p (hell-snippets-class) class) " extends munit.FunSuite {" n>
       "test(\"" (p "it works") "\") {" n>
       (r "assertEquals(obtained, expected)") n
       "}" > n
       "}" > n)
