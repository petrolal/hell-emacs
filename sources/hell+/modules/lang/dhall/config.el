;;; lang/dhall/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; Dhall programmable configuration language support.

;;; Code:

(use-package dhall-mode
  :mode ("\\.dhall\\'" . dhall-mode)
  :config
  (add-hook 'dhall-mode-hook #'lsp-deferred))

(defun hell-dhall-format ()
  "Format the current Dhall buffer's file in place."
  (interactive)
  (compile "dhall format --inplace"))

(defun hell-dhall-lint ()
  "Lint the current Dhall buffer's file in place."
  (interactive)
  (compile "dhall lint --inplace"))

(defun hell-dhall-freeze ()
  "Freeze the current Dhall buffer's imports in place."
  (interactive)
  (compile "dhall freeze --inplace"))

(hell-localleader-def 'dhall-mode
  "f" '("dhall format" . hell-dhall-format)
  "l" '("dhall lint" . hell-dhall-lint)
  "z" '("dhall freeze" . hell-dhall-freeze))

(provide 'lang-dhall-config)
;;; config.el ends here
