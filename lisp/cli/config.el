;;; lisp/cli/config.el --- Keep a config up with the default modules -*- lexical-binding: t; -*-

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

;;; Commentary:

;; New modules are enabled by default in static/init.example.el, which is
;; copied only when you have no config yet; your init.el is yours and is
;; never rewritten behind your back. So a config made before a module
;; existed never gets it (roadmap 12.8). This finds those modules:
;;
;;   - `bin/hell doctor' and `bin/hell upgrade' list them;
;;   - `bin/hell config --add-defaults' adds them to your `hell!'
;;     block, only when asked, keeping a backup.
;;
;; A module you commented out in your block is your choice: it's never
;; listed or added. Flags are yours too: only missing modules count.
;;
;; Not loaded at startup; bin/hell loads it.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'hell-lib)
(eval-and-compile (hell-require 'hell-lib 'block))

(defvar hell-dir)                   ; early-init.el
(defvar hell-user-dir)
(declare-function hell-module-key-string "hell-modules" (key))

(defvar hell-config-example-file (expand-file-name "static/init.example.el" hell-dir)
  "The config new users start from; what it enables is on by default.")

(defvar hell-config-last-backup nil
  "The backup `hell-config-add-defaults' made last.")

;;; The defaults, and what's missing -----------------------------------------------------

(defun hell-config-default-modules ()
  "The modules on by default, in order, as (KEY . LINE).
LINE is the module's line in `hell-config-example-file', with its
description; KEY is (GROUP . NAME)."
  (let ((lines (hell-block-lines hell-config-example-file)))
    (mapcar (lambda (module)
              (let ((name (symbol-name (cdr (car module)))))
                (cons (car module)
                      (or (seq-find (lambda (line)
                                      (string-match-p (concat "\\`[ \t]*(?" (regexp-quote name) "\\_>") line))
                                    lines)
                          (format "           %s" (cdr module))))))
            (hell-block-modules (hell-block-spec hell-config-example-file)))))

(defun hell-config--init (init)
  "INIT, or the user's init.el."
  (or init (expand-file-name "init.el" hell-user-dir)))

(defun hell-config-missing-defaults (&optional init)
  "The default modules INIT's `hell!' block neither enables nor comments out.
INIT defaults to your init.el. As (KEY . LINE), see
`hell-config-default-modules'. Without a block of your own the
defaults apply, so nothing is missing."
  (let ((init (hell-config--init init)))
    (when-let* ((spec (hell-block-spec init)))
      (let ((enabled (mapcar #'car (hell-block-modules spec)))
            (commented (hell-block-commented init)))
        (seq-remove (lambda (default)
                      (or (member (car default) enabled)
                          (memq (cdr (car default)) commented)))
                    (hell-config-default-modules))))))

(defun hell-config--key-string (key)
  "Module KEY as a string, as `hell-module-key-string'."
  (hell-module-key-string key))

(defun hell-config-report-lines (&optional init)
  "What `hell-config-report' says about INIT, as lines.
nil if nothing's missing."
  (let* ((init (hell-config--init init))
         (missing (hell-config-missing-defaults init))
         (n (length missing)))
    (when missing
      (append
       (list (format "%d module%s on by default %s in your hell! block (%s):"
                     n (if (= n 1) "" "s") (if (= n 1) "isn't" "aren't") (abbreviate-file-name init)))
       (mapcar (lambda (m) (format "  %-18s %s" (hell-config--key-string (car m)) (string-trim (cdr m))))
               missing)
       (list "Add the ones you want to your hell! block, or all of them with"
             "`bin/hell config --add-defaults'; then `bin/hell sync' installs them.")))))

(defun hell-config-report (&optional init)
  "Print the default modules INIT's `hell!' block misses, if any."
  (dolist (line (hell-config-report-lines init))
    (princ (concat line "\n"))))

;;; Adding them -----------------------------------------------------------------

(defun hell-config--backup (file)
  "Copy FILE to the first free FILE.bak, FILE.bak.1, ...; return its name."
  (let* ((i 0)
         (name (concat file ".bak")))
    (while (file-exists-p name)
      (setq name (format "%s.bak.%d" file (cl-incf i))))
    (copy-file file name)
    name))

(defun hell-config-add-defaults (&optional init)
  "Add the default modules INIT's `hell!' block misses; return them.
Each goes in its group, as the example writes it; a missing group is
made, in the example's order. INIT (your init.el by default) is backed
up first (`hell-config-last-backup'); if the result doesn't read
back with them, it is restored. Nothing to add leaves INIT untouched."
  (let* ((init (hell-config--init init))
         (missing (hell-config-missing-defaults init)))
    (when missing
      (let* ((order (delete-dups (mapcar (lambda (d) (car (car d))) (hell-config-default-modules))))
             (backup (hell-config--backup init))
             (example-lines (hell-block-lines hell-config-example-file))
             inserts)
        (setq hell-config-last-backup backup)
        (with-temp-buffer
          (insert-file-contents init)
          (emacs-lisp-mode)
          (pcase-let* ((`(,start ,end ,_) (hell-block-read init))
                       (groups (hell-block-group-positions start end)))
            (dolist (group (delete-dups (mapcar (lambda (m) (car (car m))) missing)))
              (let ((lines (mapconcat (lambda (m) (concat (cdr m) "\n"))
                                      (seq-filter (lambda (m) (eq (car (car m)) group)) missing)
                                      "")))
                (if (assq group groups)
                    (push (cons (hell-block-end-of-group group groups end) lines) inserts)
                  ;; A new group: before the next one you have, in the example's order.
                  (let* ((later (cdr (memq group order)))
                         (before (seq-some (lambda (g) (assq g groups)) later))
                         (heading (or (seq-find (lambda (line) (string-match-p
                                                                (concat "\\`[ \t]*" (regexp-quote (symbol-name group)) "[ \t]*\\'")
                                                                line))
                                                example-lines)
                                      (concat "           " (symbol-name group)))))
                    (cond
                     ((null before))
                     ((save-excursion (goto-char (cdr before)) (bolp))
                      (push (cons (cdr before) (concat heading "\n" lines "\n")) inserts))
                     (t
                      ;; Mid-line, as in `(hell! :tools': take its place,
                      ;; and move it down to its own line, at its column.
                      (push (cons (cdr before)
                                  (concat (string-trim-left heading) "\n" lines "\n"
                                          (make-string (save-excursion (goto-char (cdr before))
                                                                       (current-column))
                                                       ?\s)))
                            inserts)))
                    (unless before
                      (push (cons (1- end) (concat "\n\n" heading "\n" (string-trim-right lines)))
                            inserts))))))
            ;; Several at one place go in in order, as one text; then bottom
            ;; up, so earlier positions stay put.
            (let (merged)
              (pcase-dolist (`(,pos . ,text) (nreverse inserts))
                (if-let* ((same (assq pos merged)))
                    (setcdr same (concat (cdr same) text))
                  (push (cons pos text) merged)))
              (dolist (insert (sort merged (lambda (a b) (> (car a) (car b)))))
                (goto-char (car insert))
                (insert (cdr insert)))))
          (write-region nil nil init nil 'silent))
        (when (or (not (hell-block-spec init))
                  (hell-config-missing-defaults init))
          (copy-file backup init t)
          (error "Couldn't add the modules to %s; it's unchanged. Add them by hand: %s"
                 (abbreviate-file-name init)
                 (mapconcat (lambda (m) (hell-config--key-string (car m))) missing ", ")))
        missing))))

(hell-provide 'hell-cli 'config)
;;; config.el ends here
