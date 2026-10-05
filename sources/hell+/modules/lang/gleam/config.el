;;; lang/gleam/config.el -*- lexical-binding: t; -*-

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
;; Gleam type-safe Erlang VM language support.

;;; Code:

(use-package gleam-ts-mode
  :mode ("\\.gleam\\'" . gleam-ts-mode)
  :config
  (add-hook 'gleam-ts-mode-hook #'lsp-deferred))

(defun hell-gleam-build ()
  "Build the current Gleam project."
  (interactive)
  (compile "gleam build"))

(defun hell-gleam-test ()
  "Run the current Gleam project's tests."
  (interactive)
  (compile "gleam test"))

(defun hell-gleam-run ()
  "Run the current Gleam project."
  (interactive)
  (compile "gleam run"))

(defun hell-gleam-format ()
  "Format the current Gleam project."
  (interactive)
  (compile "gleam format"))

(hell-localleader-def 'gleam-ts-mode
  "b" '("gleam build" . hell-gleam-build)
  "t" '("gleam test" . hell-gleam-test)
  "r" '("gleam run" . hell-gleam-run)
  "f" '("gleam format" . hell-gleam-format))

(provide 'lang-gleam-config)
;;; config.el ends here
