;;; lang/php/config.el -*- lexical-binding: t; -*-

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

;; PHP editing and language server integration (phpactor, intelephense).

(use-package php-mode
  :mode ("\\.\\(?:php\\|phtml\\|php[345s]?\\)\\'" . php-mode)
  :config
  (add-hook 'php-mode-hook #'lsp-deferred)
  (when (fboundp 'php-ts-mode)
    (add-hook 'php-ts-mode-hook #'lsp-deferred)))

(defun hell-php-composer-test ()
  "Run the current PHP project's composer tests."
  (interactive)
  (compile "composer test"))

(defun hell-php-run ()
  "Run the current PHP file."
  (interactive)
  (compile (format "php %s" (shell-quote-argument (buffer-file-name)))))

(hell-localleader-def '(php-mode php-ts-mode)
  "b" '("composer test" . hell-php-composer-test)
  "r" '("run php" . hell-php-run))
