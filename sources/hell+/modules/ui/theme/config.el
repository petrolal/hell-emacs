;;; ui/theme/config.el -*- lexical-binding: t; -*-

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

;; Visual defaults only: theme, mode-line, line numbers. The cursor is
;; Emacs' own block.
;;
;; The theme is Hell Emacs' own (themes/hell-inferno-theme.el, in this module):
;; a charcoal altar, crimson flame, amber and gold, with no
;; dependencies. Set `hell-theme' in your init.el to use another one
;; -- e.g. `modus-vivendi', built into Emacs -- or nil to load none.

(defvar hell-theme 'hell-inferno
  "Theme loaded at startup by the `:ui theme' module, or nil for none.")

(add-to-list 'custom-theme-load-path
             (expand-file-name "themes/" (hell-module-get hell--current-module :path)))

(column-number-mode 1)
(size-indication-mode 1)
;; Line numbers only where they're actually useful for navigation.
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; The current line is highlighted where you edit (`bg-alt' in the
;; Hell Emacs theme).
(add-hook 'prog-mode-hook #'hl-line-mode)
(add-hook 'text-mode-hook #'hl-line-mode)

(when hell-theme
  ;; Themes stack; start from none, so no other theme's faces show
  ;; through where this one leaves a face unset.
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme hell-theme :no-confirm))
