;;; lang/rst/doctor.el -*- lexical-binding: t; -*-

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
(if-let* ((sphinx (executable-find "sphinx-build")))
    (hell-doctor-ok "Sphinx build tool: %s" (abbreviate-file-name sphinx))
  (hell-doctor-info "sphinx-build not found in PATH"))

(if-let* ((lsp (executable-find "esbonio")))
    (hell-doctor-ok "Esbonio Sphinx LSP: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "esbonio not found in PATH"))

(provide 'lang-rst-doctor)
;;; doctor.el ends here
