;;; test-popup.el --- Tests for the :ui popup module (Phase 10.3) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The live check (a Java build and a CIDER
;; REPL at the bottom, `q' restoring the layout) is in docs/roadmap.md, 10.3.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)

(defvar hellmacs-popup-rules)

(defun test-popup--load-config ()
  "Load the module's config.el with a scratch `C-c' map; return that map."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (mode-specific-map (make-sparse-keymap))
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:ui popup))
    (hellmacs-module--load '(:ui . popup) "config.el")
    mode-specific-map))

(defmacro test-popup--with-layout (&rest body)
  "Run BODY in a one-window frame with the module's rules, then clean up."
  (declare (indent 0))
  `(let ((display-buffer-alist nil)
         (buffers nil))
     (test-popup--load-config)
     (delete-other-windows)
     (unwind-protect
         (cl-flet ((make (name &optional mode)
                     (let ((buffer (get-buffer-create name)))
                       (push buffer buffers)
                       (when mode (with-current-buffer buffer (funcall mode)))
                       buffer)))
           ,@body)
       (delete-other-windows)
       (mapc #'kill-buffer buffers))))

(defun test-popup--keys (map &optional prefix)
  "Every key sequence bound in MAP, as `keymap-set' strings."
  (let (keys)
    (map-keymap
     (lambda (event def)
       (let ((key (concat prefix (key-description (vector event)))))
         ;; A labelled prefix is (LABEL . KEYMAP).
         (when (and (consp def) (stringp (car def)) (keymapp (cdr def)))
           (setq def (cdr def)))
         (if (keymapp def)
             (setq keys (append keys (test-popup--keys def (concat key " "))))
           (push key keys))))
     map)
    keys))

(defun test-popup--side (buffer)
  "Which side BUFFER is displayed on, nil if in an ordinary window."
  (window-parameter (display-buffer buffer) 'window-side))

(ert-deftest test-popup/no-packages ()
  "Built-in `display-buffer-alist' only: nothing to install."
  (let ((hellmacs-packages nil)
        (hellmacs-modules (make-hash-table :test #'equal)))
    (hellmacs--enable-modules '(:ui popup))
    (hellmacs-modules-read-packages)
    (should-not (cl-remove-if (lambda (p) (equal (plist-get (cdr p) :modules) '(:core)))
                              hellmacs-packages))))

(ert-deftest test-popup/popups-open-at-the-bottom ()
  "Compilation, test results, REPLs, help, xref and diagnostics each land in
the bottom side window, by name and by mode."
  (test-popup--with-layout
    (dolist (name '("*compilation*" "*run: App*" "*hellmacs-tests*" "*hellmacs-coverage*"
                    "*cider-repl demo:localhost:7888(clj)*" "*Help*" "*xref*"
                    "*Flymake diagnostics for `Foo.java'*" "*Flymake diagnostics for `/p/'*"
                    "*hellmacs-static*" "*lsp-help*" "*cider-error*" "*cider-test-report*"))
      (should (equal (cons name (test-popup--side (make name)))
                     (cons name 'bottom))))
    ;; By mode, whatever the name.
    (dolist (mode '(compilation-mode help-mode))
      (should (equal (cons mode (test-popup--side (make (format "renamed %s" mode) mode)))
                     (cons mode 'bottom))))))

(ert-deftest test-popup/ordinary-buffers-are-left-alone ()
  "Files, scratch, shells and Magit keep Emacs' own display rules."
  (test-popup--with-layout
    (dolist (name '("Foo.java" "*scratch*" "*shell*" "*eshell*" "magit: hellmacs" "*Messages*"))
      (should (equal (cons name (test-popup--side (make name)))
                     (cons name nil))))))

(ert-deftest test-popup/one-popup-at-a-time ()
  "A new popup replaces the last one in the same window: the layout above
never shrinks twice."
  (test-popup--with-layout
    (display-buffer (make "*compilation*"))
    (display-buffer (make "*Help*"))
    (should (= (length (window-list)) 2))
    (should-not (get-buffer-window "*compilation*"))
    ;; One already showing stays where it is.
    (let ((help (get-buffer-window "*Help*")))
      (should (eq (display-buffer "*Help*") help)))))

(ert-deftest test-popup/other-side-windows-are-left-alone ()
  "A bottom side window someone else opened stays when a popup opens."
  (test-popup--with-layout
    (let ((theirs (display-buffer-in-side-window (make "*their panel*") '((side . bottom) (slot . 1)))))
      (display-buffer (make "*compilation*"))
      (should (window-live-p theirs))
      (should (eq (window-buffer theirs) (get-buffer "*their panel*")))
      (should (get-buffer-window "*compilation*")))))

(ert-deftest test-popup/quit-restores-the-layout ()
  "`q' (`quit-window') in a popup deletes it: the layout is as it was."
  (test-popup--with-layout
    (let ((before (window-list))
          (popup (display-buffer (make "*Help*" #'help-mode))))
      (should (= (length (window-list)) 2))
      (with-selected-window popup (quit-window))
      (should (equal (window-list) before)))))

(ert-deftest test-popup/quit-after-several-popups ()
  "After a build, then help, one `q' closes the popup: it doesn't go back
to the build first."
  (test-popup--with-layout
    (let ((before (window-list)))
      (display-buffer (make "*compilation*" #'compilation-mode))
      (with-selected-window (display-buffer (make "*Help*" #'help-mode))
        (quit-window))
      (should (equal (window-list) before)))))

(ert-deftest test-popup/rules-are-yours-to-extend ()
  "A condition added to `hellmacs-popup-rules' makes that buffer a popup;
your own `display-buffer-alist' entries still win over the module's."
  (test-popup--with-layout
    (let ((hellmacs-popup-rules (cons "\\`\\*my-log\\*" hellmacs-popup-rules)))
      (should (eq (test-popup--side (make "*my-log*")) 'bottom)))
    (push '("\\`\\*Help\\*" display-buffer-same-window) display-buffer-alist)
    (should-not (test-popup--side (make "*Help*")))))

(ert-deftest test-popup/loading-twice-adds-one-rule ()
  "Reloading the config (`C-c h R') doesn't pile up entries."
  (let ((display-buffer-alist nil))
    (test-popup--load-config)
    (test-popup--load-config)
    (should (= (length display-buffer-alist) 1))))

(ert-deftest test-popup/keys ()
  "`C-c w t' toggles the popups (the stock `window-toggle-side-windows'),
and nothing else is bound: no `C-`', and `C-g' stays `keyboard-quit'."
  (let ((map (test-popup--load-config))
        (global (current-global-map)))
    (should (eq (keymap-lookup map "w t") 'window-toggle-side-windows))
    (should (equal (test-popup--keys map) '("w t")))
    (should-not (keymap-lookup global "C-`"))
    (should (eq (keymap-lookup global "C-g") 'keyboard-quit))
    (should (eq (keymap-lookup global "C-x 0") 'delete-window))))

(provide 'test-popup)
;;; test-popup.el ends here
