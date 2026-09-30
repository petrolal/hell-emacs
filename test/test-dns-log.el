;;; test-dns-log.el --- Tests for the telemetry check's DNS log -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The telemetry check (12.9) runs an editing
;; session where every name looked up reaches this DNS log instead of the
;; internet; its parsing and verdicts need no namespace to test.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load (expand-file-name "integration/dns-log"
                       (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defun test-dns--query (id name)
  "A DNS query message for NAME's A record, with ID (two bytes)."
  (concat id (unibyte-string #x01 #x00 0 1 0 0 0 0 0 0)
          (mapconcat (lambda (label) (concat (unibyte-string (length label)) label))
                     (split-string name "\\.") "")
          (unibyte-string 0 0 1 0 1)))

(ert-deftest test-dns-log/query-name ()
  (should (equal (dns-log-query-name (test-dns--query "\x12\x34" "sessions.bugsnag.com"))
                 "sessions.bugsnag.com"))
  (should (equal (dns-log-query-name (test-dns--query "\0\1" "localhost")) "localhost"))
  ;; Cut short, or not a query: no name.
  (should-not (dns-log-query-name "\1\2\3")))

(ert-deftest test-dns-log/answers-no-such-host ()
  "Every name gets `no such host' (NXDOMAIN), at once: a lookup fails fast, and
nothing is reached."
  (let* ((query (test-dns--query "\x12\x34" "repo.maven.apache.org"))
         (reply (dns-log-reply query)))
    (should (equal (substring reply 0 2) "\x12\x34"))   ; its id
    (should (= (logand (aref reply 2) #x80) #x80))      ; a response
    (should (= (logand (aref reply 3) #x0f) 3))         ; NXDOMAIN
    (should (equal (substring reply 4 6) "\0\1"))       ; the question, echoed
    (should (equal (substring reply 6 12) "\0\0\0\0\0\0"))
    (should (equal (substring reply 12) (substring query 12)))))

(ert-deftest test-dns-log/allowed-hosts ()
  "A name is allowed when it's a repository builds name, or one of your mirrors'
hosts; anything else (telemetry) isn't."
  (let ((allowed (dns-log-allowed-hosts '(("https://repo1.maven.org/maven2/" . "https://art.corp.example/central/")))))
    (dolist (host `("repo.maven.apache.org" "repo1.maven.org" "plugins.gradle.org" "services.gradle.org"
                    "repo.clojars.org" "art.corp.example" "localhost"
                    ;; The machine's own name: a JVM's InetAddress.getLocalHost.
                    ,(system-name)))
      (should (dns-log-allowed-p host allowed)))
    (dolist (host '("sessions.bugsnag.com" "notify.bugsnag.com" "api.segment.io" "github.com"))
      (should-not (dns-log-allowed-p host allowed)))))

(ert-deftest test-dns-log/servers-missing ()
  "The session only counts when every enabled language's server started: a
server that never ran looked nothing up, and would pass unchecked."
  (should-not (dns-log-servers-missing '((:lang . java) (:lang . yaml))
                                       '((:lang . yaml) (:lang . java))))
  (should (equal (dns-log-servers-missing '((:lang . java) (:lang . kotlin) (:lang . yaml))
                                          '((:lang . java)))
                 '((:lang . kotlin) (:lang . yaml))))
  ;; Nothing enabled is not a session.
  (should (eq (dns-log-servers-missing nil nil) 'none-enabled)))

(provide 'test-dns-log)
;;; test-dns-log.el ends here
