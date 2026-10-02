;;; lang/ruby/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "ruby")
    (hell-doctor-ok "Ruby runtime: %s" (executable-find "ruby"))
  (hell-doctor-info "ruby not found in PATH"))

(if (or (executable-find "ruby-lsp") (executable-find "solargraph"))
    (hell-doctor-ok "Ruby language server: %s" (or (executable-find "ruby-lsp") (executable-find "solargraph")))
  (hell-doctor-info "ruby-lsp or solargraph not found in PATH"))
