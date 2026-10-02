;;; lang/go/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "go")
    (hell-doctor-ok "Go runtime: %s" (executable-find "go"))
  (hell-doctor-info "go not found in PATH"))

(if (executable-find "gopls")
    (hell-doctor-ok "Go language server (gopls): %s" (executable-find "gopls"))
  (hell-doctor-info "gopls not found in PATH"))
