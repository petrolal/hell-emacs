;;; tools/docker/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Checked by `bin/hell doctor'. Only the CLI and its local context
;; are read: no daemon is needed (nor contacted) for the checks.

(hell-module-load "+paths")

(let ((cli (hell-docker-cli)))
  (when (hell-doctor-executable cli "docker.el runs every command through it (docker, or podman)"
                                nil "--version")
    ;; podman has no contexts, only connections.
    (when (equal cli "docker")
      (pcase-let ((`(,code . ,context) (hell-cli--run cli "context" "show")))
        (when (and (zerop code) (not (string-empty-p context)))
          (hell-doctor-info "Docker context: %s" context))))))
