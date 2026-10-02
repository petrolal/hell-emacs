;;; tools/magit/config.el -*- lexical-binding: t; -*-

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


;; Git through Magit. Nothing is rebound: Magit binds its own global keys
;; when its autoloads are read (`magit-define-global-key-bindings', which
;; defaults to `default'), so Magit stays unloaded until first use:
;;   C-x g      status of the current repository
;;   C-x M-g    dispatch (init, clone, and commands needing no repository)
;;   C-c M-g    file dispatch (blame, log and diff of the current file)
;; Inside a Magit buffer, `?' lists every command; `C-x g' also works
;; from any buffer in a repository, including Java sources.
;;
;; Magit's transient (the popup menus) keeps its history, levels and
;; saved values in the state directory: see lisp/hell-core.el.

(use-package magit
  :commands (magit-status magit-dispatch magit-file-dispatch))
