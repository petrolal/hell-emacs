;;; lang/sh/config.el -*- lexical-binding: t; -*-

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


;; Shell scripts (build wrappers, CI steps, entrypoints) in built-in
;; `sh-mode' (`bash-ts-mode' with +tree-sitter), with bash-language-server
;; through lsp-mode: completion, hover, go to definition across sourced
;; files, and ShellCheck's diagnostics when `shellcheck' is installed.
;; Gradle's and Maven's wrappers (gradlew, mvnw) open here too. The server
;; only starts for sh and bash scripts, not zsh or fish. No keys of its own.

(hell-module-load "+paths")

(after! lsp-bash
  ;; The pinned install only, never npm's "latest".
  (lsp-dependency 'bash-language-server `(:system ,hell-sh-ls-executable)))

(hell-lsp-pin-installer 'bash-language-server '(:lang . sh) 'hell-sh-sync-install-server)

(add-to-list 'auto-mode-alist '("/\\(?:gradlew\\|mvnw\\)\\'" . sh-mode))

(add-hook! (sh-mode bash-ts-mode) #'lsp-deferred)
