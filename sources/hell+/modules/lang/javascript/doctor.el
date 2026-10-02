;;; lang/javascript/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "node")
    (hell-doctor-ok "Node runtime: %s" (executable-find "node"))
  (hell-doctor-warn :topic 'tooling "Node is not installed; JS/TS language servers require Node"))
