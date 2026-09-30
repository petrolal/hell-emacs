;;; test-sync.el --- Tests for core/hellmacs-sync.el -*- lexical-binding: t; -*-

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
(require 'hellmacs-sync)
(or (require 'loaddefs-gen nil t)
    (require 'autoload nil t))

(ert-deftest test-sync/make-autoload-defun ()
  "Generates autoload form for defun declarations."
  (let* ((form '(defun my-custom-cmd () "Docstring" (interactive) nil))
         (file "/tmp/test-autoload.el")
         (al (hellmacs-sync--make-autoload form file)))
    (should (eq (car al) 'autoload))
    (should (equal (cadr al) ''my-custom-cmd))
    (should (equal (nth 2 al) file))
    (should (equal (nth 4 al) t))))

(ert-deftest test-sync/make-autoload-defmacro ()
  "Generates autoload form for defmacro declarations."
  (let* ((form '(defmacro my-custom-macro (x) "Macro doc" `(+ 1 ,x)))
         (file "/tmp/test-autoload.el")
         (al (hellmacs-sync--make-autoload form file)))
    (should (eq (car al) 'autoload))
    (should (equal (cadr al) ''my-custom-macro))
    (should (equal (nth 2 al) file))))

(ert-deftest test-sync/profile-paths ()
  "Profile and compiled directories are properly anchored to data directory."
  (should (string-prefix-p hellmacs-data-dir hellmacs-profile-dir))
  (should (string-prefix-p hellmacs-profile-dir hellmacs-compiled-dir)))

(ert-deftest test-sync/failed-profile-write-leaves-no-profile ()
  "A sync that fails while writing the profile leaves none behind.
Otherwise the last sync's profile.eld, still current by its inputs, would
be started from with this sync's autoloads and no compiled files."
  (let* ((hellmacs-profile-dir (file-name-as-directory (make-temp-file "hellmacs-test-profile" t)))
         (profile (expand-file-name "profile.eld" hellmacs-profile-dir)))
    (unwind-protect
        (cl-letf (((symbol-function 'hellmacs-sync--packages) #'ignore)
                  ((symbol-function 'hellmacs-sync--module-autoloads) #'ignore)
                  ((symbol-function 'hellmacs-sync--write-autoloads) #'ignore)
                  ((symbol-function 'hellmacs-sync--log) #'ignore))
          (with-temp-file profile (insert "(:emacs-version \"old\")\n"))
          (cl-letf (((symbol-function 'hellmacs-sync--compile)
                     (lambda () (error "Compiling failed"))))
            (should-error (hellmacs-sync--write-profile)))
          (should-not (file-exists-p profile))
          ;; A sync that gets through writes it.
          (cl-letf (((symbol-function 'hellmacs-sync--compile) #'ignore))
            (hellmacs-sync--write-profile))
          (should (plist-get (hellmacs-profile-read) :emacs-version)))
      (delete-directory hellmacs-profile-dir t))))

;;; npm packages, pinned by their lockfile --------------------------------------

(defmacro test-sync--with-npm (&rest body)
  "Run BODY with a fake `npm' first on the PATH, in a temporary directory ROOT.
The fake records its arguments and npm_config_* environment in ROOT/npm.log,
and makes node_modules/ as `npm ci' would."
  (declare (indent 0))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-npm" t)))
          (bin (expand-file-name "bin/" root))
          (lock (expand-file-name "lock/" root))
          (exec-path (cons bin exec-path))
          (process-environment (cons (concat "PATH=" bin path-separator (getenv "PATH"))
                                     process-environment)))
     (unwind-protect
         (progn
           (make-directory bin t)
           (make-directory lock t)
           (with-temp-file (expand-file-name "npm" bin)
             (insert "#!/bin/sh\n"
                     "echo \"args: $*\" >> " (shell-quote-argument (expand-file-name "npm.log" root)) "\n"
                     "env | grep '^npm_config_' | sort >> " (shell-quote-argument (expand-file-name "npm.log" root)) "\n"
                     "[ -f package-lock.json ] || exit 3\n"
                     "mkdir -p node_modules/.bin && touch node_modules/.bin/server\n"))
           (set-file-modes (expand-file-name "npm" bin) #o755)
           (with-temp-file (expand-file-name "package.json" lock) (insert "{\"private\":true}\n"))
           (with-temp-file (expand-file-name "package-lock.json" lock) (insert "{\"lockfileVersion\":3}\n"))
           ,@body)
       (delete-directory root t))))

(defun test-sync--npm-log (root)
  (with-temp-buffer (insert-file-contents (expand-file-name "npm.log" root)) (buffer-string)))

(ert-deftest test-sync/npm-install ()
  "`npm ci' from the module's lockfile, without scripts, with Hellmacs' own cache."
  (test-sync--with-npm
    (let ((dir (expand-file-name "servers/yaml/" root))
          (hellmacs-proxy nil) (hellmacs-ca-bundle nil) (hellmacs-mirrors nil))
      (should-not (hellmacs-npm-installed-p lock dir))
      (hellmacs-sync-npm-install "yaml-language-server" lock dir)
      (should (hellmacs-npm-installed-p lock dir))
      (should (file-exists-p (expand-file-name "package-lock.json" dir)))
      (let ((log (test-sync--npm-log root)))
        (should (string-match-p "^args: ci --ignore-scripts --no-audit --no-fund" log))
        (should (string-match-p (concat "^npm_config_cache=" (regexp-quote (expand-file-name "npm/" hellmacs-cache-dir)))
                                log))
        (should (string-match-p "^npm_config_registry=https://registry.npmjs.org/$" log))
        (should (string-match-p "^npm_config_update_notifier=false$" log)))
      ;; A changed lockfile is a new pin: installed again.
      (with-temp-file (expand-file-name "package-lock.json" lock) (insert "{\"lockfileVersion\":3,\"v\":2}\n"))
      (should-not (hellmacs-npm-installed-p lock dir)))))

(ert-deftest test-sync/npm-network-settings ()
  "npm gets the proxy, the CA bundle and the registry's mirror."
  (test-sync--with-npm
    (let* ((ca (expand-file-name "corp.pem" root))
           (hellmacs-net-ca-file (expand-file-name "ca.pem" root))
           (hellmacs-proxy "http://proxy.corp:3128")
           (hellmacs-no-proxy '("localhost" ".corp"))
           (hellmacs-ca-bundle ca)
           (hellmacs-mirrors '(("https://registry.npmjs.org/" . "https://art.corp/npm/"))))
      (with-temp-file ca (insert "-----BEGIN CERTIFICATE-----\n"))
      (hellmacs-sync-npm-install "bash-language-server" lock (expand-file-name "bash/" root))
      (let ((log (test-sync--npm-log root)))
        (should (string-match-p "^npm_config_registry=https://art.corp/npm/$" log))
        (should (string-match-p "^npm_config_https_proxy=http://proxy.corp:3128$" log))
        (should (string-match-p "^npm_config_proxy=http://proxy.corp:3128$" log))
        (should (string-match-p "^npm_config_noproxy=localhost,.corp$" log))
        (should (string-match-p (concat "^npm_config_cafile=" (regexp-quote hellmacs-net-ca-file) "$") log))))))

(ert-deftest test-sync/npm-failures ()
  "No npm, offline, or a failing npm: an error, and nothing marked installed."
  (test-sync--with-npm
    (let ((dir (expand-file-name "x/" root)))
      (let ((hellmacs-net-offline t))
        (should-error (hellmacs-sync-npm-install "x" lock dir)))
      (let ((exec-path nil))
        (should-error (hellmacs-sync-npm-install "x" lock dir)))
      (with-temp-file (expand-file-name "bin/npm" root) (insert "#!/bin/sh\necho E404 >&2\nexit 1\n"))
      (should (string-match-p "E404" (cadr (should-error (hellmacs-sync-npm-install "x" lock dir)))))
      (should-not (hellmacs-npm-installed-p lock dir)))))

(provide 'test-sync)
;;; test-sync.el ends here
