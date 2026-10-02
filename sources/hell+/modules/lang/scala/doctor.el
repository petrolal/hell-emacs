;;; lang/scala/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "sbt")
    (hell-doctor-ok "sbt build tool: %s" (executable-find "sbt"))
  (hell-doctor-info "sbt not found in PATH"))

(if (executable-find "metals")
    (hell-doctor-ok "Metals language server: %s" (executable-find "metals"))
  (hell-doctor-info "Metals binary not found in PATH; lsp-metals can install or connect via coursier"))
