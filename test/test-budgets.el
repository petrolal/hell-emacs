;;; test-budgets.el --- Tests for the Phase 12.7 performance budgets -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'. The budgets (test/integration/budgets.el)
;; are measured by the weekly job (.github/workflows/budgets.yml): these
;; check the recording, the verdicts and the pins, not the measurements.

;;; Code:

(require 'ert)
(require 'cl-lib)
(hellmacs-require 'hellmacs-cli 'config)

(load (expand-file-name "test/integration/budgets" hellmacs-dir) nil t)

(defmacro test-budgets--with-file (var &rest body)
  "Run BODY with VAR a fresh temporary file name, deleted afterwards."
  (declare (indent 1))
  `(let ((,var (make-temp-file "hellmacs-budgets")))
     (unwind-protect (progn ,@body)
       (delete-file ,var))))

(ert-deftest test-budgets/table ()
  "The four budgets of the roadmap's table, each with the metric it reads
and either a limit or an IntelliJ baseline with a factor."
  (should (equal (mapcar #'car budgets-list) '(startup import completion memory)))
  (dolist (budget budgets-list)
    (let ((spec (cdr budget)))
      (should (stringp (plist-get spec :name)))
      (should (symbolp (plist-get spec :metric)))
      (should (stringp (plist-get spec :unit)))
      (should (xor (plist-get spec :limit) (plist-get spec :baseline)))
      (when (plist-get spec :baseline)
        (should (numberp (plist-get spec :factor))))))
  (should (= (plist-get (alist-get 'startup budgets-list) :limit) 0.3))
  (should (= (plist-get (alist-get 'completion budgets-list) :limit) 200))
  (should (= (plist-get (alist-get 'import budgets-list) :factor) 1.5))
  (should (eq (plist-get (alist-get 'memory budgets-list) :baseline) 'intellij-memory-mb)))

(ert-deftest test-budgets/record-and-read ()
  "Metrics are appended one per line; reading them back, a later value wins.
Without a file (no $HELLMACS_BUDGET_OUT) nothing is written."
  (test-budgets--with-file file
    (should (= (budgets-record 'completion-p95-ms 120.5 file) 120.5))
    (budgets-record 'startup-shown-seconds 0.2 file)
    (budgets-record 'completion-p95-ms 99 file)
    (should (equal (budgets-read file)
                   '((completion-p95-ms . 99) (startup-shown-seconds . 0.2)))))
  (let ((process-environment (cons "HELLMACS_BUDGET_OUT" process-environment)))
    (should (= (budgets-record 'x 1) 1)))
  (test-budgets--with-file file
    (let ((process-environment (cons (concat "HELLMACS_BUDGET_OUT=" file) process-environment)))
      (budgets-record 'x 2)
      (should (equal (budgets-read file) '((x . 2))))))
  (should-not (budgets-read "/no/such/budget-file")))

(ert-deftest test-budgets/percentile ()
  "Nearest-rank percentiles, whatever the order of the samples."
  (let ((samples (number-sequence 20 1 -1)))
    (should (= (budgets-percentile samples 95) 19))
    (should (= (budgets-percentile samples 50) 10))
    (should (= (budgets-percentile samples 100) 20)))
  (should (= (budgets-percentile '(7) 95) 7))
  (should-not (budgets-percentile nil 95)))

(ert-deftest test-budgets/evaluate ()
  "Each budget passes, fails, or is missing when a measurement is absent.
Relative budgets scale IntelliJ's own number by their factor."
  (let* ((metrics '((startup-shown-seconds . 0.21) (jdtls-import-seconds . 160)
                    (intellij-import-seconds . 100) (completion-p95-ms . 250)
                    (hellmacs-memory-mb . 2400)))
         (results (budgets-evaluate metrics)))
    (should (equal (mapcar (lambda (r) (plist-get r :status)) results)
                   '(pass fail fail missing)))
    (let ((import (nth 1 results)))
      (should (= (plist-get import :value) 160))
      (should (= (plist-get import :limit) 150.0)))
    (should (budgets-failed-p results)))
  (let ((results (budgets-evaluate '((startup-shown-seconds . 0.1) (jdtls-import-seconds . 150)
                                     (intellij-import-seconds . 100) (completion-p95-ms . 80)
                                     (hellmacs-memory-mb . 1900) (intellij-memory-mb . 2000)))))
    ;; "Within 1.5x" includes 1.5x itself.
    (should (cl-every (lambda (r) (eq (plist-get r :status) 'pass)) results))
    (should-not (budgets-failed-p results))))

(ert-deftest test-budgets/report ()
  "A Markdown table, one row per budget: what it is, the budget, the
measurement and the verdict."
  (let ((lines (budgets-report-lines
                (budgets-evaluate '((startup-shown-seconds . 0.2104) (completion-p95-ms . 250)
                                    (intellij-import-seconds . 100))))))
    (should (= (length lines) 6))
    (should (string-prefix-p "| Measurement |" (car lines)))
    (should (string-match-p "all enterprise modules on | < 0.3 s | 0.210 s | pass |" (nth 2 lines)))
    (should (string-match-p "| <= 150 s (1.5x IntelliJ's 100 s) | not measured | missing |" (nth 3 lines)))
    (should (string-match-p "| < 200 ms | 250 ms | FAIL |" (nth 4 lines)))))

(ert-deftest test-budgets/completion-points ()
  "Where completion latency is sampled: two characters into method calls
inside method bodies, spread over the file, at most N of them."
  (with-temp-buffer
    (insert "package p;\n\nimport java.util.List;\n\nclass Big {\n"
            "  private final List<String> names = new ArrayList<>();\n\n"
            "  void one() {\n    names.add(\"a\");\n    helper();\n  }\n\n"
            "  void two() {\n    String s = names.get(0).trim();\n    System.out.println(s);\n  }\n}\n")
    (let ((points (budgets-completion-points 10)))
      (should (equal (mapcar (lambda (p) (buffer-substring (- p 2) (+ p 2))) points)
                     '("add(" "help" "get(" "trim" "prin")))
      (should (equal (sort (copy-sequence points) #'<) points)))
    (let ((points (budgets-completion-points 2)))
      (should (= (length points) 2))
      ;; Spread out: the first and one well into the file, not the first two.
      (should (equal (mapcar (lambda (p) (buffer-substring (- p 2) (+ p 2))) points)
                     '("add(" "get("))))))

(ert-deftest test-budgets/process-tree ()
  "IntelliJ's IDE process is found in the launcher's process tree (the
launcher itself, when it execs the JVM as idea.sh does, or a descendant),
and its peak memory read from /proc: no GNU time needed."
  (skip-unless (file-directory-p "/proc/self"))
  (let ((forks (start-process "budgets-tree" nil "sh" "-c" "sleep 31.5; true"))
        (execs (start-process "budgets-exec" nil "sh" "-c" "exec sleep 32.5")))
    (unwind-protect
        (let (child)
          (let ((end (+ (float-time) 5)))
            (while (and (not (setq child (budgets-find-in-tree (process-id forks) "\\`sleep 31\\.5")))
                        (< (float-time) end))
              (accept-process-output nil 0.05)))
          (should child)
          (should-not (= child (process-id forks)))
          (should (= (budgets-find-in-tree (process-id execs) "\\`sleep 32\\.5")
                     (process-id execs)))
          (should-not (budgets-find-in-tree (process-id forks) "no-such-program-here"))
          (let ((peak (budgets-peak-mb child)))
            (should (numberp peak))
            (should (> peak 0))))
      (delete-process forks)
      (delete-process execs)))
  (should-not (budgets-peak-mb 999999999)))

(ert-deftest test-budgets/intellij-pin ()
  "IntelliJ IDEA Community, pinned by version, build and SHA-256, from JetBrains."
  (should (string-prefix-p "https://download.jetbrains.com/idea/" (plist-get budgets-intellij :url)))
  (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" (plist-get budgets-intellij :sha256)))
  (should (string-match-p (regexp-quote (plist-get budgets-intellij :version))
                          (plist-get budgets-intellij :url)))
  (should (stringp (plist-get budgets-intellij :build))))

(ert-deftest test-budgets/intellij-run ()
  "IntelliJ runs headless (warmup) on the project, with its config, caches and
logs under one throwaway directory; its IDE process is the one measured."
  (should (equal (budgets-intellij-command "/opt/idea/" "/tmp/p/")
                 '("/opt/idea/bin/idea.sh" "warmup" "--project-dir=/tmp/p/")))
  (should (string-match-p budgets-intellij-process-regexp
                          "/opt/idea/jbr/bin/java -Xmx2g -cp x com.intellij.idea.Main warmup"))
  (let ((props (budgets-intellij-properties "/tmp/ij/")))
    (dolist (key '("idea.config.path" "idea.system.path" "idea.log.path" "idea.plugins.path"))
      (should (string-match-p (concat "^" (regexp-quote key) "=/tmp/ij/") props)))))

(ert-deftest test-budgets/enterprise-init ()
  "The startup budget's config: every module that exists, as
static/init.example.el lists it (commented or not), with its flags;
[idea] and [planned] lines, which have no module yet, stay out."
  (let* ((spec (budgets-enterprise-spec))
         (modules (hellmacs-config--modules spec)))
    (should (eq (car spec) :ui))
    ;; Every default is still there, flags and all.
    (dolist (default (hellmacs-config-default-modules))
      (should (assoc (car default) modules)))
    (should (member '(java +lombok +spring) spec))
    ;; The opt-in enterprise modules are on.
    (dolist (key '((:tools . db) (:tools . docker) (:tools . http) (:tools . kubernetes)
                   (:checkers . static) (:editor . format) (:editor . snippets)
                   (:ui . vc-gutter) (:lang . yaml)))
      (should (assoc key modules)))
    (dolist (entry modules)
      (let ((key (car entry)))
        (should (file-directory-p (expand-file-name (format "modules/%s/%s"
                                                            (substring (symbol-name (car key)) 1)
                                                            (cdr key))
                                                    hellmacs-dir)))))
    (should-not (assoc '(:lang . scala) modules)))
  (let ((dir (make-temp-file "hellmacs-bench-user" t)))
    (unwind-protect
        (let ((init (budgets-write-enterprise-init dir)))
          (should (equal init (expand-file-name "init.el" dir)))
          (should (equal (hellmacs-config--block-spec init) (budgets-enterprise-spec))))
      (delete-directory dir t))))

(provide 'test-budgets)
;;; test-budgets.el ends here
