;;; lang/yaml/config.el -*- lexical-binding: t; -*-

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


;; YAML (application.yml, CI pipelines, Kubernetes manifests), in Emacs'
;; own `yaml-ts-mode' (its grammar built by sync), with yaml-language-server
;; through lsp-mode: completion, hover and validation against the schemas
;; you map in `lsp-yaml-schemas' or name in a `# yaml-language-server:
;; $schema=' comment. No keys of its own.
;;
;; Spring Boot's application*.yml go to its own server instead (:lang java
;; +spring), and Compose files to :lang docker's.

(hell-module-load "+paths")

(defvar hell-yaml-schemastore nil
  "Non-nil to have the server pick schemas from SchemaStore by file name.
Off by default: its catalogue and schemas are fetched while you edit, not
pinned by `bin/hell sync'.")

;; Set before lsp-yaml loads (a defcustom keeps a value that's already set).
(setq lsp-yaml-server-command (list hell-yaml-ls-executable "--stdio")
      lsp-yaml-schema-store-enable hell-yaml-schemastore)

(defvar lsp-yaml-schema-store-enable)
(after! lsp-yaml
  ;; The pinned install only, never npm's "latest".
  (lsp-dependency 'yaml-language-server `(:system ,hell-yaml-ls-executable))
  (setq lsp-yaml-schema-store-enable hell-yaml-schemastore))

(hell-lsp-pin-installer 'yaml-language-server '(:lang . yaml) 'hell-yaml-sync-install-server)

(add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode))
(add-hook 'yaml-ts-mode-hook #'lsp-deferred)
