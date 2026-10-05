;;; lang/agda/config.el -*- lexical-binding: t; -*-

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
;; Agda 2 support with agda2-mode.

;;; Code:

(use-package agda2-mode
  :mode ("\\.l?agda\\(?:\\.md\\)?\\'" . agda2-mode))

(defun hell-agda-load ()
  "Load and typecheck the current Agda buffer."
  (interactive)
  (if (fboundp 'agda2-load) (agda2-load) (compile "agda")))

(defun hell-agda-compile ()
  "Compile the current Agda buffer."
  (interactive)
  (if (fboundp 'agda2-compile) (agda2-compile) (compile "agda -c")))

(defun hell-agda-quit ()
  "Quit the running Agda process."
  (interactive)
  (when (fboundp 'agda2-quit) (agda2-quit)))

(hell-localleader-def 'agda2-mode
  "l" '("load/typecheck" . hell-agda-load)
  "c" '("compile" . hell-agda-compile)
  "q" '("quit agda" . hell-agda-quit))

(provide 'lang-agda-config)
;;; config.el ends here
