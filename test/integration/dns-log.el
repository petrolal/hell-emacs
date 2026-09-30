;;; dns-log.el --- Log every name a session looks up, reaching none -*- lexical-binding: t; -*-

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

;; For the telemetry check (telemetry-e2e.el, 12.9): an editing session
;; runs in a network namespace whose only nameserver is this, on
;; 127.0.0.1:53. Each name looked up (by Emacs, a language server, a build
;; tool) is recorded and answered "no such host", so nothing is reached,
;; and whatever tried to phone home shows up by name.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'url-parse)

(defvar dns-log-names nil
  "The names looked up so far, newest first, each once.")

(defun dns-log-query-name (message)
  "The name MESSAGE, a DNS query, asks about, or nil if it isn't one."
  (when (> (length message) 12)
    (let ((i 12) labels)
      (while (and (< i (length message)) (> (aref message i) 0))
        (let ((n (aref message i)))
          (if (> (+ i 1 n) (length message))
              (setq i (length message) labels nil)
            (push (substring message (1+ i) (+ 1 i n)) labels)
            (setq i (+ i 1 n)))))
      (and labels (downcase (mapconcat #'identity (nreverse labels) "."))))))

(defun dns-log-reply (message)
  "The answer to MESSAGE, a DNS query: its question, and no such host (NXDOMAIN)."
  (let ((reply (concat (substring message 0 2)
                       (unibyte-string (logior #x80 (logand (aref message 2) #x79)) ; a response, RD kept
                                       #x83)                                         ; RA, NXDOMAIN
                       (substring message 4 6)                                       ; one question
                       (unibyte-string 0 0 0 0 0 0)                                  ; no answers
                       (substring message 12))))
    reply))

(defun dns-log-start ()
  "Answer and record DNS queries on 127.0.0.1:53; return the process.
Only works where this Emacs may bind that port: in the check's namespace."
  (setq dns-log-names nil)
  (make-network-process
   :name "dns-log" :type 'datagram :server t :host "127.0.0.1" :service 53
   :coding 'binary :noquery t
   :filter (lambda (proc message)
             (when-let* ((name (dns-log-query-name message)))
               (unless (member name dns-log-names) (push name dns-log-names))
               (process-send-string proc (dns-log-reply message))))))

(defconst dns-log-build-repositories
  '("repo.maven.apache.org" "repo1.maven.org" "central.sonatype.com"
    "plugins.gradle.org" "plugins-artifacts.gradle.org" "services.gradle.org"
    "downloads.gradle.org" "repo.gradle.org"
    "repo.clojars.org" "clojars.org")
  "Hosts a build fetches a project's dependencies (and its tools) from.
Contacting them is the build doing its job, not telemetry.")

(defun dns-log-allowed-hosts (mirrors)
  "The names a session may look up: localhost and this machine's own name (a
JVM's InetAddress.getLocalHost asks), the build repositories, and the hosts
of MIRRORS (`hellmacs-mirrors')."
  (append (list "localhost" (downcase (system-name)))
          dns-log-build-repositories
          (delq nil (mapcar (lambda (m) (url-host (url-generic-parse-url (cdr m)))) mirrors))))

(defun dns-log-allowed-p (name allowed)
  "Non-nil if NAME, a looked-up name, is one of ALLOWED (or under one), in any case."
  (let ((name (downcase name)))
    (seq-some (lambda (host) (or (equal name host) (string-suffix-p (concat "." host) name))) allowed)))

(defun dns-log-servers-missing (enabled started)
  "The modules of ENABLED, in order, whose server isn't in STARTED; nil when
all started, `none-enabled' when ENABLED is empty. A server that never ran
looked nothing up, so its silence proves nothing."
  (if (null enabled)
      'none-enabled
    (seq-remove (lambda (key) (member key started)) enabled)))

(provide 'dns-log)
;;; dns-log.el ends here
