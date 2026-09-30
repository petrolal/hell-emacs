;;; test-net.el --- Tests for lisp/lib/net.el -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(hellmacs-require 'hellmacs-lib 'net)
(require 'hellmacs-sync)                ; `hellmacs-sync-download-verified'

(defmacro test-net--with (settings &rest body)
  "Run BODY with the network SETTINGS (a let list) and a clean environment."
  (declare (indent 1))
  `(let ((hellmacs-proxy nil) (hellmacs-no-proxy nil) (hellmacs-ca-bundle nil) (hellmacs-mirrors nil)
         (process-environment (seq-remove (lambda (e) (string-match-p "\\`\\(?:[Hh][Tt][Tt][Pp][Ss]?_[Pp][Rr][Oo][Xx][Yy]\\|[Nn][Oo]_[Pp][Rr][Oo][Xx][Yy]\\|GIT_CONFIG_\\)" e))
                                          process-environment)))
     (let ,settings ,@body)))

(ert-deftest test-net/mirrors ()
  (test-net--with ((hellmacs-mirrors '(("https://github.com/" . "https://git.corp.example/github/")
                                       ("https://repo1.maven.org/maven2/" . "https://art.corp.example/central/"))))
    (should (equal (hellmacs-net-rewrite "https://github.com/fwcd/kotlin-language-server/releases/x.zip")
                   "https://git.corp.example/github/fwcd/kotlin-language-server/releases/x.zip"))
    (should (equal (hellmacs-net-rewrite "https://repo1.maven.org/maven2/org/x/1/x-1.jar")
                   "https://art.corp.example/central/org/x/1/x-1.jar"))
    (should (equal (hellmacs-net-rewrite "https://download.eclipse.org/jdtls/x.tar.gz")
                   "https://download.eclipse.org/jdtls/x.tar.gz"))
    ;; url.el is only redirected while Hellmacs fetches.
    (should (equal (hellmacs-net--mirror-a '("https://github.com/a" cb)) '("https://github.com/a" cb)))
    (with-hellmacs-network
      (should (equal (hellmacs-net--mirror-a '("https://github.com/a" cb))
                     '("https://git.corp.example/github/a" cb))))))

(ert-deftest test-net/proxy-settings ()
  (test-net--with ()
    (should-not (hellmacs-net-proxy))
    (setenv "HTTPS_PROXY" "http://env-proxy:8080")
    (setenv "NO_PROXY" "localhost, .corp.example")
    (should (equal (hellmacs-net-proxy) "http://env-proxy:8080"))
    (should (equal (hellmacs-net-no-proxy) '("localhost" ".corp.example")))
    (let ((hellmacs-proxy "http://proxy.corp.example:3128")
          (hellmacs-no-proxy '("localhost" "corp.example"))
          (url-proxy-services nil))
      (should (equal (hellmacs-net-proxy) "http://proxy.corp.example:3128"))
      (hellmacs-net-setup)
      (should (equal (alist-get "https" url-proxy-services nil nil #'equal) "proxy.corp.example:3128"))
      (let ((re (alist-get "no_proxy" url-proxy-services nil nil #'equal)))
        (should (string-match-p re "localhost"))
        (should (string-match-p re "corp.example"))
        (should (string-match-p re "git.corp.example"))
        (should-not (string-match-p re "evilcorp.example"))
        (should-not (string-match-p re "github.com"))))))

(ert-deftest test-net/git-sees-the-settings ()
  "Git started inside `with-hellmacs-network' gets the proxy, CA and mirrors; outside, nothing."
  (skip-unless (executable-find "git"))
  (let* ((root (make-temp-file "hellmacs-test-net" t))
         (ca (expand-file-name "corp.pem" root))
         (git-config (lambda (key)
                       (with-temp-buffer
                         (call-process "git" nil t nil "config" "--get" key)
                         (string-trim (buffer-string))))))
    (unwind-protect
        (progn
          (with-temp-file ca (insert "-----BEGIN CERTIFICATE-----\ncorp\n-----END CERTIFICATE-----\n"))
          (test-net--with ((hellmacs-proxy "http://proxy.corp.example:3128")
                           (hellmacs-ca-bundle ca)
                           (hellmacs-mirrors '(("https://github.com/" . "https://git.corp.example/github/")))
                           (hellmacs-net-ca-file (expand-file-name "bundle.pem" root)))
            ;; Another tool's GIT_CONFIG_COUNT entries are kept, and ours follow.
            (setenv "GIT_CONFIG_COUNT" "1")
            (setenv "GIT_CONFIG_KEY_0" "user.name")
            (setenv "GIT_CONFIG_VALUE_0" "someone")
            (should (equal (funcall git-config "http.proxy") ""))
            (with-hellmacs-network
              (should (equal (funcall git-config "http.proxy") "http://proxy.corp.example:3128"))
              (should (equal (funcall git-config "url.https://git.corp.example/github/.insteadOf")
                             "https://github.com/"))
              (should (equal (funcall git-config "user.name") "someone"))
              (let ((bundle (funcall git-config "http.sslCAInfo")))
                (should (equal bundle hellmacs-net-ca-file))
                ;; The system's CAs, then yours.
                (should (string-suffix-p "corp\n-----END CERTIFICATE-----\n\n"
                                         (with-temp-buffer (insert-file-contents bundle) (buffer-string))))))
            (should (equal (funcall git-config "http.proxy") ""))))
      (delete-directory root t))))

(ert-deftest test-net/downloads-go-through-the-mirror ()
  "A pinned download is fetched from its mirror, and still checked."
  (let* ((root (make-temp-file "hellmacs-test-net" t))
         (mirror (file-name-as-directory (expand-file-name "mirror" root)))
         (dest (expand-file-name "out/tool.jar" root)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "org/tool/1" mirror) t)
          (with-temp-file (expand-file-name "org/tool/1/tool.jar" mirror) (insert "jar bytes"))
          (test-net--with ((hellmacs-mirrors `(("https://repo.invalid/maven2/" . ,(concat "file://" mirror)))))
            (hellmacs-sync-download-verified "https://repo.invalid/maven2/org/tool/1/tool.jar" dest
                                             (secure-hash 'sha256 "jar bytes") "tool")
            (should (equal (with-temp-buffer (insert-file-contents dest) (buffer-string)) "jar bytes"))
            (delete-file dest)
            (should-error (hellmacs-sync-download-verified "https://repo.invalid/maven2/org/tool/1/tool.jar" dest
                                                           (make-string 64 ?0) "tool"))
            (should-not (file-exists-p dest))))
      (delete-directory root t))))

(defvar hellmacs-net-curl)

(ert-deftest test-net/downloads-stream-through-curl ()
  "With curl, a download streams to disk, through the mirror, proxy and CA
Hellmacs uses; without it, url.el fetches it."
  (let* ((root (make-temp-file "hellmacs-test-net" t))
         (log (expand-file-name "args" root))
         (curl (expand-file-name "curl" root))
         (ca (expand-file-name "corp.pem" root))
         (dest (expand-file-name "out.jar" root)))
    (unwind-protect
        (progn
          ;; A curl that records its arguments and writes the file it's told to.
          (with-temp-file curl
            (insert "#!/bin/sh\nprintf '%s\\n' \"$@\" > " (shell-quote-argument log) "\n"
                    "while [ $# -gt 0 ]; do [ \"$1\" = --output ] && printf 'bytes' > \"$2\"; shift; done\n"))
          (set-file-modes curl #o755)
          (with-temp-file ca (insert "-----BEGIN CERTIFICATE-----\ncorp\n-----END CERTIFICATE-----\n"))
          (test-net--with ((hellmacs-net-curl curl)
                           (hellmacs-mirrors '(("https://repo.invalid/" . "https://mirror.invalid/")))
                           (hellmacs-proxy "http://proxy.invalid:3128")
                           (hellmacs-no-proxy '(".corp.invalid" "localhost"))
                           (hellmacs-ca-bundle ca)
                           (hellmacs-net-ca-file (expand-file-name "bundle.pem" root)))
            (cl-letf (((symbol-function 'url-copy-file) (lambda (&rest _) (error "Not through url.el"))))
              (hellmacs-net-download "https://repo.invalid/tool.jar" dest))
            (let ((args (with-temp-buffer (insert-file-contents log) (split-string (buffer-string) "\n" t))))
              (should (equal (car (last args)) "https://mirror.invalid/tool.jar"))
              (should (equal (cadr (member "--proxy" args)) "http://proxy.invalid:3128"))
              (should (equal (cadr (member "--noproxy" args)) ".corp.invalid,localhost"))
              (should (equal (cadr (member "--cacert" args)) hellmacs-net-ca-file))
              (should (member "--fail" args)))
            (should (equal (with-temp-buffer (insert-file-contents dest) (buffer-string)) "bytes"))
            ;; A failing curl is an error, naming the URL.
            (with-temp-file curl (insert "#!/bin/sh\necho 'curl: (22) 404' >&2\nexit 22\n"))
            (should (string-match-p "mirror.invalid/tool.jar"
                                    (cadr (should-error (hellmacs-net-download "https://repo.invalid/tool.jar" dest))))))
          ;; No curl: url.el.
          (test-net--with ((hellmacs-net-curl nil))
            (let (fetched)
              (cl-letf (((symbol-function 'url-copy-file) (lambda (url file &rest _) (setq fetched (list url file)))))
                (hellmacs-net-download "https://repo.invalid/tool.jar" dest))
              (should (equal fetched (list "https://repo.invalid/tool.jar" dest)))))
          ;; Offline: nothing is fetched.
          (test-net--with ((hellmacs-net-curl curl) (hellmacs-net-offline t))
            (should-error (hellmacs-net-download "https://repo.invalid/tool.jar" dest))))
      (delete-directory root t))))

(ert-deftest test-net/jvm-options ()
  (test-net--with ((hellmacs-net-truststore (make-temp-name "/nonexistent/store")))
    (should-not (hellmacs-net-jvm-options))
    (let ((hellmacs-proxy "http://proxy.corp.example:3128")
          (hellmacs-no-proxy '(".corp.example")))
      (should (equal (hellmacs-net-jvm-options)
                     '("-Dhttp.proxyHost=proxy.corp.example" "-Dhttp.proxyPort=3128"
                       "-Dhttps.proxyHost=proxy.corp.example" "-Dhttps.proxyPort=3128"
                       "-Dhttp.nonProxyHosts=localhost|127.*|[::1]|*.corp.example"))))
    ;; The truststore only once sync has built it.
    (let ((hellmacs-ca-bundle "/some/ca.pem"))
      (should-not (hellmacs-net-jvm-options))
      (let ((hellmacs-net-truststore (make-temp-file "hellmacs-store")))
        (unwind-protect
            (should (member (concat "-Djavax.net.ssl.trustStore=" hellmacs-net-truststore)
                            (hellmacs-net-jvm-options)))
          (delete-file hellmacs-net-truststore))))))

(ert-deftest test-net/truststore ()
  "The JVMs' truststore holds the JDK's CAs and yours, and is rebuilt when yours changes."
  (skip-unless (and (hellmacs-net-java-home)
                    (file-executable-p (expand-file-name "bin/keytool" (hellmacs-net-java-home)))))
  (let* ((root (make-temp-file "hellmacs-test-store" t))
         (keytool (expand-file-name "bin/keytool" (hellmacs-net-java-home)))
         (ca (expand-file-name "corp.pem" root))
         (list-store (lambda ()
                       (with-temp-buffer
                         (call-process keytool nil t nil "-list" "-keystore" hellmacs-net-truststore
                                       "-storetype" "PKCS12" "-storepass" "changeit")
                         (buffer-string)))))
    (unwind-protect
        (test-net--with ((hellmacs-ca-bundle ca)
                         (hellmacs-net-truststore (expand-file-name "store.p12" root)))
          ;; A CA of our own, made with keytool.
          (call-process keytool nil nil nil "-genkeypair" "-alias" "corp" "-keyalg" "RSA" "-dname" "CN=Test Corp CA"
                        "-keystore" (expand-file-name "ca.p12" root) "-storepass" "secret1" "-validity" "2")
          (call-process keytool nil nil nil "-exportcert" "-rfc" "-alias" "corp" "-file" ca
                        "-keystore" (expand-file-name "ca.p12" root) "-storepass" "secret1")
          (should-not (hellmacs-net-truststore-current-p))
          (hellmacs-net-build-truststore)
          (should (hellmacs-net-truststore-current-p))
          (let ((listing (funcall list-store)))
            (should (string-match-p "^hellmacs-ca-1," listing))
            ;; ...and the JDK's own CAs, many of them.
            (should (string-match "contains \\([0-9]+\\) entr" listing))
            (should (> (string-to-number (match-string 1 listing)) 50)))
          ;; A newer CA file makes it out of date.
          (set-file-times ca (time-add (current-time) 10))
          (should-not (hellmacs-net-truststore-current-p)))
      (delete-directory root t))))

;;; Probing hosts, for doctor --------------------------------------------------

(defmacro test-net--with-fake-proxy (port-var &rest body)
  "Run BODY with a proxy on localhost, its port in PORT-VAR.
It grants a tunnel only to user u, password p, and then speaks no TLS."
  (declare (indent 1))
  `(let* ((server (make-network-process
                   :name "test-net-proxy" :server t :host "127.0.0.1" :service t :noquery t
                   :filter (lambda (proc out)
                             (process-send-string
                              proc (if (string-search (concat "Proxy-Authorization: Basic "
                                                              (base64-encode-string "u:p" t))
                                                      out)
                                       "HTTP/1.1 200 Connection established\r\n\r\n"
                                     "HTTP/1.1 407 Proxy Authentication Required\r\n\r\n")))))
          (,port-var (process-contact server :service)))
     (unwind-protect (progn ,@body)
       (delete-process server))))

(ert-deftest test-net/probe-through-a-proxy ()
  "The probe asks the proxy for a tunnel, with the proxy URL's credentials."
  (test-net--with-fake-proxy port
    (test-net--with ((hellmacs-net-probe-timeout 2))
      (let ((hellmacs-proxy (format "http://127.0.0.1:%d" port)))
        (pcase-let ((`(,step . ,message) (hellmacs-net-probe "https://repo.corp.invalid/")))
          (should (eq step 'proxy))
          (should (string-match-p "407" message))))
      (let ((hellmacs-proxy (format "http://u:p@127.0.0.1:%d" port)))
        ;; Tunnelled: the fake proxy speaking no TLS is the next step's failure.
        (pcase-let ((`(,step . ,message) (hellmacs-net-probe "https://repo.corp.invalid/")))
          (should (eq step 'connect))
          (should (string-match-p "TLS handshake failed" message)))
        ;; Plain http needs only the proxy itself.
        (should-not (hellmacs-net-probe "http://repo.corp.invalid/"))
        ;; No-proxy hosts are reached directly.
        (let ((hellmacs-no-proxy '(".corp.invalid")))
          (should-not (hellmacs-net--proxied-p "repo.corp.invalid"))
          (should (equal (hellmacs-net-probe "https://repo.corp.invalid/")
                         '(connect . "repo.corp.invalid: no such host (DNS)")))))
      (let ((hellmacs-proxy "http://127.0.0.1:1"))
        (should (eq (car (hellmacs-net-probe "https://repo.corp.invalid/")) 'proxy))))))

(ert-deftest test-net/probe-checks-the-certificate ()
  "A server signed by an unknown CA fails the TLS step; with `hellmacs-ca-bundle', it passes."
  (skip-unless (and (executable-find "openssl") (gnutls-available-p)))
  (let* ((root (make-temp-file "hellmacs-test-net" t))
         (cert (expand-file-name "cert.pem" root))
         (key (expand-file-name "key.pem" root))
         (port (+ 20000 (random 20000)))
         server)
    (unwind-protect
        (progn
          (should (zerop (call-process "openssl" nil nil nil "req" "-x509" "-newkey" "rsa:2048" "-nodes"
                                       "-keyout" key "-out" cert "-days" "1" "-subj" "/CN=127.0.0.1"
                                       "-addext" "subjectAltName=DNS:localhost,IP:127.0.0.1"
                                       "-addext" "basicConstraints=critical,CA:TRUE")))
          (setq server (start-process "test-net-tls" nil "openssl" "s_server" "-quiet"
                                      "-accept" (format "127.0.0.1:%d" port) "-cert" cert "-key" key))
          (sleep-for 0.8)
          (test-net--with ((hellmacs-net-probe-timeout 5))
            (let ((url (format "https://127.0.0.1:%d/" port)))
              (should (eq (car (hellmacs-net-probe url)) 'tls))
              (let ((hellmacs-ca-bundle cert))
                (should-not (hellmacs-net-probe url))))))
      (when server (delete-process server))
      (delete-directory root t))))

(provide 'test-net)
;;; test-net.el ends here
