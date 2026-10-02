;;; tools/db/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; A database client over JDBC (autoload.el): sql.el with sqlline, for the
;; connections in the project's .hell-emacs/db.eld. In sql-mode buffers,
;; sql-mode's own keys connect when needed:
;;   C-c C-c  run the statement at point     C-c C-b  run the buffer
;; `M-x hell-db-connect' opens a connection's SQLi buffer, where results
;; show as tables. No other keys.

(with-eval-after-load 'sql (hell-db--add-product))

(add-hook 'sql-mode-hook #'hell-db-mode)
