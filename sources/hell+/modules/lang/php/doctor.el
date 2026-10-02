;;; lang/php/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "php")
    (hell-doctor-ok "PHP runtime: %s" (executable-find "php"))
  (hell-doctor-info "php not found in PATH"))

(if (or (executable-find "phpactor") (executable-find "intelephense"))
    (hell-doctor-ok "PHP language server: %s" (or (executable-find "phpactor") (executable-find "intelephense")))
  (hell-doctor-info "phpactor or intelephense not found in PATH"))
