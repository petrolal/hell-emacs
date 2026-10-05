;;; lang/crystal/config.el -*- lexical-binding: t; -*-

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
;; Crystal programming language support and crystalline language server.

;;; Code:

(use-package crystal-mode
  :mode ("\\.cr\\'" . crystal-mode)
  :config
  (add-hook 'crystal-mode-hook #'lsp-deferred))

(defun hell-crystal-build ()
  "Build the current Crystal project."
  (interactive)
  (compile "crystal build"))

(defun hell-crystal-spec ()
  "Run the current Crystal project's specs."
  (interactive)
  (compile "crystal spec"))

(defun hell-crystal-run ()
  "Run the current Crystal project."
  (interactive)
  (compile "crystal run"))

(hell-localleader-def 'crystal-mode
  "b" '("crystal build" . hell-crystal-build)
  "t" '("crystal spec" . hell-crystal-spec)
  "r" '("crystal run" . hell-crystal-run))

(provide 'lang-crystal-config)
;;; config.el ends here
