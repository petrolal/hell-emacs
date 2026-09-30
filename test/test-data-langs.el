;;; test-data-langs.el --- Tests for Phase 10.1's project file types -*- lexical-binding: t; -*-

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

;; :lang data (XML), yaml, json, markdown, sh and docker. Run with
;; `bin/hellmacs test'. Each language server against real files is checked
;; by hand (see docs/roadmap.md, 10.1).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-sync)

(defvar lsp-xml-jar-file)
(defvar lsp-xml-server-command)
(defvar lsp-xml-server-work-dir)
(defvar lsp-yaml-server-command)
(defvar lsp-yaml-schema-store-enable)
(defvar lsp-marksman-server-command)

(defconst test-langs--modules '(data yaml json markdown sh docker))

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules `(:tools lsp :lang ,@test-langs--modules))
  (hellmacs-module--load '(:tools . lsp) "autoload.el") ; `hellmacs-lsp-pin-installer'
  (dolist (name test-langs--modules)
    (hellmacs-module--load (cons :lang name) "config.el")
    (hellmacs-module--load (cons :lang name) "cli.el")))

(defun test-langs--dir (name)
  (expand-file-name (format "modules/lang/%s/" name) hellmacs-dir))

(defun test-langs--unalias (mode)
  "MODE, or the mode it's an alias of (`xml-mode' is `nxml-mode')."
  (while (and (symbolp mode) (symbolp (symbol-function mode)) (symbol-function mode))
    (setq mode (symbol-function mode)))
  mode)

(defun test-langs--sha256-p (value)
  (and (stringp value) (string-match-p "\\`[0-9a-f]\\{64\\}\\'" value)))

(ert-deftest test-data-langs/auto-mode-alist-associations ()
  "Standard project file extensions map to appropriate major modes."
  (pcase-dolist (`(,file . ,mode)
                 '(("pom.xml" . nxml-mode) ("/p/lib.pom" . nxml-mode) ("/p/.classpath" . nxml-mode)
                   ("/p/gradlew" . sh-mode) ("/p/mvnw" . sh-mode)
                   ("/p/Dockerfile" . dockerfile-mode) ("/p/Dockerfile.dev" . dockerfile-mode)
                   ("/p/app.dockerfile" . dockerfile-mode) ("/p/Containerfile" . dockerfile-mode)))
    (should (eq (test-langs--unalias (assoc-default file auto-mode-alist #'string-match-p)) mode))))

(ert-deftest test-data-langs/servers-start-in-their-modes ()
  (pcase-dolist (`(,hook . ,fn)
                 '((nxml-mode-hook . lsp-deferred)
                   (yaml-mode-hook . lsp-deferred) (yaml-ts-mode-hook . lsp-deferred)
                   (js-json-mode-hook . lsp-deferred) (json-ts-mode-hook . lsp-deferred)
                   (markdown-mode-hook . lsp-deferred) (gfm-mode-hook . lsp-deferred)
                   (sh-mode-hook . lsp-deferred) (bash-ts-mode-hook . lsp-deferred)
                   (dockerfile-mode-hook . lsp-deferred) (dockerfile-ts-mode-hook . lsp-deferred)))
    (should (memq fn (default-value hook)))))

(ert-deftest test-data-langs/xml ()
  "lemminx: the pinned jar, run on a JDK, its work directory in Hellmacs' cache."
  (should (string-match-p (regexp-quote hellmacs-xml-lemminx-version) hellmacs-xml-lemminx-url))
  (should (test-langs--sha256-p hellmacs-xml-lemminx-sha256))
  (should (equal lsp-xml-jar-file hellmacs-xml-lemminx-jar))
  (should (string-prefix-p lsp-server-install-dir hellmacs-xml-lemminx-jar))
  (should (string-prefix-p hellmacs-cache-dir lsp-xml-server-work-dir))
  (should (eq lsp-xml-server-command #'hellmacs-xml-server-command))
  (let ((command (hellmacs-xml-server-command)))
    (should (string-match-p "java\\(?:\\.exe\\)?\\'" (car command)))
    (should (equal (last command 2) (list "-jar" hellmacs-xml-lemminx-jar)))))

(ert-deftest test-data-langs/binaries-pinned-per-platform ()
  "marksman and docker-language-server: a SHA-256 for each platform's binary."
  (dolist (pins (list hellmacs-markdown-marksman-pins hellmacs-docker-ls-pins))
    (pcase-dolist (`(,platform ,asset ,sha256) pins)
      (should (string-match-p "\\`\\(?:linux\\|darwin\\|windows\\)-\\(?:x86_64\\|aarch64\\)\\'" platform))
      (should (stringp asset))
      (should (test-langs--sha256-p sha256))))
  (let ((system-type 'gnu/linux) (system-configuration "x86_64-pc-linux-gnu"))
    (should (equal (hellmacs-markdown-marksman-url)
                   (concat "https://github.com/artempyanykh/marksman/releases/download/"
                           hellmacs-markdown-marksman-version "/marksman-linux-x64")))
    (should (equal (hellmacs-docker-ls-url)
                   (format "https://github.com/docker/docker-language-server/releases/download/v%s/docker-language-server-linux-amd64-v%s"
                           hellmacs-docker-ls-version hellmacs-docker-ls-version))))
  (let ((system-type 'berkeley-unix) (system-configuration "x86_64-unknown-freebsd14"))
    (should-not (hellmacs-markdown-marksman-pin))
    (should-not (hellmacs-docker-ls-pin))))

(ert-deftest test-data-langs/npm-servers-locked ()
  "yaml, json and bash servers: a lockfile in the module pins every package."
  (pcase-dolist (`(,module ,package ,version)
                 `((yaml "yaml-language-server" ,hellmacs-yaml-ls-version)
                   (json "vscode-langservers-extracted" ,hellmacs-json-ls-version)
                   (sh "bash-language-server" ,hellmacs-sh-ls-version)))
    (let ((lock (expand-file-name "package-lock.json" (test-langs--dir module))))
      (should (file-exists-p (expand-file-name "package.json" (test-langs--dir module))))
      (should (file-exists-p lock))
      (let* ((json (json-parse-string (with-temp-buffer (insert-file-contents lock) (buffer-string))))
             (packages (gethash "packages" json)))
        (should (equal (gethash "version" (gethash (concat "node_modules/" package) packages)) version))
        (maphash (lambda (name info)
                   (unless (string-empty-p name)
                     (should (string-prefix-p "sha512-" (gethash "integrity" info)))))
                 packages)))))

(ert-deftest test-data-langs/server-commands ()
  "lsp-mode is pointed at the pinned servers, not the PATH's or its own downloads."
  (should (equal lsp-yaml-server-command (list hellmacs-yaml-ls-executable "--stdio")))
  (should (string-prefix-p lsp-server-install-dir hellmacs-yaml-ls-executable))
  (should (string-suffix-p "node_modules/.bin/vscode-json-language-server" hellmacs-json-ls-executable))
  (should (string-suffix-p "node_modules/.bin/bash-language-server" hellmacs-sh-ls-executable))
  (should (equal lsp-marksman-server-command hellmacs-markdown-marksman-executable))
  (should (equal (hellmacs-docker-ls-command) (list hellmacs-docker-ls-executable "start" "--stdio"))))

(ert-deftest test-data-langs/docker-telemetry-off ()
  "docker-language-server sends usage data and crash reports to Docker (BugSnag)
unless told not to: its telemetry is on by default. Hellmacs turns it off
at initialize, and answers `off' when the server asks for the setting."
  (should (equal (plist-get (hellmacs-docker-ls-initialization-options) :telemetry) "off"))
  (should (equal (hellmacs-docker-ls-telemetry-setting) "off")))

(ert-deftest test-data-langs/yaml-schemastore-off ()
  "SchemaStore is fetched at runtime, so it's off unless asked for."
  (should-not hellmacs-yaml-schemastore)
  (should-not lsp-yaml-schema-store-enable))

(ert-deftest test-data-langs/compose-files ()
  (dolist (file '("/p/compose.yaml" "/p/compose.yml" "/p/docker-compose.yml" "/p/docker-compose.prod.yaml"
                  "/p/compose.override.yml"))
    (should (hellmacs-docker-compose-file-p file)))
  (dolist (file '("/p/application.yml" "/p/.github/workflows/ci.yml" "/p/compose.json"))
    (should-not (hellmacs-docker-compose-file-p file))))

(ert-deftest test-data-langs/sync-installs-the-pins ()
  "Each sync step installs its pin, and skips it once installed."
  (let (calls)
    (cl-letf (((symbol-function 'hellmacs-sync-download-verified)
               (lambda (url dest sha256 _label)
                 (push (list 'download url sha256) calls)
                 (make-directory (file-name-directory dest) t)
                 (with-temp-file dest (insert "x"))))
              ((symbol-function 'hellmacs-sync-npm-install)
               (lambda (label lock-dir dir) (push (list 'npm label lock-dir dir) calls)))
              ((symbol-function 'hellmacs-sync--log) #'ignore))
      (let* ((tmp (make-temp-file "hellmacs-test-langs" t))
             (lsp-server-install-dir (file-name-as-directory tmp))
             (hellmacs-xml-lemminx-jar (expand-file-name "xmlls/lemminx.jar" tmp))
             (hellmacs-markdown-marksman-executable (expand-file-name "marksman/marksman" tmp))
             (hellmacs-docker-ls-executable (expand-file-name "docker/docker-language-server" tmp))
             (system-type 'gnu/linux) (system-configuration "x86_64-pc-linux-gnu"))
        (unwind-protect
            (progn
              (hellmacs-xml-sync-install-server)
              (should (equal (car calls) (list 'download hellmacs-xml-lemminx-url hellmacs-xml-lemminx-sha256)))
              (hellmacs-markdown-sync-install-server)
              (should (equal (car calls) (list 'download (hellmacs-markdown-marksman-url)
                                               (hellmacs-markdown-marksman-pin))))
              (should (file-executable-p hellmacs-markdown-marksman-executable))
              (hellmacs-docker-sync-install-server)
              (should (equal (car calls) (list 'download (hellmacs-docker-ls-url) (hellmacs-docker-ls-pin))))
              (should (file-executable-p hellmacs-docker-ls-executable))
              (hellmacs-yaml-sync-install-server)
              (should (equal (car calls) (list 'npm "yaml-language-server" (test-langs--dir 'yaml)
                                               hellmacs-yaml-ls-dir)))
              (hellmacs-json-sync-install-server)
              (should (equal (nth 1 (car calls)) "vscode-json-language-server"))
              (hellmacs-sh-sync-install-server)
              (should (equal (nth 1 (car calls)) "bash-language-server"))
              ;; Installed: the binaries are marked, nothing is fetched again.
              (let ((count (length calls)))
                (hellmacs-markdown-sync-install-server)
                (hellmacs-docker-sync-install-server)
                (should (= (length calls) count))))
          (delete-directory tmp t))))))

(ert-deftest test-data-langs/tree-sitter-grammars-pinned ()
  "Tree-sitter grammars for config languages have pinned commit declarations."
  (pcase-dolist (`(,module ,url ,commit)
                 '((yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml"
                         "b733d3f5f5005890f324333dd57e1f0badec5c87")
                   (json "https://github.com/tree-sitter/tree-sitter-json"
                         "4d770d31f732d50d3ec373865822fbe659e47c75")
                   (sh "https://github.com/tree-sitter/tree-sitter-bash"
                       "487734f87fd87118028a65a4599352fa99c9cde8")
                   (docker "https://github.com/camdencheek/tree-sitter-dockerfile"
                           "087daa20438a6cc01fa5e6fe6906d77c869d19fe")))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "packages.el" (test-langs--dir module)))
      (should (search-forward "(modulep! +tree-sitter)" nil t))
      (should (search-forward url nil t))
      (should (search-forward commit nil t)))))

(provide 'test-data-langs)
;;; test-data-langs.el ends here
