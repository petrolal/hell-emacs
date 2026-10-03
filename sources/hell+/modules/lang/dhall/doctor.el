;;; lang/dhall/doctor.el -*- lexical-binding: t; -*-

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

;;; Code:

;; Checked by `bin/hell doctor'.
(if-let* ((dhall (executable-find "dhall")))
    (hell-doctor-ok "Dhall CLI: %s" (abbreviate-file-name dhall))
  (hell-doctor-info "dhall not found in PATH"))

(if-let* ((lsp (executable-find "dhall-lsp-server")))
    (hell-doctor-ok "Dhall language server: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "dhall-lsp-server not found in PATH"))

(provide 'lang-dhall-doctor)
;;; doctor.el ends here
