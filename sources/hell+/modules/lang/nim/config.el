;;; lang/nim/config.el -*- lexical-binding: t; -*-

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
;; Nim systems programming language support and nimlsp.

;;; Code:

(use-package nim-mode
  :mode ("\\.\(?:nim\\|nims\\|nimble\)\\'" . nim-mode)
  :config
  (add-hook 'nim-mode-hook #'lsp-deferred))

(defun hell-nim-compile ()
  "Compile the current Nim file."
  (interactive)
  (compile (format "nim c %s" (shell-quote-argument (buffer-file-name)))))

(defun hell-nim-run ()
  "Compile and run the current Nim file."
  (interactive)
  (compile (format "nim c -r %s" (shell-quote-argument (buffer-file-name)))))

(defun hell-nim-test ()
  "Run the current nimble project's tests."
  (interactive)
  (compile "nimble test"))

(hell-localleader-def 'nim-mode
  "c" '("nim compile" . hell-nim-compile)
  "r" '("nim run" . hell-nim-run)
  "t" '("nimble test" . hell-nim-test))

(provide 'lang-nim-config)
;;; config.el ends here
