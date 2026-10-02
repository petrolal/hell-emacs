;;; tools/kubernetes/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Checked by `bin/hell doctor'. Only kubectl and its local
;; configuration are read: no cluster is contacted.

(when (hell-doctor-executable "kubectl" "kubel runs every command through it"
                              nil "version" "--client")
  (pcase-let ((`(,code . ,context) (hell-cli--run "kubectl" "config" "current-context")))
    (if (and (zerop code) (not (string-empty-p context)))
        (hell-doctor-info "Kubernetes context: %s" context)
      (hell-doctor-info "No current Kubernetes context; kubel asks for one (`kubel-set-context')"))))
