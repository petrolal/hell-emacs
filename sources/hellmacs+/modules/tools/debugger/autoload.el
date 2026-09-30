;;; tools/debugger/autoload.el -*- lexical-binding: t; -*-

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


(declare-function dap-next "ext:dap-mode")
(declare-function dap-step-in "ext:dap-mode")
(declare-function dap-step-out "ext:dap-mode")
(declare-function dap-continue "ext:dap-mode")
(declare-function dap--cur-session "ext:dap-mode")
(declare-function dap--send-message "ext:dap-mode")
(declare-function dap--session-running "ext:dap-mode")
(declare-function dap--make-request "ext:dap-mode")
(declare-function dap-java-debug-test-method "ext:dap-java")
(declare-function dap-java-debug-test-class "ext:dap-java")
(defvar hellmacs-debug-step-map)
(defvar dap-java-hot-reload)

;;; Stepping, repeatable -------------------------------------------------------

(defun hellmacs-debug--keep-stepping ()
  "Let plain n/i/o/c keep stepping until another key is pressed.
A transient map, so Emacs' global `repeat-mode' (which would also change
built-in keys like `C-x o') stays off."
  (set-transient-map hellmacs-debug-step-map t nil
                     "Keep stepping: [n]ext [i]n [o]ut [c]ontinue, any other key to stop"))

;;;###autoload
(defun hellmacs-debug-next ()
  "Step over, then keep stepping with n/i/o/c."
  (interactive)
  (call-interactively #'dap-next)
  (hellmacs-debug--keep-stepping))

;;;###autoload
(defun hellmacs-debug-step-in ()
  "Step in, then keep stepping with n/i/o/c."
  (interactive)
  (call-interactively #'dap-step-in)
  (hellmacs-debug--keep-stepping))

;;;###autoload
(defun hellmacs-debug-step-out ()
  "Step out, then keep stepping with n/i/o/c."
  (interactive)
  (call-interactively #'dap-step-out)
  (hellmacs-debug--keep-stepping))

;;;###autoload
(defun hellmacs-debug-continue ()
  "Continue, then keep stepping with n/i/o/c."
  (interactive)
  (call-interactively #'dap-continue)
  (hellmacs-debug--keep-stepping))

;;; Tests, per language ----------------------------------------------------------

;;;###autoload
(defun hellmacs-debug-test-at-point ()
  "Debug the test method at point (stops at your breakpoints in it)."
  (interactive)
  (cond ((derived-mode-p 'java-mode 'java-ts-mode)
         (require 'dap-java)
         (call-interactively #'dap-java-debug-test-method))
        (t (user-error "No test debugging for %s" major-mode))))

;;;###autoload
(defun hellmacs-debug-test-class ()
  "Debug every test in the current class."
  (interactive)
  (cond ((derived-mode-p 'java-mode 'java-ts-mode)
         (require 'dap-java)
         (call-interactively #'dap-java-debug-test-class))
        (t (user-error "No test debugging for %s" major-mode))))

;;; Hot code replace -------------------------------------------------------------

(defvar hellmacs-debug--swap-pending nil
  "The debug session whose changed classes to redefine once JDTLS compiled them.")

;;;###autoload
(defun hellmacs-debug-hot-swap ()
  "Save the buffer so the debugged JVM picks up the change.
JDTLS recompiles on save and java-debug then reports the changed
classes; dap-java redefines them in the running JVM when
`dap-java-hot-reload' is `always' (the default). Otherwise this asks
for the redefinition itself, once java-debug says the compile is done
\(`hellmacs-debug--compiled-h')."
  (interactive)
  (let ((session (or (dap--cur-session) (user-error "No debug session"))))
    (save-buffer)
    (if (eq (bound-and-true-p dap-java-hot-reload) 'always)
        (message "Saved; the JVM swaps in the changed classes once JDTLS has compiled them")
      (setq hellmacs-debug--swap-pending session)
      (message "Saved; hot-swapping the changed classes once JDTLS has compiled them..."))))

;;;###autoload
(defun hellmacs-debug--compiled-h (session)
  "java-debug says SESSION's classes are compiled: redefine them if a save asked.
Run from its `hotcodereplace' event."
  (when (and hellmacs-debug--swap-pending (eq session hellmacs-debug--swap-pending))
    (setq hellmacs-debug--swap-pending nil)
    ;; The session may have ended while JDTLS compiled.
    (when (dap--session-running session)
      (dap--send-message
       (dap--make-request "redefineClasses")
       (lambda (result)
         (message "Hot-swapped: %s" (or (gethash "changedClasses" result) "nothing changed")))
       session))))
