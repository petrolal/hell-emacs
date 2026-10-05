;;; lisp/lib/block.el --- Reading and editing init.el's hell! block -*- lexical-binding: t; -*-

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

;; The `hell!' form in an init.el, read as text: where it is, what it
;; enables, which modules are commented out, where each group starts and
;; where a line joins it. `bin/hell config --add-defaults'
;; (lisp/cli/config.el) and the relic chamber (lisp/hell-plugins.el) edit
;; it with these.
;;
;; Part `block' of `hell-lib': (hell-require 'hell-lib 'block).

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'hell-lib)


(defun hell-block-read (file)
  "(START END SPEC) of the `hell!' form in FILE, or nil if it has none."
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
                (when (eq (car-safe form) 'hell!)
                  (throw 'found (list start (point) (cdr form))))))
          ((end-of-file invalid-read-syntax) nil))))))

(defun hell-block-spec (file)
  "The arguments of the `hell!' form in FILE, or nil."
  (nth 2 (hell-block-read file)))

(defun hell-block-modules (spec)
  "The modules SPEC (a `hell!' form's arguments) enables, as (KEY . ITEM).
KEY is (GROUP . NAME); ITEM is the module as written, flags and all."
  (let (group modules)
    (dolist (item spec)
      (cond ((keywordp item) (setq group item))
            ((and group (or (symbolp item) (and (consp item) (symbolp (car item)))))
             (push (cons (cons group (if (consp item) (car item) item)) item) modules))))
    (nreverse modules)))

(defun hell-block-lines (file)
  "The lines of the `hell!' form in FILE."
  (when-let* ((block (hell-block-read file)))
    (with-temp-buffer
      (insert-file-contents file)
      (split-string (buffer-substring-no-properties (nth 0 block) (nth 1 block)) "\n"))))

(defun hell-block-commented (file)
  "The module names commented out in FILE's `hell!' form.
As in `;;modeline' or `;;(java +x)'."
  (delq nil (mapcar (lambda (line)
                      (when (string-match "\\`[ \t]*;+[ \t]*(?\\([a-z][a-z0-9-]*\\)\\_>" line)
                        (intern (match-string 1 line))))
                    (hell-block-lines file))))

(defun hell-block-group-positions (start end)
  "(GROUP . POSITION) of each group keyword between START and END, in the buffer.
POSITION is the start of the keyword's line when the keyword starts it,
else the keyword itself (as in `(hell! :ui'). Keywords in comments
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

(defun hell-block-end-of-group (group groups end)
  "Return where lines join GROUP in GROUPS.
GROUPS is from `hell-block-group-positions'. That's after its last
line, before any blank lines that separate it from the next group.
For the last group, just before the form's closing line, which ends
at END."
  (save-excursion
    (let ((next (cadr (member (assq group groups) groups))))
      (if next
          (progn (goto-char (cdr next))
                 (skip-chars-backward " \t\n")
                 (forward-line 1)
                 (point))
        (goto-char (1- end))            ; the closing paren
        (line-beginning-position)))))

(hell-provide 'hell-lib 'block)
;;; block.el ends here
