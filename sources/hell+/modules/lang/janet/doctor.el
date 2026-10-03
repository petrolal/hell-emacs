;;; lang/janet/doctor.el -*- lexical-binding: t; -*-

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
(if-let* ((janet (executable-find "janet")))
    (hell-doctor-ok "Janet runtime: %s" (abbreviate-file-name janet))
  (hell-doctor-info "janet not found in PATH"))

(if-let* ((jpm (executable-find "jpm")))
    (hell-doctor-ok "Janet package manager (jpm): %s" (abbreviate-file-name jpm))
  (hell-doctor-info "jpm not found in PATH"))

(if-let* ((lsp (executable-find "janet-lsp")))
    (hell-doctor-ok "Janet language server: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "janet-lsp not found in PATH"))

(provide 'lang-janet-doctor)
;;; doctor.el ends here
