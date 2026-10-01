;;; lang/ruby/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "ruby")
    (hellmacs-doctor-ok "Ruby runtime: %s" (executable-find "ruby"))
  (hellmacs-doctor-info "ruby not found in PATH"))

(if (or (executable-find "ruby-lsp") (executable-find "solargraph"))
    (hellmacs-doctor-ok "Ruby language server: %s" (or (executable-find "ruby-lsp") (executable-find "solargraph")))
  (hellmacs-doctor-info "ruby-lsp or solargraph not found in PATH"))
