;;; test-debugger.el --- Tests for the :tools debugger module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. Real debugging sessions against java-debug
;; are checked by the Phase 6.5 probes (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'hellmacs-keybinds)
(require 'hellmacs-modules)

(defvar dap-java-hot-reload)
(defvar hellmacs-jvm-java-debug-jar)
(defvar hellmacs-jvm--sent-requests)
(defvar hellmacs-debug--swap-pending)

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:config default :tools debugger))
  (hellmacs-module--load '(:config . default) "autoload.el") ; `hellmacs-crucible-reload'
  (hellmacs-module--load '(:tools . debugger) "autoload.el")
  (hellmacs-module--load '(:tools . debugger) "config.el"))

(ert-deftest test-debugger/keys ()
  (dolist (spec '(("C-c d d" . dap-debug) ("C-c d b" . dap-breakpoint-toggle)
                  ("C-c d B" . dap-breakpoint-condition) ("C-c d L" . dap-breakpoint-log-message)
                  ("C-c d n" . hellmacs-debug-next) ("C-c d i" . hellmacs-debug-step-in)
                  ("C-c d o" . hellmacs-debug-step-out) ("C-c d c" . hellmacs-debug-continue)
                  ("C-c d e" . dap-eval-thing-at-point) ("C-c d q" . dap-disconnect)
                  ("C-c d t" . hellmacs-debug-test-at-point) ("C-c d T" . hellmacs-debug-test-class)))
    (should (eq (keymap-lookup global-map (car spec)) (cdr spec)))))

(ert-deftest test-debugger/stepping-repeats-with-plain-keys ()
  "After `C-c d n', plain n/i/o/c step until another key; no global repeat-mode."
  (let (called (overriding-terminal-local-map nil))
    (cl-letf (((symbol-function 'dap-next) (lambda (&rest _) (interactive) (push 'next called))))
      (hellmacs-debug-next)
      (should (equal called '(next)))
      (should (keymapp overriding-terminal-local-map))
      (should (eq (keymap-lookup overriding-terminal-local-map "n") 'hellmacs-debug-next))
      (should (eq (keymap-lookup overriding-terminal-local-map "c") 'hellmacs-debug-continue)))
    (should-not (bound-and-true-p repeat-mode))))

(ert-deftest test-debugger/hot-swap ()
  "Saves; unless dap-java does it, asks for the redefinition once java-debug
reports the compile done (its hotcodereplace event), not after a guess."
  (let ((sent nil) (saved 0) (hellmacs-debug--swap-pending nil))
    (cl-letf (((symbol-function 'dap--cur-session) (lambda () 'session))
              ((symbol-function 'dap--session-running) (lambda (_) t))
              ((symbol-function 'save-buffer) (lambda (&rest _) (cl-incf saved)))
              ((symbol-function 'dap--make-request) (lambda (name &rest _) name))
              ((symbol-function 'dap--send-message) (lambda (msg &rest _) (push msg sent))))
      (let ((dap-java-hot-reload 'always))
        (hellmacs-debug-hot-swap)
        (should (= saved 1))
        (hellmacs-debug--compiled-h 'session)
        (should-not sent))
      (let ((dap-java-hot-reload 'never))
        (hellmacs-debug-hot-swap)
        (should (= saved 2))
        (should-not sent)                 ; not before the compile is done
        (hellmacs-debug--compiled-h 'other-session)
        (should-not sent)
        (hellmacs-debug--compiled-h 'session)
        (should (equal sent '("redefineClasses")))
        ;; Once per save.
        (hellmacs-debug--compiled-h 'session)
        (should (equal sent '("redefineClasses")))))
    (cl-letf (((symbol-function 'dap--cur-session) #'ignore))
      (should-error (hellmacs-debug-hot-swap) :type 'user-error))))

(ert-deftest test-debugger/hot-swap-skips-an-ended-session ()
  "The redefinition isn't sent to a session that ended while JDTLS compiled."
  (let ((sent nil) (running t) (hellmacs-debug--swap-pending nil))
    (cl-letf (((symbol-function 'dap--cur-session) (lambda () 'session))
              ((symbol-function 'dap--session-running) (lambda (_) running))
              ((symbol-function 'save-buffer) #'ignore)
              ((symbol-function 'dap--make-request) (lambda (name &rest _) name))
              ((symbol-function 'dap--send-message) (lambda (msg &rest _) (push msg sent))))
      (let ((dap-java-hot-reload 'never))
        (hellmacs-debug-hot-swap)
        (setq running nil)
        (hellmacs-debug--compiled-h 'session)
        (should-not sent)))))

(ert-deftest test-debugger/crucible-calls-the-buffer-reload-function ()
  "`C-c h r' does what the buffer's language set, and says so when it set nothing."
  (with-temp-buffer
    (should-error (hellmacs-crucible-reload) :type 'user-error)
    (let (called)
      (setq-local hellmacs-reload-function (lambda () (setq called t)))
      (hellmacs-crucible-reload)
      (should called))))

(ert-deftest test-debugger/java-debug-pin ()
  "The java-debug bundle is replaced only by a download matching the pin."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :tools debugger :lang java))
    (hellmacs-module--load '(:lang . java) "cli.el"))
  (let* ((dir (make-temp-file "hellmacs-test-dbg" t))
         (jar (expand-file-name "bundles/java.debug.plugin.jar" dir))
         (hellmacs-jvm-java-debug-jar jar))
    (unwind-protect
        (progn
          (make-directory (file-name-directory jar) t)
          (with-temp-file jar (insert "old bundle"))
          (should-not (hellmacs-jvm-java-debug-jar-valid-p))
          (cl-letf (((symbol-function 'hellmacs-net-download)
                     (lambda (_u f &rest _) (with-temp-file f (insert "new bundle"))))
                    ((symbol-function 'hellmacs-sync--log) #'ignore))
            ;; Wrong checksum: the old bundle stays, nothing left over.
            (let ((hellmacs-jvm-java-debug-sha256 "0000"))
              (should-error (hellmacs-jvm-sync-install-java-debug))
              (with-temp-buffer (insert-file-contents jar) (should (equal (buffer-string) "old bundle")))
              (should-not (file-exists-p (concat jar ".part"))))
            ;; Matching checksum: replaced, then left alone.
            (let ((hellmacs-jvm-java-debug-sha256 (secure-hash 'sha256 "new bundle")))
              (hellmacs-jvm-sync-install-java-debug)
              (should (hellmacs-jvm-java-debug-jar-valid-p))
              (cl-letf (((symbol-function 'hellmacs-net-download) (lambda (&rest _) (error "Shouldn't download"))))
                (hellmacs-jvm-sync-install-java-debug)))))
      (delete-directory dir t))))

(provide 'test-debugger)
;;; test-debugger.el ends here
