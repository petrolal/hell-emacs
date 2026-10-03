;;; tools/make/config.el -*- lexical-binding: t; -*-

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

;;; Commentary:
;; Execute Makefile targets via makefile-executor.

;;; Code:

(declare-function makefile-executor-execute-target "makefile-executor")
(declare-function makefile-executor-execute-project-target "makefile-executor")

(use-package makefile-executor
  :defer t
  :commands (makefile-executor-execute-target
             makefile-executor-execute-project-target))

(hell-localleader-def 'makefile-mode
  "b" '("build target" . makefile-executor-execute-target)
  "p" '("project target" . makefile-executor-execute-project-target))

(provide 'tools-make-config)
;;; config.el ends here
