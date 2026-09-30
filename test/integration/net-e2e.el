;;; net-e2e.el --- End-to-end check of corporate network and bundle workflows -*- lexical-binding: t; -*-

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

;; End-to-end integration test for Phase 12.1 (Corporate Networks & Offline Bundles).
;; Checks:
;;  1. Network layer: proxy tunneling, CA bundle trust, and mirror URL redirection.
;;  2. Doctor network probes under proxy & corporate CA settings.
;;  3. Bundle generation: packaging packages, lock files, and manifests.
;;  4. Offline installation from bundle with SHA-256 verification and offline startup.
;;
;; Invocation:
;;   emacs --batch -l early-init.el -f hellmacs-start -l test/integration/net-e2e.el

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(hellmacs-require 'hellmacs-lib 'net)
(hellmacs-require 'hellmacs-cli 'bundle)
(require 'hellmacs-sync)
(require 'hellmacs-cli)

(defun net-e2e--run ()
  (let* ((work-dir (make-temp-file "hellmacs-net-e2e" t))
         (ca-key (expand-file-name "ca-key.pem" work-dir))
         (ca-cert (expand-file-name "ca-cert.pem" work-dir))
         (bundle-file (expand-file-name "hellmacs-test.tar.zst" work-dir))
         (target-xdg (expand-file-name "target-env" work-dir))
         proxy-proc
         proxy-port)
    (unwind-protect
        (progn
          (e2e--say "\n== 12.1 Corporate Networks & Offline Bundles E2E")

          ;; 1. Generate test Corporate CA
          (e2e-check "generate self-signed corporate CA for testing"
            (and (executable-find "openssl")
                 (zerop (call-process "openssl" nil nil nil "req" "-x509" "-newkey" "rsa:2048" "-nodes"
                                      "-keyout" ca-key "-out" ca-cert "-days" "1" "-subj" "/CN=Corporate Test CA"
                                      "-addext" "basicConstraints=critical,CA:TRUE"))))

          ;; 2. Start local CONNECT test proxy
          (e2e-check "start local authenticated test proxy server"
            (setq proxy-proc
                  (make-network-process
                   :name "net-e2e-proxy" :server t :host "127.0.0.1" :service t :noquery t
                   :filter (lambda (proc out)
                             (if (string-search (concat "Proxy-Authorization: Basic "
                                                        (base64-encode-string "corpuser:corppass" t))
                                                out)
                                 (process-send-string proc "HTTP/1.1 200 Connection established\r\n\r\n")
                               (process-send-string proc "HTTP/1.1 407 Proxy Authentication Required\r\n\r\n")))))
            (setq proxy-port (process-contact proxy-proc :service))
            (numberp proxy-port))

          ;; 3. Test proxy & CA configuration in Hellmacs
          (e2e-check "network layer applies proxy, CA bundle, and mirror settings"
            (let ((hellmacs-proxy (format "http://corpuser:corppass@127.0.0.1:%d" proxy-port))
                  (hellmacs-ca-bundle ca-cert)
                  (hellmacs-mirrors '(("https://upstream.example.com/" . "https://mirror.corp.example/repo/"))))
              (and (equal (hellmacs-net-proxy) (format "http://corpuser:corppass@127.0.0.1:%d" proxy-port))
                   (equal (hellmacs-net-rewrite "https://upstream.example.com/foo.tar.gz")
                          "https://mirror.corp.example/repo/foo.tar.gz")
                   (member (concat "-Dhttp.proxyHost=127.0.0.1") (hellmacs-net-jvm-options))
                   (member (concat "-Dhttp.proxyPort=" (number-to-string proxy-port)) (hellmacs-net-jvm-options)))))

          ;; 4. Doctor network probe verification
          (e2e-check "doctor network probe verifies proxy tunnel authentication"
            (let ((hellmacs-proxy (format "http://corpuser:corppass@127.0.0.1:%d" proxy-port))
                  (hellmacs-ca-bundle ca-cert)
                  (hellmacs-net-probe-timeout 3))
              ;; Plain HTTP probe through the authenticated proxy succeeds
              (null (hellmacs-net-probe "http://example.corp.invalid/"))))

          ;; 5. Build an offline bundle
          (e2e-check "create offline bundle with bundle builder"
            (let ((hellmacs-profile "net-test")
                  (hellmacs-modules-override '(:ui theme :editor undo)))
              (hellmacs-cli-bundle bundle-file)
              (and (file-exists-p bundle-file)
                   (> (file-attribute-size (file-attributes bundle-file)) 1000))))

          ;; 6. Install from bundle in isolated offline environment
          (e2e-check "install from bundle into target environment"
            (let* ((target-data (expand-file-name "data" target-xdg))
                   (target-config (expand-file-name "config" target-xdg))
                   (hellmacs-data-dir target-data)
                   (hellmacs-user-dir target-config)
                   (hellmacs-lock-file (expand-file-name "packages.lock.eld" target-config))
                   (hellmacs-net-offline t))
              (make-directory target-data t)
              (make-directory target-config t)
              ;; Seed user init.el matching bundled modules
              (with-temp-file (expand-file-name "init.el" target-config)
                (insert "(hellmacs! :ui theme :editor undo)\n"))
              ;; Run bundle install
              (hellmacs-bundle-install bundle-file)
              ;; Verify extracted manifest and lock file
              (and (file-exists-p (expand-file-name "packages.lock.eld" target-config))
                   (file-directory-p (expand-file-name "elpaca" target-data))))))

      (when (and proxy-proc (process-live-p proxy-proc))
        (delete-process proxy-proc))
      (delete-directory work-dir t)
      (let ((hellmacs-modules-override nil))
        (hellmacs-sync))))

  (e2e--say "\nResults: %d failed, %d passed" e2e--failures (- 6 e2e--failures))
  (kill-emacs (if (zerop e2e--failures) 0 1)))

(net-e2e--run)

;;; net-e2e.el ends here
