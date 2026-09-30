;;; lisp/cli/config.el --- Keep a config up with the default modules -*- lexical-binding: t; -*-

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

;; New modules are enabled by default in static/init.example.el, which is
;; copied only when you have no config yet; your init.el is yours and is
;; never rewritten behind your back. So a config made before a module
;; existed never gets it (roadmap 12.8). This finds those modules:
;;
;;   - `bin/hellmacs doctor' and `bin/hellmacs upgrade' list them;
;;   - `bin/hellmacs config --add-defaults' adds them to your `hellmacs!'
;;     block, only when asked, keeping a backup.
;;
;; A module you commented out in your block is your choice: it's never
;; listed or added. Flags are yours too: only missing modules count.
;;
;; Not loaded at startup; bin/hellmacs loads it.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'hellmacs-lib)

(defvar hellmacs-dir)                   ; early-init.el
(defvar hellmacs-user-dir)

(defvar hellmacs-config-example-file (expand-file-name "static/init.example.el" hellmacs-dir)
  "The config new users start from; what it enables is on by default.")

(defvar hellmacs-config-last-backup nil
  "The backup `hellmacs-config-add-defaults' made last.")

;;; Reading a hellmacs! block ------------------------------------------------------

(defun hellmacs-config--block (file)
  "(START END SPEC) of the `hellmacs!' form in FILE, or nil if it has none."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (emacs-lisp-mode)
      (goto-char (point-min))
      (catch 'found
        (condition-case nil
            (while t
              (forward-comment (buffer-size))
              (let* ((start (point))
                     (form (read (current-buffer))))
                (when (eq (car-safe form) 'hellmacs!)
                  (throw 'found (list start (point) (cdr form))))))
          ((end-of-file invalid-read-syntax) nil))))))

(defun hellmacs-config--block-spec (file)
  "The arguments of the `hellmacs!' form in FILE, or nil."
  (nth 2 (hellmacs-config--block file)))

(defun hellmacs-config--modules (spec)
  "The modules SPEC (a `hellmacs!' form's arguments) enables, as (KEY . ITEM).
KEY is (GROUP . NAME); ITEM is the module as written, flags and all."
  (let (group modules)
    (dolist (item spec)
      (cond ((keywordp item) (setq group item))
            ((and group (or (symbolp item) (and (consp item) (symbolp (car item)))))
             (push (cons (cons group (if (consp item) (car item) item)) item) modules))))
    (nreverse modules)))

(defun hellmacs-config--block-lines (file)
  "The lines of the `hellmacs!' form in FILE."
  (when-let* ((block (hellmacs-config--block file)))
    (with-temp-buffer
      (insert-file-contents file)
      (split-string (buffer-substring-no-properties (nth 0 block) (nth 1 block)) "\n"))))

(defun hellmacs-config--commented (file)
  "The module names commented out in FILE's `hellmacs!' form.
As in `;;modeline' or `;;(java +x)'."
  (delq nil (mapcar (lambda (line)
                      (when (string-match "\\`[ \t]*;+[ \t]*(?\\([a-z][a-z0-9-]*\\)\\_>" line)
                        (intern (match-string 1 line))))
                    (hellmacs-config--block-lines file))))

;;; The defaults, and what's missing -----------------------------------------------------

(defun hellmacs-config-default-modules ()
  "The modules on by default, in order, as (KEY . LINE).
LINE is the module's line in `hellmacs-config-example-file', with its
description; KEY is (GROUP . NAME)."
  (let ((lines (hellmacs-config--block-lines hellmacs-config-example-file)))
    (mapcar (lambda (module)
              (let ((name (symbol-name (cdr (car module)))))
                (cons (car module)
                      (or (seq-find (lambda (line)
                                      (string-match-p (concat "\\`[ \t]*(?" (regexp-quote name) "\\_>") line))
                                    lines)
                          (format "           %s" (cdr module))))))
            (hellmacs-config--modules (hellmacs-config--block-spec hellmacs-config-example-file)))))

(defun hellmacs-config--init (init)
  "INIT, or the user's init.el."
  (or init (expand-file-name "init.el" hellmacs-user-dir)))

(defun hellmacs-config-missing-defaults (&optional init)
  "The default modules INIT's `hellmacs!' block neither enables nor comments out.
INIT defaults to your init.el. As (KEY . LINE), see
`hellmacs-config-default-modules'. Without a block of your own the
defaults apply, so nothing is missing."
  (let ((init (hellmacs-config--init init)))
    (when-let* ((spec (hellmacs-config--block-spec init)))
      (let ((enabled (mapcar #'car (hellmacs-config--modules spec)))
            (commented (hellmacs-config--commented init)))
        (seq-remove (lambda (default)
                      (or (member (car default) enabled)
                          (memq (cdr (car default)) commented)))
                    (hellmacs-config-default-modules))))))

(defun hellmacs-config--key-string (key)
  (hellmacs-module-key-string key))

(defun hellmacs-config-report-lines (&optional init)
  "What `hellmacs-config-report' says about INIT, as lines.
nil if nothing's missing."
  (let* ((init (hellmacs-config--init init))
         (missing (hellmacs-config-missing-defaults init))
         (n (length missing)))
    (when missing
      (append
       (list (format "%d module%s on by default %s in your hellmacs! block (%s):"
                     n (if (= n 1) "" "s") (if (= n 1) "isn't" "aren't") (abbreviate-file-name init)))
       (mapcar (lambda (m) (format "  %-18s %s" (hellmacs-config--key-string (car m)) (string-trim (cdr m))))
               missing)
       (list "Add the ones you want to your hellmacs! block, or all of them with"
             "`bin/hellmacs config --add-defaults'; then `bin/hellmacs sync' installs them.")))))

(defun hellmacs-config-report (&optional init)
  "Print the default modules INIT's `hellmacs!' block misses, if any."
  (dolist (line (hellmacs-config-report-lines init))
    (princ (concat line "\n"))))

;;; Adding them -----------------------------------------------------------------

(defun hellmacs-config--backup (file)
  "Copy FILE to the first free FILE.bak, FILE.bak.1, ...; return its name."
  (let* ((i 0)
         (name (concat file ".bak")))
    (while (file-exists-p name)
      (setq name (format "%s.bak.%d" file (cl-incf i))))
    (copy-file file name)
    name))

(defun hellmacs-config--group-positions (start end)
  "(GROUP . POSITION) of each group keyword between START and END, in the buffer.
POSITION is the start of the keyword's line when the keyword starts it,
else the keyword itself (as in `(hellmacs! :ui'). Keywords in comments
and strings, and a module's options (`(java :depth 5)'), don't count."
  (let ((depth (1+ (car (syntax-ppss start))))   ; the form's own elements
        groups)
    (save-excursion
      (goto-char start)
      (while (re-search-forward ":\\([a-z]+\\)\\_>" end t)
        ;; Not a module's option, as in `(java :depth 5)'.
        (unless (or (nth 8 (syntax-ppss)) (/= (car (syntax-ppss)) depth))
          (let ((keyword (match-beginning 0)))
            (push (cons (intern (concat ":" (match-string 1)))
                        (if (save-excursion (goto-char keyword) (skip-chars-backward " \t") (bolp))
                            (line-beginning-position)
                          keyword))
                  groups)))))
    (nreverse groups)))

(defun hellmacs-config--end-of-group (group groups end)
  "Where lines join GROUP (in GROUPS, from `hellmacs-config--group-positions'):
after its last line, before any blank lines that separate it from the
next group. For the last group, just before the form's closing line."
  (save-excursion
    (let ((next (cadr (member (assq group groups) groups))))
      (if next
          (progn (goto-char (cdr next))
                 (skip-chars-backward " \t\n")
                 (forward-line 1)
                 (point))
        (goto-char (1- end))            ; the closing paren
        (line-beginning-position)))))

(defun hellmacs-config-add-defaults (&optional init)
  "Add the default modules INIT's `hellmacs!' block misses; return them.
Each goes in its group, as the example writes it; a missing group is
made, in the example's order. INIT (your init.el by default) is backed
up first (`hellmacs-config-last-backup'); if the result doesn't read
back with them, it is restored. Nothing to add leaves INIT untouched."
  (let* ((init (hellmacs-config--init init))
         (missing (hellmacs-config-missing-defaults init)))
    (when missing
      (let* ((order (delete-dups (mapcar (lambda (d) (car (car d))) (hellmacs-config-default-modules))))
             (backup (hellmacs-config--backup init))
             (example-lines (hellmacs-config--block-lines hellmacs-config-example-file))
             inserts)
        (setq hellmacs-config-last-backup backup)
        (with-temp-buffer
          (insert-file-contents init)
          (emacs-lisp-mode)
          (pcase-let* ((`(,start ,end ,_) (hellmacs-config--block init))
                       (groups (hellmacs-config--group-positions start end)))
            (dolist (group (delete-dups (mapcar (lambda (m) (car (car m))) missing)))
              (let ((lines (mapconcat (lambda (m) (concat (cdr m) "\n"))
                                      (seq-filter (lambda (m) (eq (car (car m)) group)) missing)
                                      "")))
                (if (assq group groups)
                    (push (cons (hellmacs-config--end-of-group group groups end) lines) inserts)
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
                      ;; Mid-line, as in `(hellmacs! :tools': take its place,
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
        (when (or (not (hellmacs-config--block-spec init))
                  (hellmacs-config-missing-defaults init))
          (copy-file backup init t)
          (error "Couldn't add the modules to %s; it's unchanged. Add them by hand: %s"
                 (abbreviate-file-name init)
                 (mapconcat (lambda (m) (hellmacs-config--key-string (car m))) missing ", ")))
        missing))))

(hellmacs-provide 'hellmacs-cli 'config)
;;; config.el ends here
