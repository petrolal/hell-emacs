;;; tools/build/config.el -*- lexical-binding: t; -*-

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


;; Building and testing with Emacs' own `compile': the project's build
;; tool is detected (Gradle or Maven, wrapper first), so `C-x p c'
;; (`project-compile') proposes the right command; output is colored,
;; and compile errors and failing tests are clickable (`M-g n' / `M-g p'
;; step through them). When a build ends, the echo area says so --
;; [FORGE TEMPERED] or [BYTECODE PURGATORY] -- and the project's
;; language servers show JVM:purgatory in the mode-line until the next
;; successful build.
;;
;; Built-in packages only; no keys of its own. Language modules call
;; `hellmacs-forge-setup-build-h' and run tests through
;; `hellmacs-forge-test-at-point' / `hellmacs-forge-test-class'.

(defgroup hellmacs-forge nil
  "Hellmacs' build integration."
  :group 'hellmacs)

(use-package compile
  :ensure nil
  :hook
  (compilation-filter . ansi-color-compilation-filter) ; render colors, don't show escape codes
  :custom
  (compilation-scroll-output 'first-error)  ; follow output, stop at the first error
  (compilation-always-kill t)               ; a new build replaces a running one
  (compilation-ask-about-save nil)          ; save modified buffers without asking
  (compilation-max-output-line-length nil)  ; don't elide long lines (stack traces)
  :config
  (hellmacs-forge--add-error-regexps)
  (add-hook 'compilation-start-hook #'hellmacs-forge--note-start-h)
  (add-hook 'compilation-finish-functions #'hellmacs-forge--report-h))
