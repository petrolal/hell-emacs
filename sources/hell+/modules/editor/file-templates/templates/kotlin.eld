;;; kotlin.eld --- Hell Emacs' Kotlin file templates (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hell Emacs.

;; Filled into a new, empty file (see :editor file-templates); `M-}' and
;; `M-{' move between the fields.

kotlin-mode kotlin-ts-mode

;; Foo.kt: its package and class.
(__class (hell-snippets-package-line "")
         "class " (hell-snippets-class) " {" n>
         q n
         "}" > n)

;; FooTest.kt: a kotlin.test class (JUnit 5 underneath on the JVM).
(__test (hell-snippets-package-line "")
        "import kotlin.test.Test" n
        "import kotlin.test.assertEquals" n n
        "class " (hell-snippets-class) " {" n n>
        "@Test" n>
        "fun " (p "itWorks") "() {" n>
        q n
        "}" > n
        "}" > n)
