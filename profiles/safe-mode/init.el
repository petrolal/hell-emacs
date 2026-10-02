;;; profiles/safe-mode/init.el --- Hell Emacs with no modules -*- lexical-binding: t; -*-

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

;; The safe-mode profile: Hell Emacs' core and its own module (the Altar,
;; the themed UX), and none of the others, nor your config.el. When
;; something in your config or a module breaks Emacs, start here and add
;; modules back one at a time to find it:
;;
;;   bin/hell --profile safe-mode sync
;;   emacs --init-directory ~/.config/emacs --profile safe-mode
;;
;; Like Doom v3's profiles/safe-mode/. Its packages, caches and history are
;; its own (~/.local/share/hell-emacs-safe-mode/, ...), never your config's.

;;; Code:

(hell!)

;;; init.el ends here
