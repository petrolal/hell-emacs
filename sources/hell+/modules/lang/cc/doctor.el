;;; lang/cc/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (or (executable-find "clangd") (executable-find "ccls"))
    (hell-doctor-ok "C/C++ language server: %s" (or (executable-find "clangd") (executable-find "ccls")))
  (hell-doctor-info "clangd not found in PATH"))
