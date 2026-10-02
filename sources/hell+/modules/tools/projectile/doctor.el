;;; tools/projectile/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "git")
    (hell-doctor-ok "Git VCS for Projectile: %s" (executable-find "git"))
  (hell-doctor-info "git not found in PATH"))

(if (executable-find "rg")
    (hell-doctor-ok "ripgrep for Projectile search: %s" (executable-find "rg"))
  (hell-doctor-info "ripgrep not found in PATH"))
