;;; lang/python/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "python3")
    (hell-doctor-ok "Python runtime: %s" (executable-find "python3"))
  (hell-doctor-info "python3 not found in PATH"))

(let ((ls (or (executable-find "pyright")
              (executable-find "basedpyright")
              (executable-find "ruff")
              (executable-find "pylsp"))))
  (if ls
      (hell-doctor-ok "Python language server: %s" ls)
    (hell-doctor-info "No Python LSP (pyright, basedpyright, ruff) found in PATH")))
