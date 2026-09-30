;;; lang/clojure/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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


;; Checked by `bin/hellmacs doctor'.

(hellmacs-module-load "+paths")

;; CIDER starts a REPL (`M-x cider-jack-in') with one of these.
(let ((tools (seq-filter #'executable-find '("clojure" "clj" "lein" "bb"))))
  (if tools
      (hellmacs-doctor-ok "REPL tool: %s" (string-join tools ", "))
    (hellmacs-doctor-warn "No clojure, lein or bb on the PATH: cider-jack-in can't start a REPL (M-x cider-connect still reaches one you started)"))
  ;; deps.edn projects need the Clojure CLI itself, for the REPL and for
  ;; clojure-lsp's classpath lookup (`clojure -Spath'); lein or bb aren't enough.
  (when (and tools (not (executable-find "clojure")))
    (hellmacs-doctor-warn "No Clojure CLI (clojure) on the PATH: in deps.edn projects the REPL can't start and clojure-lsp can't read the classpath")))

;; clojure-lsp is native code, so it needs no JDK; a project's REPL does.
(hellmacs-doctor-executable "java" "the REPL (the Clojure CLI runs on the JVM)" nil "-version")
(hellmacs-doctor-executable "unzip" "installing clojure-lsp")

(cond ((executable-find "clojure-lsp")
       (hellmacs-doctor-ok "clojure-lsp: %s (on the PATH, used instead of the pinned one)"
                           (abbreviate-file-name (executable-find "clojure-lsp"))))
      ((not (hellmacs-clojure-lsp-pin))
       (hellmacs-doctor-warn "No pinned clojure-lsp for this platform (%s); install it and put it on the PATH"
                             (or (hellmacs-clojure-lsp-platform) system-type)))
      (t
       (hellmacs-doctor-reachable (hellmacs-clojure-lsp-url) "installing clojure-lsp")
       (hellmacs-doctor-pinned "clojure-lsp" hellmacs-clojure-lsp-version
                               (hellmacs-clojure-lsp-installed-p) (file-exists-p hellmacs-clojure-lsp-executable)
                               :where hellmacs-clojure-lsp-dir
                               :missing-note " (or the first Clojure file does, unpinned)")))

;; Its grammars are checked from the declaration in packages.el.
(when (and (modulep! +tree-sitter) (version< emacs-version "30.1"))
  (hellmacs-doctor-error "clojure-ts-mode needs Emacs 30.1 or newer (this is %s); drop +tree-sitter" emacs-version))
