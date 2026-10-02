;;; tools/http/config.el -*- lexical-binding: t; -*-

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


;; IntelliJ's HTTP Client files (.http, .rest), sent with restclient
;; (autoload.el). Flags:
;;   +httpyac  run requests and whole files with their JavaScript response
;;             handlers, through httpyac (needs Node; pinned by lockfile)
;;
;; Keys in .http buffers (the mode's own, as major modes have them):
;;   C-c C-c  send the request at point      C-c C-e  choose an environment
;;   C-c M-e  reload the environment         C-c C-l  run it with httpyac
;;   C-c C-a  run the whole file with httpyac
;; plus restclient's own (C-c C-n / C-c C-p between requests, C-c C-u copy
;; as curl...). No global keys.

(add-to-list 'auto-mode-alist '("\\.\\(?:http\\|rest\\)\\'" . hell-http-mode))

(setq hell-http--httpyac (modulep! +httpyac))

(after! restclient
  (advice-add 'restclient-find-vars-before-point :filter-return #'hell-http--add-dynamic-vars-a))
