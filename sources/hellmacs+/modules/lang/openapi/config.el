;;; lang/openapi/config.el -*- lexical-binding: t; -*-

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

;; OpenAPI and Swagger specifications support in YAML and JSON.

(defun hellmacs-openapi-file-p (filename)
  "Return non-nil if FILENAME matches an OpenAPI / Swagger definition."
  (and (stringp filename)
       (string-match-p "\\(openapi\\|swagger\\).*\\.\\(yaml\\|yml\\|json\\)\\'" (file-name-nondirectory filename))))

(defun hellmacs-openapi--setup-h ()
  "Enable LSP in OpenAPI/Swagger buffers."
  (when (and buffer-file-name (hellmacs-openapi-file-p buffer-file-name))
    (lsp-deferred)))

(add-hook 'yaml-mode-hook #'hellmacs-openapi--setup-h)
(add-hook 'json-mode-hook #'hellmacs-openapi--setup-h)
(when (fboundp 'yaml-ts-mode)
  (add-hook 'yaml-ts-mode-hook #'hellmacs-openapi--setup-h))
(when (fboundp 'json-ts-mode)
  (add-hook 'json-ts-mode-hook #'hellmacs-openapi--setup-h))
