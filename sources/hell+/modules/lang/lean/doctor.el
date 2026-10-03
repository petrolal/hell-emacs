;;; lang/lean/doctor.el -*- lexical-binding: t; -*-

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
(if-let* ((lean (executable-find "lean")))
    (hell-doctor-ok "Lean binary: %s" (abbreviate-file-name lean))
  (hell-doctor-info "lean not found in PATH"))

(if-let* ((lake (executable-find "lake")))
    (hell-doctor-ok "Lake build tool: %s" (abbreviate-file-name lake))
  (hell-doctor-info "lake not found in PATH"))

(if-let* ((elan (executable-find "elan")))
    (hell-doctor-ok "Elan toolchain manager: %s" (abbreviate-file-name elan))
  (hell-doctor-info "elan not found in PATH"))

(provide 'lang-lean-doctor)
;;; doctor.el ends here
