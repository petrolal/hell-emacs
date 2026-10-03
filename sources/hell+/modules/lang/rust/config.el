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

(hell-localleader-def '(rust-mode rust-ts-mode)
  "b" '("cargo build" . (lambda () (interactive) (compile "cargo build")))
  "t" '("cargo test" . (lambda () (interactive) (compile "cargo test")))
  "r" '("cargo run" . (lambda () (interactive) (compile "cargo run")))
  "c" '("cargo check" . (lambda () (interactive) (compile "cargo check"))))

(provide 'lang-rust-config)
;;; config.el ends here
