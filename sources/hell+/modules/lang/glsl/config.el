;;; lang/glsl/config.el -*- lexical-binding: t; -*-

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
;; GLSL (OpenGL shading language) editing and language server
;; integration. `lsp-mode' ships its GLSL client out of the box
;; (`lsp-glsl', activating on `glsl-mode') and talks to `glslls'
;; (https://github.com/svenstaro/glsl-language-server); no custom
;; client is needed here.

;;; Code:

(use-package glsl-mode
  :mode ("\\.glsl\\'"
         "\\.vert\\'"
         "\\.frag\\'"
         "\\.geom\\'"
         "\\.tesc\\'"
         "\\.tese\\'"
         "\\.comp\\'")
  :config
  (add-hook 'glsl-mode-hook #'lsp-deferred))

(defun hell-glsl-validate ()
  "Validate the current shader with glslangValidator."
  (interactive)
  (compile (format "glslangValidator %s" (shell-quote-argument (buffer-file-name)))))

(defun hell-glsl-compile-spirv ()
  "Compile the current shader to SPIR-V with glslc."
  (interactive)
  (compile (format "glslc %s -o %s.spv"
                    (shell-quote-argument (buffer-file-name))
                    (shell-quote-argument (file-name-nondirectory (buffer-file-name))))))

(hell-localleader-def 'glsl-mode
  "v" '("validate shader" . hell-glsl-validate)
  "c" '("compile to SPIR-V" . hell-glsl-compile-spirv))

(provide 'lang-glsl-config)
;;; config.el ends here
