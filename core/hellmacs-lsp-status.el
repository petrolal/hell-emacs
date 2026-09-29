;;; hellmacs-lsp-status.el --- Status messages for language servers -*- lexical-binding: t; -*-

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

;; The `[FORGE IGNITED]' / `[DAEMON READY]' / `[BYTECODE PURGATORY]' /
;; `[DAEMON BANISHED]' messages and the mode-line's JVM:... segment, for
;; every language server a `:lang' module registers:
;;
;;   (hellmacs-lsp-status-register 'kotlin-ls
;;     :label "Kotlin server"
;;     :on-log #'hellmacs-kotlin--note-log)     ; (ROOT MESSAGE)
;;
;; `:on-notification' and `:on-request' take (ROOT METHOD PARAMS). Each
;; server sends different signals for "the project is imported" or "it
;; failed", so the handlers read those and call `hellmacs-lsp-status-ready'
;; or `-fail'. Starting and exiting are the same for every server, and
;; handled here. lsp-mode's hooks and advice are installed once, whatever
;; the number of servers, and dispatch by server id.
;;
;; A session (one server in one project) is `igniting', `ready' or
;; `failed' (the import failed). Separately, `:tools build' reports each
;; build (`hellmacs-lsp-status-build-result'): after a failed build, every
;; server in that project shows as failed until a build succeeds.
;;
;; Wording follows `hellmacs-ux-enable': themed, or plain.

;;; Code:

(require 'seq)

(defvar lsp--cur-workspace)
(defvar lsp--buffer-workspaces)
(declare-function lsp--workspace-root "ext:lsp-mode")
(declare-function lsp--workspace-client "ext:lsp-mode")
(declare-function lsp--client-server-id "ext:lsp-mode")

(defface hellmacs-jvm-busy '((t (:inherit warning)))
  "Face for a language server that is starting or importing a project."
  :group 'hellmacs)

(defface hellmacs-jvm-ready '((t (:inherit success)))
  "Face for a language server that is ready."
  :group 'hellmacs)

(defface hellmacs-jvm-failed '((t (:inherit error)))
  "Face for a server that died, or a project that failed to import or build."
  :group 'hellmacs)

(defcustom hellmacs-lsp-status-messages
  '((ignited  hellmacs-jvm-busy   "[FORGE IGNITED] %s bound to %s"          "%s started for %s")
    (ready    hellmacs-jvm-ready  "[DAEMON READY] %s indexed in %.1fs"      "%s indexed in %.1fs")
    (failed   hellmacs-jvm-failed "[BYTECODE PURGATORY] %s failed to import: %s" "%s failed to import: %s")
    (banished hellmacs-jvm-failed "[DAEMON BANISHED] %s for %s exited"      "%s for %s exited"))
  "Status messages: (EVENT FACE THEMED PLAIN). `ignited' and `banished'
take the server's label and the project; `ready' the project and
seconds; `failed' the project and the reason."
  :type '(repeat (list symbol face string string))
  :group 'hellmacs)

(defcustom hellmacs-lsp-status-mode-line-states
  '((igniting hellmacs-jvm-busy   "JVM:igniting"  "JVM:igniting")
    (ready    hellmacs-jvm-ready  "JVM:ready"     "JVM:ready")
    (failed   hellmacs-jvm-failed "JVM:purgatory" "JVM:failed"))
  "Mode-line text for each state: (STATE FACE THEMED PLAIN)."
  :type '(repeat (list symbol face string string))
  :group 'hellmacs)

;;; Servers ------------------------------------------------------------------------

(defvar hellmacs-lsp-status--servers nil
  "Alist: server id -> its `hellmacs-lsp-status-register' properties.")

(defun hellmacs-lsp-status-register (server &rest props)
  "Report the status of SERVER (an lsp-mode server id, like `jdtls').
PROPS: `:label', the name its messages use (default: the id);
`:on-log', called with the project root and each log message;
`:on-notification' and `:on-request', called with the project root and
each notification's or request's method and params."
  (setf (alist-get server hellmacs-lsp-status--servers) props))

(defun hellmacs-lsp-status--server (workspace)
  "The id of lsp-mode WORKSPACE's server, if it's registered."
  (let ((id (lsp--client-server-id (lsp--workspace-client workspace))))
    (and (assq id hellmacs-lsp-status--servers) id)))

(defun hellmacs-lsp-status--root (workspace)
  "WORKSPACE's project root."
  (lsp--workspace-root workspace))

(defun hellmacs-lsp-status--label (server)
  (or (plist-get (alist-get server hellmacs-lsp-status--servers) :label)
      (symbol-name server)))

(defun hellmacs-lsp-status-get (object key)
  "Return KEY (a keyword, like :method) from a protocol OBJECT.
lsp-mode gives plists when built with LSP_USE_PLISTS (Hellmacs does that),
and hash tables otherwise; this reads either."
  (if (hash-table-p object)
      (gethash (substring (symbol-name key) 1) object)
    (plist-get object key)))

;;; Sessions -----------------------------------------------------------------------

(defvar hellmacs-lsp-status--sessions (make-hash-table :test #'equal)
  "(SERVER . PROJECT-ROOT) -> (STATE SINCE BUILD-FAILED).
STATE is igniting, ready or failed; SINCE when the server started;
BUILD-FAILED non-nil while the project's last build failed.")

(defun hellmacs-lsp-status--key (server root)
  (cons server (directory-file-name (file-truename root))))

(defun hellmacs-lsp-status--shown (session)
  "The state SESSION shows: failed after a failed build, else its own."
  (and session (if (nth 2 session) 'failed (car session))))

(defun hellmacs-lsp-status-state (server root)
  "The state of SERVER (a symbol) for project ROOT: igniting, ready, failed or nil."
  (hellmacs-lsp-status--shown
   (gethash (hellmacs-lsp-status--key server root) hellmacs-lsp-status--sessions)))

(defun hellmacs-lsp-status--set (key state)
  "Record STATE for session KEY, keeping its start time and build result."
  (let ((session (gethash key hellmacs-lsp-status--sessions)))
    (puthash key (list state (or (nth 1 session) (float-time)) (nth 2 session))
             hellmacs-lsp-status--sessions))
  (force-mode-line-update t))

(defun hellmacs-lsp-status-announce (event &rest args)
  "Show the message for EVENT (see `hellmacs-lsp-status-messages') formatted with ARGS.
Returns the text."
  (apply #'hellmacs-announce hellmacs-lsp-status-messages event args))

(defun hellmacs-lsp-status-ignite (server root)
  "SERVER just started for project ROOT."
  (puthash (hellmacs-lsp-status--key server root) (list 'igniting (float-time) nil)
           hellmacs-lsp-status--sessions)
  (force-mode-line-update t)
  (hellmacs-lsp-status-announce 'ignited (hellmacs-lsp-status--label server)
                                (abbreviate-file-name root)))

(defun hellmacs-lsp-status-ready (server root &optional recovered)
  "SERVER finished indexing project ROOT. Only counts right after it started;
with RECOVERED, only after its import failed (and the cause was fixed)."
  (let* ((key (hellmacs-lsp-status--key server root))
         (session (gethash key hellmacs-lsp-status--sessions)))
    (when (eq (car session) (if recovered 'failed 'igniting))
      (hellmacs-lsp-status--set key 'ready)
      (hellmacs-lsp-status-announce 'ready (abbreviate-file-name root)
                                    (- (float-time) (nth 1 session))))))

(defun hellmacs-lsp-status-fail (server root reason)
  "SERVER couldn't import project ROOT, for REASON. Announced once per start."
  (let ((key (hellmacs-lsp-status--key server root)))
    (unless (eq (car (gethash key hellmacs-lsp-status--sessions)) 'failed)
      (hellmacs-lsp-status--set key 'failed)
      (hellmacs-lsp-status-announce 'failed (abbreviate-file-name root)
                                    (truncate-string-to-width (string-trim reason) 110 nil nil t)))))

(defun hellmacs-lsp-status-banish (server root)
  "SERVER's process for ROOT exited."
  (remhash (hellmacs-lsp-status--key server root) hellmacs-lsp-status--sessions)
  (force-mode-line-update t)
  (hellmacs-lsp-status-announce 'banished (hellmacs-lsp-status--label server)
                                (abbreviate-file-name root)))

(defun hellmacs-lsp-status-build-result (root ok)
  "A build of project ROOT ended, successfully if OK.
Every server's session in ROOT shows failed until a build succeeds."
  (let ((dir (directory-file-name (file-truename root))))
    (maphash (lambda (key session)
               (when (equal (cdr key) dir)
                 (setf (nth 2 session) (not ok))))
             hellmacs-lsp-status--sessions))
  (force-mode-line-update t))

;;; lsp-mode hooks, installed once ---------------------------------------------------

(defun hellmacs-lsp-status--dispatch (workspace handler &rest args)
  "Call the HANDLER (a keyword) WORKSPACE's server registered.
It gets WORKSPACE's root, then ARGS."
  (when-let* ((server (hellmacs-lsp-status--server workspace))
              (fn (plist-get (alist-get server hellmacs-lsp-status--servers) handler)))
    ;; Runs inside lsp-mode's message handling: never break that.
    (with-demoted-errors "Hellmacs status: %S"
      (apply fn (hellmacs-lsp-status--root workspace) args))))

(defun hellmacs-lsp-status--ignited-h ()
  "For `lsp-after-initialize-hook'."
  (when-let* ((workspace lsp--cur-workspace)
              (server (hellmacs-lsp-status--server workspace)))
    (hellmacs-lsp-status-ignite server (hellmacs-lsp-status--root workspace))))

(defun hellmacs-lsp-status--banished-h (workspace)
  "For `lsp-after-uninitialized-functions'."
  (hellmacs-lsp-status--forget-workspace workspace)
  (when-let* ((server (hellmacs-lsp-status--server workspace)))
    (hellmacs-lsp-status-banish server (hellmacs-lsp-status--root workspace))))

(defun hellmacs-lsp-status--log-a (workspace params)
  "Before lsp-mode shows a log message (PARAMS) from WORKSPACE."
  (hellmacs-lsp-status--dispatch workspace :on-log
                                 (or (hellmacs-lsp-status-get params :message) "")))

(defun hellmacs-lsp-status--notification-a (workspace notification)
  "Before lsp-mode handles NOTIFICATION from WORKSPACE."
  (hellmacs-lsp-status--dispatch workspace :on-notification
                                 (hellmacs-lsp-status-get notification :method)
                                 (hellmacs-lsp-status-get notification :params)))

(defun hellmacs-lsp-status--request-a (workspace request)
  "Before lsp-mode handles REQUEST from WORKSPACE."
  (hellmacs-lsp-status--dispatch workspace :on-request
                                 (hellmacs-lsp-status-get request :method)
                                 (hellmacs-lsp-status-get request :params)))

(with-eval-after-load 'lsp-mode
  (add-hook 'lsp-after-initialize-hook #'hellmacs-lsp-status--ignited-h)
  (add-hook 'lsp-after-uninitialized-functions #'hellmacs-lsp-status--banished-h)
  (advice-add 'lsp--window-log-message :before #'hellmacs-lsp-status--log-a)
  (advice-add 'lsp--on-notification :before #'hellmacs-lsp-status--notification-a)
  (advice-add 'lsp--on-request :before #'hellmacs-lsp-status--request-a))

;;; Mode-line --------------------------------------------------------------------------

(defvar-local hellmacs-lsp-status--buffer-key nil
  "(WORKSPACE . KEY): this buffer's session key, and the workspace it came from.")

(defun hellmacs-lsp-status--buffer-key ()
  "The session key of the current buffer's registered server, cached.
The mode-line asks on nearly every redisplay, and a project's true name
reads the disk; it's only worked out again for another workspace.
Without one it's forgotten, so a stopped server's workspace isn't kept."
  (if-let* ((workspace (seq-find #'hellmacs-lsp-status--server
                                 (bound-and-true-p lsp--buffer-workspaces))))
      (progn
        (unless (eq workspace (car hellmacs-lsp-status--buffer-key))
          (setq hellmacs-lsp-status--buffer-key
                (cons workspace (hellmacs-lsp-status--key
                                 (hellmacs-lsp-status--server workspace)
                                 (hellmacs-lsp-status--root workspace)))))
        (cdr hellmacs-lsp-status--buffer-key))
    (setq hellmacs-lsp-status--buffer-key nil)))

(defun hellmacs-lsp-status--forget-workspace (workspace)
  "Drop WORKSPACE from every buffer's cached session key."
  (dolist (buffer (buffer-list))
    (when (eq workspace (car (buffer-local-value 'hellmacs-lsp-status--buffer-key buffer)))
      (with-current-buffer buffer
        (setq hellmacs-lsp-status--buffer-key nil)))))

(defun hellmacs-lsp-status-mode-line ()
  "Mode-line text for the state of the current buffer's language server, or nil."
  (when-let* ((key (hellmacs-lsp-status--buffer-key))
              (state (hellmacs-lsp-status--shown (gethash key hellmacs-lsp-status--sessions))))
    (pcase-let ((`(,face ,themed ,plain) (alist-get state hellmacs-lsp-status-mode-line-states)))
      ;; Spaced on both sides: lsp-mode's own entries (the code-action
      ;; count and lightbulb, lsp-java's progress) follow with no space.
      (concat " " (propertize (if (bound-and-true-p hellmacs-ux-enable) themed plain) 'face face) " "))))

;; A standard `mode-line-misc-info' entry, so any mode-line shows it
;; (`:ui modeline' included); empty in buffers without such a server.
(add-to-list 'mode-line-misc-info '(:eval (hellmacs-lsp-status-mode-line)))

(provide 'hellmacs-lsp-status)
;;; hellmacs-lsp-status.el ends here
