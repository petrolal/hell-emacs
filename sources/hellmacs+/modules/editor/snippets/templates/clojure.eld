;;; clojure.eld --- Hellmacs' Clojure snippets (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hellmacs.

clojure-mode clojure-ts-mode

;; A clojure.test test.
(deftest "(deftest " (p "it-works") "-test" n>
         "(is (= " (p "expected") " " (p "actual") ")))")
