;;; test-db.el --- Tests for :tools db (Phase 12.6) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. Queries against a real database are
;; checked by hand (see docs/roadmap.md, 12.6).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'sql)
(require 'auth-source)
(require 'hellmacs-modules)
(require 'hellmacs-sync)

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools db))
  (hellmacs-module--load '(:tools . db) "autoload.el")
  (hellmacs-module--load '(:tools . db) "config.el")
  (hellmacs-module--load '(:tools . db) "cli.el"))

(defmacro test-db--with-tree (files &rest body)
  "Run BODY in a temporary directory ROOT holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-db" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (dolist (b (buffer-list))
         (when (or (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
                   (string-prefix-p "*SQL: test" (buffer-name b)))
           (let ((kill-buffer-query-functions nil))
             (when (get-buffer-process b) (delete-process (get-buffer-process b)))
             (kill-buffer b))))
       (delete-directory root t))))

(ert-deftest test-db/connection-profile-parsing ()
  "Generates JDBC / client connection URLs from profile plists."
  (let ((profile '(:name "Local Postgres"
                   :driver postgresql
                   :host "localhost"
                   :port 5432
                   :database "hellmacs_dev"
                   :user "postgres")))
    (should (equal (hellmacs-db-connection-url profile)
                   "jdbc:postgresql://localhost:5432/hellmacs_dev"))))

(ert-deftest test-db/connection-urls-per-driver ()
  "Each driver's URL form, with its default port; an explicit :url wins."
  (pcase-dolist (`(,profile ,url)
                 '(((:driver mysql :host "db" :database "app") "jdbc:mysql://db:3306/app")
                   ((:driver mariadb :host "db" :port 3307 :database "app") "jdbc:mariadb://db:3307/app")
                   ((:driver sqlserver :host "db" :database "app") "jdbc:sqlserver://db:1433;databaseName=app")
                   ((:driver oracle :host "db" :database "ORCLPDB1") "jdbc:oracle:thin:@//db:1521/ORCLPDB1")
                   ((:driver db2 :host "db" :database "SAMPLE") "jdbc:db2://db:50000/SAMPLE")
                   ((:driver h2 :database "mem:test") "jdbc:h2:mem:test")
                   ((:driver sqlite :database "/tmp/app.db") "jdbc:sqlite:/tmp/app.db")
                   ((:driver postgresql :url "jdbc:postgresql://x/y?ssl=true") "jdbc:postgresql://x/y?ssl=true")))
    (should (equal (hellmacs-db-connection-url profile) url)))
  (should-error (hellmacs-db-connection-url '(:driver nosuch :host "x")) :type 'user-error))

(ert-deftest test-db/connections-file ()
  "Connections come from the project's .hellmacs/db.eld; a password in it is refused."
  (test-db--with-tree
      '((".hellmacs/db.eld" . "((:name \"dev\" :driver postgresql :host \"localhost\" :database \"app\" :user \"ann\")
 (:name \"mem\" :driver h2 :database \"mem:t\" :user \"sa\"))")
        ("src/q.sql" . "select 1;\n"))
    (let ((default-directory (expand-file-name "src/" root)))
      (should (equal (mapcar (lambda (c) (plist-get c :name)) (hellmacs-db-connections)) '("dev" "mem")))))
  (test-db--with-tree
      '((".hellmacs/db.eld" . "((:name \"dev\" :driver postgresql :host \"h\" :user \"u\" :password \"oops\"))"))
    (should-error (hellmacs-db-connections) :type 'user-error)))

(ert-deftest test-db/password-from-auth-source ()
  (test-db--with-tree '(("authinfo" . "machine dbhost port 5432 login ann password s3cret\n"))
    (let ((auth-sources (list (expand-file-name "authinfo" root)))
          (auth-source-do-cache nil))
      (should (equal (hellmacs-db--password '(:driver postgresql :host "dbhost" :user "ann")) "s3cret"))
      ;; Nothing stored: asked for, never saved.
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "typed")))
        (should (equal (hellmacs-db--password '(:driver postgresql :host "other" :user "bob")) "typed"))))))

(ert-deftest test-db/command ()
  "sqlline and the driver on the classpath, table output, no password on the command line."
  (let ((command (hellmacs-db--command '(:driver postgresql :host "h" :user "u"))))
    (should (member "sqlline.SqlLine" command))
    (let ((cp (cadr (member "-cp" command))))
      (should (string-search (plist-get (hellmacs-db-jar-spec 'sqlline) :file) cp))
      (should (string-search (plist-get (hellmacs-db-driver-spec 'postgresql) :file) cp)))
    (should (member "--outputformat=table" command))
    (should (seq-some (lambda (arg) (string-prefix-p "--maxWidth=" arg)) command))
    (should-not (seq-some (lambda (arg) (string-search "-p" arg)) (cdr (member "sqlline.SqlLine" command))))))

(ert-deftest test-db/pins ()
  (dolist (spec (cons (hellmacs-db-jar-spec 'sqlline)
                      (mapcar #'hellmacs-db-driver-spec '(postgresql mysql mariadb sqlserver oracle db2 h2 sqlite))))
    (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" (plist-get spec :sha256)))
    (should (string-prefix-p "https://repo1.maven.org/maven2/" (plist-get spec :url)))
    (should (string-match-p (regexp-quote (plist-get spec :version)) (plist-get spec :url)))
    (should (string-prefix-p hellmacs-data-dir (plist-get spec :file)))))

(ert-deftest test-db/connect ()
  "Connecting starts an SQLi buffer and logs in on stdin: the password is never shown."
  (test-db--with-tree '(("fake-sqlline" . "#!/bin/sh\nprintf 'sqlline> '\nexec cat >> \"$HELLMACS_TEST_LOG\"\n"))
    (let* ((log (expand-file-name "stdin.log" root))
           (process-environment (cons (concat "HELLMACS_TEST_LOG=" log) process-environment))
           (fake (expand-file-name "fake-sqlline" root)))
      (set-file-modes fake #o755)
      (cl-letf (((symbol-function 'hellmacs-db--command) (lambda (_) (list fake)))
                ((symbol-function 'hellmacs-db--ensure-jars) #'ignore)
                ((symbol-function 'hellmacs-db--password) (lambda (_) "s3cret")))
        (let ((buffer (hellmacs-db-connect '(:name "test" :driver h2 :database "mem:t" :user "sa"))))
          (should (equal (buffer-name buffer) "*SQL: test*"))
          (with-current-buffer buffer
            (should (derived-mode-p 'sql-interactive-mode))
            (should (eq sql-product 'sqlline)))
          (let ((deadline (+ (float-time) 5)))
            (while (and (< (float-time) deadline)
                        (not (and (file-exists-p log)
                                  (string-search "!connect" (with-temp-buffer (insert-file-contents log) (buffer-string))))))
              (accept-process-output nil 0.1)))
          (should (string-search "!connect jdbc:h2:mem:t sa s3cret"
                                 (with-temp-buffer (insert-file-contents log) (buffer-string))))
          (should-not (string-search "s3cret" (with-current-buffer buffer (buffer-string)))))))))

(ert-deftest test-db/execute ()
  "The statement at point, or the buffer, goes to the connection, ending in `;'."
  (let (sent)
    (cl-letf (((symbol-function 'sql-send-string) (lambda (s) (push s sent)))
              ((symbol-function 'hellmacs-db--ensure-connection) #'ignore))
      (with-temp-buffer
        (sql-mode)
        (insert "select *\nfrom t\nwhere id = 1\n\nupdate t set x = 1;\n")
        (goto-char (point-min))
        (forward-line 1)
        (hellmacs-db-execute-statement)
        (should (equal (car sent) "select *\nfrom t\nwhere id = 1;"))
        (goto-char (point-max))
        (forward-line -1)
        (hellmacs-db-execute-statement)
        (should (equal (car sent) "update t set x = 1;"))
        ;; On the blank line after a statement (just typed it): that statement.
        (goto-char (point-max))
        (hellmacs-db-execute-statement)
        (should (equal (car sent) "update t set x = 1;"))
        (hellmacs-db-execute-buffer)
        (should (equal (car sent) "select *\nfrom t\nwhere id = 1\n\nupdate t set x = 1;"))))))

(ert-deftest test-db/sql-buffer-evaluation ()
  "Verifies SQL query buffer interactive execution keys."
  ;; sql-mode's own keys run Hellmacs' versions: remaps only.
  (should (eq (keymap-lookup hellmacs-db-mode-map "<remap> <sql-send-paragraph>") #'hellmacs-db-execute-statement))
  (should (eq (keymap-lookup hellmacs-db-mode-map "<remap> <sql-send-buffer>") #'hellmacs-db-execute-buffer))
  (map-keymap (lambda (event _) (should (eq event 'remap))) hellmacs-db-mode-map)
  (should (memq #'hellmacs-db-mode (default-value 'sql-mode-hook))))

(ert-deftest test-db/sync-and-drivers-on-demand ()
  (let (downloads)
    (cl-letf (((symbol-function 'hellmacs-sync-download-verified)
               (lambda (url dest sha256 _label) (push (list url sha256) downloads)
                 (make-directory (file-name-directory dest) t) (with-temp-file dest (insert "x"))))
              ((symbol-function 'hellmacs-sync--log) #'ignore)
              ((symbol-function 'hellmacs-file-pinned-p) (lambda (file _) (file-exists-p file))))
      (let* ((tmp (make-temp-file "hellmacs-test-db-jars" t))
             (hellmacs-db-jars (mapcar (lambda (e) (cons (car e) (plist-put (copy-sequence (cdr e)) :file
                                                                           (expand-file-name (format "%s.jar" (car e)) tmp))))
                                       hellmacs-db-jars))
             (hellmacs-db-drivers '(postgresql)))
        (unwind-protect
            (progn
              (hellmacs-db-sync-install)
              (should (= (length downloads) 2)) ; sqlline and PostgreSQL's driver
              (hellmacs-db--ensure-jars '(:driver oracle))
              (should (equal (car downloads) (list (plist-get (hellmacs-db-driver-spec 'oracle) :url)
                                                   (plist-get (hellmacs-db-driver-spec 'oracle) :sha256))))
              (hellmacs-db--ensure-jars '(:driver oracle))
              (should (= (length downloads) 3)))
          (delete-directory tmp t))))))

(ert-deftest test-db/login-quoting ()
  "An empty password is sent as \"\", or sqlline would take the next line for it."
  (should (equal (hellmacs-db--quote "") "\"\""))
  (should (equal (hellmacs-db--quote "s3cret") "s3cret"))
  (should (equal (hellmacs-db--quote "a b\"c") "\"a b\\\"c\"")))

(provide 'test-db)
;;; test-db.el ends here
