;;; lang/scala/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Scala and sbt support with Metals LSP (`lsp-metals').
;; Provides syntax highlighting, auto-completion, diagnostics,
;; build tool integration, and localleader keybindings on `C-c l'.

(use-package scala-mode
  :mode ("\\.\\(scala\\|sbt\\|worksheet\\.sc\\)\\'" . scala-mode)
  :config
  (add-hook 'scala-mode-hook #'lsp-deferred)
  (when (fboundp 'scala-ts-mode)
    (add-hook 'scala-ts-mode-hook #'lsp-deferred)))

(use-package sbt-mode
  :commands sbt-start sbt-command
  :init
  (setq sbt:program-options '("-Dsbt.supershell=false")))

(use-package lsp-metals
  :after (lsp-mode scala-mode)
  :custom
  (lsp-metals-server-args '("-J-Dmetals.allow-skipping-full-compilation=true"))
  :config
  (when (fboundp 'hellmacs-lsp-status-register)
    (hellmacs-lsp-status-register 'metals :label "Metals")))

(hellmacs-localleader-def '(scala-mode scala-ts-mode)
  "b" '("build/compile" . (lambda () (interactive) (if (fboundp 'sbt-command) (sbt-command "compile") (compile "sbt compile"))))
  "c" '("metals doctor" . lsp-metals-doctor-run)
  "d" '("metals dashboard" . lsp-metals-dashboard-show)
  "i" '("import build" . lsp-metals-build-import)
  "s" '("sbt shell" . sbt-start)
  "w" '("worksheet evaluate" . lsp-metals-worksheet-hover))
