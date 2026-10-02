;;; lang/groovy/+paths.el -*- lexical-binding: t; -*-

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


;; Where groovy-language-server lives, and what `bin/hell sync' builds
;; it from. Loaded by config.el at startup, by cli.el in bin/hell and
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

(defconst hell-groovy-server-commit "347d098a928707223ce44b52cc45174a6327a5f3"
  "The groovy-language-server commit `bin/hell sync' builds: main on 2026-05-19.")

(defvar hell-groovy-server-url "https://github.com/GroovyLanguageServer/groovy-language-server"
  "Where the server's source is fetched from (`hell-mirrors' apply).")

(defconst hell-groovy-gradle-version "9.1.0"
  "The Gradle the server is built with: the release its wrapper names.")

(defconst hell-groovy-gradle-sha256
  "a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806"
  "SHA-256 of gradle-9.1.0-bin.zip (services.gradle.org's .sha256 matched).")

(defconst hell-groovy-gradle-url
  (format "https://services.gradle.org/distributions/gradle-%s-bin.zip" hell-groovy-gradle-version)
  "Where the pinned Gradle is downloaded from.")

(defconst hell-groovy-verification-metadata
  (expand-file-name "verification-metadata.xml"
                    (if hell--current-module
                        (hell-module-get hell--current-module :path)
                      (file-name-directory (or load-file-name buffer-file-name))))
  "The SHA-256 of every dependency the server's build resolves.")

(defvar hell-groovy-server-dir (expand-file-name "groovy/" lsp-server-install-dir)
  "Where the built server is installed.")

(defvar hell-groovy-server-jar
  (expand-file-name "groovy-language-server-all.jar" hell-groovy-server-dir)
  "The built server: one jar, with its dependencies.")

(defvar hell-groovy-gradle-dir (expand-file-name "gradle/" hell-groovy-server-dir)
  "Where the pinned Gradle is unpacked; only building the server uses it.")

(hell-component! :name "groovy-language-server" :version hell-groovy-server-commit
                 :license "Apache-2.0" :url hell-groovy-server-url
                     :path hell-groovy-server-jar)

(hell-component! :name "gradle" :version hell-groovy-gradle-version :license "Apache-2.0"
                 :url hell-groovy-gradle-url :sha256 hell-groovy-gradle-sha256
                     :path hell-groovy-gradle-dir)

(defun hell-groovy-server-spec ()
  "What the server is built from: a plist of :commit, :gradle-version,
:gradle-sha256 and :verification-metadata."
  (list :commit hell-groovy-server-commit
        :gradle-version hell-groovy-gradle-version
        :gradle-sha256 hell-groovy-gradle-sha256
        :verification-metadata hell-groovy-verification-metadata))

(defun hell-groovy--server-marker ()
  (concat hell-groovy-server-jar ".commit"))

(defun hell-groovy-server-installed-p ()
  "Non-nil if the server built from the pinned commit is installed."
  (and (file-exists-p hell-groovy-server-jar)
       (hell-marker-current-p (hell-groovy--server-marker)
                              (plist-get (hell-groovy-server-spec) :commit))))

;;; lang/groovy/+paths.el ends here
