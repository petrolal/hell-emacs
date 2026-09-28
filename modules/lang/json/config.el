;;; lang/json/config.el -*- lexical-binding: t; -*-

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


;; JSON, in built-in `js-json-mode' (`json-ts-mode' with +tree-sitter),
;; with vscode-json-language-server through lsp-mode: completion, hover
;; and validation against the file's `$schema' or `lsp-json-schemas'.
;; No keys of its own.

(hellmacs-module-load "+paths")

(after! lsp-json
  ;; The pinned install only, never npm's "latest".
  (lsp-dependency 'vscode-json-languageserver `(:system ,hellmacs-json-ls-executable)))

(hellmacs-lsp-pin-installer 'vscode-json-languageserver '(:lang . json) 'hellmacs-json-sync-install-server)

(add-hook! (js-json-mode json-ts-mode) #'lsp-deferred)
