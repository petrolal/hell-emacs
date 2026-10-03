;;; editor/parinfer/config.el -*- lexical-binding: t; -*-

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
;; Indentation-driven Lisp editing via parinfer-rust-mode.

;;; Code:

(defvar parinfer-rust-auto-download)
(declare-function parinfer-rust-mode "parinfer-rust-mode" (&optional arg))

(use-package parinfer-rust-mode
  :defer t
  :hook ((clojure-mode . parinfer-rust-mode)
         (emacs-lisp-mode . parinfer-rust-mode)
         (lisp-mode . parinfer-rust-mode)
         (scheme-mode . parinfer-rust-mode))
  :init
  (setq parinfer-rust-auto-download t))

(provide 'editor-parinfer-config)
;;; config.el ends here
