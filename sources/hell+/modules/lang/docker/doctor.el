;;; lang/docker/doctor.el -*- lexical-binding: t; -*-

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


;; Checked by `bin/hell doctor'.

(hell-module-load "+paths")

(if (not (hell-docker-ls-pin))
    (hell-doctor-warn :topic 'installs "No pinned docker-language-server for %s" (or (hell-platform) system-type))
  (hell-doctor-reachable (hell-docker-ls-url) "installing docker-language-server")
  (hell-doctor-pinned "docker-language-server" hell-docker-ls-version
                          (hell-docker-ls-installed-p) (file-exists-p hell-docker-ls-executable)
                          :where hell-docker-ls-executable))
(hell-doctor-executable "docker" "Docker's build checks in the server's diagnostics" nil "--version")
