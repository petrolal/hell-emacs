;;; tools/projectile/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "git")
    (hellmacs-doctor-ok "Git VCS for Projectile: %s" (executable-find "git"))
  (hellmacs-doctor-info "git not found in PATH"))

(if (executable-find "rg")
    (hellmacs-doctor-ok "ripgrep for Projectile search: %s" (executable-find "rg"))
  (hellmacs-doctor-info "ripgrep not found in PATH"))
