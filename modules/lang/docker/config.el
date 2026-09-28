;;; lang/docker/config.el -*- lexical-binding: t; -*-

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


;; Dockerfiles and Compose files, with Docker's docker-language-server
;; through lsp-mode: completion, hover (image tags, instructions),
;; diagnostics (including Docker's build checks) and formatting.
;; Dockerfiles open in `dockerfile-mode' (`dockerfile-ts-mode' with
;; +tree-sitter); Compose files (compose.yaml, docker-compose.*.yml) stay
;; in YAML's mode and get this server instead of the YAML one. No keys of
;; its own.
;;
;; lsp-mode has no client for this server (its `lsp-dockerfile' runs the
;; older npm dockerfile-language-server-nodejs), so one is registered here,
;; ahead of that one.

(hellmacs-module-load "+paths")

(defconst hellmacs-docker-compose-file-regexp
  "/\\(?:docker-\\)?compose\\(?:\\.[^/]+\\)?\\.ya?ml\\'"
  "Compose files: compose.yaml, docker-compose.yml, compose.override.yml...")

(defun hellmacs-docker-compose-file-p (file)
  "Non-nil if FILE is a Docker Compose file."
  (and file (string-match-p hellmacs-docker-compose-file-regexp file)))

(defun hellmacs-docker-ls-command ()
  "The command starting the pinned server."
  (list hellmacs-docker-ls-executable "start" "--stdio"))

(declare-function lsp-register-client "lsp-mode")
(declare-function make-lsp-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")
(declare-function lsp-activate-on "lsp-mode")
(declare-function hellmacs-lsp-install-pinned "../../tools/lsp/autoload")
(defvar lsp-language-id-configuration)

(after! lsp-mode
  ;; First, so they win over the YAML entries.
  (add-to-list 'lsp-language-id-configuration (cons hellmacs-docker-compose-file-regexp "dockercompose"))
  (add-to-list 'lsp-language-id-configuration '(dockerfile-mode . "dockerfile"))
  (add-to-list 'lsp-language-id-configuration '(dockerfile-ts-mode . "dockerfile"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection #'hellmacs-docker-ls-command
                                          (lambda () (file-executable-p hellmacs-docker-ls-executable)))
    :activation-fn (lsp-activate-on "dockerfile" "dockercompose")
    :priority 1                         ; over lsp-dockerfile's
    :server-id 'docker-language-server
    :download-server-fn (lambda (_client callback error-callback _update?)
                          (hellmacs-lsp-install-pinned '(:lang . docker)
                                                       #'hellmacs-docker-sync-install-server
                                                       callback error-callback)))))

(add-to-list 'auto-mode-alist '("/\\(?:Dockerfile\\|Containerfile\\)\\(?:\\.[^/]*\\)?\\'" . dockerfile-mode))
(add-to-list 'auto-mode-alist '("\\.dockerfile\\'" . dockerfile-mode))

(defun hellmacs-docker--compose-lsp-h ()
  "Start the server in a Compose file (without :lang yaml, nothing else would)."
  (when (hellmacs-docker-compose-file-p buffer-file-name)
    (lsp-deferred)))

(add-hook! (dockerfile-mode dockerfile-ts-mode) #'lsp-deferred)
(add-hook! (yaml-mode yaml-ts-mode) #'hellmacs-docker--compose-lsp-h)
