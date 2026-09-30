;;; tools/debugger/config.el -*- lexical-binding: t; -*-

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


;; Debugging through the Debug Adapter Protocol (dap-mode): launch or
;; attach, breakpoints (conditional, log points), stepping, locals,
;; watches and a REPL. Language modules provide the adapter: `:lang
;; java' uses Microsoft's java-debug (dap-java), installed with JDTLS.
;;
;; Owns `C-c d':
;;   d start (pick a template)  D restart the last one
;;   b toggle breakpoint        B condition   L log message   x delete all
;;   n next  i step in  o step out  c continue -- after one of these,
;;     plain n/i/o/c keep stepping (C-c d n n n) until another key
;;   e evaluate at point        E evaluate an expression
;;   r restart session          q disconnect
;;   t debug the test at point  T debug the test class
;; `C-c h r' saves and hot-swaps the changed code into the session.
;;
;; The session windows (sessions, locals, breakpoints, expressions,
;; REPL) open when a session starts. The mouse-driven controls and
;; tooltips stay off: they need a graphical frame and posframe.

(use-package dap-mode
  :commands (dap-debug dap-debug-last dap-breakpoint-toggle)
  :custom
  (dap-auto-configure-features '(sessions locals breakpoints expressions repl))
  (dap-breakpoints-file (hellmacs-state-file "dap-breakpoints"))
  :config
  (dap-auto-configure-mode 1))

;; `C-c h r' with `dap-java-hot-reload' other than `always': redefine the
;; changed classes when java-debug says JDTLS has compiled them.
(with-eval-after-load 'dap-java
  (cl-defmethod dap-handle-event :after ((_event (eql 'hotcodereplace)) session _params)
    (hellmacs-debug--compiled-h session)))

(defvar-keymap hellmacs-debug-step-map
  :doc "Keys that keep stepping after `C-c d n/i/o/c'."
  "n" #'hellmacs-debug-next
  "i" #'hellmacs-debug-step-in
  "o" #'hellmacs-debug-step-out
  "c" #'hellmacs-debug-continue)

(hellmacs-leader-def
  "d"   "debug"
  "d d" '("start (pick a template)" . dap-debug)
  "d D" '("start last again" . dap-debug-last)
  "d b" '("toggle breakpoint" . dap-breakpoint-toggle)
  "d B" '("breakpoint condition" . dap-breakpoint-condition)
  "d L" '("breakpoint log message" . dap-breakpoint-log-message)
  "d x" '("delete all breakpoints" . dap-breakpoint-delete-all)
  "d n" '("next" . hellmacs-debug-next)
  "d i" '("step in" . hellmacs-debug-step-in)
  "d o" '("step out" . hellmacs-debug-step-out)
  "d c" '("continue" . hellmacs-debug-continue)
  "d e" '("evaluate at point" . dap-eval-thing-at-point)
  "d E" '("evaluate expression" . dap-eval)
  "d r" '("restart session" . dap-debug-restart)
  "d q" '("disconnect" . dap-disconnect)
  "d t" '("debug test at point" . hellmacs-debug-test-at-point)
  "d T" '("debug test class" . hellmacs-debug-test-class))
