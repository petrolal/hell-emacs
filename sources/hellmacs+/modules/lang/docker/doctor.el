;;; lang/docker/doctor.el -*- lexical-binding: t; -*-

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


;; Checked by `bin/hellmacs doctor'.

(hellmacs-module-load "+paths")

(if (not (hellmacs-docker-ls-pin))
    (hellmacs-doctor-warn "No pinned docker-language-server for %s" (or (hellmacs-platform) system-type))
  (hellmacs-doctor-reachable (hellmacs-docker-ls-url) "installing docker-language-server")
  (hellmacs-doctor-pinned "docker-language-server" hellmacs-docker-ls-version
                          (hellmacs-docker-ls-installed-p) (file-exists-p hellmacs-docker-ls-executable)
                          :where hellmacs-docker-ls-executable))
(hellmacs-doctor-executable "docker" "Docker's build checks in the server's diagnostics" nil "--version")
