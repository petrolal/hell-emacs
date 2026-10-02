;;; tools/eglot/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (fboundp 'eglot)
    (hell-doctor-ok "eglot built-in LSP client available")
  (hell-doctor-error "eglot is not available; requires Emacs 29+"))
