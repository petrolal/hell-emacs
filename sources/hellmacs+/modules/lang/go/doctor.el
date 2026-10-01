;;; lang/go/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "go")
    (hellmacs-doctor-ok "Go runtime: %s" (executable-find "go"))
  (hellmacs-doctor-info "go not found in PATH"))

(if (executable-find "gopls")
    (hellmacs-doctor-ok "Go language server (gopls): %s" (executable-find "gopls"))
  (hellmacs-doctor-info "gopls not found in PATH"))
