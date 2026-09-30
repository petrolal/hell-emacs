;;; java.eld --- Hellmacs' Java file templates (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hellmacs.

;; Filled into a new, empty file (see :editor file-templates); `M-}' and
;; `M-{' move between the fields.

java-mode java-ts-mode

;; Foo.java: its package and class.
(__class (hellmacs-snippets-package-line ";")
         "public class " (hellmacs-snippets-class) " {" n>
         q n
         "}" > n)

;; FooTest.java (FooTests, FooIT): a JUnit 5 test class.
(__test (hellmacs-snippets-package-line ";")
        "import static org.junit.jupiter.api.Assertions.assertEquals;" n n
        "import org.junit.jupiter.api.Test;" n n
        "class " (hellmacs-snippets-class) " {" n n>
        "@Test" n>
        "void " (p "itWorks") "() {" n>
        q n
        "}" > n
        "}" > n)
