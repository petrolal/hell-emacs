;;; lang/crystal/doctor.el -*- lexical-binding: t; -*-

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
(if-let* ((cr (executable-find "crystal")))
    (hell-doctor-ok "Crystal compiler: %s" (abbreviate-file-name cr))
  (hell-doctor-info "crystal not found in PATH"))

(if-let* ((lsp (or (executable-find "crystalline") (executable-find "scry"))))
    (hell-doctor-ok "Crystal language server: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "crystalline or scry not found in PATH"))

(provide 'lang-crystal-doctor)
;;; doctor.el ends here
