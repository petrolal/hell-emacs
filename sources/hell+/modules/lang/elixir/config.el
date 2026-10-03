;;; lang/elixir/config.el -*- lexical-binding: t; -*-

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
;; Elixir support with elixir-mode and elixir-ls.

;;; Code:

(use-package elixir-mode
  :mode ("\\.exs?\\'" . elixir-mode)
  :config
  (add-hook 'elixir-mode-hook #'lsp-deferred)
  (when (fboundp 'elixir-ts-mode)
    (add-hook 'elixir-ts-mode-hook #'lsp-deferred)))

(hell-localleader-def '(elixir-mode elixir-ts-mode)
  "b" '("mix compile" . (lambda () (interactive) (compile "mix compile")))
  "t" '("mix test" . (lambda () (interactive) (compile "mix test")))
  "r" '("mix run" . (lambda () (interactive) (compile "mix run"))))

(provide 'lang-elixir-config)
;;; config.el ends here
