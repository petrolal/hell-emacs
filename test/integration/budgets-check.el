;;; budgets-check.el --- Judge a run's measurements against the budgets -*- lexical-binding: t; -*-

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

;; Phase 12.7: the last step of the weekly budget job. Reads what the
;; measuring scripts recorded in $HELLMACS_BUDGET_OUT, prints the budget
;; table (also to $GITHUB_STEP_SUMMARY, when set) and exits non-zero if a
;; budget was broken or not measured:
;;
;;   HELLMACS_BUDGET_OUT=/tmp/budgets.txt \
;;     emacs --batch -l early-init.el -l test/integration/budgets-check.el

;;; Code:

(load (expand-file-name "budgets" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(let* ((file (or (getenv "HELLMACS_BUDGET_OUT") (error "Set HELLMACS_BUDGET_OUT to the measurements file")))
       (results (budgets-evaluate (budgets-read file)))
       (table (concat (mapconcat #'identity (budgets-report-lines results) "\n") "\n"))
       (summary (getenv "GITHUB_STEP_SUMMARY")))
  (princ table)
  (when (and summary (not (string-empty-p summary)))
    (write-region (concat "## Performance budgets (Phase 12.7)\n\n" table) nil summary 'append 'silent))
  (kill-emacs (if (budgets-failed-p results) 1 0)))

;;; budgets-check.el ends here
