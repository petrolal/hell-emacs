;;; clojure.eld --- Hell Emacs' Clojure file templates (tempel) -*- mode: lisp-data -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later. This file is part of Hell Emacs.

;; Filled into a new, empty file (see :editor file-templates); `M-}' and
;; `M-{' move between the fields.

clojure-mode clojure-ts-mode

;; src/shop/cart.clj: (ns shop.cart).
(__ns "(ns " (hell-file-templates-clojure-ns) ")" n n
      q)

;; test/shop/cart_test.clj: the test namespace, requiring shop.cart.
(__test "(ns " (hell-file-templates-clojure-ns) n>
        "(:require [clojure.test :refer [deftest is testing]]" n>
        "[" (hell-file-templates-clojure-tested-ns) " :as sut]))" n n
        "(deftest " (p "it-works") n>
        "(is " q "))" n)
