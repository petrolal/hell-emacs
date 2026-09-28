;;; spring-e2e.el --- End-to-end check of Spring Boot's language server -*- lexical-binding: t; -*-

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

;; Phase 12.4's Spring Boot language server (:lang java +spring), on the
;; spring-demo fixture: it starts beside JDTLS, completes and checks
;; properties in application.yml and application.properties, and knows the
;; request mappings and beans.
;;
;; It needs a synced profile with (java +spring), and network access on the
;; first run (Maven fetches Spring Boot):
;;
;;   emacs --batch -l early-init.el -l init.el -l test/integration/spring-e2e.el
;;
;; The fixture is copied to a temporary directory, deleted at exit
;; (HELLMACS_E2E_KEEP=1 keeps it). Exits 1 if any check fails.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defun e2e--boot-ws ()
  (lsp-find-workspace 'boot-ls nil))

(defun e2e--labels-at-point ()
  "The completion labels the servers offer at point."
  (ignore-errors
    (e2e-completion-items
     (lsp-request "textDocument/completion" (lsp--text-document-position-params)))))

(defun e2e--offers (label-regexp)
  "Wait until completion at point offers a label matching LABEL-REGEXP."
  (e2e--wait (lambda ()
               (seq-some (lambda (item)
                           (string-match-p label-regexp (lsp-get item :label)))
                         (e2e--labels-at-point)))
             180))

(defun e2e--diagnostic (regexp)
  "Wait until this buffer has a diagnostic whose message matches REGEXP."
  (e2e--wait (lambda ()
               (seq-some (lambda (d) (string-match-p regexp (lsp-get d :message)))
                         (gethash (lsp--fix-path-casing buffer-file-name)
                                  (lsp-diagnostics t))))
             180))

(defun e2e--symbols (query)
  "Spring Boot's workspace symbols for QUERY, as their names."
  (with-lsp-workspace (e2e--boot-ws)
    (mapcar (lambda (s) (lsp-get s :name))
            (append (lsp-request "workspace/symbol" (list :query query)) nil))))

(let* ((proj (e2e-copy-fixture "java/spring-demo"))
       (resources (expand-file-name "src/main/resources/" proj))
       (app (expand-file-name "src/main/java/dev/hellmacs/spring/DemoApplication.java" proj)))
  (e2e--say "Hellmacs Spring Boot end-to-end, in %s" proj)
  (with-temp-file (expand-file-name "application.properties" resources)
    (insert "spring.main.banner-mode=off\n"))

  (e2e--say "\n== 12.4 :lang java +spring")
  (switch-to-buffer (find-file-noselect app))
  (e2e-check "the pinned Spring Boot server is installed"
    (hellmacs-jvm-spring-installed-p))
  (e2e-check "JDTLS imports the project"
    (e2e-add-project proj)
    (lsp)
    (e2e--wait (lambda () (eq (hellmacs-jvm-state proj) 'ready)) 600))
  (e2e-check "JDTLS got Spring Tools' extensions"
    (seq-some (lambda (jar) (string-suffix-p "jdt-ls-extension.jar" jar)) lsp-java-bundles))
  (e2e-check "the Spring Boot server starts beside it, on a JDK JDTLS runs on"
    (and (e2e--wait #'e2e--boot-ws 120)
         (let* ((java (car (process-command (lsp--workspace-proc (e2e--boot-ws)))))
                (major (hellmacs-jdk-home-major
                        (file-name-directory (directory-file-name (file-name-directory java))))))
           (e2e--say "    its java: %s (JDK %s)" java major)
           (and major (<= hellmacs-jvm-jdtls-java-min major hellmacs-jvm-jdtls-java-max)))))

  (with-current-buffer (find-file-noselect (expand-file-name "application.yml" resources))
    (e2e-check "application.yml: yaml-mode, the Spring server, its language id"
      (and (derived-mode-p 'yaml-mode)
           lsp--buffer-deferred         ; our hook asked for lsp...
           (progn (lsp) t)              ; ...but `lsp-deferred' waits for a redisplay
           (e2e--wait (lambda () (memq (e2e--boot-ws) (lsp-workspaces))) 120)
           (equal (lsp-buffer-language) "spring-boot-properties-yaml")))
    (e2e-check "application.yml completes Spring Boot properties (server.po -> port)"
      (goto-char (point-max))
      (insert "  po")
      (prog1 (e2e--offers "\\`port")
        (delete-char -4)))
    (e2e-check "and reports one that doesn't exist"
      (goto-char (point-max))
      (insert "  no-such-property: 1\n")
      (prog1 (e2e--diagnostic "no-such-property")
        (forward-line -1) (delete-region (point) (point-max))
        (save-buffer))))

  (with-current-buffer (find-file-noselect (expand-file-name "application.properties" resources))
    (e2e-check "application.properties: the Spring server, its language id"
      (and lsp--buffer-deferred
           (progn (lsp) t)
           (e2e--wait (lambda () (memq (e2e--boot-ws) (lsp-workspaces))) 120)
           (equal (lsp-buffer-language) "spring-boot-properties")))
    (e2e-check "application.properties completes them too (server.por -> server.port)"
      (goto-char (point-max))
      (insert "server.por")
      (prog1 (e2e--offers "\\`server\\.port")
        (delete-char -10))))

  (switch-to-buffer (find-file-noselect app))
  (e2e-check "request mappings are workspace symbols (@/): /hello"
    (e2e--wait (lambda ()
                 (let ((names (e2e--symbols "@/")))
                   (when names (e2e--say "    %S" names))
                   (seq-some (lambda (n) (string-match-p "/hello" n)) names)))
               180))
  (e2e-check "and beans (@+): greetingController"
    (e2e--wait (lambda () (seq-some (lambda (n) (string-match-p "greetingController" n))
                                    (e2e--symbols "@+")))
               60))

  (e2e--say "\n== 12.4 Profiles (with :tools run)")
  (if (not (fboundp 'hellmacs-run-configurations))
      (e2e--say "  skipped: :tools run isn't enabled")
    (make-directory (expand-file-name ".hellmacs" proj) t)
    (with-temp-file (expand-file-name ".hellmacs/run.eld" proj)
      ;; A random port: the dev profile's own (8081) may be taken.
      (insert "((:name \"Boot\" :task \"spring-boot:run\" :args (\"--server.port=0\")))\n"))
    (let ((default-directory proj))
      (e2e-check "the run list offers the configuration once more per profile: Boot [dev]"
        (equal (mapcar (lambda (c) (plist-get c :name)) (hellmacs-run-configurations))
               '("Boot" "Boot [dev]")))
      (e2e-check "Boot [dev] starts the application with the dev profile active"
        (let ((buffer (hellmacs-run-config
                       (seq-find (lambda (c) (equal (plist-get c :name) "Boot [dev]"))
                                 (hellmacs-run-configurations)))))
          (prog1 (e2e--wait (lambda ()
                              (with-current-buffer buffer
                                (save-excursion
                                  (goto-char (point-min))
                                  (re-search-forward "profile is active: \"dev\"" nil t))))
                            300)
            (when-let* ((process (get-buffer-process buffer)))
              (interrupt-process process)
              (e2e--wait (lambda () (not (process-live-p process))) 30)))))))

  (unless (getenv "HELLMACS_E2E_KEEP")
    (delete-directory (file-name-directory (directory-file-name proj)) t)))

(e2e--say "\n%s" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)))
(kill-emacs (if (zerop e2e--failures) 0 1))

;;; spring-e2e.el ends here
