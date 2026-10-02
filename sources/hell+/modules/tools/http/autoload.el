;;; tools/http/autoload.el -*- lexical-binding: t; -*-

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


;; IntelliJ's HTTP Client files (.http, shared with VS Code's REST Client),
;; sent by restclient.el, extended where it falls short of the format:
;; - environments from http-client.env.json and http-client.private.env.json
;;   (found from the file's directory up; private over public, and each
;;   environment over `$shared');
;; - dynamic variables: {{$uuid}}, {{$timestamp}}, {{$isoTimestamp}},
;;   {{$randomInt}}, {{$random.uuid}}, {{$guid}};
;; - JavaScript response handlers (`> {% ... %}') and `>> file' lines are
;;   left out of what's sent (restclient would send them as the body);
;;   with +httpyac, `C-c C-l' / `C-c C-a' run them for real.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(hell-module-load "+paths")

(defvar restclient-var-defaults)
(defvar restclient-current-env-name)
(defvar restclient-current-env-file)
(defvar hell-net-ca-file)
(declare-function restclient-http-send-current "restclient")
(declare-function project-root "project")
(declare-function hell-net-ca-file "../../../lisp/lib/net")

;;; Reading a file's requests ---------------------------------------------------

(defconst hell-http--method-regexp
  (concat "^[ \t]*\\(GET\\|POST\\|PUT\\|PATCH\\|DELETE\\|HEAD\\|OPTIONS\\|TRACE\\|CONNECT\\|QUERY\\)"
          "[ \t]+\\(\\S-+\\)\\(?:[ \t]+HTTP/[0-9.]+\\)?[ \t]*$")
  "A request line: method, URL, and an optional HTTP version.")

(defconst hell-http--handler-regexp "^>>!?[ \t]\\|^>[ \t]*\\(?:{%\\|\\S-\\)"
  "A response handler (`> {% ... %}', `> script.js') or redirection (`>> file').")

;;;###autoload
(defun hell-http-parse-requests (&optional buffer)
  "The requests in BUFFER (an .http file): plists of :name :method :url :position :handler.
A request is named by `# @name NAME', else by its `###' line. :position is
its request line; :handler is non-nil if it has a response handler or
output redirection, which restclient doesn't run."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let (requests current label)
          (while (not (eobp))
            (cond ((looking-at "^###[ \t]*\\(.*?\\)[ \t]*$")
                   (when current (push current requests))
                   (setq current nil
                         label (let ((text (match-string-no-properties 1))) (and (not (string-empty-p text)) text))))
                  ((looking-at "^\\(?:#\\|//\\)[ \t]*@name[ \t]+\\(\\S-+\\)")
                   (if current (plist-put current :name (match-string-no-properties 1))
                     (setq label (match-string-no-properties 1))))
                  ((and (not current) (looking-at hell-http--method-regexp))
                   (setq current (list :name label
                                       :method (match-string-no-properties 1)
                                       :url (match-string-no-properties 2)
                                       :position (line-beginning-position)
                                       :handler nil)))
                  ((and current (looking-at hell-http--handler-regexp))
                   (plist-put current :handler t)))
            (forward-line 1))
          (when current (push current requests))
          (nreverse requests))))))

(defun hell-http--request-at-point ()
  "The request around point, or nil."
  (let ((pos (point)))
    (car (last (seq-filter (lambda (r) (<= (save-excursion (goto-char (plist-get r :position))
                                                           (line-beginning-position))
                                           (max pos (save-excursion (goto-char pos) (line-end-position)))))
                           (hell-http-parse-requests))))))

;;; Environments: http-client.env.json ---------------------------------------------

(defconst hell-http--env-files '("http-client.env.json" "http-client.private.env.json")
  "IntelliJ's environment files: the shared one, then the private one (not committed).")

(defun hell-http--env-dir (dir)
  "The nearest directory from DIR up with an environment file, or nil."
  (locate-dominating-file dir (lambda (d) (seq-some (lambda (f) (file-exists-p (expand-file-name f d)))
                                                     hell-http--env-files))))

(defun hell-http--read-env-file (file)
  "FILE's environments: an alist of (NAME . ((VAR . VALUE) ...)), in order."
  (when (file-readable-p file)
    (let ((json (with-temp-buffer
                  (insert-file-contents file)
                  (json-parse-buffer :object-type 'alist :null-object nil :false-object "false"))))
      (mapcar (lambda (env)
                (cons (symbol-name (car env))
                      (mapcar (lambda (var)
                                (cons (symbol-name (car var))
                                      (let ((value (cdr var))) (if (stringp value) value (format "%s" value)))))
                              (and (listp (cdr env)) (cdr env)))))
              json))))

(defun hell-http--env-data (dir)
  "The public and private environment files' contents, from DIR's env directory."
  (when-let* ((env-dir (hell-http--env-dir dir)))
    (mapcar (lambda (f) (hell-http--read-env-file (expand-file-name f env-dir))) hell-http--env-files)))

;;;###autoload
(defun hell-http-environments (dir)
  "The environments DIR's http-client.env.json files define, `$shared' aside."
  (seq-uniq (seq-remove (lambda (name) (equal name "$shared"))
                        (mapcar #'car (apply #'append (hell-http--env-data dir))))))

;;;###autoload
(defun hell-http-environment-vars (dir name)
  "The variables of environment NAME for .http files in DIR, as ((VAR . VALUE) ...).
The private file's over the public one's, and NAME's over `$shared''s."
  (pcase-let ((`(,public ,private) (hell-http--env-data dir)))
    (let (vars)
      (dolist (source (list (cdr (assoc name private)) (cdr (assoc name public))
                            (cdr (assoc "$shared" private)) (cdr (assoc "$shared" public))))
        (dolist (var source)
          (unless (assoc (car var) vars) (push var vars))))
      (nreverse vars))))

(defvar hell-http--chosen nil
  "Alist: a directory with http-client.env.json files -> the environment chosen there.
Every .http file under it uses that one; other projects have their own.")

(defun hell-http--use-environment ()
  "Give this buffer the environment chosen for its project, read afresh; return its name.
restclient's variables are set buffer-locally, never for every .http file."
  (let* ((dir (hell-http--env-dir default-directory))
         (name (and dir (cdr (assoc (expand-file-name dir) hell-http--chosen)))))
    (setq-local restclient-current-env-file nil ; restclient's own reload doesn't know the private file
                restclient-current-env-name name
                restclient-var-defaults (and name (hell-http-environment-vars default-directory name)))
    name))

;;;###autoload
(defun hell-http-select-environment (name)
  "Use environment NAME from the http-client.env.json files near this file.
For every .http file of the project (under the same env files)."
  (interactive
   (let ((names (or (hell-http-environments default-directory)
                    (user-error "No http-client.env.json here or above"))))
     (list (completing-read "Environment: " names nil t nil nil (hell-http--use-environment)))))
  (let ((dir (or (hell-http--env-dir default-directory)
                 (user-error "No http-client.env.json here or above"))))
    (setf (alist-get (expand-file-name dir) hell-http--chosen nil nil #'equal) name))
  (hell-http--use-environment)
  (message "Environment \"%s\" (%d variables)" name (length restclient-var-defaults)))

(defun hell-http-reload-environment ()
  "Read the chosen environment's files again."
  (interactive)
  (let ((name (or (hell-http--use-environment)
                  (user-error "No environment chosen yet (C-c C-e)"))))
    (message "Environment \"%s\" (%d variables)" name (length restclient-var-defaults))))

;;; Dynamic variables --------------------------------------------------------------

(defun hell-http--uuid ()
  "A random (version 4) UUID."
  (format "%08x-%04x-4%03x-%x%03x-%012x"
          (random (ash 1 32)) (random (ash 1 16)) (random (ash 1 12))
          (+ 8 (random 4)) (random (ash 1 12)) (random (ash 1 48))))

(defun hell-http--dynamic-vars ()
  "IntelliJ's and REST Client's dynamic variables, with fresh values."
  (let ((uuid (hell-http--uuid)))
    `(("$uuid" . ,uuid) ("$random.uuid" . ,uuid) ("$guid" . ,uuid)
      ("$timestamp" . ,(format-time-string "%s"))
      ("$isoTimestamp" . ,(format-time-string "%FT%T.%3NZ" nil t))
      ("$randomInt" . ,(number-to-string (random 1001))))))

;;;###autoload
(defun hell-http--add-dynamic-vars-a (vars)
  "VARS, then the dynamic variables (the file's own definitions win).
Around `restclient-find-vars-before-point'."
  (append vars (hell-http--dynamic-vars)))

;;; Sending ------------------------------------------------------------------------

(defun hell-http--strip-handlers ()
  "Turn this buffer's response handlers and redirections into comment lines.
Lines are kept, so each request stays where it was; a comment ends a
request's body in restclient. Returns how many were turned."
  (save-excursion
    (let (ranges)
      ;; First find them all (as line numbers), then rewrite those lines.
      (goto-char (point-min))
      (while (re-search-forward hell-http--handler-regexp nil t)
        (let ((first (line-number-at-pos)))
          (when (save-excursion (beginning-of-line) (looking-at "^>[ \t]*{%"))
            (unless (re-search-forward "%}" nil t) (goto-char (point-max))))
          (push (cons first (line-number-at-pos)) ranges)
          (forward-line 1)))
      (pcase-dolist (`(,first . ,last) ranges)
        (goto-char (point-min))
        (forward-line (1- first))
        (dotimes (_ (1+ (- last first)))
          (delete-region (point) (line-end-position))
          (insert "#")
          (forward-line 1)))
      (length ranges))))

;;;###autoload
(defun hell-http-send-request ()
  "Send the request at point, with restclient.
Its response handler or `>> file' line isn't run (restclient has none);
with +httpyac, `C-c C-l' runs the request with it."
  (interactive)
  (let ((text (buffer-substring-no-properties (point-min) (point-max)))
        (line (line-number-at-pos))
        (column (current-column))
        (dir default-directory)
        (handler (plist-get (hell-http--request-at-point) :handler))
        (env-name (hell-http--use-environment))
        (env-vars restclient-var-defaults)
        ;; One for every file: restclient reads the request from it as it
        ;; sends, and the response comes back in its own buffer.
        (copy (get-buffer-create " *http-send*")))
    (unless (fboundp 'restclient-http-send-current) (require 'restclient))
    (with-current-buffer copy
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text))
      (setq default-directory dir)  ; for `< file' bodies
      (setq-local restclient-current-env-file nil
                  restclient-current-env-name env-name
                  restclient-var-defaults env-vars)
      (hell-http--strip-handlers)
      (goto-char (point-min))
      (forward-line (1- line))
      (move-to-column column)
      (restclient-http-send-current))
    (when handler
      (message "This request's response handler isn't run here%s"
               (if (hell-http--httpyac-p) "; C-c C-l runs it with httpyac" " (+httpyac runs them)")))))

;;; httpyac (+httpyac) ------------------------------------------------------------

(defvar hell-http--httpyac nil
  "Non-nil when the module was enabled with +httpyac.")

(defun hell-http--httpyac-p () hell-http--httpyac)

(defun hell-http--httpyac-command (file &optional line)
  "httpyac's command running FILE's request at LINE, or every request in it."
  `(,hell-http-httpyac-executable "send" ,file
    ,@(if line (list "--line" (number-to-string line)) (list "--all"))
    "--no-color" "-o" "response"
    ,@(and restclient-current-env-name (list "--env" restclient-current-env-name))))

(defun hell-http--run-httpyac (line)
  (unless (hell-http--httpyac-p)
    (user-error "Running handlers needs httpyac: enable :tools (http +httpyac), then `bin/hell sync'"))
  (unless (file-executable-p hell-http-httpyac-executable)
    (user-error "httpyac isn't installed yet; `bin/hell sync' installs it"))
  (save-buffer)
  (hell-http--use-environment)
  (let ((command (mapconcat #'shell-quote-argument (hell-http--httpyac-command buffer-file-name line) " "))
        ;; Your company's CA, for the APIs behind it.
        (process-environment (let ((ca (ignore-errors (hell-net-ca-file))))
                               (if ca (cons (concat "NODE_EXTRA_CA_CERTS=" ca) process-environment)
                                 process-environment))))
    (compilation-start command 'special-mode (lambda (_) "*httpyac*"))))

;;;###autoload
(defun hell-http-run-file ()
  "Run every request in this file with httpyac, handlers and all (+httpyac)."
  (interactive)
  (hell-http--run-httpyac nil))

;;;###autoload
(defun hell-http-run-request ()
  "Run the request at point with httpyac, with its handler (+httpyac)."
  (interactive)
  (let ((request (or (hell-http--request-at-point) (user-error "No request here"))))
    (hell-http--run-httpyac (line-number-at-pos (plist-get request :position)))))

;;; The mode -----------------------------------------------------------------------

(defvar hell-http-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-c" #'hell-http-send-request)
    (keymap-set map "C-c C-e" #'hell-http-select-environment)
    (keymap-set map "C-c M-e" #'hell-http-reload-environment)
    (keymap-set map "C-c C-l" #'hell-http-run-request)
    (keymap-set map "C-c C-a" #'hell-http-run-file)
    map)
  "Keys of `hell-http-mode', over restclient's own.")

(defun hell-http--imenu-index ()
  (mapcar (lambda (r) (cons (or (plist-get r :name) (concat (plist-get r :method) " " (plist-get r :url)))
                            (plist-get r :position)))
          (hell-http-parse-requests)))

;;;###autoload
(define-derived-mode hell-http-mode restclient-mode "HTTP"
  "IntelliJ HTTP Client files (.http), sent with restclient.
\\{hell-http-mode-map}"
  (setq-local imenu-create-index-function #'hell-http--imenu-index))

;;; tools/http/autoload.el ends here
