;;; test-clojure.el --- Tests for the :lang clojure module -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. These cover the module's own logic; its
;; behavior against a real clojure-lsp and CIDER is checked by the Phase
;; 8.3 probes (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)
(require 'hellmacs-ux)

(defvar hellmacs-lsp-status--sessions)
(defvar hellmacs-clojure-lsp-sha256)
(defvar hellmacs-clojure-lsp-executable)
(defvar hellmacs-clojure-lsp-marker)

(defvar cider-repl-mode-hook)
(defvar hellmacs-ux-jvm-output-hooks)

(defvar test-clojure--loaded nil)

(defun test-clojure--load ()
  "Load :lang clojure's config.el, once."
  (unless test-clojure--loaded
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:tools lsp :lang clojure))
      (hellmacs-module--load '(:tools . lsp) "autoload.el") ; `hellmacs-lsp-pin-installer'
      (hellmacs-module--load '(:lang . clojure) "config.el"))
    (setq test-clojure--loaded t)))

(ert-deftest test-clojure/hooks-and-settings ()
  (test-clojure--load)
  (dolist (hook '(clojure-mode-hook clojurec-mode-hook clojurescript-mode-hook))
    (should (memq #'hellmacs-clojure--lsp-h (symbol-value hook))))
  ;; (CIDER's own settings apply when it loads; kotlin-e2e style checks
  ;; in clojure-e2e.el cover them.) Nothing is rebound: CIDER keeps its own keys.
  (should-not (keymap-lookup global-map "C-c M-j")))

(ert-deftest test-clojure/reload-into-the-repl ()
  "`C-c h r' loads a Clojure buffer, refreshes from the REPL, and needs a REPL."
  (test-clojure--load)
  (should (memq #'hellmacs-clojure--setup-reload-h cider-repl-mode-hook))
  (should (memq 'cider-repl-mode-hook hellmacs-ux-jvm-output-hooks))
  (let (did)
    (cl-letf (((symbol-function 'cider-current-repl) #'ignore)
              ((symbol-function 'cider-load-buffer) (lambda () (push 'load did)))
              ((symbol-function 'cider-ns-refresh) (lambda () (push 'refresh did))))
      (with-temp-buffer
        (should-error (hellmacs-clojure-reload) :type 'user-error)
        (cl-letf (((symbol-function 'cider-current-repl) (lambda () 'repl)))
          (hellmacs-clojure-reload)       ; not a Clojure buffer: the REPL's case
          (cl-letf (((symbol-function 'derived-mode-p) (lambda (&rest _) t)))
            (hellmacs-clojure-reload)))))
    (should (equal did '(load refresh)))))

(ert-deftest test-clojure/status-flow ()
  "ready on the first progress end; a failed classpath says why, once."
  (test-clojure--load)
  (let* ((root (make-temp-file "hellmacs-test-clojure" t))
         (hellmacs-lsp-status--sessions (make-hash-table :test #'equal))
         (hellmacs-ux-enable t)
         (shown nil)
         (fail-message "LSP classpath lookup failed when running `clojure -A:test:dev -Spath`. Some features may not work.\n\nError: Error building classpath. The following artifacts could not be resolved: no.such:lib:jar:0.0.1"))
    (unwind-protect
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (push (apply #'format fmt args) shown))))
          (hellmacs-lsp-status-ignite 'clojure-lsp root)
          (should (string-match-p "FORGE IGNITED\\] clojure-lsp" (car shown)))
          ;; A progress report isn't the end.
          (hellmacs-clojure--note-notification root "$/progress" '(:token "1" :value (:kind "report" :percentage 25)))
          (should (eq (hellmacs-clojure-state root) 'igniting))
          (hellmacs-clojure--note-notification root "textDocument/publishDiagnostics" '(:diagnostics []))
          (should (eq (hellmacs-clojure-state root) 'igniting))
          (hellmacs-clojure--note-notification root "$/progress" '(:token "1" :value (:kind "end")))
          (should (eq (hellmacs-clojure-state root) 'ready))
          (should (string-match-p "DAEMON READY" (car shown)))
          ;; Later progress runs (it re-analyses on edits) don't announce again.
          (let ((count (length shown)))
            (hellmacs-clojure--note-notification root "$/progress" '(:token "2" :value (:kind "end")))
            (should (= count (length shown))))
          ;; Unrelated requests are ignored; the classpath one fails the project.
          (hellmacs-clojure--note-request root "window/showMessageRequest" '(:type 2 :message "Something else"))
          (should (eq (hellmacs-clojure-state root) 'ready))
          (hellmacs-clojure--note-request root "window/showMessageRequest" (list :type 2 :message fail-message))
          (should (eq (hellmacs-clojure-state root) 'failed))
          (should (string-match-p "PURGATORY.*Error building classpath. The following artifacts could not be resolved"
                                  (car shown))))
      (delete-directory root t))))

(ert-deftest test-clojure/failure-reason-fallback ()
  (test-clojure--load)
  (should (string-match-p "classpath lookup failed"
                          (hellmacs-clojure--failure-reason "LSP classpath lookup failed when running x"))))

(ert-deftest test-clojure/server-pin-per-platform ()
  "Every platform has a 64-hex pin; only a marked, executable binary is installed."
  (test-clojure--load)
  (dolist (entry hellmacs-clojure-lsp-sha256)
    (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" (cdr entry))))
  (skip-unless (hellmacs-clojure-lsp-pin)) ; a platform with no pinned build
  (let ((dir (make-temp-file "hellmacs-test-clsp" t)))
    (unwind-protect
        (let ((hellmacs-clojure-lsp-executable (expand-file-name "clojure-lsp" dir))
              (hellmacs-clojure-lsp-marker (expand-file-name ".hellmacs-sha256" dir)))
          (should-not (hellmacs-clojure-lsp-installed-p))
          (with-temp-file hellmacs-clojure-lsp-executable (insert "#!/bin/sh\n"))
          (set-file-modes hellmacs-clojure-lsp-executable #o755)
          (should-not (hellmacs-clojure-lsp-installed-p)) ; unmarked: not the pin
          (with-temp-file hellmacs-clojure-lsp-marker (insert "0000\n"))
          (should-not (hellmacs-clojure-lsp-installed-p))
          (with-temp-file hellmacs-clojure-lsp-marker (insert (hellmacs-clojure-lsp-pin) "\n"))
          (should (hellmacs-clojure-lsp-installed-p)))
      (delete-directory dir t))))

(ert-deftest test-clojure/which-key-names-cider-groups ()
  "CIDER's and clojure-mode's unnamed groups get names in Clojure buffers."
  (test-clojure--load)
  (dolist (hook '(clojure-mode-hook clojure-ts-mode-hook))
    (should (memq #'hellmacs-clojure--which-key-h (symbol-value hook))))
  (let (args)
    (cl-letf (((symbol-function 'hellmacs-which-key-labels) (lambda (&rest a) (setq args a))))
      (with-temp-buffer
        (setq major-mode 'clojure-mode)
        (hellmacs-clojure--which-key-h)))
    (should (eq (car args) 'clojure-mode))
    (dolist (key '("C-c C-?" "C-c M-l" "C-c C-r n" "C-c C-r s"))
      (should (stringp (plist-get (cdr args) key #'equal))))))

(provide 'test-clojure)
;;; test-clojure.el ends here
