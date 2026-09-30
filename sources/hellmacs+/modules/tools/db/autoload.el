;;; tools/db/autoload.el -*- lexical-binding: t; -*-

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


;; A database client over JDBC: built-in sql.el, with sqlline (Apache's JDBC
;; shell) as its interpreter, so every database with a JDBC driver works the
;; same way -- Oracle, SQL Server, DB2, PostgreSQL, MySQL, MariaDB, H2,
;; SQLite. Connections are the project's `.hellmacs/db.eld':
;;
;;   ((:name "dev" :driver postgresql :host "localhost" :database "app" :user "ann")
;;    (:name "reports" :driver oracle :host "db.corp" :database "ORCLPDB1" :user "rep")
;;    (:name "legacy" :driver sqlserver :url "jdbc:sqlserver://h:1433;databaseName=x" :user "u"))
;;
;; Passwords come from auth-source (machine HOST port PORT login USER), or
;; are asked for and never stored; a password in db.eld is refused. It
;; reaches sqlline on its standard input, never on its command line.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(hellmacs-module-load "+paths")

(defvar sql-product)
(defvar sql-buffer)
(defvar sql-product-alist)
(declare-function sql-add-product "sql")
(declare-function sql-interactive-mode "sql")
(declare-function sql-send-string "sql")
(declare-function sql-buffer-live-p "sql")
(declare-function auth-source-search "auth-source")
(declare-function comint-check-proc "comint")
(declare-function hellmacs-jdk-java-executable "../../../lisp/lib/jdk")
(declare-function hellmacs-jdk-home-major "../../../lisp/lib/jdk")
(declare-function hellmacs-sync-download-verified "cli/sync")

;;;###autoload
(defun hellmacs-db-jar-spec (name)
  "sqlline's or a driver's pinned jar: a plist of :version :url :sha256 :file."
  (cdr (assq name hellmacs-db-jars)))

;;;###autoload
(defun hellmacs-db-driver-spec (driver)
  "DRIVER's pinned jar, like `hellmacs-db-jar-spec'."
  (hellmacs-db-jar-spec driver))

;;; Connections --------------------------------------------------------------------

(defun hellmacs-db--port (profile)
  (or (plist-get profile :port) (plist-get (hellmacs-db-driver-spec (plist-get profile :driver)) :port)))

;;;###autoload
(defun hellmacs-db-connection-url (profile)
  "The JDBC URL of connection PROFILE: its :url, else made from its parts."
  (or (plist-get profile :url)
      (let ((host (plist-get profile :host))
            (port (hellmacs-db--port profile))
            (db (plist-get profile :database)))
        (pcase (plist-get profile :driver)
          ('postgresql (format "jdbc:postgresql://%s:%s/%s" host port db))
          ('mysql (format "jdbc:mysql://%s:%s/%s" host port db))
          ('mariadb (format "jdbc:mariadb://%s:%s/%s" host port db))
          ('sqlserver (format "jdbc:sqlserver://%s:%s;databaseName=%s" host port db))
          ('oracle (format "jdbc:oracle:thin:@//%s:%s/%s" host port db))
          ('db2 (format "jdbc:db2://%s:%s/%s" host port db))
          ('h2 (if host (format "jdbc:h2:tcp://%s%s/%s" host (if port (format ":%s" port) "") db)
                 (format "jdbc:h2:%s" db)))
          ('sqlite (format "jdbc:sqlite:%s" db))
          (driver (user-error "No JDBC driver `%s'; give the connection a :url, or one of: %s"
                              driver (mapconcat #'symbol-name (remq 'sqlline (mapcar #'car hellmacs-db-jars)) ", ")))))))

(defun hellmacs-db--connections-file ()
  (when-let* ((dir (locate-dominating-file default-directory ".hellmacs/db.eld")))
    (expand-file-name ".hellmacs/db.eld" dir)))

;;;###autoload
(defun hellmacs-db-connections ()
  "The project's connections, from its .hellmacs/db.eld."
  (when-let* ((file (hellmacs-db--connections-file)))
    (let ((connections (with-temp-buffer (insert-file-contents file) (read (current-buffer)))))
      (when (seq-some (lambda (c) (plist-member c :password)) connections)
        (user-error "%s holds a password; keep it in auth-source (~/.authinfo.gpg) instead"
                    (abbreviate-file-name file)))
      connections)))

(defun hellmacs-db--password (profile)
  "PROFILE's password: from auth-source, else asked for (and not kept)."
  (let* ((port (hellmacs-db--port profile))
         (found (car (auth-source-search :host (or (plist-get profile :host) (plist-get profile :database))
                                         :port (and port (format "%s" port))
                                         :user (plist-get profile :user)
                                         :max 1)))
         (secret (plist-get found :secret)))
    (if secret
        (if (functionp secret) (funcall secret) secret)
      (read-passwd (format "Password for %s@%s: " (plist-get profile :user)
                           (or (plist-get profile :name) (hellmacs-db-connection-url profile)))))))

;;; sqlline ------------------------------------------------------------------------

(defun hellmacs-db--ensure-jars (profile)
  "Install sqlline and PROFILE's driver if they aren't yet (pinned downloads)."
  (dolist (name (list 'sqlline (plist-get profile :driver)))
    (let ((spec (hellmacs-db-jar-spec name)))
      (when (and spec (not (hellmacs-file-pinned-p (plist-get spec :file) (plist-get spec :sha256))))
        (hellmacs-require 'hellmacs-cli 'sync)
        (message "Installing %s %s (pinned)..." name (plist-get spec :version))
        (with-hellmacs-network
          (hellmacs-sync-download-verified (plist-get spec :url) (plist-get spec :file)
                                           (plist-get spec :sha256) (symbol-name name)))))))

(defun hellmacs-db--command (profile)
  "The command running sqlline with PROFILE's driver. No credentials in it."
  (let* ((java (hellmacs-jdk-java-executable 11))
         (major (and (file-name-absolute-p java)
                     (hellmacs-jdk-home-major (file-name-directory (directory-file-name (file-name-directory java)))))))
    `(,java
      ,@(and major (>= major 22) '("--enable-native-access=ALL-UNNAMED")) ; JLine's, quietly
      "-Dorg.jline.terminal.dumb=true" "-Dorg.jline.terminal.type=dumb"
      "-cp" ,(mapconcat (lambda (name) (plist-get (hellmacs-db-jar-spec name) :file))
                        (delq nil (list 'sqlline (and (hellmacs-db-driver-spec (plist-get profile :driver))
                                                      (plist-get profile :driver))))
                        path-separator)
      "sqlline.SqlLine" "--outputformat=table" ,(format "--maxWidth=%d" (max 100 (window-width)))
      "--color=false" "--incremental=true"
      ;; With Hellmacs' state, not in ~/.sqlline.
      ,(concat "--historyfile=" (hellmacs-state-file "sqlline/history")))))

;;;###autoload
(defun hellmacs-db--add-product ()
  "Teach sql.el about sqlline, once."
  (require 'sql)
  (unless (assq 'sqlline sql-product-alist)
    (sql-add-product 'sqlline "JDBC (sqlline)"
                     :free-software t
                     :prompt-regexp "^\\(?:sqlline\\|[0-9]+: [^>\n]*\\)> "
                     :prompt-cont-regexp "^\\(?:\\. \\)+> *")))

(defun hellmacs-db--quote (word)
  "WORD as one sqlline argument."
  (if (or (string-empty-p word) (string-match-p "[ \"]" word))
      (concat "\"" (string-replace "\"" "\\\"" word) "\"")
    word))

;;;###autoload
(defun hellmacs-db-connect (profile)
  "Connect to PROFILE (one of the project's connections): an SQLi buffer running sqlline.
Returns the buffer; queries from `sql-mode' buffers go there."
  (interactive (list (hellmacs-db--read-connection)))
  (hellmacs-db--add-product)
  (hellmacs-db--ensure-jars profile)
  (let* ((name (or (plist-get profile :name) (hellmacs-db-connection-url profile)))
         (buffer (get-buffer-create (format "*SQL: %s*" name))))
    (unless (comint-check-proc buffer)
      (let ((command (hellmacs-db--command profile))
            (password (hellmacs-db--password profile)))
        (when (string-match-p "[\n\r]" password)
          (user-error "The password for %s has a line break, which sqlline can't take" name))
        (apply #'make-comint-in-buffer (format "SQL: %s" name) buffer (car command) nil (cdr command))
        (with-current-buffer buffer
          (let ((sql-product 'sqlline)) (sql-interactive-mode))
          (setq-local sql-product 'sqlline
                      truncate-lines t))  ; wide result tables scroll, not wrap
        (make-directory (file-name-directory (hellmacs-state-file "sqlline/history")) t)
        ;; Sent, not typed: comint doesn't insert it, and sqlline doesn't
        ;; echo it. The password answers sqlline's own prompt: on the
        ;; !connect line it would be written to sqlline's history file.
        (comint-send-string (get-buffer-process buffer)
                            (format "!connect %s %s\n%s\n" (hellmacs-db-connection-url profile)
                                    (hellmacs-db--quote (or (plist-get profile :user) ""))
                                    password))))
    (when (called-interactively-p 'any) (pop-to-buffer buffer))
    buffer))

(defun hellmacs-db--read-connection ()
  (let ((connections (or (hellmacs-db-connections)
                         (user-error "No .hellmacs/db.eld here or above"))))
    (if (cdr connections)
        (let ((name (completing-read "Connection: " (mapcar (lambda (c) (plist-get c :name)) connections) nil t)))
          (seq-find (lambda (c) (equal (plist-get c :name) name)) connections))
      (car connections))))

;;; Running statements ---------------------------------------------------------------

(defun hellmacs-db--ensure-connection ()
  "Make sure this buffer's statements have somewhere to go: connect if needed."
  (unless (sql-buffer-live-p sql-buffer)
    (setq-local sql-buffer (buffer-name (hellmacs-db-connect (hellmacs-db--read-connection))))))

(defun hellmacs-db--send (text)
  (let ((statement (string-trim text)))
    (when (string-empty-p statement) (user-error "No statement here"))
    (hellmacs-db--ensure-connection)
    (sql-send-string (if (string-suffix-p ";" statement) statement (concat statement ";")))))

;;;###autoload
(defun hellmacs-db-execute-statement ()
  "Run the statement at point (the lines between blank lines) on the connection.
Connects first, choosing among the project's connections, if needed."
  (interactive)
  (save-excursion
    ;; On a blank line (say, just after typing a statement): the one above.
    (beginning-of-line)
    (while (and (looking-at "[ \t]*$") (not (bobp)))
      (forward-line -1))
    (let ((start (save-excursion (if (re-search-backward "^[ \t]*$" nil t) (match-end 0) (point-min))))
          (end (save-excursion (if (re-search-forward "^[ \t]*$" nil t) (match-beginning 0) (point-max)))))
      (hellmacs-db--send (buffer-substring-no-properties start end)))))

;;;###autoload
(defun hellmacs-db-execute-buffer ()
  "Run the whole buffer on the connection."
  (interactive)
  (hellmacs-db--send (buffer-substring-no-properties (point-min) (point-max))))

(defvar hellmacs-db-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "<remap> <sql-send-paragraph>" #'hellmacs-db-execute-statement)
    (keymap-set map "<remap> <sql-send-buffer>" #'hellmacs-db-execute-buffer)
    map)
  "Remaps only: sql-mode's `C-c C-c' and `C-c C-b' connect when needed.")

;;;###autoload
(define-minor-mode hellmacs-db-mode
  "Run statements from this sql-mode buffer on the project's JDBC connections."
  :keymap hellmacs-db-mode-map)

;;; tools/db/autoload.el ends here
