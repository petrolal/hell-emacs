;;; lang/zig/config.el -*- lexical-binding: t; -*-

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
;; Zig support with zig-mode and zls language server.

;;; Code:

(use-package zig-mode
  :mode ("\\.\\(?:zig\\|zon\\)\\'" . zig-mode)
  :config
  (add-hook 'zig-mode-hook #'lsp-deferred)
  (when (fboundp 'zig-ts-mode)
    (add-hook 'zig-ts-mode-hook #'lsp-deferred)))

(defun hell-zig-build ()
  "Build the current Zig project."
  (interactive)
  (compile "zig build"))

(defun hell-zig-test ()
  "Run the current Zig project's tests."
  (interactive)
  (compile "zig build test"))

(defun hell-zig-run ()
  "Run the current Zig project."
  (interactive)
  (compile "zig build run"))

(hell-localleader-def '(zig-mode zig-ts-mode)
  "b" '("zig build" . hell-zig-build)
  "t" '("zig test" . hell-zig-test)
  "r" '("zig run" . hell-zig-run))

(provide 'lang-zig-config)
;;; config.el ends here
