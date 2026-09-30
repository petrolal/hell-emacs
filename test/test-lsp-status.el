;;; test-lsp-status.el --- Tests for lisp/hellmacs-lsp-status.el -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. lsp-mode isn't loaded here: workspaces
;; are plain symbols, and the two functions that read one are stubbed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-ux)                  ; `hellmacs-ux-enable', bound below
(hellmacs-require 'hellmacs-lib 'lsp-status)

(defvar lsp--cur-workspace)             ; lsp-mode's; bound below
(defvar lsp--buffer-workspaces)

(defmacro test-lsp-status--with (servers &rest body)
  "Run BODY with fresh sessions, only SERVERS registered, and workspaces stubbed.
SERVERS is a list of (SERVER . PROPS). A workspace is a symbol whose
`test-server' and `test-root' properties say its server and root.
Messages shown are pushed onto `shown', newest first."
  (declare (indent 1))
  `(let ((hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-lsp-status--servers nil)
         (hellmacs-ux-enable t)
         (shown nil))
     (dolist (server ,servers)
       (apply #'hellmacs-lsp-status-register server))
     (cl-letf (((symbol-function 'hellmacs-lsp-status--server)
                (lambda (ws) (let ((id (get ws 'test-server)))
                               (and (assq id hellmacs-lsp-status--servers) id))))
               ((symbol-function 'hellmacs-lsp-status--root)
                (lambda (ws) (get ws 'test-root)))
               ((symbol-function 'message)
                (lambda (fmt &rest args) (push (apply #'format fmt args) shown))))
       ,@body)))

(defun test-lsp-status--workspace (name server root)
  (put name 'test-server server)
  (put name 'test-root root)
  name)

(ert-deftest test-lsp-status/registered-servers-are-dispatched ()
  "Start, log, notification, request and exit reach the right server's handlers."
  (let* ((root (make-temp-file "hellmacs-test-status" t))
         (calls nil)
         (log (lambda (&rest args) (push (cons 'log args) calls)))
         (note (lambda (&rest args) (push (cons 'note args) calls)))
         (req (lambda (&rest args) (push (cons 'req args) calls))))
    (unwind-protect
        (test-lsp-status--with (list (list 'fake-ls :label "Fake server" :on-log log
                                           :on-notification note :on-request req))
          (let ((ws (test-lsp-status--workspace 'test-ws 'fake-ls root))
                (other (test-lsp-status--workspace 'test-other 'unregistered-ls root)))
            (let ((lsp--cur-workspace ws)) (hellmacs-lsp-status--ignited-h))
            (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'igniting))
            (should (string-match-p "\\[FORGE IGNITED\\] Fake server bound to" (car shown)))
            (hellmacs-lsp-status--log-a ws '(:type 3 :message "hello"))
            (hellmacs-lsp-status--notification-a ws '(:method "$/progress" :params (:token "1")))
            (hellmacs-lsp-status--request-a ws '(:id 1 :method "window/showMessageRequest" :params (:type 2)))
            (should (equal (reverse calls)
                           `((log ,root "hello")
                             (note ,root "$/progress" (:token "1"))
                             (req ,root "window/showMessageRequest" (:type 2)))))
            ;; Another server's traffic, and its start, are left alone.
            (setq calls nil shown nil)
            (let ((lsp--cur-workspace other)) (hellmacs-lsp-status--ignited-h))
            (hellmacs-lsp-status--log-a other '(:message "hello"))
            (should-not calls)
            (should-not shown)
            ;; A handler's error doesn't reach lsp-mode.
            (hellmacs-lsp-status-register 'fake-ls :on-log (lambda (&rest _) (error "Boom")))
            (hellmacs-lsp-status--log-a ws '(:message "x"))
            ;; Exiting forgets the session and says so.
            (hellmacs-lsp-status--banished-h ws)
            (should-not (hellmacs-lsp-status-state 'fake-ls root))
            (should (string-match-p "\\[DAEMON BANISHED\\] fake-ls for .* exited" (car shown)))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/ready-and-recovery ()
  "Ready counts after a start; a recovery only after a failed import."
  (let ((root (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((fake-ls :label "Fake"))
          (hellmacs-lsp-status-ignite 'fake-ls root)
          ;; A recovery signal while starting isn't "ready".
          (hellmacs-lsp-status-ready 'fake-ls root 'recovered)
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'igniting))
          (hellmacs-lsp-status-fail 'fake-ls root "  why  ")
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'failed))
          (should (string-match-p "PURGATORY\\] .* failed to import: why\\'" (car shown)))
          ;; Neither a plain "ready" nor a second failure changes that.
          (let ((count (length shown)))
            (hellmacs-lsp-status-ready 'fake-ls root)
            (hellmacs-lsp-status-fail 'fake-ls root "again")
            (should (= count (length shown))))
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'failed))
          (hellmacs-lsp-status-ready 'fake-ls root 'recovered)
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'ready))
          (should (string-match-p "DAEMON READY" (car shown)))
          ;; With or without a trailing slash, it's the same project.
          (should (eq (hellmacs-lsp-status-state 'fake-ls (file-name-as-directory root)) 'ready)))
      (delete-directory root t))))

(ert-deftest test-lsp-status/outcome-before-initialize-is-kept ()
  "An import that fails and recovers before `initialize' returns stays ready.
lsp-mode runs `lsp-after-initialize-hook' (ignite) only once the server
answers `initialize'; JDTLS can report its import, failed and reimported,
before that (Spring Framework, Gradle 9). Ignite then mustn't reset it,
or the project waits for a ready that already came."
  (let ((root (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((fake-ls :label "Fake"))
          (hellmacs-lsp-status-fail 'fake-ls root "Gradle 9 refused it; importing again")
          (hellmacs-lsp-status-ready 'fake-ls root 'recovered)
          (hellmacs-lsp-status-ignite 'fake-ls root)
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'ready))
          (should (string-match-p "FORGE IGNITED" (car shown)))
          ;; A failure reported early is kept too.
          (hellmacs-lsp-status-banish 'fake-ls root)
          (hellmacs-lsp-status-fail 'fake-ls root "broken")
          (hellmacs-lsp-status-ignite 'fake-ls root)
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'failed))
          ;; Once the process exited, a new start begins afresh.
          (hellmacs-lsp-status-banish 'fake-ls root)
          (hellmacs-lsp-status-ignite 'fake-ls root)
          (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'igniting)))
      (delete-directory root t))))

(ert-deftest test-lsp-status/restart-outlives-the-old-server ()
  "On a restart the old server's exit can come after the new one started:
it mustn't end the new session, nor announce that the server exited."
  (let ((root (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((fake-ls :label "Fake"))
          (let ((old (test-lsp-status--workspace 'test-old 'fake-ls root))
                (new (test-lsp-status--workspace 'test-new 'fake-ls root)))
            (let ((lsp--cur-workspace old)) (hellmacs-lsp-status--ignited-h))
            (hellmacs-lsp-status-ready 'fake-ls root)
            (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'ready))
            ;; The new server answers `initialize' before the old one exits:
            ;; the old one's outcome isn't the new one's.
            (let ((lsp--cur-workspace new)) (hellmacs-lsp-status--ignited-h))
            (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'igniting))
            (setq shown nil)
            (hellmacs-lsp-status--banished-h old)
            (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'igniting))
            (should-not shown)
            (hellmacs-lsp-status-ready 'fake-ls root)
            (should (eq (hellmacs-lsp-status-state 'fake-ls root) 'ready))
            ;; The new server's own exit ends it.
            (hellmacs-lsp-status--banished-h new)
            (should-not (hellmacs-lsp-status-state 'fake-ls root))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/build-result ()
  "A failed build shows every server in that project as failed until a good one."
  (let ((root (make-temp-file "hellmacs-test-status" t))
        (elsewhere (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((a-ls) (b-ls))
          (dolist (server '(a-ls b-ls))
            (hellmacs-lsp-status-ignite server root)
            (hellmacs-lsp-status-ready server root))
          (hellmacs-lsp-status-ignite 'a-ls elsewhere)
          (hellmacs-lsp-status-build-result (file-name-as-directory root) nil)
          (should (eq (hellmacs-lsp-status-state 'a-ls root) 'failed))
          (should (eq (hellmacs-lsp-status-state 'b-ls root) 'failed))
          (should (eq (hellmacs-lsp-status-state 'a-ls elsewhere) 'igniting))
          ;; The server's own state is kept: a good build brings it back.
          (hellmacs-lsp-status-build-result root t)
          (should (eq (hellmacs-lsp-status-state 'a-ls root) 'ready))
          (should (eq (hellmacs-lsp-status-state 'b-ls root) 'ready))
          ;; A good build doesn't hide a failed import.
          (hellmacs-lsp-status-fail 'b-ls root "no JDK")
          (hellmacs-lsp-status-build-result root t)
          (should (eq (hellmacs-lsp-status-state 'b-ls root) 'failed))
          ;; A build of a project without a server is ignored.
          (hellmacs-lsp-status-build-result temporary-file-directory nil)
          (should-not (hellmacs-lsp-status-state 'a-ls temporary-file-directory)))
      (delete-directory root t)
      (delete-directory elsewhere t))))

(ert-deftest test-lsp-status/mode-line ()
  "The segment shows the buffer's registered server, themed or plain."
  (let ((root (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((fake-ls))
          (with-temp-buffer
            (should-not (hellmacs-lsp-status-mode-line)) ; no server at all
            (setq-local lsp--buffer-workspaces
                        (list (test-lsp-status--workspace 'test-unknown 'other-ls root)
                              (test-lsp-status--workspace 'test-ws 'fake-ls root)))
            (should-not (hellmacs-lsp-status-mode-line)) ; not started yet
            (hellmacs-lsp-status-ignite 'fake-ls root)
            (should (equal (substring-no-properties (hellmacs-lsp-status-mode-line)) " JVM:igniting "))
            (hellmacs-lsp-status-ready 'fake-ls root)
            (should (eq (get-text-property 1 'face (hellmacs-lsp-status-mode-line)) 'hellmacs-jvm-ready))
            (hellmacs-lsp-status-build-result root nil)
            (should (equal (substring-no-properties (hellmacs-lsp-status-mode-line)) " JVM:purgatory "))
            (let ((hellmacs-ux-enable nil))
              (should (equal (substring-no-properties (hellmacs-lsp-status-mode-line)) " JVM:failed ")))
            (hellmacs-lsp-status-banish 'fake-ls root)
            (should-not (hellmacs-lsp-status-mode-line))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/mode-line-caches-the-project ()
  "Redrawing the mode-line doesn't work out the project again."
  (let ((root (make-temp-file "hellmacs-test-status" t))
        (lookups 0))
    (unwind-protect
        (test-lsp-status--with '((fake-ls))
          (with-temp-buffer
            (setq-local lsp--buffer-workspaces (list (test-lsp-status--workspace 'test-ws 'fake-ls root)))
            (hellmacs-lsp-status-ignite 'fake-ls root)
            (cl-letf* ((stub (symbol-function 'hellmacs-lsp-status--root))
                       ((symbol-function 'hellmacs-lsp-status--root)
                        (lambda (ws) (cl-incf lookups) (funcall stub ws))))
              (dotimes (_ 5) (should (hellmacs-lsp-status-mode-line)))
              (should (= lookups 1))
              ;; Another workspace is worked out again.
              (setq-local lsp--buffer-workspaces (list (test-lsp-status--workspace 'test-ws2 'fake-ls root)))
              (should (hellmacs-lsp-status-mode-line))
              (should (= lookups 2)))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/mode-line-forgets-dead-workspaces ()
  "A buffer's cached workspace goes when the workspace does, so the buffer
doesn't keep a stopped server's workspace (process, diagnostics...) alive."
  (let ((root (make-temp-file "hellmacs-test-status" t)))
    (unwind-protect
        (test-lsp-status--with '((fake-ls))
          (let ((ws (test-lsp-status--workspace 'test-ws 'fake-ls root)))
            (with-temp-buffer
              ;; The buffer leaves its workspace (lsp-disconnect, say).
              (setq-local lsp--buffer-workspaces (list ws))
              (hellmacs-lsp-status-mode-line)
              (should hellmacs-lsp-status--buffer-key)
              (setq-local lsp--buffer-workspaces nil)
              (should-not (hellmacs-lsp-status-mode-line))
              (should-not hellmacs-lsp-status--buffer-key))
            (with-temp-buffer
              ;; The server stops, in a buffer that's not redrawn meanwhile.
              (setq-local lsp--buffer-workspaces (list ws))
              (hellmacs-lsp-status-mode-line)
              (hellmacs-lsp-status--banished-h ws)
              (should-not hellmacs-lsp-status--buffer-key))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/ready-functions ()
  "`hellmacs-lsp-status-ready-functions' run with the server and root when a
project becomes ready (again, after a recovery), not on every signal."
  (let ((root (make-temp-file "hellmacs-test-status" t))
        (called nil))
    (unwind-protect
        (test-lsp-status--with '((fake-ls))
          (let ((hellmacs-lsp-status-ready-functions
                 (list (lambda (server r) (push (cons server r) called)))))
            (hellmacs-lsp-status-ignite 'fake-ls root)
            (hellmacs-lsp-status-ready 'fake-ls root)
            (hellmacs-lsp-status-ready 'fake-ls root)      ; already ready: nothing
            (should (equal called (list (cons 'fake-ls root))))
            (hellmacs-lsp-status-fail 'fake-ls root "broken")
            (hellmacs-lsp-status-ready 'fake-ls root 'recovered)
            (should (= (length called) 2))))
      (delete-directory root t))))

(ert-deftest test-lsp-status/mode-line-entry-is-installed-once ()
  (should (= 1 (seq-count (lambda (entry) (equal entry '(:eval (hellmacs-lsp-status-mode-line))))
                          mode-line-misc-info))))

;;; test-lsp-status.el ends here
