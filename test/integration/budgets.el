;;; budgets.el --- The Phase 12.7 performance budgets -*- lexical-binding: t; -*-

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

;; Phase 12.7: the budgets of the roadmap's table, measured every week by
;; .github/workflows/budgets.yml. The measuring scripts (startup-bench.el,
;; java-parity.el, intellij-baseline.el) each append their numbers to
;; $HELLMACS_BUDGET_OUT with `budgets-record', one "METRIC VALUE" line
;; each; budgets-check.el then reads the file, prints the table and fails
;; the job if a budget is broken or wasn't measured.
;; Not a test by itself; test/test-budgets.el checks it.

;;; Code:

(require 'cl-lib)

(defvar hellmacs-dir)                   ; early-init.el

(defconst budgets-list
  '((startup
     :name "Emacs startup, synced profile, all enterprise modules on"
     :metric startup-shown-seconds :limit 0.3 :unit "s" :format "%.3f")
    (import
     :name "JDTLS first import of the reference monorepo"
     :metric jdtls-import-seconds :baseline intellij-import-seconds :factor 1.5 :op <=
     :unit "s" :format "%.0f")
    (completion
     :name "Completion latency (p95) in a large class"
     :metric completion-p95-ms :limit 200 :unit "ms" :format "%.0f")
    (memory
     :name "Memory, Emacs plus JDTLS, after import"
     :metric hellmacs-memory-mb :baseline intellij-memory-mb :factor 1.0
     :unit "MB" :format "%.0f"))
  "The budgets: (ID :name :metric :unit :format, and :limit or :baseline).
A budget passes when its :metric is below :limit, or below :factor times
the :baseline metric (IntelliJ's own number, from the same run). :op is
the comparison, `<' unless given.")

;;; Recording and reading measurements --------------------------------------

(defun budgets-record (metric value &optional file)
  "Append METRIC's VALUE to FILE, else $HELLMACS_BUDGET_OUT; return VALUE.
Nothing is written when there's neither."
  (when-let* ((file (or file (getenv "HELLMACS_BUDGET_OUT")))
              ((not (string-empty-p file))))
    (write-region (format "%s %s\n" metric value) nil file 'append 'silent))
  value)

(defun budgets-read (file)
  "The metrics recorded in FILE, as (METRIC . VALUE), in the order first seen.
A metric recorded twice keeps its last value. nil if FILE doesn't exist."
  (when (file-readable-p file)
    (let (metrics)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward "^\\([a-z0-9-]+\\) \\(-?[0-9.]+\\)$" nil t)
          (let ((metric (intern (match-string 1)))
                (value (string-to-number (match-string 2))))
            (if-let* ((cell (assq metric metrics)))
                (setcdr cell value)
              (push (cons metric value) metrics)))))
      (nreverse metrics))))

(defun budgets-percentile (samples p)
  "The P-th percentile (nearest rank) of the numbers SAMPLES; nil if none."
  (when samples
    (let ((sorted (sort (copy-sequence samples) #'<)))
      (nth (max 0 (1- (ceiling (* (/ p 100.0) (length sorted))))) sorted))))

;;; Verdicts ------------------------------------------------------------------

(defun budgets-evaluate (metrics)
  "Each budget's verdict on METRICS, from `budgets-read', in `budgets-list' order.
A plist: :id, :name, :unit, :format, :value, :limit, :baseline, :factor,
:op, and :status, one of `pass', `fail' or `missing' (a number wasn't
measured: the budget's own, or the baseline it is compared with)."
  (mapcar
   (lambda (budget)
     (let* ((spec (cdr budget))
            (value (alist-get (plist-get spec :metric) metrics))
            (baseline (and (plist-get spec :baseline)
                           (alist-get (plist-get spec :baseline) metrics)))
            (limit (or (plist-get spec :limit)
                       (and baseline (* (plist-get spec :factor) baseline 1.0))))
            (op (or (plist-get spec :op) '<)))
       (append (list :id (car budget) :value value :limit limit :baseline baseline :op op
                     :status (cond ((not (and value limit)) 'missing)
                                   ((funcall op value limit) 'pass)
                                   (t 'fail)))
               spec)))
   budgets-list))

(defun budgets-failed-p (results)
  "Non-nil if any of RESULTS, from `budgets-evaluate', didn't pass."
  (cl-some (lambda (r) (not (eq (plist-get r :status) 'pass))) results))

(defun budgets--amount (result number)
  "NUMBER in RESULT's format and unit."
  (format (concat (plist-get result :format) " %s") number (plist-get result :unit)))

(defun budgets--budget-string (result)
  "RESULT's budget as the table shows it."
  (let ((op (plist-get result :op))
        (limit (plist-get result :limit))
        (factor (plist-get result :factor)))
    (cond ((not factor) (format "%s %s %s" op limit (plist-get result :unit)))
          ((not limit) (format "%s %sx IntelliJ's (not measured)" op factor))
          ((= factor 1) (format "%s %s (IntelliJ's)" op (budgets--amount result limit)))
          (t (format "%s %s (%sx IntelliJ's %s)" op (budgets--amount result limit)
                     factor (budgets--amount result (plist-get result :baseline)))))))

(defun budgets-report-lines (results)
  "RESULTS, from `budgets-evaluate', as the lines of a Markdown table."
  (append
   '("| Measurement | Budget | Measured | Verdict |"
     "|---|---|---|---|")
   (mapcar (lambda (r)
             (format "| %s | %s | %s | %s |"
                     (plist-get r :name)
                     (budgets--budget-string r)
                     (if (plist-get r :value) (budgets--amount r (plist-get r :value)) "not measured")
                     (pcase (plist-get r :status) ('pass "pass") ('fail "FAIL") (_ "missing"))))
           results)))

;;; Measuring -----------------------------------------------------------------

(defun budgets--ppid (pid)
  "PID's parent, from /proc, or nil if PID is gone."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (format "/proc/%d/stat" pid))
      ;; The name, in parens, may hold spaces: the fields after it are fixed
      ;; (state, then the parent).
      (goto-char (point-max))
      (search-backward ")")
      (string-to-number (nth 1 (split-string (buffer-substring (1+ (point)) (point-max))))))))

(defun budgets--cmdline (pid)
  "PID's command line, arguments joined by spaces, or nil."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents-literally (format "/proc/%d/cmdline" pid))
      (subst-char-in-string ?\0 ?\s (buffer-string)))))

(defun budgets-find-in-tree (pid regexp)
  "PID, or a process below it, whose command line matches REGEXP; nil if none.
PID itself first: a launcher that execs its program (idea.sh) is it."
  (let ((parents (make-hash-table)))
    (dolist (entry (directory-files "/proc" nil "\\`[0-9]+\\'"))
      (let ((child (string-to-number entry)))
        (when-let* ((ppid (budgets--ppid child)))
          (push child (gethash ppid parents)))))
    (let ((queue (list pid)) found)
      (while (and queue (not found))
        (let ((p (pop queue)))
          (if (string-match-p regexp (or (budgets--cmdline p) ""))
              (setq found p)
            (setq queue (append queue (gethash p parents))))))
      found)))

(defun budgets-peak-mb (pid)
  "PID's peak resident set size (VmHWM) in MB, or nil if PID is gone."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (format "/proc/%d/status" pid))
      (when (re-search-forward "^VmHWM:[ \t]+\\([0-9]+\\) kB" nil t)
        (/ (string-to-number (match-string 1)) 1024.0)))))

(defconst budgets-intellij-process-regexp "com\\.intellij\\.idea\\.Main"
  "The IDE's own JVM among the launcher's processes: the one measured.
Not the Gradle daemon it starts, as JDTLS's side leaves Gradle's out.")

(defconst budgets-intellij
  '(:version "2025.3"
    :build "253.28294.334"
    :url "https://download.jetbrains.com/idea/idea-2025.3.tar.gz"
    :sha256 "13f4174ba16c1cef04871cb261433536d002586c269a809392c20ee3f94959f5")
  "IntelliJ IDEA Community (Apache-2.0), the baseline of the relative budgets.
2025.3 is its last release: JetBrains folded Community into one IntelliJ
IDEA distribution after it, which needs a licence decision this one doesn't.")

(defun budgets-intellij-properties (dir)
  "An idea.properties that keeps IntelliJ's config, caches, logs and plugins in DIR."
  (let ((dir (file-name-as-directory dir)))
    (mapconcat (lambda (key) (format "idea.%s.path=%s%s\n" key dir key))
               '("config" "system" "log" "plugins")
               "")))

(defun budgets-intellij-command (home project)
  "The command that imports and indexes PROJECT with the IntelliJ in HOME, headless."
  (list (expand-file-name "bin/idea.sh" home)
        "warmup" (concat "--project-dir=" project)))

(defconst budgets--java-keywords
  '("if" "for" "while" "switch" "catch" "synchronized" "super" "this" "return" "try")
  "Words followed by a paren that aren't method calls.")

(defun budgets-completion-points (n)
  "Up to N places in this Java buffer to ask for completion, in order.
Each is two characters into a method call's name (as when typing it),
spread evenly over the file. Declarations (`void run(') don't count."
  (let (candidates)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\_<\\([a-z][A-Za-z0-9_]\\{2,\\}\\)(" nil t)
        (let* ((start (match-beginning 1))
               (before (buffer-substring-no-properties (line-beginning-position) start)))
          (unless (or (member (match-string 1) budgets--java-keywords)
                      ;; A type (or `>', `]') right before the name: a declaration.
                      (and (string-match-p "[]A-Za-z0-9_>][ \t]+\\'" before)
                           (not (string-match-p "\\_<return[ \t]+\\'" before))))
            (push (+ start 2) candidates)))))
    (let* ((candidates (nreverse candidates))
           (k (length candidates)))
      (if (<= k n)
          candidates
        (mapcar (lambda (i) (nth (/ (* i k) n) candidates)) (number-sequence 0 (1- n)))))))

;;; The startup budget's config -----------------------------------------------

(defun budgets--module-exists-p (group item)
  "Non-nil if Hellmacs ships module GROUP ITEM (ITEM as written, flags and all)."
  (file-directory-p
   (expand-file-name (format "modules/%s/%s" (substring (symbol-name group) 1)
                             (if (consp item) (car item) item))
                     hellmacs-dir)))

(defun budgets-enterprise-spec ()
  "A `hellmacs!' spec with every module Hellmacs ships on.
Taken from static/init.example.el's block, commented-out lines too, with
their flags and order; [idea] and [planned] lines have no module yet."
  (let (group spec)
    (with-temp-buffer
      (insert-file-contents (expand-file-name "static/init.example.el" hellmacs-dir))
      (goto-char (point-min))
      (re-search-forward "^(hellmacs!")
      (goto-char (match-beginning 0))
      (let ((end (save-excursion (forward-sexp) (point))))
        (while (< (point) end)
          (let* ((line (buffer-substring-no-properties (point) (line-end-position)))
                 (commented (string-match-p "\\`[ \t]*;" line))
                 (body (replace-regexp-in-string "\\`[ \t;]*\\(?:(hellmacs![ \t]*\\)?" "" line)))
            (cond ((and (not commented) (string-match "\\`\\(:[a-z]+\\)" body))
                   (setq group (intern (match-string 1 body)))
                   (push group spec))
                  ((and group (string-match-p "\\`(?[a-z][a-z0-9-]*" body)
                        (not (string-match-p "\\[\\(?:idea\\|planned\\)\\]" line)))
                   (let ((item (car (read-from-string (car (split-string body ";"))))))
                     (when (budgets--module-exists-p group item)
                       (push item spec))))))
          (forward-line 1))))
    (nreverse spec)))

(defun budgets-write-enterprise-init (dir)
  "Write DIR/init.el with `budgets-enterprise-spec' as its block; return its name."
  (let ((file (expand-file-name "init.el" dir)))
    (with-temp-file file
      (insert ";;; init.el --- every Hellmacs module on (Phase 12.7 startup budget) -*- lexical-binding: t; -*-\n\n")
      (insert (format "%S\n" (cons 'hellmacs! (budgets-enterprise-spec)))))
    file))

(provide 'budgets)
;;; budgets.el ends here
