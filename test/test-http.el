;;; test-http.el --- Tests for :tools http (Phase 12.6) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. Requests against a real server are
;; checked by hand (see docs/roadmap.md, 12.6).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-sync)

(defvar restclient-var-defaults)
(defvar restclient-current-env-name)
(defvar hellmacs-http--chosen)

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools (http +httpyac)))
  (hellmacs-module--load '(:tools . http) "autoload.el")
  (hellmacs-module--load '(:tools . http) "config.el")
  (hellmacs-module--load '(:tools . http) "cli.el"))

(defmacro test-http--with-tree (files &rest body)
  "Run BODY in a temporary directory ROOT holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-http" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
           (kill-buffer b)))
       (delete-directory root t))))

(defconst test-http--file
  "@base = /api

### Login
# @name login
POST {{host}}{{base}}/login
Content-Type: application/json

{\"password\": \"{{password}}\"}

> {%
  client.global.set(\"token\", response.body.token);
%}

### Me
GET {{host}}{{base}}/me HTTP/1.1
Authorization: Bearer {{token}}

>> me.json
")

(ert-deftest test-http/parse-http-request-block ()
  "Parses standard IntelliJ .http / REST Client request syntax."
  (let ((request-block "### Get User Details
GET https://api.example.com/users/42
Accept: application/json
Authorization: Bearer {{token}}

### Create User
POST https://api.example.com/users
Content-Type: application/json

{
  \"name\": \"Hellmacs Developer\",
  \"email\": \"dev@hellmacs.org\"
}"))
    (with-temp-buffer
      (insert request-block)
      (let ((requests (hellmacs-http-parse-requests (current-buffer))))
        (should (= (length requests) 2))
        (let ((r1 (nth 0 requests))
              (r2 (nth 1 requests)))
          (should (equal (plist-get r1 :name) "Get User Details"))
          (should (equal (plist-get r1 :method) "GET"))
          (should (equal (plist-get r1 :url) "https://api.example.com/users/42"))
          (should (equal (plist-get r2 :name) "Create User"))
          (should (equal (plist-get r2 :method) "POST")))))))

(ert-deftest test-http/parse-intellij-details ()
  "`# @name' names a request; the HTTP version isn't part of the URL; handlers are noted."
  (with-temp-buffer
    (insert test-http--file)
    (let ((requests (hellmacs-http-parse-requests (current-buffer))))
      (should (= (length requests) 2))
      (should (equal (plist-get (nth 0 requests) :name) "login"))
      (should (plist-get (nth 0 requests) :handler))
      (should (equal (plist-get (nth 1 requests) :url) "{{host}}{{base}}/me"))
      (should (plist-get (nth 1 requests) :handler))
      (should (= (line-number-at-pos (plist-get (nth 1 requests) :position)) 15)))))

(ert-deftest test-http/environments ()
  "IntelliJ's env files: found up the tree, private over public, env over $shared."
  (test-http--with-tree
      '(("http-client.env.json" . "{\"$shared\": {\"host\": \"http://shared\", \"v\": \"1\"},
 \"dev\": {\"host\": \"http://localhost:8080\", \"user\": \"ann\"},
 \"prod\": {\"host\": \"https://api.example.com\"}}")
        ("http-client.private.env.json" . "{\"dev\": {\"password\": \"s3cret\", \"user\": \"bob\"}}")
        ("requests/api.http" . "GET {{host}}/x\n"))
    (let ((dir (expand-file-name "requests/" root)))
      (should (equal (hellmacs-http-environments dir) '("dev" "prod")))
      (let ((vars (hellmacs-http-environment-vars dir "dev")))
        (should (equal (cdr (assoc "host" vars)) "http://localhost:8080"))
        (should (equal (cdr (assoc "password" vars)) "s3cret"))
        (should (equal (cdr (assoc "user" vars)) "bob"))
        (should (equal (cdr (assoc "v" vars)) "1")))
      (should (equal (cdr (assoc "host" (hellmacs-http-environment-vars dir "prod")))
                     "https://api.example.com"))))
  (test-http--with-tree '(("api.http" . "GET http://x\n"))
    (should-not (hellmacs-http-environments root))))

(ert-deftest test-http/select-environment ()
  "Choosing an environment hands its variables to restclient."
  (test-http--with-tree '(("http-client.env.json" . "{\"dev\": {\"host\": \"http://localhost:8080\"}}")
                          ("api.http" . "GET {{host}}/x\n"))
    (let ((restclient-var-defaults nil) (restclient-current-env-name nil))
      (with-current-buffer (find-file-noselect (expand-file-name "api.http" root))
        (hellmacs-http-select-environment "dev")
        (should (equal restclient-current-env-name "dev"))
        (should (equal (cdr (assoc "host" restclient-var-defaults)) "http://localhost:8080"))))))

(ert-deftest test-http/environment-per-project ()
  "An environment chosen in one project is every .http file's there, and no
other project's: each has its own http-client.env.json."
  (test-http--with-tree '(("a/http-client.env.json" . "{\"dev\": {\"host\": \"http://a\"}}")
                          ("a/one.http" . "GET {{host}}/x\n") ("a/two.http" . "GET {{host}}/y\n")
                          ("b/http-client.env.json" . "{\"dev\": {\"host\": \"http://b\"}}")
                          ("b/api.http" . "GET {{host}}/z\n"))
    (let ((restclient-var-defaults nil) (restclient-current-env-name nil)
          (hellmacs-http--chosen nil) (sent nil))
      (cl-letf (((symbol-function 'restclient-http-send-current)
                 (lambda (&rest _) (push (cons restclient-current-env-name
                                               (cdr (assoc "host" restclient-var-defaults)))
                                         sent))))
        (with-current-buffer (find-file-noselect (expand-file-name "a/one.http" root))
          (hellmacs-http-select-environment "dev"))
        (with-current-buffer (find-file-noselect (expand-file-name "a/two.http" root))
          (goto-char (point-min))
          (hellmacs-http-send-request))
        (with-current-buffer (find-file-noselect (expand-file-name "b/api.http" root))
          (goto-char (point-min))
          (hellmacs-http-send-request)))
      (should (equal (reverse sent) '(("dev" . "http://a") (nil . nil))))
      ;; Nothing global changed.
      (should-not (default-value 'restclient-var-defaults))
      (should-not (default-value 'restclient-current-env-name)))))

(ert-deftest test-http/dynamic-variables ()
  "IntelliJ's and REST Client's dynamic variables, fresh for each request."
  (let ((vars (hellmacs-http--dynamic-vars)))
    (should (string-match-p "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-4[0-9a-f]\\{3\\}-[89ab][0-9a-f]\\{3\\}-[0-9a-f]\\{12\\}\\'"
                            (cdr (assoc "$uuid" vars))))
    (should (equal (cdr (assoc "$random.uuid" vars)) (cdr (assoc "$uuid" vars))))
    (should (string-match-p "\\`[0-9]+\\'" (cdr (assoc "$timestamp" vars))))
    (should (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T" (cdr (assoc "$isoTimestamp" vars))))
    (should (string-match-p "\\`[0-9]+\\'" (cdr (assoc "$randomInt" vars))))
    (should (assoc "$guid" vars))
    (should-not (equal (cdr (assoc "$uuid" vars)) (cdr (assoc "$uuid" (hellmacs-http--dynamic-vars)))))))

(ert-deftest test-http/handlers-stripped ()
  "Response handlers and output redirections never go out as the body."
  (with-temp-buffer
    (insert test-http--file)
    (let ((skipped (hellmacs-http--strip-handlers)))
      (should (= skipped 2))
      (should-not (string-search "client.global" (buffer-string)))
      (should-not (string-search ">> me.json" (buffer-string)))
      (should (string-search "{\"password\": \"{{password}}\"}" (buffer-string)))
      ;; Line count is kept, so a request stays on its line.
      (should (= (count-lines (point-min) (point-max))
                 (with-temp-buffer (insert test-http--file) (count-lines (point-min) (point-max))))))))

(ert-deftest test-http/send-request ()
  "C-c C-c sends the request at point through restclient, without its handler."
  (let (sent)
    (cl-letf (((symbol-function 'restclient-http-send-current)
               (lambda (&rest _)
                 (setq sent (list (buffer-substring-no-properties (line-beginning-position) (line-end-position))
                                  (buffer-string))))))
      (with-temp-buffer
        (insert test-http--file)
        (goto-char (point-min))
        (search-forward "GET {{host}}")
        (forward-line 1)                ; on the header: still the Me request
        (hellmacs-http-send-request)
        (should (string-prefix-p "Authorization:" (car sent)))
        (should-not (string-search "client.global" (cadr sent)))
        (should (string-search "@base = /api" (cadr sent)))))))

(ert-deftest test-http/send-keeps-one-copy ()
  "Sending from many .http files keeps one hidden copy to send from, not one
per file, each holding its whole text."
  (let ((copies (lambda () (seq-filter (lambda (b) (string-prefix-p " *http" (buffer-name b)))
                                       (buffer-list))))
        (buffers nil))
    (mapc #'kill-buffer (funcall copies))
    (unwind-protect
        (cl-letf (((symbol-function 'restclient-http-send-current) #'ignore))
          (dolist (name '("a.http" "b.http" "c.http"))
            (with-current-buffer (generate-new-buffer name)
              (push (current-buffer) buffers)
              (insert "GET https://example.invalid/\n")
              (goto-char (point-min))
              (hellmacs-http-send-request)))
          (should (= (length (funcall copies)) 1)))
      (mapc #'kill-buffer buffers)
      (mapc #'kill-buffer (funcall copies)))))

(ert-deftest test-http/keys-and-files ()
  (should (eq (keymap-lookup hellmacs-http-mode-map "C-c C-c") #'hellmacs-http-send-request))
  (should (eq (keymap-lookup hellmacs-http-mode-map "C-c C-e") #'hellmacs-http-select-environment))
  (should (eq (keymap-lookup hellmacs-http-mode-map "C-c C-a") #'hellmacs-http-run-file))
  (should (eq (keymap-lookup hellmacs-http-mode-map "C-c C-l") #'hellmacs-http-run-request))
  (dolist (file '("/p/api.http" "/p/requests/users.rest"))
    (should (eq (assoc-default file auto-mode-alist #'string-match-p) 'hellmacs-http-mode))))

(ert-deftest test-http/httpyac ()
  "+httpyac: pinned by lockfile; it runs the file or the request at point, in the env chosen."
  (let ((lock (expand-file-name "modules/tools/http/package-lock.json" hellmacs-dir)))
    (should (file-exists-p lock))
    (should (string-search (format "\"version\": \"%s\"" hellmacs-http-httpyac-version)
                           (with-temp-buffer (insert-file-contents lock) (buffer-string)))))
  (let ((restclient-current-env-name "dev"))
    (should (equal (hellmacs-http--httpyac-command "/p/api.http")
                   (list hellmacs-http-httpyac-executable "send" "/p/api.http" "--all"
                         "--no-color" "-o" "response" "--env" "dev")))
    (should (equal (hellmacs-http--httpyac-command "/p/api.http" 15)
                   (list hellmacs-http-httpyac-executable "send" "/p/api.http" "--line" "15"
                         "--no-color" "-o" "response" "--env" "dev"))))
  (let ((restclient-current-env-name nil))
    (should-not (member "--env" (hellmacs-http--httpyac-command "/p/api.http"))))
  (let (installs)
    (cl-letf (((symbol-function 'hellmacs-sync-npm-install) (lambda (&rest args) (push args installs)))
              ((symbol-function 'hellmacs-sync--log) #'ignore)
              ((symbol-function 'hellmacs-npm-installed-p) #'ignore))
      (hellmacs-http-sync-install)
      (should (equal (car (car installs)) "httpyac")))))

(provide 'test-http)
;;; test-http.el ends here
