;;; hell/+ux.el --- Thematic prompts and error reporting -*- lexical-binding: t; -*-

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

;; Hell Emacs' voice in Emacs' own prompts and error reports:
;;
;; - Quitting with unsaved buffers asks "Extinguish the forge and return
;;   to the void?": Emacs' own "Modified buffers exist; exit anyway?"
;;   (yes or no), in Hell Emacs' words. Only then, as in stock Emacs.
;; - Errors that reach the top level (an unhandled error in a command)
;;   are reported as "[CRITICAL FATALITY]: <message>" in inferno crimson,
;;   through `command-error-function'. `user-error's (routine "you
;;   can't do that here" messages) and quits (C-g) keep Emacs' plain
;;   reporting.
;; - JVM exceptions and stack traces in compilation buffers (Gradle,
;;   Maven) and REPLs are colored the same way, so a failure stands out
;;   of pages of build output.
;;
;; Only interactive sessions are affected; bin/hell output stays
;; plain. Set `hell-ux-enable' to nil in your init.el to keep
;; stock prompts and error reporting.

;;; Code:

(require 'cl-lib)

(defgroup hell-ux nil
  "Hell Emacs' thematic prompts and error reporting."
  :group 'hell)

(defcustom hell-ux-enable t
  "Whether to use Hell Emacs' prompts and error reporting.
Read when Hell Emacs starts; set it in your init.el."
  :type 'boolean)

(defface hell-fatality '((t (:inherit error :weight bold)))
  "Face for unhandled errors and JVM exceptions.
Follows the loaded theme's `error'; the Hell Emacs theme sets its own.")


;;; Quitting -------------------------------------------------------------------

(defconst hell-ux-kill-prompt "Extinguish the forge and return to the void? "
  "What Emacs asks before exiting with unsaved buffers.")

(defun hell-ux--kill-emacs-a (fn &rest args)
  "Around `save-buffers-kill-emacs' (FN with ARGS): its unsaved-buffers
question in Hell Emacs' words. Emacs asks it only when modified buffers
are left unsaved; nothing else changes."
  (let ((ask (symbol-function 'yes-or-no-p)))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (prompt)
                 (funcall ask (if (string-prefix-p "Modified buffers exist" prompt)
                                  hell-ux-kill-prompt
                                prompt)))))
      (apply fn args))))

;;; Unhandled errors -----------------------------------------------------------

(defun hell-ux--routine-error-p (data)
  "Non-nil if DATA is a routine signal, not a failure worth alarming about.
Quits, `user-error's (and errors built on it), and what Emacs itself
treats as routine in `debug-ignored-errors': the end of the buffer, a
read-only buffer, no mark, ..."
  (let ((conditions (get (car-safe data) 'error-conditions)))
    (or (eq (car-safe data) 'quit)
        (eq (car-safe data) 'minibuffer-quit)
        (memq 'quit conditions)
        (memq 'user-error conditions)
        (let ((message (condition-case nil
                           (error-message-string data)
                         ((error quit) nil))))
          (seq-some (lambda (ignored)
                      (if (stringp ignored)
                          (and message (string-match-p ignored message))
                        (memq ignored conditions)))
                    debug-ignored-errors)))))

(defun hell-ux-command-error (data context caller)
  "Report the unhandled error DATA as a [CRITICAL FATALITY].
For `command-error-function'; CONTEXT and CALLER are as there. Routine
signals (`hell-ux--routine-error-p') are passed to
`command-error-default-function'."
  (if (hell-ux--routine-error-p data)
      (command-error-default-function data context caller)
    (let ((text (propertize (concat "[CRITICAL FATALITY]: " (or context "")
                                    (error-message-string data))
                            'face 'hell-fatality)))
      (discard-input)
      (ding)
      ;; In the minibuffer, show it without wiping out the user's input.
      (if (minibufferp)
          (minibuffer-message text)
        (message "%s" text)))))

;;; JVM exceptions in build output and REPLs -----------------------------------

(defconst hell-ux-jvm-exception-regexp
  (rx line-start (* blank)
      (or (seq "Exception in thread \"" (* (not (any "\"\n"))) "\"")
          "Caused by:"
          (seq (+ (any "a-zA-Z0-9_$")) (* "." (+ (any "a-zA-Z0-9_$")))
               (or "Exception" "Error") ":")
          (seq "Execution error" (* nonl))
          (seq "Syntax error" (* nonl) "compiling")
          "BUILD FAILED"                ; Gradle
          "BUILD FAILURE")              ; Maven
      (* nonl))
  "Lines that start a JVM exception report: Java's \"Exception in thread\",
\"Caused by:\", \"java.lang.FooException: ...\", Clojure's \"Execution
error\" / \"Syntax error ... compiling\", and Gradle/Maven build failures.")

(defconst hell-ux-jvm-frame-regexp
  (rx line-start (+ blank) "at " (+ (not (any "(\n"))) "(" (* (not (any ")\n"))) ")")
  "A stack frame line: \"\\tat com.example.Foo.bar(Foo.java:42)\".")

(defun hell-ux--highlight-jvm-exceptions-h ()
  "Color JVM exceptions and their stack frames in the current buffer."
  (font-lock-add-keywords
   nil
   `((,hell-ux-jvm-exception-regexp 0 'hell-fatality prepend)
     (,hell-ux-jvm-frame-regexp 0 'font-lock-comment-face prepend))
   'append))

(defvar hell-ux-jvm-output-hooks
  '(compilation-mode-hook compilation-shell-minor-mode-hook)
  "Hooks of modes whose output may contain JVM stack traces.
Builds, and comint buffers running one (:tools run's, with
`compilation-shell-minor-mode'); not every shell or SQLi buffer.
Language modules add their REPLs' (`:lang clojure' adds CIDER's).")

;;; Activation -----------------------------------------------------------------

(defun hell-ux-activate ()
  "Turn on Hell Emacs' prompts and error reporting, unless disabled."
  (when (and hell-ux-enable (not noninteractive))
    (advice-add 'save-buffers-kill-emacs :around #'hell-ux--kill-emacs-a)
    (setq command-error-function #'hell-ux-command-error)
    (dolist (hook hell-ux-jvm-output-hooks)
      (add-hook hook #'hell-ux--highlight-jvm-exceptions-h))))

;; After the user's init.el, where `hell-ux-enable' can be set.
(add-hook 'hell-after-init-hook #'hell-ux-activate)

(provide 'hell-ux)
;;; +ux.el ends here
