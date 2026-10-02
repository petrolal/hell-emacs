;;; java.eld --- Hell Emacs' Java file templates (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hell Emacs.

;; Filled into a new, empty file (see :editor file-templates); `M-}' and
;; `M-{' move between the fields.

java-mode java-ts-mode

;; Foo.java: its package and class.
(__class (hell-snippets-package-line ";")
         "public class " (hell-snippets-class) " {" n>
         q n
         "}" > n)

;; FooTest.java (FooTests, FooIT): a JUnit 5 test class.
(__test (hell-snippets-package-line ";")
        "import static org.junit.jupiter.api.Assertions.assertEquals;" n n
        "import org.junit.jupiter.api.Test;" n n
        "class " (hell-snippets-class) " {" n n>
        "@Test" n>
        "void " (p "itWorks") "() {" n>
        q n
        "}" > n
        "}" > n)
