;;; lang/nix/config.el -*- lexical-binding: t; -*-

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
;; Nix language support with nix-mode and nixd/nil language servers.

;;; Code:

(use-package nix-mode
  :mode ("\\.nix\\'" . nix-mode)
  :config
  (add-hook 'nix-mode-hook #'lsp-deferred)
  (when (fboundp 'nix-ts-mode)
    (add-hook 'nix-ts-mode-hook #'lsp-deferred)))

(hell-localleader-def '(nix-mode nix-ts-mode)
  "b" '("nix build" . (lambda () (interactive) (compile "nix build")))
  "f" '("flake check" . (lambda () (interactive) (compile "nix flake check"))))

(provide 'lang-nix-config)
;;; config.el ends here
