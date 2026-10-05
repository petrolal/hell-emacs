;;; lang/plantuml/config.el -*- lexical-binding: t; -*-

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
;; PlantUML diagramming text-based DSL support.

;;; Code:

(use-package plantuml-mode
  :mode ("\\.\(?:puml\\|plantuml\)\\'" . plantuml-mode))

(defun hell-plantuml-preview ()
  "Preview the current PlantUML diagram at point."
  (interactive)
  (if (fboundp 'plantuml-preview) (plantuml-preview nil) (compile "plantuml")))

(defun hell-plantuml-preview-buffer ()
  "Preview the current PlantUML buffer."
  (interactive)
  (if (fboundp 'plantuml-preview-current-buffer)
      (plantuml-preview-current-buffer)
    (compile "plantuml")))

(hell-localleader-def 'plantuml-mode
  "p" '("preview diagram" . hell-plantuml-preview)
  "b" '("preview buffer" . hell-plantuml-preview-buffer))

(provide 'lang-plantuml-config)
;;; config.el ends here
