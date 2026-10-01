;;; lang/sql/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; SQL editing, formatting and execution via `sql-mode', `sql-indent'
;; and `:tools db' integration.

(use-package sql
  :ensure nil
  :mode ("\\.sql\\'" . sql-mode)
  :init
  (setq sql-input-ring-file-name (expand-file-name "sql-history" hellmacs-state-dir))
  :config
  (add-hook 'sql-mode-hook #'lsp-deferred))

(use-package sql-indent
  :after sql
  :hook (sql-mode . sqlind-minor-mode))

(hellmacs-localleader-def 'sql-mode
  "c" '("connect to database" . (if (modulep! :tools db) #'hellmacs-db-connect #'sql-connect))
  "b" '("send buffer" . sql-send-buffer)
  "r" '("send region" . sql-send-region)
  "s" '("send paragraph" . sql-send-paragraph)
  "q" '("list connections" . (if (modulep! :tools db) #'hellmacs-db-list-connections #'ignore)))
