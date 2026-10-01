;;; lang/terraform/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "terraform")
    (hellmacs-doctor-ok "Terraform CLI: %s" (executable-find "terraform"))
  (hellmacs-doctor-info "terraform CLI not found in PATH"))

(if (executable-find "terraform-ls")
    (hellmacs-doctor-ok "Terraform Language Server: %s" (executable-find "terraform-ls"))
  (hellmacs-doctor-info "terraform-ls not found in PATH"))
