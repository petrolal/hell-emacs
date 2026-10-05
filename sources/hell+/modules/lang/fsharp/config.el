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

(defun hell-fsharp-build ()
  "Build the current .NET project."
  (interactive)
  (compile "dotnet build"))

(defun hell-fsharp-test ()
  "Run the current .NET project's tests."
  (interactive)
  (compile "dotnet test"))

(defun hell-fsharp-run ()
  "Run the current .NET project."
  (interactive)
  (compile "dotnet run"))

(defun hell-fsharp-interactive ()
  "Start an F# interactive session."
  (interactive)
  (if (fboundp 'run-fsharp) (run-fsharp) (compile "dotnet fsi")))

(hell-localleader-def 'fsharp-mode
  "b" '("dotnet build" . hell-fsharp-build)
  "t" '("dotnet test" . hell-fsharp-test)
  "r" '("dotnet run" . hell-fsharp-run)
  "s" '("F# interactive" . hell-fsharp-interactive))

(provide 'lang-fsharp-config)
;;; config.el ends here
