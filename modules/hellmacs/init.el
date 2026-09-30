;;; hellmacs/init.el -*- lexical-binding: t; -*-

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

;; Core's own module, `:hellmacs' (Doom v3's modules/doom/): what every
;; configuration gets, whatever its `hellmacs!' block says. It's enabled
;; by `hellmacs-modules-enable-core' and loads before every other module.
;; lisp/ is the engine; this is Hellmacs' own features and packages.

;;; Code:

;; gcmh collects garbage while Emacs is idle (see "GC lifecycle" in
;; lisp/hellmacs.el, which restores a bounded threshold after startup).
;; Emacs builds with the incremental GC (igc) don't need it.
(unless (fboundp 'igc-info)
  (setq gcmh-idle-delay 'auto              ; scale the delay with GC time...
        gcmh-auto-idle-delay-factor 10     ; ...collect after 10x the last GC's duration idle
        gcmh-high-cons-threshold (* 64 1024 1024))
  (add-hook 'hellmacs-first-buffer-hook
            (defun hellmacs--start-gcmh-h ()
              ;; Unless the user disabled it with (package! gcmh :disable t).
              (when (fboundp 'gcmh-mode)
                (gcmh-mode 1)))))

;; The Altar (the startup screen) and the themed prompts and errors.
(hellmacs-module-load "+splash")
(hellmacs-module-load "+ux")

;;; init.el ends here
