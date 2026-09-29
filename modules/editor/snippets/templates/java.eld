;;; java.eld --- Hellmacs' Java snippets (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hellmacs.

;; Complete a name (`C-M-i', or the corfu popup) to expand it; `M-}' and
;; `M-{' move between its fields.

java-mode java-ts-mode

;; A JUnit 5 test class, named after the file, in the file's package.
(junit (hellmacs-snippets-package-line ";")
       "import static org.junit.jupiter.api.Assertions.assertEquals;" n n
       "import org.junit.jupiter.api.Test;" n n
       "class " (p (hellmacs-snippets-class) class) " {" n n>
       "@Test" n>
       "void " (p "itWorks") "() {" n>
       (r "assertEquals(expected, actual);") n
       "}" > n
       "}" > n)

;; A Spring REST controller.
(controller (hellmacs-snippets-package-line ";")
            "import org.springframework.web.bind.annotation.GetMapping;" n
            "import org.springframework.web.bind.annotation.RequestMapping;" n
            "import org.springframework.web.bind.annotation.RestController;" n n
            "@RestController" n
            "@RequestMapping(\"/" (p "items") "\")" n
            "public class " (p (hellmacs-snippets-class) class) " {" n n>
            "@GetMapping" n>
            "public String " (p "list") "() {" n>
            (r "return \"ok\";") n
            "}" > n
            "}" > n)
