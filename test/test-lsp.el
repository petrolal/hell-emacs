;;; test-lsp.el --- Tests for :tools lsp -*- lexical-binding: t; no-byte-compile: t; -*-

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
(require 'hellmacs-modules)

(let ((hellmacs-modules (make-hash-table :test #'equal)))
  (hellmacs--enable-modules '(:tools lsp))
  (hellmacs-module--load '(:tools . lsp) "autoload.el"))

(defvar lsp-completion-mode)

(defun test-lsp--capf () nil)

(defvar gcmh-high-cons-threshold)

(ert-deftest test-lsp/completion-keeps-the-buffer-functions ()
  "The server's completion joins the buffer's own; words are the last fallback."
  (dolist (had-dabbrev '(nil t))
    (with-temp-buffer
      (cl-letf (((symbol-function 'cape-dabbrev) #'ignore))
        (setq-local completion-at-point-functions (list #'test-lsp--capf t))
        (when had-dabbrev
          (add-hook 'completion-at-point-functions #'cape-dabbrev 90 t))
        (let ((before completion-at-point-functions))
          ;; lsp-mode adds its function, then runs its mode hook.
          (setq-local lsp-completion-mode t)
          (add-hook 'completion-at-point-functions #'lsp-completion-at-point nil t)
          (hellmacs-lsp--setup-completion-h)
          (should (eq (car completion-at-point-functions) #'lsp-completion-at-point))
          (should (memq #'test-lsp--capf completion-at-point-functions))
          (should (eq (car (last (remq t completion-at-point-functions))) #'cape-dabbrev))
          ;; lsp-mode turns off and takes its function back.
          (setq lsp-completion-mode nil)
          (remove-hook 'completion-at-point-functions #'lsp-completion-at-point t)
          (hellmacs-lsp--setup-completion-h)
          (should (equal completion-at-point-functions before)))))))

(defvar lsp-keymap-prefix)
(defvar hellmacs-lsp--pinned-installers)

(ert-deftest test-lsp/lsp-mode-configured-unless-disabled ()
  "lsp-mode gets Hellmacs' settings, unless your packages.el disables it."
  (dolist (disabled '(nil t))
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (hellmacs-packages nil)
          (lsp-keymap-prefix "s-l")               ; lsp-mode's own default
          (gcmh-high-cons-threshold (* 64 1024 1024)) ; core's
          (warning-minimum-log-level :emergency))
      (hellmacs--enable-modules '(:tools lsp))
      (hellmacs-modules-read-packages)
      (when disabled (package! lsp-mode :disable t))
      (hellmacs-module--load '(:tools . lsp) "config.el")
      (should (eq (hellmacs-lsp-mode-used-p) (not disabled)))
      (should (equal lsp-keymap-prefix (if disabled "s-l" "C-c l")))
      ;; Collecting less often is for language servers' allocations.
      (should (= gcmh-high-cons-threshold (* (if disabled 64 128) 1024 1024))))))

(ert-deftest test-lsp/build-output-not-watched ()
  "A Maven or Gradle workspace's build output isn't watched; other workspaces' is.
On Spring Framework Gradle's build/ and JDTLS's bin/ took the watched
directories from 2726 to 6119 after one import and build, past
`lsp-file-watch-threshold', so the next session stopped to ask
(docs/roadmap.md, 12.7 Tuning). lsp-mode asks for the list from a
buffer whose file is under the workspace's root."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp))
    (hellmacs-module--load '(:tools . lsp) "config.el"))
  (let ((root (file-name-as-directory (file-truename (make-temp-file "hellmacs-test-lsp" t)))))
    (unwind-protect
        (let ((ignored (lambda ()
                         (with-temp-buffer
                           (setq buffer-file-name (expand-file-name "lsp-mode-temp" root))
                           (hellmacs-lsp--ignore-build-output-a '("[/\\\\]\\.git\\'"))))))
          ;; Not a JVM build: bin/ holds scripts.
          (should (equal (funcall ignored) '("[/\\\\]\\.git\\'")))
          (with-temp-file (expand-file-name "settings.gradle.kts" root))
          (let ((dirs (funcall ignored)))
            (should (= (length dirs) 2))
            (should (seq-some (lambda (re) (string-match-p re (concat root "core/bin"))) dirs))
            (should-not (seq-some (lambda (re) (string-match-p re (concat root "core/src/main/java/build")))
                                  dirs))))
      (delete-directory root t)))
  ;; No file: left alone.
  (with-temp-buffer
    (should (equal (hellmacs-lsp--ignore-build-output-a '("x")) '("x")))))

(defvar flymake-mode-map)

(ert-deftest test-lsp/diagnostic-keys-wherever-flymake-runs ()
  "C-c ! n/p/l are flymake's, in every flymake buffer (elisp too), not only lsp-mode's."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp))
    (hellmacs-module--load '(:tools . lsp) "config.el")
    (require 'flymake)
    (should (eq (keymap-lookup flymake-mode-map "C-c ! n") 'flymake-goto-next-error))
    (should (eq (keymap-lookup flymake-mode-map "C-c ! p") 'flymake-goto-prev-error))
    (should (eq (keymap-lookup flymake-mode-map "C-c ! l") 'flymake-show-buffer-diagnostics))))

(ert-deftest test-lsp/language-modules-depend-on-it ()
  "Every module on lsp-mode declares it, and gets its packages first."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-packages nil)
        (hellmacs-module-dependencies nil)
        (warning-minimum-log-level :emergency))
    ;; Languages listed before :tools, and :tools lsp left out.
    (hellmacs--enable-modules '(:lang java kotlin clojure :tools debugger))
    (hellmacs-modules-read-packages)
    (dolist (key '((:lang . java) (:lang . kotlin) (:lang . clojure) (:tools . debugger)))
      (should (equal (hellmacs-module-missing-dependencies key) '((:tools lsp)))))
    (hellmacs--enable-modules '(:lang java kotlin clojure :tools debugger lsp))
    (hellmacs-modules-read-packages)
    (let ((order (mapcar #'car (reverse hellmacs-packages))))
      (should (< (seq-position order 'lsp-mode) (seq-position order 'lsp-java))))
    (dolist (key (hellmacs-module-list))
      (should-not (hellmacs-module-missing-dependencies key)))))

(ert-deftest test-lsp/pinned-installers ()
  "A registered server is installed by its module; any other by lsp-mode."
  (let ((hellmacs-lsp--pinned-installers nil)
        (loaded nil) (installed nil) (lsp-own nil) (done nil))
    (cl-letf (((symbol-function 'lsp-package-ensure)
               (lambda (dep _cb _err) (setq lsp-own dep)))
              ((symbol-function 'hellmacs-module--load) (lambda (key file) (push (cons key file) loaded)))
              ((symbol-function 'message) #'ignore))
      (unwind-protect
          (progn
            (hellmacs-lsp-pin-installer 'fake-ls '(:lang . fake) (lambda () (setq installed t)))
            (lsp-package-ensure 'fake-ls (lambda () (setq done 'ok)) (lambda (m) (setq done m)))
            (should installed)
            (should (eq done 'ok))
            (should (equal loaded '(((:lang . fake) . "cli.el"))))
            (should-not lsp-own)
            ;; Another server: lsp-mode's own installer, untouched.
            (lsp-package-ensure 'other-ls #'ignore #'ignore)
            (should (eq lsp-own 'other-ls))
            ;; A failing install reaches lsp-mode's error callback.
            (hellmacs-lsp-pin-installer 'fake-ls '(:lang . fake) (lambda () (error "No network")))
            (lsp-package-ensure 'fake-ls #'ignore (lambda (m) (setq done m)))
            (should (equal done "No network")))
        (advice-remove 'lsp-package-ensure #'hellmacs-lsp--package-ensure-a)))))

(defvar lsp-mode-hook)

(ert-deftest test-lsp/which-key-names-whenever-lsp-starts ()
  "lsp-mode's `C-c l' groups are named even when a file opened at startup
starts it before which-key has loaded: which-key is loaded first."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-packages nil)
        (lsp-mode-hook nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp))
    (hellmacs-modules-read-packages)
    (hellmacs-module--load '(:tools . lsp) "config.el")
    (should (memq 'hellmacs-lsp--which-key-h lsp-mode-hook))
    (should-not (memq 'lsp-enable-which-key-integration lsp-mode-hook)))
  (let (calls)
    (cl-letf (((symbol-function 'require) (lambda (feature &rest _) (push feature calls) t))
              ((symbol-function 'lsp-enable-which-key-integration)
               (lambda (&rest _) (push 'integration calls))))
      (hellmacs-lsp--which-key-h))
    (should (equal (nreverse calls) '(which-key integration)))))

(provide 'test-lsp)
;;; test-lsp.el ends here
