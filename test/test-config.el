;;; test-config.el --- Tests for keeping configs up with default modules -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. Roadmap 12.8, "Configs keep up with new
;; default modules": an init.el from an early template misses modules
;; enabled by default since (Magit, among others).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-cli)

(defconst test-config--early-init
  ";;; init.el -*- lexical-binding: t; -*-
;; My settings.
(setq hellmacs-proxy nil)

(hellmacs! :ui
           theme              ; the Hellmacs theme, line numbers, current line
           dashboard          ; startup dashboard with the sigil, C-c h s
           ;;modeline         ; don't want it

           :editor
           undo               ; persistent undo history (undo-fu-session)

           :completion
           vertico            ; minibuffer completion + consult commands
           corfu              ; in-buffer completion popup (+tab: TAB completes)

           :config
           default)           ; C-c leader groups: h, q, w; which-key

;; More of my settings.
(setq hellmacs-ux-enable t)
"
  "An init.el from an early template: no :tools, no :lang, modeline turned off.")

(defmacro test-config--with-init (content &rest body)
  "Run BODY with `init' an init.el holding CONTENT, in a temporary user dir."
  (declare (indent 1))
  `(let* ((hellmacs-user-dir (file-name-as-directory (make-temp-file "hellmacs-test-config" t)))
          (init (expand-file-name "init.el" hellmacs-user-dir)))
     (unwind-protect
         (progn
           (when ,content (with-temp-file init (insert ,content)))
           ,@body)
       (delete-directory hellmacs-user-dir t))))

(defun test-config--keys (modules)
  (mapcar #'car modules))

(ert-deftest test-config/defaults-from-the-example ()
  "The default modules are what static/init.example.el enables, each with its line."
  (let ((defaults (hellmacs-config-default-modules)))
    (should (member '(:tools . magit) (test-config--keys defaults)))
    (should (member '(:lang . java) (test-config--keys defaults)))
    (should-not (member '(:tools . docker) (test-config--keys defaults))) ; commented out there
    (should (string-match-p "^ +magit +; Git via Magit"
                            (cdr (assoc '(:tools . magit) defaults))))
    (should (string-match-p "^ +(java \\+lombok \\+spring) +; Java"
                            (cdr (assoc '(:lang . java) defaults))))))

(ert-deftest test-config/missing-defaults ()
  "Missing: on by default, but neither enabled nor commented out in your block."
  (test-config--with-init test-config--early-init
    (let ((missing (test-config--keys (hellmacs-config-missing-defaults init))))
      (should (equal missing '((:tools . build) (:tools . debugger) (:tools . direnv)
                               (:tools . lsp) (:tools . magit) (:tools . run)
                               (:lang . java) (:lang . kotlin) (:lang . clojure))))
      (should-not (member '(:ui . modeline) missing))))   ; commented out: a choice
  ;; No block of your own: the defaults apply, nothing is missing.
  (test-config--with-init "(setq hellmacs-proxy nil)\n"
    (should-not (hellmacs-config-missing-defaults init)))
  (test-config--with-init nil
    (should-not (hellmacs-config-missing-defaults init))))

(ert-deftest test-config/report ()
  "The report names each missing module with its line, and what to do."
  (test-config--with-init test-config--early-init
    (let ((out (with-output-to-string (hellmacs-config-report init))))
      (should (string-match-p "9 modules on by default aren't in your hellmacs! block" out))
      (should (string-match-p ":tools magit +magit +; Git via Magit" out))
      (should (string-match-p "bin/hellmacs config --add-defaults" out))))
  (test-config--with-init "(hellmacs! :ui theme)\n"
    ;; Everything else is missing too, but a block this short still reports.
    (should (string-match-p "aren't in your hellmacs! block"
                            (with-output-to-string (hellmacs-config-report init)))))
  (test-config--with-init nil
    (should (equal (with-output-to-string (hellmacs-config-report init)) ""))))

(ert-deftest test-config/add-defaults ()
  "Adding them edits only the block: new groups in the example's order, the rest intact."
  (test-config--with-init test-config--early-init
    (let ((added (hellmacs-config-add-defaults init)))
      (should (equal (test-config--keys added)
                     '((:tools . build) (:tools . debugger) (:tools . direnv) (:tools . lsp)
                       (:tools . magit) (:tools . run) (:lang . java) (:lang . kotlin) (:lang . clojure)))))
    (should (equal (with-temp-buffer (insert-file-contents (concat init ".bak")) (buffer-string))
                   test-config--early-init))
    (should-not (hellmacs-config-missing-defaults init))
    (let ((text (with-temp-buffer (insert-file-contents init) (buffer-string))))
      ;; Your settings and choices are kept.
      (should (string-match-p "^;; My settings\\.$" text))
      (should (string-match-p "^(setq hellmacs-ux-enable t)$" text))
      (should (string-match-p ";;modeline +; don't want it" text))
      ;; Groups in the example's order, before :config.
      (should (< (string-match "^ +:tools$" text) (string-match "^ +:lang$" text)
                 (string-match "^ +:config$" text)))
      (should (string-match-p "^ +magit +; Git via Magit" text))
      ;; It still reads as one block.
      (let ((spec (hellmacs-config--block-spec init)))
        (should (equal (car spec) :ui))
        (should (memq 'magit spec))
        (should (member '(java +lombok +spring) spec))
        (should (eq (car (last spec)) 'default))))
    ;; Nothing left: a second run adds nothing and leaves the file alone.
    (let ((before (file-attribute-modification-time (file-attributes init))))
      (should-not (hellmacs-config-add-defaults init))
      (should (equal before (file-attribute-modification-time (file-attributes init)))))))

(ert-deftest test-config/add-into-an-existing-group ()
  "A group you have gets the missing lines; an earlier backup isn't overwritten."
  (test-config--with-init "(hellmacs! :tools\n           magit\n\n           :config\n           default)\n"
    (with-temp-file (concat init ".bak") (insert "older backup"))
    (hellmacs-config-add-defaults init)
    (should (equal (with-temp-buffer (insert-file-contents (concat init ".bak")) (buffer-string))
                   "older backup"))
    (should (file-exists-p (concat init ".bak.1")))
    (let ((text (with-temp-buffer (insert-file-contents init) (buffer-string))))
      (should (= 1 (cl-count-if (lambda (line) (string-match-p "^ +:tools$" line))
                                (split-string text "\n"))))
      (should (string-match-p "^ +build +; build/test" text)))
    (should-not (hellmacs-config-missing-defaults init))))

(ert-deftest test-config/cli-command ()
  "`bin/hellmacs config' reports; with --add-defaults it adds and says to sync."
  (test-config--with-init test-config--early-init
    (should (string-match-p "config --add-defaults"
                            (with-output-to-string (hellmacs-cli-config))))
    (should (file-exists-p init))
    (should-not (file-exists-p (concat init ".bak")))
    (let ((out (with-output-to-string (hellmacs-cli-config "--add-defaults"))))
      (should (string-match-p "Added 9 modules to .*init\\.el" out))
      (should (string-match-p "bin/hellmacs sync" out)))
    (should (string-match-p "Nothing to add"
                            (with-output-to-string (hellmacs-cli-config "--add-defaults"))))))

(provide 'test-config)
;;; test-config.el ends here
