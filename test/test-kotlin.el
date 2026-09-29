;;; test-debugger.el --- Tests for the :tools debugger module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. These cover the module's own logic; its
;; behavior against a real kotlin-language-server is checked by the Phase
;; 8.2 probes (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-ux)

(defvar hellmacs-lsp-status--sessions)
(defvar hellmacs-kotlin-ls-executable)
(defvar hellmacs-kotlin-ls-marker)
(defvar hellmacs-kotlin-ls-sha256)
(defvar hellmacs-kotlin-map)
(defvar lsp-clients-kotlin-server-executable)

(defvar test-kotlin--loaded nil)

(defun test-kotlin--load ()
  "Load :lang kotlin's config.el, once, with :tools build and lsp on."
  (unless test-kotlin--loaded
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:tools build lsp :lang kotlin))
      (hellmacs-module--load '(:tools . lsp) "autoload.el") ; `hellmacs-lsp-pin-installer'
      (hellmacs-module--load '(:lang . kotlin) "config.el"))
    (setq test-kotlin--loaded t)))

(ert-deftest test-kotlin/keys-in-hellmacs-own-mode ()
  "C-c l k is in a Hellmacs minor mode Kotlin buffers turn on, not in
kotlin-mode's own map: `C-c letter' is the user's, not a package's."
  (test-kotlin--load)
  (should (memq #'hellmacs-kotlin-keys-mode kotlin-mode-hook))
  (should (memq #'hellmacs-kotlin-keys-mode kotlin-ts-mode-hook))
  (with-temp-buffer
    (hellmacs-kotlin-keys-mode 1)
    (should (eq (key-binding (kbd "C-c l k t")) #'hellmacs-forge-test-at-point))
    (hellmacs-kotlin-keys-mode -1)
    (should-not (eq (key-binding (kbd "C-c l k t")) #'hellmacs-forge-test-at-point))))

(ert-deftest test-kotlin/keys-and-server ()
  (test-kotlin--load)
  (should (eq (keymap-lookup hellmacs-kotlin-map "t") #'hellmacs-forge-test-at-point))
  (should (eq (keymap-lookup hellmacs-kotlin-map "T") #'hellmacs-forge-test-class))
  (should (eq (keymap-lookup hellmacs-kotlin-map "b") #'hellmacs-forge-build))
  ;; lsp-mode is pointed at the pinned server, not whatever is on the PATH.
  (should (equal lsp-clients-kotlin-server-executable hellmacs-kotlin-ls-executable))
  (should (memq #'lsp-deferred kotlin-mode-hook))
  (should (memq #'hellmacs-kotlin--setup-build-h kotlin-mode-hook)))

(ert-deftest test-kotlin/test-class-and-method ()
  (test-kotlin--load)
  (with-temp-buffer
    (setq buffer-file-name "/tmp/GreeterTest.kt")
    (insert "package dev.x

import kotlin.test.Test

class GreeterTest {
    @Test
    fun greets() {
        assertTrue(true)
    }

    @Test
    fun `greets someone by name`() {
        assertTrue(true)
    }
}
")
    (hellmacs-kotlin--setup-build-h)
    (should (equal (hellmacs-forge--test-class) "dev.x.GreeterTest"))
    (goto-char (point-min)) (search-forward "assertTrue")
    (should (equal (funcall hellmacs-forge-test-method-function) "greets"))
    (search-forward "assertTrue")
    (should (equal (hellmacs-kotlin-test-method) "greets someone by name"))
    (goto-char (point-min))
    (should-not (hellmacs-kotlin-test-method))
    (set-buffer-modified-p nil))
  ;; A file that holds a differently named class: the class wins over the file name.
  (with-temp-buffer
    (setq buffer-file-name "/tmp/Helpers.kt")
    (insert "package dev.x

data class Person(val name: String)
")
    (should (equal (hellmacs-kotlin-test-class) "dev.x.Person"))
    (set-buffer-modified-p nil)))

(ert-deftest test-kotlin/status-flow ()
  "ignited, then ready on the full index; a failed Gradle task says why, once."
  (test-kotlin--load)
  (let* ((root (make-temp-file "hellmacs-test-kotlin" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-ux-enable t)
         (shown nil))
    (unwind-protect
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) shown))))
          (should-not (hellmacs-kotlin-state root))
          (hellmacs-lsp-status-ignite 'kotlin-ls root)
          (should (eq (hellmacs-kotlin-state root) 'igniting))
          (should (string-match-p "FORGE IGNITED\\] Kotlin server" (car shown)))
          ;; The per-file symbol index isn't "ready"; the full one is.
          (hellmacs-kotlin--note-log root "async2    Updated symbol index in 8 ms! (1 symbol(s))")
          (should (eq (hellmacs-kotlin-state root) 'igniting))
          (hellmacs-kotlin--note-log root "..worker-1Updated full symbol index in 2053 ms! (18900 symbol(s))")
          (should (eq (hellmacs-kotlin-state root) 'ready))
          (should (string-match-p "DAEMON READY" (car shown)))
          ;; A later failure (say, build.gradle.kts edited badly).
          (hellmacs-kotlin--note-log
           root "async0    Gradle task failed: e: file:///p/build.gradle.kts:36:10: Unresolved reference 'x'.")
          (should (eq (hellmacs-kotlin-state root) 'failed))
          (should (string-match-p "BYTECODE PURGATORY.*failed to import: e: /p/build.gradle.kts:36:10" (car shown)))
          (let ((count (length shown)))
            (hellmacs-kotlin--note-log root "async1    Gradle task failed: again")
            (should (= count (length shown)))))       ; announced once
      (delete-directory root t))))

(ert-deftest test-kotlin/plain-wording ()
  (let ((hellmacs-ux-enable nil))
    (should (equal (hellmacs-lsp-status-announce 'failed "~/p" "why") "~/p failed to import: why"))))

(ert-deftest test-kotlin/server-install-is-pinned ()
  "Only the pinned release, marked and executable, counts as installed."
  (test-kotlin--load)
  (let* ((dir (make-temp-file "hellmacs-test-kls" t))
         (hellmacs-kotlin-ls-executable (expand-file-name "server/bin/kotlin-language-server" dir))
         (hellmacs-kotlin-ls-marker (expand-file-name ".hellmacs-sha256" dir)))
    (unwind-protect
        (progn
          (should-not (hellmacs-kotlin-ls-installed-p))
          (make-directory (file-name-directory hellmacs-kotlin-ls-executable) t)
          (with-temp-file hellmacs-kotlin-ls-executable (insert "#!/bin/sh\n"))
          (set-file-modes hellmacs-kotlin-ls-executable #o755)
          ;; Unmarked (say, installed by lsp-mode from "latest"): not the pin.
          (should-not (hellmacs-kotlin-ls-installed-p))
          (with-temp-file hellmacs-kotlin-ls-marker (insert "0000\n"))
          (should-not (hellmacs-kotlin-ls-installed-p))
          (with-temp-file hellmacs-kotlin-ls-marker (insert hellmacs-kotlin-ls-sha256 "\n"))
          (should (hellmacs-kotlin-ls-installed-p))
          (set-file-modes hellmacs-kotlin-ls-executable #o644)
          (should-not (hellmacs-kotlin-ls-installed-p)))
      (delete-directory dir t))))

(provide 'test-kotlin)
;;; test-kotlin.el ends here
