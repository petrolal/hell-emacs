;;; tools/direnv/config.el -*- lexical-binding: t; -*-

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


;; Per-project environments (Phase 12.3): a project's .envrc, run by
;; direnv, sets JAVA_HOME, MAVEN_OPTS, GRADLE_USER_HOME, proxy variables...
;; for that project's buffers only (buffer-local `process-environment' and
;; `exec-path'). Everything started from those buffers inherits it: the
;; build and tests (`C-x p c', :tools build), a language server started
;; there, shell commands. Switch to another project's buffer and its own
;; environment applies.
;;
;; A new or changed .envrc must be allowed first, as in a shell: M-x
;; envrc-allow (or `direnv allow' in a terminal), then M-x envrc-reload.
;; No keys are bound: envrc's own `envrc-command-map' is there to give a
;; prefix of your choosing (envrc suggests C-c e):
;;   (with-eval-after-load 'envrc
;;     (keymap-set envrc-mode-map "C-c e" 'envrc-command-map))
;;
;; Without the direnv program, envrc does nothing (`bin/hellmacs doctor'
;; says so).
;;
;; On with the first file rather than at startup. A global mode enabled
;; late sets each buffer's environment before other modes act on it: envrc
;; recommends it.

(use-package envrc
  :commands (envrc-global-mode envrc-allow envrc-reload envrc-deny)
  :init
  (add-hook 'hellmacs-first-file-hook #'envrc-global-mode))
