;;; editor/fold/config.el -*- lexical-binding: t; -*-

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

;;; Code:

(defvar hs-minor-mode-map)
(defvar treesit-fold-mode-map)
(declare-function treesit-fold-mode "treesit-fold" (&optional arg))

;; Built-in hideshow (hs-minor-mode) is enabled for programming modes as
;; the foundational folding mechanism across all languages.
(add-hook 'prog-mode-hook #'hs-minor-mode)

;; Tree-sitter AST-aware folding when treesit is available.
(use-package treesit-fold
  :defer t
  :init
  (when (and (fboundp 'treesit-available-p) (treesit-available-p))
    (add-hook 'prog-mode-hook
              (lambda ()
                (when (and (fboundp 'treesit-parser-list)
                           (treesit-parser-list))
                  (treesit-fold-mode 1))))))

;; Remaps, not the stock `C-c @' keys themselves (13.5): whichever key
;; the user (or another package) has hs-toggle-hiding/hs-show-all/
;; hs-hide-all on also reaches these.
(with-eval-after-load 'hideshow
  (keymap-set hs-minor-mode-map "<remap> <hs-toggle-hiding>" #'hell-fold-toggle)
  (keymap-set hs-minor-mode-map "<remap> <hs-show-all>" #'hell-fold-open-all)
  (keymap-set hs-minor-mode-map "<remap> <hs-hide-all>" #'hell-fold-close-all))

(with-eval-after-load 'treesit-fold
  (keymap-set treesit-fold-mode-map "C-c @ C-c" #'hell-fold-toggle)
  (keymap-set treesit-fold-mode-map "C-c @ C-a" #'hell-fold-open-all)
  (keymap-set treesit-fold-mode-map "C-c @ C-t" #'hell-fold-close-all))
