;;; lang/fsharp/config.el -*- lexical-binding: t; -*-

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
;; F# functional .NET development and FsAutoComplete LSP.

;;; Code:

(use-package fsharp-mode
  :mode ("\\.fs[xi]?\\'" . fsharp-mode)
  :config
  (add-hook 'fsharp-mode-hook #'lsp-deferred))

(hell-localleader-def 'fsharp-mode
  "b" '("dotnet build" . (lambda () (interactive) (compile "dotnet build")))
  "t" '("dotnet test" . (lambda () (interactive) (compile "dotnet test")))
  "r" '("dotnet run" . (lambda () (interactive) (compile "dotnet run")))
  "s" '("F# interactive" . (lambda () (interactive) (if (fboundp 'run-fsharp) (run-fsharp) (compile "dotnet fsi")))))

(provide 'lang-fsharp-config)
;;; config.el ends here
