;;; lang/haskell/doctor.el -*- lexical-binding: t; -*-

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

;; Checked by `bin/hell doctor'.
(if-let* ((ghc (executable-find "ghc")))
    (hell-doctor-ok "GHC compiler: %s" (abbreviate-file-name ghc))
  (hell-doctor-info "ghc not found in PATH"))

(if-let* ((build (or (executable-find "cabal") (executable-find "stack"))))
    (hell-doctor-ok "Haskell build tool: %s" (abbreviate-file-name build))
  (hell-doctor-info "cabal or stack not found in PATH"))

(if-let* ((lsp (or (executable-find "haskell-language-server-wrapper") (executable-find "haskell-language-server"))))
    (hell-doctor-ok "Haskell language server: %s" (abbreviate-file-name lsp))
  (hell-doctor-info "haskell-language-server not found in PATH"))
