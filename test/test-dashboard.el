;;; test-dashboard.el --- Tests for :ui dashboard -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The dashboard package itself isn't
;; installed in the test environment; drawing it in a GUI and in
;; `emacs -nw' is checked live (docs/roadmap.md, 9.2).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)

;; Loading the module sets the startup screen and a remap; keep both
;; out of the other suites.
(require 'hellmacs-splash (expand-file-name "hellmacs/+splash" hellmacs-modules-dir))
(let ((hellmacs-splash-buffer-function hellmacs-splash-buffer-function)
      (hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:ui dashboard))
  (hellmacs-module--load '(:ui . dashboard) "config.el")
  (defvar test-dashboard--startup-buffer-function hellmacs-splash-buffer-function))
(keymap-unset global-map "<remap> <hellmacs-splash>" t)

(defvar dashboard-mode-map)

(defmacro test-dashboard--with-assets (names &rest body)
  "Run BODY with an assets directory holding only the files NAMES."
  (declare (indent 1))
  `(let* ((dir (make-temp-file "hellmacs-assets" t))
          (hellmacs-dashboard-assets-dir (file-name-as-directory dir)))
     (unwind-protect
         (progn (dolist (name ,names)
                  (write-region "" nil (expand-file-name name dir)))
                ,@body)
       (delete-directory dir t))))

(defmacro test-dashboard--graphic (graphic &rest body)
  "Run BODY as if the frame were GRAPHIC (non-nil) or a terminal."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) ,graphic))
             ((symbol-function 'image-type-available-p) (lambda (&rest _) t)))
     ,@body))

(defvar hellmacs-prefix-map)

(ert-deftest test-dashboard/leader-label-says-dashboard ()
  "With the dashboard on, which-key calls `C-c h s' the dashboard, as it opens it."
  (dolist (modules '((:config default) (:config default :ui dashboard)))
    (let ((hellmacs-modules (make-hash-table :test #'equal))
          (mode-specific-map (make-sparse-keymap))
          (warning-minimum-log-level :emergency))
      (makunbound 'hellmacs-prefix-map)
      (hellmacs--enable-modules modules)
      (hellmacs-module--load '(:config . default) "config.el")
      (let ((label (car (alist-get ?s (cdr hellmacs-prefix-map)))))
        (should (equal label (if (memq :ui modules) "+altar/dashboard" "+altar/return"))))
      (should (eq (keymap-lookup hellmacs-prefix-map "s") 'hellmacs-splash)))))

(ert-deftest test-dashboard/banner-graphical ()
  "A graphical frame gets the small PNG first, with the text as fallback."
  (test-dashboard--with-assets '("banner-960.png" "banner.png" "banner.svg" "banner-ascii.txt")
    (test-dashboard--graphic t
      (let ((banner (hellmacs-dashboard-banner)))
        (should (equal (file-name-nondirectory (car banner)) "banner-960.png"))
        (should (equal (file-name-nondirectory (cdr banner)) "banner-ascii.txt"))))))

(ert-deftest test-dashboard/banner-graphical-fallbacks ()
  "Each missing picture falls back to the next, then to the text."
  (test-dashboard--graphic t
    (test-dashboard--with-assets '("banner.png" "banner-ascii.txt")
      (should (equal (file-name-nondirectory (car (hellmacs-dashboard-banner))) "banner.png")))
    (test-dashboard--with-assets '("banner.svg" "banner-ascii.txt")
      (should (equal (file-name-nondirectory (car (hellmacs-dashboard-banner))) "banner.svg")))
    (test-dashboard--with-assets '("banner.svg")
      (should (equal (file-name-nondirectory (hellmacs-dashboard-banner)) "banner.svg")))
    (test-dashboard--with-assets '("banner-ascii.txt")
      (should (equal (file-name-nondirectory (hellmacs-dashboard-banner)) "banner-ascii.txt"))))
  ;; No SVG support (no librsvg): the SVG is skipped.
  (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
            ((symbol-function 'image-type-available-p) (lambda (type) (eq type 'png))))
    (test-dashboard--with-assets '("banner.svg" "banner-ascii.txt")
      (should (equal (file-name-nondirectory (hellmacs-dashboard-banner)) "banner-ascii.txt")))))

(ert-deftest test-dashboard/banner-terminal ()
  "A terminal gets the text banner, never a picture."
  (test-dashboard--with-assets '("banner-960.png" "banner.png" "banner.svg" "banner-ascii.txt")
    (test-dashboard--graphic nil
      (should (equal (file-name-nondirectory (hellmacs-dashboard-banner)) "banner-ascii.txt")))))

(ert-deftest test-dashboard/banner-nothing ()
  "With no assets at all, dashboard's own ASCII logo, and no error."
  (test-dashboard--with-assets '()
    (test-dashboard--graphic t (should (eq (hellmacs-dashboard-banner) 'ascii)))
    (test-dashboard--graphic nil (should (eq (hellmacs-dashboard-banner) 'ascii))))
  (let ((hellmacs-dashboard-assets-dir "/nonexistent/"))
    (should (eq (hellmacs-dashboard-banner) 'ascii))))

(ert-deftest test-dashboard/startup-line ()
  "The spec's line, from the startup time and startup's GC count.
The same line as the Altar's (`hellmacs-splash-startup-line')."
  (let ((hellmacs-init-time 0.0567) (hellmacs-splash--init-gcs 3))
    (should (equal (hellmacs-splash-startup-line)
                   "[ALTAR] Bound in 0.06 seconds with 3 garbage collections.")))
  (let ((hellmacs-init-time 0.04) (hellmacs-splash--init-gcs 1))
    (should (equal (hellmacs-splash-startup-line)
                   "[ALTAR] Bound in 0.04 seconds with 1 garbage collection.")))
  (let ((hellmacs-init-time nil))
    (should (equal (hellmacs-splash-startup-line) "[ALTAR] Binding..."))))

(ert-deftest test-dashboard/footer-rotates ()
  "Each drawing shows the next of the three footers, then starts over."
  (let ((hellmacs-dashboard--footer-index -1))
    (should (equal (cl-loop repeat 4 collect (hellmacs-dashboard--next-footer))
                   (append hellmacs-dashboard-footers
                           (list (car hellmacs-dashboard-footers)))))))

(ert-deftest test-dashboard/icons ()
  "No icons in a terminal unless asked for."
  (test-dashboard--graphic nil
    (let ((hellmacs-dashboard-tty-icons nil)) (should-not (hellmacs-dashboard-icons-p)))
    (let ((hellmacs-dashboard-tty-icons t)) (should (hellmacs-dashboard-icons-p)))))

(ert-deftest test-dashboard/items-and-title ()
  "The spec's items, title and no shortcut keys, set before dashboard loads."
  (should (equal dashboard-items '((recents . 5) (projects . 5) (bookmarks . 3))))
  (should (eq dashboard-projects-backend 'project-el))
  (should (equal dashboard-banner-logo-title "HELLMACS: THE INFERNAL JVM HACKING ENVIRONMENT"))
  (should (null dashboard-item-shortcuts))
  (should (eq dashboard-init-info #'hellmacs-splash-startup-line)))

(ert-deftest test-dashboard/vanilla-keys ()
  "dashboard's own jump and remove keys are taken out; TAB, S-TAB, RET stay."
  (let ((dashboard-mode-map (make-sparse-keymap)))
    ;; dashboard's bindings (dashboard.el), on a stand-in map.
    (dolist (key (append hellmacs-dashboard-removed-keys '("TAB" "<backtab>" "RET")))
      (keymap-set dashboard-mode-map key #'ignore))
    (hellmacs-dashboard--vanilla-keys)
    (dolist (key hellmacs-dashboard-removed-keys)
      (should-not (keymap-lookup dashboard-mode-map key)))
    (dolist (key '("TAB" "<backtab>" "RET"))
      (should (keymap-lookup dashboard-mode-map key)))))

(ert-deftest test-dashboard/startup-buffer ()
  "The dashboard is the startup screen; a file on the command line wins."
  (should (eq test-dashboard--startup-buffer-function #'hellmacs-dashboard--startup-buffer))
  (let ((hellmacs-splash-buffer-function test-dashboard--startup-buffer-function))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/Foo.java")
      (should (eq (hellmacs-splash--initial-buffer) (current-buffer)))
      (setq buffer-file-name nil))
    (let ((hellmacs-splash-enable nil))
      (should (equal (buffer-name (hellmacs-splash--initial-buffer)) "*scratch*")))))

(provide 'test-dashboard)
;;; test-dashboard.el ends here
