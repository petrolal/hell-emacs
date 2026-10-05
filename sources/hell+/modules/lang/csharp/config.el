;;; lang/csharp/config.el -*- lexical-binding: t; -*-

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
;; C# support with dotnet, csharp-ls and OmniSharp.

;;; Code:

(use-package csharp-mode
  :mode ("\\.cs\\'" . csharp-mode)
  :config
  (add-hook 'csharp-mode-hook #'lsp-deferred)
  (when (fboundp 'csharp-ts-mode)
    (add-hook 'csharp-ts-mode-hook #'lsp-deferred)))

(defun hell-csharp-build ()
  "Build the current .NET project."
  (interactive)
  (compile "dotnet build"))

(defun hell-csharp-test ()
  "Run the current .NET project's tests."
  (interactive)
  (compile "dotnet test"))

(defun hell-csharp-run ()
  "Run the current .NET project."
  (interactive)
  (compile "dotnet run"))

(hell-localleader-def '(csharp-mode csharp-ts-mode)
  "b" '("dotnet build" . hell-csharp-build)
  "t" '("dotnet test" . hell-csharp-test)
  "r" '("dotnet run" . hell-csharp-run))

(provide 'lang-csharp-config)
;;; config.el ends here
