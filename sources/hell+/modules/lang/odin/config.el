;;; lang/odin/config.el -*- lexical-binding: t; -*-

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
;; Odin programming language support and ols language server.

;;; Code:

(use-package odin-mode
  :mode ("\\.odin\\'" . odin-mode)
  :config
  (add-hook 'odin-mode-hook #'lsp-deferred))

(defun hell-odin-build ()
  "Build the current Odin project."
  (interactive)
  (compile "odin build ."))

(defun hell-odin-run ()
  "Run the current Odin project."
  (interactive)
  (compile "odin run ."))

(defun hell-odin-test ()
  "Run the current Odin project's tests."
  (interactive)
  (compile "odin test ."))

(hell-localleader-def 'odin-mode
  "b" '("odin build" . hell-odin-build)
  "r" '("odin run" . hell-odin-run)
  "t" '("odin test" . hell-odin-test))

(provide 'lang-odin-config)
;;; config.el ends here
