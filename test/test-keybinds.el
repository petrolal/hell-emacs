;;; test-keybinds.el --- Tests for keybinds and leader layout -*- lexical-binding: t; -*-

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
(require 'hellmacs-keybinds)

(ert-deftest test-keybinds/leader-def-basic ()
  "hellmacs-leader-def registers commands under mode-specific-map."
  (let ((mode-specific-map (make-sparse-keymap)))
    (hellmacs-leader-def
      "h h" 'hellmacs-dashboard-open
      "f f" 'find-file)
    (should (eq (keymap-lookup mode-specific-map "h h") 'hellmacs-dashboard-open))
    (should (eq (keymap-lookup mode-specific-map "f f") 'find-file))))

(ert-deftest test-keybinds/leader-def-command-binding ()
  "hellmacs-leader-def binds commands under prefix groups."
  (let ((mode-specific-map (make-sparse-keymap)))
    (hellmacs-leader-def
      "b" "buffer"
      "b b" 'switch-to-buffer
      "b k" 'kill-current-buffer)
    (should (eq (keymap-lookup mode-specific-map "b b") 'switch-to-buffer))
    (should (eq (keymap-lookup mode-specific-map "b k") 'kill-current-buffer))))

(ert-deftest test-keybinds/leader-def-preserves-stock-keys ()
  "hellmacs-leader-def stays within mode-specific-map (C-c prefix)."
  (let ((mode-specific-map (make-sparse-keymap)))
    (hellmacs-leader-def "p p" 'project-switch-project)
    (should (eq (keymap-lookup mode-specific-map "p p") 'project-switch-project))))

;;; which-key names ------------------------------------------------------------

(defun test-keybinds--unnamed-prefixes (prefix &optional depth)
  "Prefix keys under PREFIX that which-key would show as \"+prefix\"."
  (let (unnamed)
    (dolist (b (which-key--get-bindings (kbd prefix)))
      (let ((key (concat prefix " " (substring-no-properties (car b))))
            (desc (substring-no-properties (nth 2 b))))
        (when (equal desc "+prefix") (push key unnamed))
        (when (and (string-prefix-p "+" desc) (< (or depth 0) 3))
          (setq unnamed (append (test-keybinds--unnamed-prefixes key (1+ (or depth 0))) unnamed)))))
    unnamed))

(ert-deftest test-keybinds/which-key-labels ()
  "`hellmacs-which-key-labels' names prefixes everywhere, or in one major mode."
  (require 'which-key)
  (let ((which-key-replacement-alist (copy-tree which-key-replacement-alist))
        (map (make-sparse-keymap)))
    (keymap-set map "C-c 9 a" #'ignore)
    (keymap-set map "C-c 8 a" #'ignore)
    (with-temp-buffer
      (use-local-map map)
      (hellmacs-which-key-labels nil "C-c 9" "nine")
      (hellmacs-which-key-labels 'test-keybinds-mode "C-c 8" "eight")
      (should-not (member "C-c 9" (test-keybinds--unnamed-prefixes "C-c")))
      (should (member "C-c 8" (test-keybinds--unnamed-prefixes "C-c")))  ; another mode's
      (setq major-mode 'test-keybinds-mode)
      (should-not (member "C-c 8" (test-keybinds--unnamed-prefixes "C-c"))))))

(ert-deftest test-keybinds/which-key-names-every-stock-prefix ()
  "With `:config default', which-key shows no \"+prefix\": Emacs' own prefix
keys (`C-x 8', `C-x r', `C-x v', `C-x w', `M-s h', `C-c ^'...) get names."
  (require 'which-key)
  (require 'iso-transl)                 ; `C-x 8''s accents
  (require 'hellmacs-modules)
  (let ((which-key-replacement-alist (copy-tree which-key-replacement-alist))
        (hellmacs-modules (make-hash-table :test #'equal))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:config default))
    (let ((mode-specific-map (copy-keymap mode-specific-map))) ; its own C-c keys aside
      (hellmacs-module--load '(:config . default) "config.el"))
    (unwind-protect
        (with-temp-buffer
          (fundamental-mode)
          (should-not (append (test-keybinds--unnamed-prefixes "C-x")
                              (test-keybinds--unnamed-prefixes "M-s")
                              (test-keybinds--unnamed-prefixes "M-g")
                              (seq-filter (lambda (k) (equal k "C-c ^"))
                                          (test-keybinds--unnamed-prefixes "C-c")))))
      (which-key-mode -1))))

(provide 'test-keybinds)
;;; test-keybinds.el ends here
