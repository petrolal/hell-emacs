;;; lang/erlang/config.el -*- lexical-binding: t; -*-

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
;; Erlang/OTP concurrent platform support.

;;; Code:

(use-package erlang
  :mode ("\\.[he]rl\\'" . erlang-mode)
  :config
  (add-hook 'erlang-mode-hook #'lsp-deferred))

(defun hell-erlang-compile ()
  "Compile the current rebar3 project."
  (interactive)
  (compile "rebar3 compile"))

(defun hell-erlang-eunit ()
  "Run the current rebar3 project's EUnit tests."
  (interactive)
  (compile "rebar3 eunit"))

(defun hell-erlang-shell ()
  "Start a rebar3 shell for the current project."
  (interactive)
  (compile "rebar3 shell"))

(hell-localleader-def 'erlang-mode
  "b" '("rebar3 compile" . hell-erlang-compile)
  "t" '("rebar3 eunit" . hell-erlang-eunit)
  "r" '("rebar3 shell" . hell-erlang-shell))

(provide 'lang-erlang-config)
;;; config.el ends here
