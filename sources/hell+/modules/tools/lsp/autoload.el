;;; tools/lsp/autoload.el -*- lexical-binding: t; -*-

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


;;;###autoload
(defvar-local hell-lsp--added-dabbrev nil
  "Non-nil if `hell-lsp--setup-completion-h' added `cape-dabbrev' here.")

;;;###autoload
(defun hell-lsp--setup-completion-h ()
  "In a buffer with a language server, fall back to words from open buffers.
The server's completion comes first (lsp-mode puts it there), then the
buffer's own functions and file names (`:completion corfu'), then words
(`cape-dabbrev'); all of it shows in corfu. The server's function itself
is cache-busted once, globally (see config.el). Runs from
`lsp-completion-mode-hook', which also runs when the mode turns off:
then the fallback goes again, unless the buffer had it already."
  (cond ((not (fboundp 'cape-dabbrev)))
        ((bound-and-true-p lsp-completion-mode)
         (unless (memq #'cape-dabbrev completion-at-point-functions)
           (add-hook 'completion-at-point-functions #'cape-dabbrev 90 t)
           (setq hell-lsp--added-dabbrev t)))
        (hell-lsp--added-dabbrev
         (remove-hook 'completion-at-point-functions #'cape-dabbrev t)
         (setq hell-lsp--added-dabbrev nil))))

;;; Pinned server installs, when a file comes first --------------------------------
;;
;; `bin/hell sync' installs each language's server, pinned. Opening a
;; file before any sync makes lsp-mode offer its own installer instead,
;; which fetches unpinned, from anywhere; this routes it to the module's.

(declare-function hell-module--load "hell-modules")

;;;###autoload
(defun hell-lsp-install-pinned (module install callback error-callback)
  "Run MODULE's pinned server INSTALL (from its cli.el), then CALLBACK.
For lsp-mode's installers: ERROR-CALLBACK gets the message if it fails.
It blocks while it downloads; `bin/hell sync' does it ahead of time."
  (condition-case err
      (progn
        (hell-require 'hell-cli 'sync)
        (hell-module--load module "cli.el")
        (message "Installing the pinned server for %s %s (`bin/hell sync' does this ahead of time)..."
                 (car module) (cdr module))
        (with-hell-network (funcall install))
        (funcall callback))
    (error (funcall error-callback (error-message-string err)))))

(defvar hell-lsp--pinned-installers nil
  "lsp-mode dependency -> (MODULE . INSTALL), for `hell-lsp-pin-installer'.")

(defun hell-lsp--package-ensure-a (fn dependency callback error-callback)
  "Install DEPENDENCY with its module's pinned installer, if it has one."
  (if-let* ((pinned (alist-get dependency hell-lsp--pinned-installers)))
      (hell-lsp-install-pinned (car pinned) (cdr pinned) callback error-callback)
    (funcall fn dependency callback error-callback)))

;;;###autoload
(defun hell-lsp-pin-installer (dependency module install)
  "Install lsp-mode's DEPENDENCY (a server, like `clojure-lsp') with MODULE's INSTALL.
MODULE is a (GROUP . NAME) key; INSTALL, a function of its cli.el."
  (setf (alist-get dependency hell-lsp--pinned-installers) (cons module install))
  (advice-add 'lsp-package-ensure :around #'hell-lsp--package-ensure-a))
