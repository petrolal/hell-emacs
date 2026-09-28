;;; lang/markdown/config.el -*- lexical-binding: t; -*-

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


;; Markdown (READMEs, docs, ADRs), in `markdown-mode' (`gfm-mode' for
;; GitHub-flavoured files), with marksman through lsp-mode: completion and
;; go to definition for links and headings across the project, broken-link
;; diagnostics, and a table of contents in `C-c l' symbols.
;; markdown-mode's own `C-c C-...' keys are its standard ones and stay; no
;; other keys.

(hellmacs-module-load "+paths")

;; Set before lsp-marksman loads (a defcustom keeps a value that's already
;; set): the pinned binary, found before anything on the PATH.
(setq lsp-marksman-server-command hellmacs-markdown-marksman-executable)

(hellmacs-lsp-pin-installer 'marksman '(:lang . markdown) 'hellmacs-markdown-sync-install-server)

(add-hook! (markdown-mode gfm-mode) #'lsp-deferred)
