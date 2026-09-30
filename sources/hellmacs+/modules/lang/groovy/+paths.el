;;; lang/groovy/+paths.el -*- lexical-binding: t; -*-

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


;; Where groovy-language-server lives, and what `bin/hellmacs sync' builds
;; it from. Loaded by config.el at startup, by cli.el in bin/hellmacs and
;; by doctor.el, before lsp-groovy loads.
;;
;; The server publishes no releases, so there's no download to pin by
;; SHA-256. It's built instead: its source at a pinned commit (git
;; checks the commit's hash, as for tree-sitter grammars), with a
;; pinned Gradle (checked by SHA-256, against Gradle's published one),
;; not the checkout's wrapper, which carries no checksum. Its build
;; resolves its dependencies from Maven Central and the Gradle plugin
;; portal; verification-metadata.xml, next to this file, is the
;; SHA-256 of each of them, and Gradle refuses one that differs. It
;; was written by `gradle --write-verification-metadata sha256' for
;; this commit on 2026-09-30; write it again with a new pin.

(defconst hellmacs-groovy-server-commit "347d098a928707223ce44b52cc45174a6327a5f3"
  "The groovy-language-server commit `bin/hellmacs sync' builds: main on 2026-05-19.")

(defvar hellmacs-groovy-server-url "https://github.com/GroovyLanguageServer/groovy-language-server"
  "Where the server's source is fetched from (`hellmacs-mirrors' apply).")

(defconst hellmacs-groovy-gradle-version "9.1.0"
  "The Gradle the server is built with: the release its wrapper names.")

(defconst hellmacs-groovy-gradle-sha256
  "a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806"
  "SHA-256 of gradle-9.1.0-bin.zip (services.gradle.org's .sha256 matched).")

(defconst hellmacs-groovy-gradle-url
  (format "https://services.gradle.org/distributions/gradle-%s-bin.zip" hellmacs-groovy-gradle-version)
  "Where the pinned Gradle is downloaded from.")

(defconst hellmacs-groovy-verification-metadata
  (expand-file-name "verification-metadata.xml"
                    (if hellmacs--current-module
                        (hellmacs-module-get hellmacs--current-module :path)
                      (file-name-directory (or load-file-name buffer-file-name))))
  "The SHA-256 of every dependency the server's build resolves.")

(defvar hellmacs-groovy-server-dir (expand-file-name "groovy/" lsp-server-install-dir)
  "Where the built server is installed.")

(defvar hellmacs-groovy-server-jar
  (expand-file-name "groovy-language-server-all.jar" hellmacs-groovy-server-dir)
  "The built server: one jar, with its dependencies.")

(defvar hellmacs-groovy-gradle-dir (expand-file-name "gradle/" hellmacs-groovy-server-dir)
  "Where the pinned Gradle is unpacked; only building the server uses it.")

(hellmacs-component! :name "groovy-language-server" :version hellmacs-groovy-server-commit
                     :license "Apache-2.0" :url hellmacs-groovy-server-url
                     :path hellmacs-groovy-server-jar)

(hellmacs-component! :name "gradle" :version hellmacs-groovy-gradle-version :license "Apache-2.0"
                     :url hellmacs-groovy-gradle-url :sha256 hellmacs-groovy-gradle-sha256
                     :path hellmacs-groovy-gradle-dir)

(defun hellmacs-groovy-server-spec ()
  "What the server is built from: a plist of :commit, :gradle-version,
:gradle-sha256 and :verification-metadata."
  (list :commit hellmacs-groovy-server-commit
        :gradle-version hellmacs-groovy-gradle-version
        :gradle-sha256 hellmacs-groovy-gradle-sha256
        :verification-metadata hellmacs-groovy-verification-metadata))

(defun hellmacs-groovy--server-marker ()
  (concat hellmacs-groovy-server-jar ".commit"))

(defun hellmacs-groovy-server-installed-p ()
  "Non-nil if the server built from the pinned commit is installed."
  (and (file-exists-p hellmacs-groovy-server-jar)
       (hellmacs-marker-current-p (hellmacs-groovy--server-marker)
                                  (plist-get (hellmacs-groovy-server-spec) :commit))))

;;; lang/groovy/+paths.el ends here
