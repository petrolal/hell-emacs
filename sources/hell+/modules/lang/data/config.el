;;; lang/data/config.el -*- lexical-binding: t; -*-

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


;; XML (pom.xml, Spring and Maven settings files, Android manifests,
;; Eclipse's .classpath and .launch), in built-in `nxml-mode', with
;; lemminx through lsp-mode: completion, hover and validation from the
;; schemas and DTDs the files name (it downloads them, through your proxy,
;; and caches them under Hell Emacs' cache directory), formatting, and
;; `C-c l' as in any lsp buffer. `bin/hell sync' installs the pinned
;; jar (+paths.el). No keys of its own.

(hell-module-load "+paths")

;; Set before lsp-xml loads (a defcustom keeps a value that's already set).
(setq lsp-xml-jar-file hell-xml-lemminx-jar
      lsp-xml-prefer-jar t
      lsp-xml-server-work-dir (expand-file-name "lemminx/" hell-cache-dir)
      lsp-xml-server-command #'hell-xml-server-command)

(defvar hell-xml-vmargs '("-Xmx256m")
  "JVM options for lemminx.")

(defun hell-xml-server-command ()
  "lemminx's command: the pinned jar, with your proxy and CA for the schemas it fetches."
  `(,(hell-xml-java) ,@hell-xml-vmargs ,@(hell-net-jvm-options)
    "-jar" ,hell-xml-lemminx-jar))

;; Installed with sync's installer, not lsp-mode's own, if it's missing.
(hell-lsp-pin-installer 'xmlls '(:lang . data) 'hell-xml-sync-install-server)

;; Maven's other XML files, and XSLT/XPath schemas.
(add-to-list 'auto-mode-alist '("\\.pom\\'" . nxml-mode))
(add-to-list 'auto-mode-alist '("/\\.classpath\\'" . nxml-mode))
(add-to-list 'auto-mode-alist '("\\.launch\\'" . nxml-mode))
(add-to-list 'auto-mode-alist '("\\.xslt?\\'" . nxml-mode))
(add-to-list 'auto-mode-alist '("\\.xpath\\'" . nxml-mode))

(add-hook! nxml-mode #'lsp-deferred)
