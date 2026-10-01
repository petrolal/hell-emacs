;;; lang/sql/doctor.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(let ((cli (or (executable-find "psql")
               (executable-find "mysql")
               (executable-find "sqlite3")
               (executable-find "sqlcmd"))))
  (if cli
      (hellmacs-doctor-ok "SQL client CLI: %s" cli)
    (hellmacs-doctor-info "No SQL CLI client (psql, mysql, sqlite3) found in PATH")))
