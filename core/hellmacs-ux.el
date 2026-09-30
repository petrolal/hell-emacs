;;; hellmacs-ux.el --- Thematic prompts and error reporting -*- lexical-binding: t; -*-

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

;; Hellmacs' voice in Emacs' own prompts and error reports:
;;
;; - Quitting asks "Extinguish the forge and return to the void?"
;;   (`confirm-kill-emacs'). Same y/n question as before, new words.
;; - Errors that reach the top level (an unhandled error in a command)
;;   are reported as "[CRITICAL FATALITY]: <message>" in inferno crimson,
;;   through `command-error-function'. `user-error's (routine "you
;;   can't do that here" messages) and quits (C-g) keep Emacs' plain
;;   reporting.
;; - JVM exceptions and stack traces in compilation buffers (Gradle,
;;   Maven) and REPLs are colored the same way, so a failure stands out
;;   of pages of build output.
;;
;; Only interactive sessions are affected; bin/hellmacs output stays
;; plain. Set `hellmacs-ux-enable' to nil in your init.el to keep
;; stock prompts and error reporting.

;;; Code:

(defgroup hellmacs-ux nil
  "Hellmacs' thematic prompts and error reporting."
  :group 'hellmacs)

(defcustom hellmacs-ux-enable t
  "Whether to use Hellmacs' prompts and error reporting.
Read when Hellmacs starts; set it in your init.el."
  :type 'boolean)

(defface hellmacs-fatality '((t (:inherit error :weight bold)))
  "Face for unhandled errors and JVM exceptions.
Follows the loaded theme's `error'; the Hellmacs theme sets its own.")

;;; Quitting ---------------------------------------------------------------

(defconst hellmacs-ux-kill-prompt "Extinguish the forge and return to the void? "
  "Question asked before Emacs exits.")

(defun hellmacs-ux-confirm-kill-emacs (_prompt)
  "Ask whether to exit Emacs, in Hellmacs' words. For `confirm-kill-emacs'."
  (y-or-n-p hellmacs-ux-kill-prompt))

;;; Unhandled errors -----------------------------------------------------------

(defun hellmacs-ux--routine-error-p (data)
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

(defun hellmacs-ux-command-error (data context caller)
  "Report the unhandled error DATA as a [CRITICAL FATALITY].
For `command-error-function'; CONTEXT and CALLER are as there. Routine
signals (`hellmacs-ux--routine-error-p') are passed to
`command-error-default-function'."
  (if (hellmacs-ux--routine-error-p data)
      (command-error-default-function data context caller)
    (let ((text (propertize (concat "[CRITICAL FATALITY]: " (or context "")
                                    (error-message-string data))
                            'face 'hellmacs-fatality)))
      (discard-input)
      (ding)
      ;; In the minibuffer, show it without wiping out the user's input.
      (if (minibufferp)
          (minibuffer-message text)
        (message "%s" text)))))

;;; JVM exceptions in build output and REPLs -----------------------------------

(defconst hellmacs-ux-jvm-exception-regexp
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

(defconst hellmacs-ux-jvm-frame-regexp
  (rx line-start (+ blank) "at " (+ (not (any "(\n"))) "(" (* (not (any ")\n"))) ")")
  "A stack frame line: \"\\tat com.example.Foo.bar(Foo.java:42)\".")

(defun hellmacs-ux--highlight-jvm-exceptions-h ()
  "Color JVM exceptions and their stack frames in the current buffer."
  (font-lock-add-keywords
   nil
   `((,hellmacs-ux-jvm-exception-regexp 0 'hellmacs-fatality prepend)
     (,hellmacs-ux-jvm-frame-regexp 0 'font-lock-comment-face prepend))
   'append))

(defvar hellmacs-ux-jvm-output-hooks
  '(compilation-mode-hook compilation-shell-minor-mode-hook)
  "Hooks of modes whose output may contain JVM stack traces.
Builds, and comint buffers running one (:tools run's, with
`compilation-shell-minor-mode'); not every shell or SQLi buffer.
Language modules add their REPLs' (`:lang clojure' adds CIDER's).")

;;; Activation -----------------------------------------------------------------

(defun hellmacs-ux-activate ()
  "Turn on Hellmacs' prompts and error reporting, unless disabled."
  (when (and hellmacs-ux-enable (not noninteractive))
    ;; Over Hellmacs' own default (hellmacs-core.el) only, not yours.
    (when (eq confirm-kill-emacs #'y-or-n-p)
      (setq confirm-kill-emacs #'hellmacs-ux-confirm-kill-emacs))
    (setq command-error-function #'hellmacs-ux-command-error)
    (dolist (hook hellmacs-ux-jvm-output-hooks)
      (add-hook hook #'hellmacs-ux--highlight-jvm-exceptions-h))))

;; After the user's init.el, where `hellmacs-ux-enable' can be set.
(add-hook 'hellmacs-after-init-hook #'hellmacs-ux-activate)

(provide 'hellmacs-ux)
;;; hellmacs-ux.el ends here
