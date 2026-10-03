;;; lang/toml/config.el -*- lexical-binding: t; -*-

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
;; TOML support with toml-mode and taplo.

;;; Code:

(use-package toml-mode
  :mode ("\\.toml\\'" . toml-mode)
  :config
  (add-hook 'toml-mode-hook #'lsp-deferred)
  (when (fboundp 'toml-ts-mode)
    (add-hook 'toml-ts-mode-hook #'lsp-deferred)))

(provide 'lang-toml-config)
;;; config.el ends here
