;;; kotlin.eld --- Hellmacs' Kotlin snippets (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hellmacs.

kotlin-mode kotlin-ts-mode

;; A data class, named after the file.
(dataclass "data class " (p (hellmacs-snippets-class) name) "(" n>
           "val " (p "id") ": " (p "Long") "," n>
           "val " (p "name") ": " (p "String") n
           ")" > n)
