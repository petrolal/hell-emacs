;;; lang/docker/config.el -*- lexical-binding: t; -*-

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


;; Dockerfiles and Compose files, with Docker's docker-language-server
;; through lsp-mode: completion, hover (image tags, instructions),
;; diagnostics (including Docker's build checks) and formatting.
;; Dockerfiles open in Emacs' own `dockerfile-ts-mode' (its grammar built
;; by sync); Compose files (compose.yaml, docker-compose.*.yml) stay
;; in YAML's mode and get this server instead of the YAML one. No keys of
;; its own.
;;
;; lsp-mode has no client for this server (its `lsp-dockerfile' runs the
;; older npm dockerfile-language-server-nodejs), so one is registered here,
;; ahead of that one.

(hell-module-load "+paths")

(defconst hell-docker-compose-file-regexp
  "/\\(?:docker-\\)?compose\\(?:\\.[^/]+\\)?\\.ya?ml\\'"
  "Compose files: compose.yaml, docker-compose.yml, compose.override.yml...")

(defun hell-docker-compose-file-p (file)
  "Non-nil if FILE is a Docker Compose file."
  (and file (string-match-p hell-docker-compose-file-regexp file)))

(defun hell-docker-ls-command ()
  "The command starting the pinned server."
  (list hell-docker-ls-executable "start" "--stdio"))

;; Docker's server sends usage data and crash reports (to BugSnag) unless
;; told not to: its telemetry is on by default (its TELEMETRY.md). Off at
;; initialize, and when it asks for `docker.lsp.telemetry' later.
(defun hell-docker-ls-initialization-options ()
  "What the server is told at initialize: no telemetry."
  (list :telemetry (hell-docker-ls-telemetry-setting)))

(defun hell-docker-ls-telemetry-setting ()
  "The server's telemetry setting: off."
  "off")

(declare-function lsp-register-client "lsp-mode")
(declare-function lsp-register-custom-settings "lsp-mode")
(declare-function make-lsp-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")
(declare-function lsp-activate-on "lsp-mode")
(declare-function hell-lsp-install-pinned "../../tools/lsp/autoload")
(defvar lsp-language-id-configuration)

(after! lsp-mode
  ;; First, so they win over the YAML entries.
  (add-to-list 'lsp-language-id-configuration (cons hell-docker-compose-file-regexp "dockercompose"))
  (add-to-list 'lsp-language-id-configuration '(dockerfile-ts-mode . "dockerfile"))
  (lsp-register-custom-settings '(("docker.lsp.telemetry" hell-docker-ls-telemetry-setting)))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection #'hell-docker-ls-command
                                          (lambda () (file-executable-p hell-docker-ls-executable)))
    :activation-fn (lsp-activate-on "dockerfile" "dockercompose")
    :initialization-options #'hell-docker-ls-initialization-options
    :priority 1                         ; over lsp-dockerfile's
    :server-id 'docker-language-server
    :download-server-fn (lambda (_client callback error-callback _update?)
                          (hell-lsp-install-pinned '(:lang . docker)
                                                   #'hell-docker-sync-install-server
                                                       callback error-callback)))))

(add-to-list 'auto-mode-alist '("/\\(?:Dockerfile\\|Containerfile\\)\\(?:\\.[^/]*\\)?\\'" . dockerfile-ts-mode))
(add-to-list 'auto-mode-alist '("\\.dockerfile\\'" . dockerfile-ts-mode))

(defun hell-docker--compose-lsp-h ()
  "Start the server in a Compose file (without :lang yaml, nothing else would)."
  (when (hell-docker-compose-file-p buffer-file-name)
    (lsp-deferred)))

(add-hook 'dockerfile-ts-mode-hook #'lsp-deferred)
(add-hook 'yaml-ts-mode-hook #'hell-docker--compose-lsp-h)
