;;; lisp/lib/lsp-status.el --- Status messages for language servers -*- lexical-binding: t; -*-

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

;; The `[FORGE IGNITED]' / `[DAEMON READY]' / `[BYTECODE PURGATORY]' /
;; `[DAEMON BANISHED]' messages and the mode-line's JVM:... segment, for
;; every language server a `:lang' module registers:
;;
;;   (hell-lsp-status-register 'kotlin-ls
;;     :label "Kotlin server"
;;     :on-log #'hell-kotlin--note-log)     ; (ROOT MESSAGE)
;;
;; `:on-notification' and `:on-request' take (ROOT METHOD PARAMS). Each
;; server sends different signals for "the project is imported" or "it
;; failed", so the handlers read those and call `hell-lsp-status-ready'
;; or `-fail'. Starting and exiting are the same for every server, and
;; handled here. lsp-mode's hooks and advice are installed once, whatever
;; the number of servers, and dispatch by server id.
;;
;; A session (one server in one project) is `igniting', `ready' or
;; `failed' (the import failed). Separately, `:tools build' reports each
;; build (`hell-lsp-status-build-result'): after a failed build, every
;; server in that project shows as failed until a build succeeds.
;;
;; Wording follows `hell-ux-enable': themed, or plain.

;;; Code:

(require 'seq)
(require 'hell-lib)

(defvar lsp--cur-workspace)
(defvar lsp--buffer-workspaces)
(declare-function lsp--workspace-root "ext:lsp-mode")
(declare-function lsp--workspace-client "ext:lsp-mode")
(declare-function lsp--client-server-id "ext:lsp-mode")

(defface hell-jvm-busy '((t (:inherit warning)))
  "Face for a language server that is starting or importing a project."
  :group 'hell)

(defface hell-jvm-ready '((t (:inherit success)))
  "Face for a language server that is ready."
  :group 'hell)

(defface hell-jvm-failed '((t (:inherit error)))
  "Face for a server that died, or a project that failed to import or build."
  :group 'hell)

(defcustom hell-lsp-status-messages
  '((ignited  hell-jvm-busy   "[FORGE IGNITED] %s bound to %s"          "%s started for %s")
    (slow     hell-jvm-busy   "[FORGE IGNITED] %s still importing %s after %ds: no completion until it's done (progress in *lsp-log*)"
              "%s still importing %s after %ds: no completion until it's done (progress in *lsp-log*)")
    (ready    hell-jvm-ready  "[DAEMON READY] %s indexed in %.1fs"      "%s indexed in %.1fs")
    (failed   hell-jvm-failed "[BYTECODE PURGATORY] %s failed to import: %s" "%s failed to import: %s")
    (banished hell-jvm-failed "[DAEMON BANISHED] %s for %s exited"      "%s for %s exited"))
  "Status messages: (EVENT FACE THEMED PLAIN). `ignited' and `banished'
take the server's label and the project; `slow' those and seconds;
`ready' the project and seconds; `failed' the project and the reason."
  :type '(repeat (list symbol face string string))
  :group 'hell)

(defcustom hell-lsp-status-mode-line-states
  '((igniting hell-jvm-busy   "JVM:igniting"  "JVM:igniting")
    (ready    hell-jvm-ready  "JVM:ready"     "JVM:ready")
    (failed   hell-jvm-failed "JVM:purgatory" "JVM:failed"))
  "Mode-line text for each state: (STATE FACE THEMED PLAIN)."
  :type '(repeat (list symbol face string string))
  :group 'hell)

;;; Servers ------------------------------------------------------------------------

(defvar hell-lsp-status--servers nil
  "Alist: server id -> its `hell-lsp-status-register' properties.")

(defun hell-lsp-status-register (server &rest props)
  "Report the status of SERVER (an lsp-mode server id, like `jdtls').
PROPS: `:label', the name its messages use (default: the id);
`:on-log', called with the project root and each log message;
`:on-notification' and `:on-request', called with the project root and
each notification's or request's method and params."
  (setf (alist-get server hell-lsp-status--servers) props))

(defun hell-lsp-status--server (workspace)
  "The id of lsp-mode WORKSPACE's server, if it's registered."
  (let ((id (lsp--client-server-id (lsp--workspace-client workspace))))
    (and (assq id hell-lsp-status--servers) id)))

(defun hell-lsp-status--root (workspace)
  "WORKSPACE's project root."
  (lsp--workspace-root workspace))

(defun hell-lsp-status--label (server)
  (or (plist-get (alist-get server hell-lsp-status--servers) :label)
      (symbol-name server)))

(defun hell-lsp-status-get (object key)
  "Return KEY (a keyword, like :method) from a protocol OBJECT.
lsp-mode gives plists when built with LSP_USE_PLISTS (Hell Emacs does that),
and hash tables otherwise; this reads either."
  (if (hash-table-p object)
      (gethash (substring (symbol-name key) 1) object)
    (plist-get object key)))

;;; Sessions -----------------------------------------------------------------------

(defcustom hell-lsp-status-slow-seconds 90
  "Seconds a project may take to import before Hell Emacs says it's still at it.
An import that never ends (a build tool waiting on a lock, a download that
hangs) is otherwise silent, and completion stays empty. nil never says."
  :type '(choice (const :tag "Never" nil) natnum)
  :group 'hell)

(defvar hell-lsp-status--sessions (make-hash-table :test #'equal)
  "(SERVER . PROJECT-ROOT) -> (STATE SINCE BUILD-FAILED WORKSPACE).
STATE is igniting, ready or failed; SINCE when the server started;
BUILD-FAILED non-nil while the project's last build failed; WORKSPACE
the lsp-mode workspace the session is, once it has started (nil for an
outcome reported before that).")

(defun hell-lsp-status--key (server root)
  (cons server (directory-file-name (file-truename root))))

(defun hell-lsp-status--shown (session)
  "The state SESSION shows: failed after a failed build, else its own."
  (and session (if (nth 2 session) 'failed (car session))))

(defun hell-lsp-status-state (server root)
  "The state of SERVER (a symbol) for project ROOT: igniting, ready, failed or nil."
  (hell-lsp-status--shown
   (gethash (hell-lsp-status--key server root) hell-lsp-status--sessions)))

(defun hell-lsp-status--set (key state)
  "Record STATE for session KEY, keeping its start time and build result."
  (let ((session (gethash key hell-lsp-status--sessions)))
    (puthash key (list state (or (nth 1 session) (float-time)) (nth 2 session) (nth 3 session))
             hell-lsp-status--sessions))
  (force-mode-line-update t))

(defun hell-lsp-status-announce (event &rest args)
  "Show the message for EVENT (see `hell-lsp-status-messages') formatted with ARGS.
Returns the text."
  (apply #'hell-announce hell-lsp-status-messages event args))

(defun hell-lsp-status-ignite (server root &optional workspace)
  "SERVER just started for project ROOT, as lsp-mode WORKSPACE.
An outcome it already reported is kept: this runs once the server has
answered `initialize', and it may have imported (or failed to) before
that. An outcome of another workspace isn't: on a restart the old
server may not have exited yet (`hell-lsp-status-banish')."
  (let* ((key (hell-lsp-status--key server root))
         (session (gethash key hell-lsp-status--sessions)))
    (if (and (memq (car session) '(ready failed))
             (memq (nth 3 session) (list nil workspace)))
        (puthash key (list (nth 0 session) (nth 1 session) (nth 2 session) workspace)
                 hell-lsp-status--sessions)
      (puthash key (list 'igniting (float-time) nil workspace) hell-lsp-status--sessions)
      (when hell-lsp-status-slow-seconds
        (run-with-timer hell-lsp-status-slow-seconds nil
                        #'hell-lsp-status--still-igniting key workspace))))
  (force-mode-line-update t)
  (hell-lsp-status-announce 'ignited (hell-lsp-status--label server)
                            (abbreviate-file-name root)))

(defun hell-lsp-status--still-igniting (key workspace)
  "Say so if session KEY, started as WORKSPACE, is still importing."
  (let ((session (gethash key hell-lsp-status--sessions)))
    (when (and (eq (car session) 'igniting) (eq (nth 3 session) workspace))
      (hell-lsp-status-announce 'slow (hell-lsp-status--label (car key))
                                (abbreviate-file-name (cdr key))
                                    (round (- (float-time) (nth 1 session)))))))

(defvar hell-lsp-status-ready-functions nil
  "Functions called with SERVER and ROOT when a project becomes ready.
When its server finishes importing it, and again when it recovers from a
failed import: when what the server knows of the project is new.")

(defun hell-lsp-status-ready (server root &optional recovered)
  "SERVER finished indexing project ROOT. Only counts right after it started;
with RECOVERED, only after its import failed (and the cause was fixed)."
  (let* ((key (hell-lsp-status--key server root))
         (session (gethash key hell-lsp-status--sessions)))
    (when (eq (car session) (if recovered 'failed 'igniting))
      (hell-lsp-status--set key 'ready)
      (hell-lsp-status-announce 'ready (abbreviate-file-name root)
                                (- (float-time) (nth 1 session)))
      ;; Isolated: a broken function mustn't break lsp-mode's handling.
      (dolist (fn hell-lsp-status-ready-functions)
        (with-demoted-errors "Hell Emacs status: %S"
          (funcall fn server root))))))

(defun hell-lsp-status-fail (server root reason)
  "SERVER couldn't import project ROOT, for REASON. Announced once per start."
  (let ((key (hell-lsp-status--key server root)))
    (unless (eq (car (gethash key hell-lsp-status--sessions)) 'failed)
      (hell-lsp-status--set key 'failed)
      (hell-lsp-status-announce 'failed (abbreviate-file-name root)
                                (truncate-string-to-width (string-trim reason) 110 nil nil t)))))

(defun hell-lsp-status-banish (server root &optional workspace)
  "SERVER's process for ROOT, lsp-mode WORKSPACE, exited.
Nothing happens when a newer workspace has the session already: the
old server of a restart exiting after the new one started."
  (let* ((key (hell-lsp-status--key server root))
         (owner (nth 3 (gethash key hell-lsp-status--sessions))))
    (unless (and workspace owner (not (eq owner workspace)))
      (remhash key hell-lsp-status--sessions)
      (force-mode-line-update t)
      (hell-lsp-status-announce 'banished (hell-lsp-status--label server)
                                (abbreviate-file-name root)))))

(defun hell-lsp-status-build-result (root ok)
  "A build of project ROOT ended, successfully if OK.
Every server's session in ROOT shows failed until a build succeeds."
  (let ((dir (directory-file-name (file-truename root))))
    (maphash (lambda (key session)
               (when (equal (cdr key) dir)
                 (setf (nth 2 session) (not ok))))
             hell-lsp-status--sessions))
  (force-mode-line-update t))

;;; lsp-mode hooks, installed once ---------------------------------------------------

(defun hell-lsp-status--dispatch (workspace handler &rest args)
  "Call the HANDLER (a keyword) WORKSPACE's server registered.
It gets WORKSPACE's root, then ARGS."
  (when-let* ((server (hell-lsp-status--server workspace))
              (fn (plist-get (alist-get server hell-lsp-status--servers) handler)))
    ;; Runs inside lsp-mode's message handling: never break that.
    (with-demoted-errors "Hell Emacs status: %S"
      (apply fn (hell-lsp-status--root workspace) args))))

(defun hell-lsp-status--ignited-h ()
  "For `lsp-after-initialize-hook'."
  (when-let* ((workspace lsp--cur-workspace)
              (server (hell-lsp-status--server workspace)))
    (hell-lsp-status-ignite server (hell-lsp-status--root workspace) workspace)))

(defun hell-lsp-status--banished-h (workspace)
  "For `lsp-after-uninitialized-functions'."
  (hell-lsp-status--forget-workspace workspace)
  (when-let* ((server (hell-lsp-status--server workspace)))
    (hell-lsp-status-banish server (hell-lsp-status--root workspace) workspace)))

(defun hell-lsp-status--log-a (workspace params)
  "Before lsp-mode shows a log message (PARAMS) from WORKSPACE."
  (hell-lsp-status--dispatch workspace :on-log
                             (or (hell-lsp-status-get params :message) "")))

(defun hell-lsp-status--notification-a (workspace notification)
  "Before lsp-mode handles NOTIFICATION from WORKSPACE."
  (hell-lsp-status--dispatch workspace :on-notification
                             (hell-lsp-status-get notification :method)
                                 (hell-lsp-status-get notification :params)))

(defun hell-lsp-status--request-a (workspace request)
  "Before lsp-mode handles REQUEST from WORKSPACE."
  (hell-lsp-status--dispatch workspace :on-request
                             (hell-lsp-status-get request :method)
                                 (hell-lsp-status-get request :params)))

(with-eval-after-load 'lsp-mode
  (add-hook 'lsp-after-initialize-hook #'hell-lsp-status--ignited-h)
  (add-hook 'lsp-after-uninitialized-functions #'hell-lsp-status--banished-h)
  (advice-add 'lsp--window-log-message :before #'hell-lsp-status--log-a)
  (advice-add 'lsp--on-notification :before #'hell-lsp-status--notification-a)
  (advice-add 'lsp--on-request :before #'hell-lsp-status--request-a))

;;; Mode-line --------------------------------------------------------------------------

(defvar-local hell-lsp-status--buffer-key nil
  "(WORKSPACE . KEY): this buffer's session key, and the workspace it came from.")

(defun hell-lsp-status--buffer-key ()
  "The session key of the current buffer's registered server, cached.
The mode-line asks on nearly every redisplay, and a project's true name
reads the disk; it's only worked out again for another workspace.
Without one it's forgotten, so a stopped server's workspace isn't kept."
  (if-let* ((workspace (seq-find #'hell-lsp-status--server
                                 (bound-and-true-p lsp--buffer-workspaces))))
      (progn
        (unless (eq workspace (car hell-lsp-status--buffer-key))
          (setq hell-lsp-status--buffer-key
                (cons workspace (hell-lsp-status--key
                                 (hell-lsp-status--server workspace)
                                 (hell-lsp-status--root workspace)))))
        (cdr hell-lsp-status--buffer-key))
    (setq hell-lsp-status--buffer-key nil)))

(defun hell-lsp-status--forget-workspace (workspace)
  "Drop WORKSPACE from every buffer's cached session key."
  (dolist (buffer (buffer-list))
    (when (eq workspace (car (buffer-local-value 'hell-lsp-status--buffer-key buffer)))
      (with-current-buffer buffer
        (setq hell-lsp-status--buffer-key nil)))))

(defun hell-lsp-status-mode-line ()
  "Mode-line text for the state of the current buffer's language server, or nil."
  (when-let* ((key (hell-lsp-status--buffer-key))
              (state (hell-lsp-status--shown (gethash key hell-lsp-status--sessions))))
    (pcase-let ((`(,face ,themed ,plain) (alist-get state hell-lsp-status-mode-line-states)))
      ;; Spaced on both sides: lsp-mode's own entries (the code-action
      ;; count and lightbulb, lsp-java's progress) follow with no space.
      (concat " " (propertize (if (bound-and-true-p hell-ux-enable) themed plain) 'face face) " "))))

;; A standard `mode-line-misc-info' entry, so any mode-line shows it
;; (`:ui modeline' included); empty in buffers without such a server.
(add-to-list 'mode-line-misc-info '(:eval (hell-lsp-status-mode-line)))

(hell-provide 'hell-lib 'lsp-status)
;;; lsp-status.el ends here
