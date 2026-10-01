;;; tools/projectile/config.el -*- lexical-binding: t; -*-

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

;; Project management via Projectile and consult-projectile.
;; Interoperates seamlessly with built-in project.el.

(use-package projectile
  :defer 1
  :init
  (setq projectile-cache-file (expand-file-name "projectile.cache" hellmacs-cache-dir)
        projectile-known-projects-file (expand-file-name "projectile-bookmarks.eld" hellmacs-state-dir)
        projectile-enable-caching t
        projectile-sort-order 'recentf)
  :config
  (projectile-mode 1))

(use-package consult-projectile
  :after (projectile consult)
  :bind
  (("C-c p p" . consult-projectile-switch-project)
   ("C-c p f" . consult-projectile-find-file)
   ("C-c p b" . consult-projectile-switch-to-buffer)
   ("C-c p d" . consult-projectile-find-dir)
   ("C-c p s" . consult-projectile-ripgrep)))
