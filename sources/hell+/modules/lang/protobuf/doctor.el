;;; lang/protobuf/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(if (executable-find "protoc")
    (hell-doctor-ok "protoc compiler: %s" (executable-find "protoc"))
  (hell-doctor-info "protoc compiler not found in PATH"))
