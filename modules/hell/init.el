;;; hell/init.el -*- lexical-binding: t; -*-

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

;; Core's own module, `:hell' (Doom v3's modules/doom/): what every
;; configuration gets, whatever its `hell!' block says. It's enabled
;; by `hell-modules-enable-core' and loads before every other module.
;; lisp/ is the engine; this is Hell Emacs' own features and packages.

;;; Code:

;; Hell Emacs' dotfiles (.hell-emacs, .hellmodule, .hellprofile) are Lisp
;; data, as Doom's are.
(add-to-list 'auto-mode-alist '("/\\.hell\\(?:-emacs\\|module\\|profile\\)\\'" . lisp-data-mode))

;; gcmh collects garbage while Emacs is idle (see "GC lifecycle" in
;; lisp/hell-core.el, which restores a bounded threshold after startup).
;; Emacs builds with the incremental GC (igc) don't need it.
(unless (fboundp 'igc-info)
  (setq gcmh-idle-delay 'auto              ; scale the delay with GC time...
        gcmh-auto-idle-delay-factor 10     ; ...collect after 10x the last GC's duration idle
        gcmh-high-cons-threshold (* 64 1024 1024))
  (add-hook 'hell-first-buffer-hook
            (defun hell--start-gcmh-h ()
              ;; Unless the user disabled it with (package! gcmh :disable t).
              (when (fboundp 'gcmh-mode)
                (gcmh-mode 1)))))

;; The Altar (the startup screen) and the themed prompts and errors.
(hell-module-load "+splash")
(hell-module-load "+ux")

;;; init.el ends here
