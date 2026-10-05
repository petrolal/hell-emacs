;;; lang/rust/config.el -*- lexical-binding: t; -*-

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
;; Rust support with rust-analyzer and cargo.

;;; Code:

(use-package rust-mode
  :mode ("\\.rs\\'" . rust-mode)
  :config
  (add-hook 'rust-mode-hook #'lsp-deferred)
  (when (fboundp 'rust-ts-mode)
    (add-hook 'rust-ts-mode-hook #'lsp-deferred)))

(defun hell-rust-build ()
  "Build the current cargo project."
  (interactive)
  (compile "cargo build"))

(defun hell-rust-test ()
  "Run the current cargo project's tests."
  (interactive)
  (compile "cargo test"))

(defun hell-rust-run ()
  "Run the current cargo project."
  (interactive)
  (compile "cargo run"))

(defun hell-rust-check ()
  "Check the current cargo project without producing binaries."
  (interactive)
  (compile "cargo check"))

(hell-localleader-def '(rust-mode rust-ts-mode)
  "b" '("cargo build" . hell-rust-build)
  "t" '("cargo test" . hell-rust-test)
  "r" '("cargo run" . hell-rust-run)
  "c" '("cargo check" . hell-rust-check))

(provide 'lang-rust-config)
;;; config.el ends here
