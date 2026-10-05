;;; lisp/lib/net.el --- Proxies, corporate CAs and mirrors -*- lexical-binding: t; -*-

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

;;; Commentary:

;; Every connection Hell Emacs itself makes, set up for a corporate network.
;; In your init.el:
;;
;;   (setq hell-proxy "http://proxy.corp.example:3128")  ; nil: $HTTPS_PROXY, $HTTP_PROXY
;;   (setq hell-no-proxy '("localhost" ".corp.example"))  ; nil: $NO_PROXY
;;   (setq hell-ca-bundle "~/certs/corp-root-ca.pem")     ; your company's root CA
;;   (setq hell-mirrors                                  ; upstream prefix -> mirror prefix
;;         '(("https://github.com/" . "https://git.corp.example/github/")
;;           ("https://repo1.maven.org/maven2/" . "https://artifactory.corp.example/maven-central/")))
;;
;; The proxy and the CA apply to all of Emacs (url.el and GnuTLS): a proxy
;; is how the network works, and trusting one more CA takes nothing away.
;; Mirrors apply only while Hell Emacs itself fetches (`with-hell-network':
;; sync, upgrade, package and server installs), to url.el and to git; they
;; never touch your own repositories. Downloads stay pinned by SHA-256, so a
;; mirror can't serve a different file.
;;
;; Git gets its settings through GIT_CONFIG_* variables (git 2.31+), so the
;; git processes Elpaca starts inherit them: the proxy, a CA bundle (git
;; replaces its trusted CAs with the file it's given, so it gets the system's
;; and yours combined), and each mirror as a `url.<mirror>.insteadOf' rule.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'hell-lib)

(defvar hell-dir)       ; early-init.el
(defvar hell-core-dir)  ; early-init.el
(defvar url-proxy-services)
(defvar gnutls-trustfiles)

(defcustom hell-proxy nil
  "The HTTP(S) proxy, as a URL (\"http://proxy.corp.example:3128\").
nil uses $HTTPS_PROXY or $HTTP_PROXY, as `bin/hell env' saved them."
  :type '(choice (const :tag "From the environment" nil) string)
  :group 'hell)

(defcustom hell-no-proxy nil
  "Hosts reached without `hell-proxy': names, or \".domain\" suffixes.
nil uses $NO_PROXY."
  :type '(repeat string)
  :group 'hell)

(defcustom hell-ca-bundle nil
  "A PEM file with your company's root CA(s), trusted on top of the system's."
  :type '(choice (const nil) file)
  :group 'hell)

(defcustom hell-mirrors nil
  "Alist of (UPSTREAM-PREFIX . MIRROR-PREFIX), for Hell Emacs' own fetches.
A URL starting with UPSTREAM-PREFIX is fetched from MIRROR-PREFIX
instead, with the rest of the URL kept. One table covers Artifactory's
and Nexus' GitHub, Maven and generic remote repositories."
  :type '(alist :key-type string :value-type string)
  :group 'hell)

;;; The settings in effect ------------------------------------------------------

(defun hell-net--getenv (var)
  "The value of environment variable VAR, or nil if it's unset or empty."
  (let ((value (getenv var)))
    (and value (not (string-empty-p value)) value)))

(defun hell-net-proxy ()
  "The proxy URL in use: `hell-proxy', else the environment's, or nil."
  (or hell-proxy
      (seq-some #'hell-net--getenv
                '("HTTPS_PROXY" "https_proxy" "HTTP_PROXY" "http_proxy"))))

(defun hell-net-no-proxy ()
  "The hosts reached directly: `hell-no-proxy', else $NO_PROXY's."
  (or hell-no-proxy
      (when-let* ((value (or (getenv "NO_PROXY") (getenv "no_proxy"))))
        (split-string value "[, \t]+" t))))

(defun hell-net-rewrite (url)
  "URL, fetched through its mirror in `hell-mirrors' if it has one."
  (or (seq-some (pcase-lambda (`(,from . ,to))
                  (and (string-prefix-p from url)
                       (concat to (substring url (length from)))))
                hell-mirrors)
      url))

(defun hell-net--parse-proxy (proxy)
  "(HOST . PORT) of PROXY, a URL; without a scheme, http:// is assumed."
  (require 'url-parse)
  (let ((url (url-generic-parse-url (if (string-match-p "://" proxy) proxy (concat "http://" proxy)))))
    (cons (url-host url) (url-port url))))

(defun hell-net--host-port (proxy)
  "\"host:port\" of PROXY, a URL, as url.el wants it."
  (pcase-let ((`(,host . ,port) (hell-net--parse-proxy proxy)))
    (format "%s:%d" host port)))

(defun hell-net--no-proxy-regexp (hosts)
  "A regexp matching the host names HOSTS describe, for url.el's no_proxy.
\"corp.example\" or \".corp.example\" matches subdomain; \"*\" matches all."
  (if (member "*" hosts)
      "."
    (concat "\\`\\(?:"
            (mapconcat (lambda (host)
                         (let ((domain (regexp-quote (string-remove-prefix "." host))))
                           (concat "\\(?:.*\\.\\)?" domain)))
                       hosts "\\|")
            "\\)\\'")))

;;; A CA bundle for git and the JVMs ---------------------------------------------

(defvar hell-net-ca-file (expand-file-name "ca-bundle.pem" hell-data-dir)
  "Where the system's CAs and `hell-ca-bundle' are combined, for git.")

(defconst hell-net--system-ca-files
  '("/etc/ssl/certs/ca-certificates.crt"          ; Debian, Ubuntu, Arch, Alpine
    "/etc/pki/tls/certs/ca-bundle.crt"            ; Fedora, RHEL
    "/etc/ssl/ca-bundle.pem"                      ; openSUSE
    "/etc/ssl/cert.pem"                           ; macOS, BSDs
    "/opt/homebrew/etc/openssl@3/cert.pem" "/usr/local/etc/openssl@3/cert.pem")
  "Where operating systems keep their trusted CAs, as one PEM file.")

(defun hell-net-ca-file ()
  "The combined CA bundle (the system's and `hell-ca-bundle'), or nil.
Written again whenever a file it's made from is newer."
  (when hell-ca-bundle
    (let* ((ca (expand-file-name hell-ca-bundle))
           (system (seq-find #'file-readable-p hell-net--system-ca-files))
           (sources (delq nil (list system ca))))
      (unless (file-readable-p ca)
        (error "`hell-ca-bundle' is %s, which can't be read" (abbreviate-file-name ca)))
      (unless (and (file-exists-p hell-net-ca-file)
                   (seq-every-p (lambda (f) (file-newer-than-file-p hell-net-ca-file f)) sources))
        (make-directory (file-name-directory hell-net-ca-file) t)
        (with-hell-atomic-file hell-net-ca-file
          (dolist (f sources)
            (insert-file-contents f)
            (goto-char (point-max))
            (insert "\n"))))
      hell-net-ca-file)))

;;; The JVMs: a truststore, and -D options ------------------------------------------
;;
;; JVMs don't read GnuTLS' trust files or $HTTPS_PROXY. They get a truststore
;; of their own -- the JDK's CAs plus yours, built by sync with the JDK's
;; keytool -- and system properties: `hell-net-jvm-options', which the
;; JVM modules hand to JDTLS, kotlin-language-server and Gradle/Maven runs.
;; (Maven reads its proxy from your settings.xml, never from these.)

(defvar hell-net-truststore (expand-file-name "jvm/truststore.p12" hell-data-dir)
  "The JVMs' truststore: the JDK's CAs and `hell-ca-bundle''s, built by sync.")

(defconst hell-net--truststore-password "changeit"
  "Truststore password: JDK's own, since it only holds public certs.")

(defun hell-net-java-home ()
  "JDK whose CAs and keytool truststore comes from: $JAVA_HOME, else `java''s."
  (or (hell-net--getenv "JAVA_HOME")
      (when-let* ((java (executable-find "java")))
        (file-name-directory (directory-file-name (file-name-directory (file-truename java)))))))

(defun hell-net--jdk-cacerts ()
  "The JDK's cacerts file, if there's a JDK and it's readable."
  (when-let* ((home (hell-net-java-home)))
    (let ((file (expand-file-name "lib/security/cacerts" home)))
      (and (file-readable-p file) file))))

(defun hell-net-truststore-current-p ()
  "Non-nil if the truststore exists and is newer than the CAs it's made from."
  (and hell-ca-bundle
       (file-exists-p hell-net-truststore)
       (seq-every-p (lambda (f) (file-newer-than-file-p hell-net-truststore f))
                    (delq nil (list (expand-file-name hell-ca-bundle) (hell-net--jdk-cacerts))))))

(defun hell-net--pem-certificates (file)
  "The certificates in PEM FILE, each as a string."
  (with-temp-buffer
    (insert-file-contents file)
    (let (certs)
      (while (re-search-forward "^-----BEGIN CERTIFICATE-----\n\\(?:.*\n\\)*?-----END CERTIFICATE-----$" nil t)
        (push (match-string 0) certs))
      (nreverse certs))))

(defun hell-net-build-truststore ()
  "Build `hell-net-truststore' from the JDK's CAs and `hell-ca-bundle''s.
Written next to its place and moved there once complete. Signals an
error saying what's missing (a JDK, its keytool, a readable CA)."
  (let* ((home (or (hell-net-java-home) (error "No JDK found (JAVA_HOME or java on the PATH) to build the truststore with")))
         (keytool (expand-file-name "bin/keytool" home))
         (cacerts (or (hell-net--jdk-cacerts) (error "The JDK in %s has no lib/security/cacerts" home)))
         (ca (expand-file-name hell-ca-bundle))
         (certs (hell-net--pem-certificates ca))
         (tmp (concat hell-net-truststore ".part"))
         (pem (make-temp-file "hell-ca" nil ".pem"))
         (run (lambda (&rest args)
                (pcase-let ((`(,code . ,output) (apply #'hell-process-output keytool args)))
                  (unless (zerop code)
                    (error "keytool %s failed: %s" (car args) output))))))
    (unless (file-executable-p keytool) (error "No keytool in %s" home))
    (unless certs (error "No certificate in `hell-ca-bundle' (%s)" (abbreviate-file-name ca)))
    (make-directory (file-name-directory hell-net-truststore) t)
    (when (file-exists-p tmp) (delete-file tmp))
    (unwind-protect
        (progn
          (funcall run "-importkeystore" "-noprompt"
                   "-srckeystore" cacerts "-srcstorepass" hell-net--truststore-password
                   "-destkeystore" tmp "-deststoretype" "PKCS12"
                   "-deststorepass" hell-net--truststore-password)
          (cl-loop for cert in certs for i from 1
                   do (with-temp-file pem (insert cert "\n"))
                      (funcall run "-importcert" "-noprompt" "-trustcacerts"
                               "-alias" (format "hell-ca-%d" i) "-file" pem
                               "-keystore" tmp "-storetype" "PKCS12"
                               "-storepass" hell-net--truststore-password))
          (rename-file tmp hell-net-truststore t))
      (delete-file pem)
      (when (file-exists-p tmp) (delete-file tmp)))
    hell-net-truststore))

(declare-function hell-sync--log "cli/sync")

(defun hell-net-sync ()
  "Build JVMs' truststore when `hell-ca-bundle' is set.  For sync functions."
  (when hell-ca-bundle
    (if (hell-net-truststore-current-p)
        (hell-sync--log "JVM truststore is up to date")
      (hell-net-build-truststore)
      (hell-sync--log "JVM truststore built: the JDK's CAs and yours (%s)"
                      (abbreviate-file-name hell-net-truststore)))))

(defun hell-net--java-no-proxy (hosts)
  "HOSTS as Java's http.nonProxyHosts: \"a|*.b\", local addresses always in."
  (string-join
   (delete-dups
    (append '("localhost" "127.*" "[::1]")
            (mapcan (lambda (host)
                      (cond ((equal host "*") (list "*"))
                            ((string-prefix-p "." host) (list (concat "*" host)))
                            ;; A domain covers its subdomains; a plain name or an address doesn't.
                            ((and (string-search "." host)
                                  (not (string-match-p "\\`[0-9.]+\\'" host)))
                             (list host (concat "*." host)))
                            (t (list host))))
                    hosts)))
   "|"))

(defun hell-net-jvm-options ()
  "System properties for JVMs Hell starts: proxy, and truststore.
Empty when nothing is set. The truststore only once sync has built it."
  (append
   (when-let* ((proxy (hell-net-proxy)))
     (pcase-let ((`(,host . ,port) (hell-net--parse-proxy proxy)))
       (setq port (number-to-string port))
       (list (concat "-Dhttp.proxyHost=" host) (concat "-Dhttp.proxyPort=" port)
             (concat "-Dhttps.proxyHost=" host) (concat "-Dhttps.proxyPort=" port)
             (concat "-Dhttp.nonProxyHosts=" (hell-net--java-no-proxy (hell-net-no-proxy))))))
   (when (and hell-ca-bundle (file-exists-p hell-net-truststore))
     (list (concat "-Djavax.net.ssl.trustStore=" hell-net-truststore)
           (concat "-Djavax.net.ssl.trustStorePassword=" hell-net--truststore-password)
           "-Djavax.net.ssl.trustStoreType=PKCS12"))))

;;; All of Emacs: proxy and CA ----------------------------------------------------

(defun hell-net-setup ()
  "Point Emacs at `hell-proxy' and trust `hell-ca-bundle'.
Run after your init.el.  An environment proxy needs nothing: url.el reads
$HTTPS_PROXY itself."
  (when hell-proxy
    (let ((host-port (hell-net--host-port hell-proxy)))
      (setq url-proxy-services `(("http" . ,host-port) ("https" . ,host-port)))
      (when-let* ((hosts (hell-net-no-proxy)))
        (push (cons "no_proxy" (hell-net--no-proxy-regexp hosts)) url-proxy-services))))
  (when hell-ca-bundle
    (let ((ca (expand-file-name hell-ca-bundle)))
      (with-eval-after-load 'gnutls
        (add-to-list 'gnutls-trustfiles ca)))))

;;; Probing a host, for doctor ------------------------------------------------------
;;
;; url.el reports every failed fetch the same way (it just doesn't
;; return), so a missing corporate CA looked like "Could not create
;; connection". The probe opens the connection itself, the way url.el
;; does (through the proxy's CONNECT when there is one), then checks the
;; server's certificate with GnuTLS, so it can say which step failed.

(declare-function gnutls-negotiate "gnutls")
(declare-function gnutls-trustfiles "gnutls")
(declare-function url-host "url-parse")
(declare-function url-port "url-parse")
(declare-function url-type "url-parse")
(declare-function url-user "url-parse")
(declare-function url-password "url-parse")

(defcustom hell-net-probe-timeout 10
  "Seconds `hell-net-probe' waits for each step."
  :type 'natnum
  :group 'hell)

(defun hell-net--proxied-p (host)
  "Non-nil if connections to HOST go through the proxy."
  (and (hell-net-proxy)
       (not (when-let* ((hosts (hell-net-no-proxy)))
              (string-match-p (hell-net--no-proxy-regexp hosts) host)))))

(defun hell-net--probe-connect (host port)
  "Open plain connection to HOST:PORT; return process, or signal an error."
  (unless (network-lookup-address-info host)
    (error "%s: no such host (DNS)" host))
  (let* ((event nil)
         (proc (make-network-process :name "hell-probe" :host host :service port
                                     :nowait t :noquery t
                                     :sentinel (lambda (_ e) (unless event (setq event (string-trim e))))))
         (deadline (+ (float-time) hell-net-probe-timeout)))
    (while (and (eq (process-status proc) 'connect) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (pcase (process-status proc)
      ('open (set-process-sentinel proc #'ignore) proc)
      ('connect (delete-process proc) (error "%s:%s didn't answer in %ds" host port hell-net-probe-timeout))
      (_ (delete-process proc) (error "connecting to %s:%s %s" host port (or event "failed"))))))

(defun hell-net--probe-tunnel (proc host port proxy)
  "Ask the proxy on PROC for a tunnel to HOST:PORT; signal an error if refused.
PROXY is its URL, whose user and password, if any, authenticate."
  (require 'url-parse)
  (let* ((url (url-generic-parse-url (if (string-match-p "://" proxy) proxy (concat "http://" proxy))))
         (auth (and (url-user url)
                    (format "Proxy-Authorization: Basic %s\r\n"
                            (base64-encode-string (concat (url-user url) ":" (or (url-password url) "")) t))))
         (reply "")
         (deadline (+ (float-time) hell-net-probe-timeout)))
    (set-process-filter proc (lambda (_ out) (setq reply (concat reply out))))
    (process-send-string proc (format "CONNECT %s:%d HTTP/1.1\r\nHost: %s:%d\r\n%s\r\n"
                                      host port host port (or auth "")))
    (while (and (not (string-search "\r\n\r\n" reply)) (process-live-p proc) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (set-process-filter proc #'internal-default-process-filter)
    (unless (string-match "\\`HTTP/[0-9.]+ \\([0-9]+\\)\\([^\r\n]*\\)" reply)
      (error "it sent no HTTP answer"))
    (unless (equal (match-string 1 reply) "200")
      (error "it refused the tunnel (HTTP %s%s)" (match-string 1 reply) (match-string 2 reply)))))

(defun hell-net--probe-tls (proc host)
  "Check HOST's certificate over PROC, a connection to it.
Return why it isn't trusted, or nil if it is. A handshake that fails
signals an error. This one can't time out: run it in
`hell-net-probe''s child."
  (condition-case err
      (gnutls-negotiate :process proc :hostname host
                        :trustfiles (delete-dups (append (gnutls-trustfiles)
                                                         (and hell-ca-bundle
                                                              (list (expand-file-name hell-ca-bundle))))))
    (error (error "its TLS handshake failed%s"
                  (if-let* ((code (car (last err))) ((integerp code)))
                      (concat ": " (gnutls-error-string code))
                    ""))))
  (let* ((warnings (plist-get (gnutls-peer-status proc) :warnings))
         ;; Emacs flags every self-signed certificate, even one you trust
         ;; (`hell-ca-bundle'); only GnuTLS' other warnings mean it isn't.
         (untrusted (remq :self-signed warnings)))
    (when untrusted
      ;; One reason is enough; the rest follow from it.
      (gnutls-peer-status-warning-describe
       (if (memq :self-signed warnings) :self-signed (car untrusted))))))

(defun hell-net-probe (url)
  "Check that URL's host can be reached, as Hell Emacs' own fetches reach it.
URL goes through `hell-mirrors' and the proxy; an https URL's
certificate is checked against the trusted CAs (`hell-ca-bundle'
included). No request is sent. Return nil if it's reachable, else
\(STEP . MESSAGE): STEP is `proxy' (the proxy is unreachable or refuses),
`tls' (the certificate isn't trusted) or `connect' (anything else).

It runs in a child Emacs, killed if it takes too long: GnuTLS'
handshake waits forever for a server that accepts the connection and
never answers, and nothing in the Emacs running it can stop that."
  (let* ((form `(progn (add-to-list 'load-path ,hell-core-dir)
                       (require 'hell-lib)
                       (hell-require 'hell-lib 'net)
                       (setq hell-proxy ',hell-proxy
                             hell-no-proxy ',hell-no-proxy
                             hell-ca-bundle ',hell-ca-bundle
                             hell-mirrors ',hell-mirrors
                             hell-net-probe-timeout ',hell-net-probe-timeout)
                       (prin1 (list :result (hell-net--probe-here ,url t)))))
         (out (generate-new-buffer " *hell-probe*"))
         (err (generate-new-buffer " *hell-probe-stderr*"))
         (proc (make-process :name "hell-probe" :buffer out :stderr err :noquery t
                             :connection-type 'pipe :sentinel #'ignore
                             :command (list (expand-file-name invocation-name invocation-directory)
                                            "--batch" "-Q" "-l" (expand-file-name "early-init.el" hell-dir)
                                            "--eval" (prin1-to-string form))))
         ;; Three steps at most (connect, tunnel, handshake), and the child's start.
         (limit (+ 5 (* 3 hell-net-probe-timeout)))
         (deadline (+ (float-time) limit)))
    (unwind-protect
        (progn
          (while (and (process-live-p proc) (< (float-time) deadline))
            (accept-process-output nil 0.05))
          (when (not (process-live-p proc))
            (accept-process-output proc 0))
          ;; The child prints (:result RESULT) on stdout, and each step as
          ;; it starts on stderr (unbuffered, so a killed child's last is there).
          (let ((said (ignore-errors (car (read-from-string (with-current-buffer out (buffer-string))))))
                (step (with-current-buffer err
                        (goto-char (point-max))
                        (and (re-search-backward "^hell-probe-step \\([a-z]+\\)$" nil t)
                             (intern (match-string 1))))))
            (cond ((eq (car-safe said) :result) (cadr said))
                  ;; A stalled handshake is no verdict on the certificate.
                  ((process-live-p proc)
                   (if (eq step 'tls)
                       (cons 'connect (format "its TLS handshake got no answer in %ds" limit))
                     (cons (or step 'connect) (format "no answer in %ds" limit))))
                  (t (cons (or step 'connect)
                           (format "the probe failed: %s"
                                   (with-current-buffer err (string-trim (buffer-string)))))))))
      (delete-process proc)
      (when-let* ((pipe (get-buffer-process err))) (delete-process pipe))
      (kill-buffer out)
      (kill-buffer err))))

(defun hell-net--probe-here (url &optional report)
  "`hell-net-probe' URL, in this Emacs: a silent server hangs it.
With REPORT, each step's name is logged (on stderr, in batch) as it starts."
  (require 'url-parse)
  (require 'gnutls)
  (let* ((url (url-generic-parse-url (hell-net-rewrite url)))
         (host (url-host url))
         (tls (equal (url-type url) "https"))
         (port (url-port url))
         (proxy (and (hell-net--proxied-p host) (hell-net-proxy)))
         (step (if proxy 'proxy 'connect))
         proc)
    (when report (message "hell-probe-step %s" step))
    (condition-case err
        (unwind-protect
            (progn
              (setq proc (if proxy
                             (pcase-let ((`(,phost . ,pport) (hell-net--parse-proxy proxy)))
                               (hell-net--probe-connect phost pport))
                           (hell-net--probe-connect host port)))
              (when (and proxy tls)
                (hell-net--probe-tunnel proc host port proxy)
                (setq step 'connect))     ; past the proxy
              (when tls
                (when report (message "hell-probe-step tls"))
                (when-let* ((untrusted (hell-net--probe-tls proc host)))
                  (setq step 'tls)
                  (error "%s" untrusted)))
              nil)
          (when proc (delete-process proc)))
      (error (cons step (error-message-string err))))))

;;; Hell Emacs' own fetching: mirrors, and git's settings ----------------------------

(defvar hell-net--active nil
  "Non-nil inside `with-hell-network'.")

(defvar hell-net--outer-environment nil
  "`process-environment' outside every `with-hell-network', while inside one.")

(defvar hell-net-offline nil
  "Non-nil refuses all of Hell Emacs' own fetching.
url.el fetches fail, and git refuses every network transport inside
`with-hell-network'. Bound by `bin/hell install --from-bundle',
so what the bundle doesn't carry fails the install instead of being
downloaded.")

(defconst hell-net--offline-git-config
  '(("protocol.allow" . "never")
    ("protocol.http.allow" . "never") ("protocol.https.allow" . "never")
    ("protocol.ssh.allow" . "never") ("protocol.git.allow" . "never"))
  "Git settings refusing the network, over any your own git config sets.")

(defun hell-net--git-config ()
  "The git settings for Hell Emacs' own fetches, as (KEY . VALUE)s."
  (append (when hell-net-offline hell-net--offline-git-config)
          (when hell-proxy (list (cons "http.proxy" hell-proxy)))
          (when-let* ((ca (hell-net-ca-file))) (list (cons "http.sslCAInfo" ca)))
          (mapcar (pcase-lambda (`(,from . ,to)) (cons (format "url.%s.insteadOf" to) from))
                  hell-mirrors)))

(defun hell-net-environment (&optional base-environment)
  "`process-environment' for fetches, made from BASE-ENVIRONMENT.
Git settings go in GIT_CONFIG_COUNT/KEY_n/VALUE_n (after any already
there), and an explicit proxy's exceptions in NO_PROXY."
  (let* ((env (copy-sequence (or base-environment process-environment)))
         (config (hell-net--git-config))
         (base (string-to-number (or (getenv-internal "GIT_CONFIG_COUNT" env) "0"))))
    (when config
      (cl-loop for (key . value) in config
               for i from base
               do (push (format "GIT_CONFIG_KEY_%d=%s" i key) env)
                  (push (format "GIT_CONFIG_VALUE_%d=%s" i value) env))
      (push (format "GIT_CONFIG_COUNT=%d" (+ base (length config))) env))
    (when-let* ((hosts (and hell-proxy (hell-net-no-proxy))))
      (let ((value (string-join hosts ",")))
        (push (concat "NO_PROXY=" value) env)
        (push (concat "no_proxy=" value) env)))
    env))

(defmacro with-hell-network (&rest body)
  "Run BODY as Hell Emacs' own fetching.
url.el fetches go to their mirrors (`hell-mirrors'), and processes
started meanwhile -- git, including Elpaca's -- get the proxy, CA and
mirrors (`hell-net-environment')."
  (declare (indent 0) (debug t))
  `(let* ((hell-net--outer-environment (if hell-net--active
                                               hell-net--outer-environment
                                         process-environment))
          ;; Made again from the outer one when nested, so settings changed
          ;; since take effect and nothing is added twice.
          (process-environment (hell-net-environment hell-net--outer-environment))
          (hell-net--active t))
     ,@body))

(defun hell-net--mirror-a (args)
  "`url-retrieve-internal' fetches through mirror, in `with-hell-network'.
Rewrites the URL in ARGS."
  (if (and hell-net--active hell-mirrors (stringp (car args)))
      (cons (hell-net-rewrite (car args)) (cdr args))
    args))
(advice-add 'url-retrieve-internal :filter-args #'hell-net--mirror-a)

(defun hell-net--offline-a (url &rest _)
  "Refuse URL's fetch while `hell-net-offline'."
  (when hell-net-offline
    (error "Offline install: Hell Emacs can't fetch %s; the bundle doesn't carry it" url)))
(advice-add 'url-retrieve-internal :before #'hell-net--offline-a)

;;; Downloading a file ---------------------------------------------------------

(defcustom hell-net-curl 'auto
  "The curl `hell-net-download' streams downloads with.
`auto' finds it on the PATH; nil always uses url.el, which holds the
whole download in memory first."
  :type '(choice (const auto) (const :tag "url.el" nil) file)
  :group 'hell)

(defun hell-net--curl ()
  "The curl to download with, or nil: `hell-net-curl', found if `auto'."
  (if (eq hell-net-curl 'auto) (executable-find "curl") hell-net-curl))

(defun hell-net-download (url file)
  "Download URL to FILE: its mirror, proxy, and CAs.
Through curl when there is one, which streams it to disk (JDTLS and the
Spring server run to tens of megabytes); else url.el's `url-copy-file'.
An HTTP error status is an error. Refused while `hell-net-offline'."
  (when hell-net-offline
    (error "Offline install: Hell Emacs can't fetch %s; the bundle doesn't carry it" url))
  (with-hell-network
    (if-let* ((curl (hell-net--curl)))
        (let* ((target (hell-net-rewrite url))
               (proxy (hell-net-proxy))
               (no-proxy (and proxy (hell-net-no-proxy)))
               (ca (hell-net-ca-file)))
          (with-temp-buffer
            (unless (zerop (apply #'call-process curl nil t nil
                                  `("--fail" "--location" "--silent" "--show-error"
                                    "--retry" "2" "--connect-timeout" "30"
                                    ,@(and proxy (list "--proxy" proxy))
                                    ,@(and no-proxy (list "--noproxy" (string-join no-proxy ",")))
                                    ,@(and ca (list "--cacert" ca))
                                    "--output" ,(expand-file-name file)
                                    ,target)))
              (error "Downloading %s failed: %s" target (string-trim (buffer-string))))))
      ;; url.el goes to the mirror by itself here (`hell-net--mirror-a').
      (url-copy-file url file t))))

(hell-provide 'hell-lib 'net)
;;; net.el ends here
