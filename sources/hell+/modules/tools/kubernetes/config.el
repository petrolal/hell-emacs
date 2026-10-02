;;; tools/kubernetes/config.el -*- lexical-binding: t; -*-

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

;; Pods, deployments and every other resource through kubel (Phase
;; 12.6): logs, port forwards, a shell in a pod, describe and edit, with
;; the developer's own kubectl and its current context and namespace
;; (switched in kubel with `C' and `n'). Nothing is downloaded.
;;
;; kubel, not kubernetes-el: it asks kubectl only when you open or refresh
;; a view, where kubernetes-el polls the cluster every few seconds, and it
;; needs neither magit-popup (deprecated) nor request.
;;
;; Keys: `C-c o k' opens kubel; everything else is kubel's own, in its
;; buffers (`?' lists them).

(hell-leader-def
  "o"   "open"
  "o k" '("kubernetes" . kubel))

(use-package kubel
  :commands (kubel kubel-open kubel-set-context kubel-set-namespace
             kubel-port-forward-pod kubel-get-pod-logs kubel-exec-pod))
