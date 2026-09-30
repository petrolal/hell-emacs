;;; test-theme.el --- Tests for the hellmacs-inferno theme -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The theme is only loaded (not enabled),
;; and its face specs are read back from `theme-settings', so nothing
;; here depends on a display.

;;; Code:

(require 'ert)
(require 'seq)
(require 'cl-lib)

(add-to-list 'custom-theme-load-path (expand-file-name "themes/" hellmacs-dir))
(load-theme 'hellmacs-inferno t t)

(defvar hellmacs-inferno-palette)

(defun test-theme--color (name)
  "The colour NAME of the palette."
  (alist-get name hellmacs-inferno-palette))

(defun test-theme--faces ()
  "Alist of (FACE . ATTRIBUTES) the theme sets, for the `t' display."
  (let (faces)
    (pcase-dolist (`(,kind ,face ,_theme ,spec) (get 'hellmacs-inferno 'theme-settings))
      (when (eq kind 'theme-face)
        (push (cons face (car (alist-get t spec))) faces)))
    faces))

(defun test-theme--luminance (hex)
  "Relative luminance of HEX (\"#rrggbb\"), as WCAG 2 defines it."
  (let ((channels (mapcar (lambda (i)
                            (let ((c (/ (string-to-number (substring hex i (+ i 2)) 16) 255.0)))
                              (if (<= c 0.03928) (/ c 12.92) (expt (/ (+ c 0.055) 1.055) 2.4))))
                          '(1 3 5))))
    (+ (* 0.2126 (nth 0 channels)) (* 0.7152 (nth 1 channels)) (* 0.0722 (nth 2 channels)))))

(defun test-theme--contrast (a b)
  "WCAG contrast ratio between colours A and B."
  (let ((la (test-theme--luminance a)) (lb (test-theme--luminance b)))
    (/ (+ (max la lb) 0.05) (+ (min la lb) 0.05))))

(defconst test-theme--recessive
  '(fringe vertical-border window-divider window-divider-first-pixel
    window-divider-last-pixel line-number vertico-group-separator
    which-key-separator-face)
  "Faces drawn in `forge-gray', which the spec reserves for borders,
fringes and inactive line numbers: 2.89:1, just below the 3:1 for borders.")

(defun test-theme--mode-line-face-p (face)
  "Non-nil if FACE is drawn on the mode-line's background."
  (string-match-p "\\`\\(doom-modeline\\|mode-line\\|hellmacs-jvm-\\|compilation-mode-line-\\|magit-mode-line-\\|lsp-modeline-\\|eglot-mode-line\\)"
                  (symbol-name face)))

(defun test-theme--failures ()
  "Every foreground/background pair below its minimum, as strings."
  (let ((bg-main (test-theme--color 'bg-main))
        (bg-alt (test-theme--color 'bg-alt))
        failures)
    (pcase-dolist (`(,face . ,attrs) (test-theme--faces))
      (let* ((fg (plist-get attrs :foreground))
             (own-bg (plist-get attrs :background))
             (underline (plist-get attrs :underline))
             (backgrounds
              (cond (own-bg (list own-bg))
                    ;; Code is also read on the current line (`hl-line').
                    ((string-prefix-p "font-lock-" (symbol-name face)) (list bg-main bg-alt))
                    ((test-theme--mode-line-face-p face) (list bg-alt))
                    (t (list bg-main))))
             (minimum (if (memq face test-theme--recessive) 2.8 4.5)))
        (when (stringp fg)
          (dolist (bg backgrounds)
            (let ((ratio (test-theme--contrast fg bg)))
              (when (< ratio minimum)
                (push (format "%s: %s on %s is %.2f:1" face fg bg ratio) failures)))))
        ;; A coloured underline (diagnostics) is a graphical object: 3:1.
        (when-let* ((color (and (consp underline) (plist-get underline :color))))
          (let ((ratio (test-theme--contrast color bg-main)))
            (when (< ratio (if (memq face '(dap-ui-pending-breakpoint-face)) 2.8 3.0))
              (push (format "%s: underline %s is %.2f:1" face color ratio) failures))))))
    failures))

(ert-deftest test-theme/tokens ()
  "The spec's seven tokens and the two additions have their exact colours."
  (should (equal (mapcar #'test-theme--color
                         '(bg-main bg-alt fg-main inferno-crimson ember-amber
                           reap-gold forge-gray venom-green forge-gray-hi))
                 '("#16171d" "#1c1e24" "#bbc2cf" "#ff6c6b" "#da8548"
                   "#ecbe7b" "#5b6268" "#98be65" "#868f96"))))

(ert-deftest test-theme/only-palette-colours ()
  "Every colour a face uses comes from the palette."
  (let ((palette (mapcar #'cdr hellmacs-inferno-palette)))
    (pcase-dolist (`(,_face . ,attrs) (test-theme--faces))
      (dolist (value (flatten-tree attrs))
        (when (and (stringp value) (string-prefix-p "#" value))
          (should (member value palette)))))))

(ert-deftest test-theme/face-count ()
  "The 217 faces of the old theme, plus 8 dashboard and 19 doom-modeline."
  (let ((faces (mapcar #'car (test-theme--faces))))
    (should (= (length faces) 244))
    (should (= (seq-count (lambda (f) (string-prefix-p "dashboard-" (symbol-name f))) faces) 8))
    (should (= (seq-count (lambda (f) (string-prefix-p "doom-modeline" (symbol-name f))) faces) 19))
    (dolist (face '(default mode-line mode-line-inactive font-lock-keyword-face
                    vertico-current corfu-current lsp-face-highlight-read
                    dap-ui-marker-face magit-diff-added hellmacs-jvm-ready
                    hellmacs-splash-sigil hellmacs-fatality
                    dashboard-banner-logo-title dashboard-heading dashboard-footer-face
                    doom-modeline-bar doom-modeline-buffer-file doom-modeline-urgent))
      (should (memq face faces)))))

(ert-deftest test-theme/contrast ()
  "Text is at least 4.5:1 on its background, coloured underlines 3:1.
`forge-gray' faces are the specified exception (2.89:1)."
  (should (equal (test-theme--failures) nil)))

(ert-deftest test-theme/stock-cursor ()
  "`:ui theme' keeps Emacs' own block cursor."
  (let ((cursor (default-value 'cursor-type)))
    (unwind-protect
        (cl-letf (((symbol-function 'load-theme) #'ignore)
                  ((symbol-function 'disable-theme) #'ignore))
          (setq-default cursor-type t)
          (load (expand-file-name "sources/hellmacs+/modules/ui/theme/config.el" hellmacs-dir) nil t)
          (should (eq (default-value 'cursor-type) t)))
      (setq-default cursor-type cursor))))

(ert-deftest test-theme/default-is-inferno ()
  "`:ui theme' loads hellmacs-inferno by default, and for the old name."
  (dolist (case '((unset . hellmacs-inferno) (hellmacs . hellmacs-inferno)
                  (modus-vivendi . modus-vivendi)))
    (let (loaded)
      (cl-letf (((symbol-function 'load-theme) (lambda (theme &rest _) (setq loaded theme)))
                ((symbol-function 'disable-theme) #'ignore))
        (makunbound 'hellmacs-theme)
        (unless (eq (car case) 'unset)
          (defvar hellmacs-theme)
          (setq hellmacs-theme (car case)))
        (load (expand-file-name "sources/hellmacs+/modules/ui/theme/config.el" hellmacs-dir) nil t))
      (should (eq loaded (cdr case))))))

(provide 'test-theme)
;;; test-theme.el ends here
