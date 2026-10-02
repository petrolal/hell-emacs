;;; tools/docker/config.el -*- lexical-binding: t; -*-

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

;; Containers, images, volumes, networks and Compose through docker.el
;; (Phase 12.6), with the developer's own CLI and its current context
;; (`docker context use' applies; `M-x docker-contexts' switches it).
;; Nothing is downloaded: docker.el runs the `docker' already installed,
;; or `podman' when that is the only one (`hell-docker-cli').
;;
;; Keys: `C-c o d' opens docker.el's menu; everything else is docker.el's
;; own, in its buffers (`?' lists them). A container's shell or files go
;; through Emacs' own TRAMP methods (`/docker:' and `/podman:'), so no
;; docker-tramp package is needed. Dockerfiles and Compose files are
;; `:lang docker''s.

(hell-module-load "+paths")

(defvar docker-command)
(defvar docker-compose-command)
(defvar docker-container-tramp-method)

(defun hell-docker-use-installed-cli ()
  "Point docker.el at podman when it's the CLI installed, not docker.
Its commands, Compose and container shells alike. A `docker-command' of
your own (anything but docker.el's \"docker\") is kept."
  (when (equal docker-command "docker")
    (let ((cli (hell-docker-cli)))
      (unless (equal cli "docker")
        (setq docker-command cli)
        (when (equal docker-compose-command "docker compose")
          (setq docker-compose-command (concat cli " compose")))
        (when (equal docker-container-tramp-method "docker")
          (setq docker-container-tramp-method cli))))))

(hell-leader-def
  "o"   "open"
  "o d" '("docker" . docker))

(use-package docker
  :commands (docker docker-containers docker-images docker-volumes docker-networks
             docker-compose docker-contexts)
  :config
  ;; The container submodule, where the TRAMP method is, is loaded with it.
  (require 'docker-container nil t)
  (hell-docker-use-installed-cli))
