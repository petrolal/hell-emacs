;;; lang/beancount/doctor.el -*- lexical-binding: t; -*-

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
(if-let* ((bean (executable-find "bean-check")))
    (hell-doctor-ok "Beancount checker: %s" (abbreviate-file-name bean))
  (hell-doctor-info "bean-check not found in PATH"))

(if-let* ((fava (executable-find "fava")))
    (hell-doctor-ok "Fava web interface: %s" (abbreviate-file-name fava))
  (hell-doctor-info "fava not found in PATH"))

(if-let* ((lsp (executable-find "beancount-language-server")))
    (hell-doctor-ok "Beancount language server: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "beancount-language-server not found in PATH"))

(provide 'lang-beancount-doctor)
;;; doctor.el ends here
