;;; intellij-baseline.el --- IntelliJ's own numbers for the relative budgets -*- lexical-binding: t; -*-

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

;; Phase 12.7: two budgets are relative to IntelliJ on the same machine,
;; the first import's time and the memory after it. This imports and
;; indexes the reference project (reference.el) with IntelliJ IDEA
;; Community, headless (`idea.sh warmup'), and records the wall-clock time
;; and the IDE process's peak memory (from /proc) to $HELLMACS_BUDGET_OUT:
;;
;;   HELLMACS_BUDGET_OUT=/tmp/budgets.txt \
;;     emacs --batch -l early-init.el -f hellmacs-start \
;;           -l test/integration/intellij-baseline.el
;;
;; IntelliJ is pinned in budgets.el (`budgets-intellij') and downloaded
;; the first time, checked by SHA-256, into Hellmacs' cache (or
;; $HELLMACS_INTELLIJ_DIR). Its config, caches and logs go to a throwaway
;; directory, so every run is a first import. Linux only (/proc).
;;
;; Optional variables:
;;   HELLMACS_PARITY_REFERENCE  the reference project (spring-framework)
;;   HELLMACS_PARITY_TIMEOUT    seconds before the import is given up (1800)

;;; Code:

(require 'cl-lib)
(require 'hellmacs-sync)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)
(load (expand-file-name "reference" (file-name-directory (or load-file-name buffer-file-name))) nil t)
(load (expand-file-name "budgets" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defun baseline--home ()
  "The pinned IntelliJ's directory, installed there first if needed."
  (let* ((store (or (getenv "HELLMACS_INTELLIJ_DIR")
                    (expand-file-name "intellij/" hellmacs-cache-dir)))
         (home (file-name-as-directory
                (expand-file-name (concat "idea-IC-" (plist-get budgets-intellij :build)) store))))
    (unless (file-executable-p (expand-file-name "bin/idea.sh" home))
      (let ((tarball (expand-file-name (file-name-nondirectory (plist-get budgets-intellij :url)) store))
            (stage (make-temp-file "hellmacs-intellij" t)))
        (e2e--say "     downloading IntelliJ IDEA Community %s" (plist-get budgets-intellij :version))
        (unwind-protect
            (progn
              (hellmacs-sync-download-verified (plist-get budgets-intellij :url) tarball
                                               (plist-get budgets-intellij :sha256) "IntelliJ IDEA")
              (unless (zerop (call-process "tar" nil nil nil "-xzf" tarball "-C" stage))
                (error "Unpacking %s failed" tarball))
              (let ((top (car (directory-files stage t "\\`[^.]"))))
                (when (file-directory-p home) (delete-directory home t))
                (rename-file top (directory-file-name home))))
          (delete-directory stage t)
          (when (file-exists-p tarball) (delete-file tarball)))))
    home))

(let* ((name (intern (or (getenv "HELLMACS_PARITY_REFERENCE") "spring-framework")))
       (spec (e2e-reference name))
       (timeout (string-to-number (or (getenv "HELLMACS_PARITY_TIMEOUT") "1800")))
       (proj (e2e-copy-project (e2e-reference-fetch name)))
       (home (baseline--home))
       (state (make-temp-file "hellmacs-intellij-state" t))
       (props (expand-file-name "idea.properties" state))
       (process-environment (cons (concat "IDEA_PROPERTIES=" props) process-environment))
       measured)
  (e2e--say "IntelliJ baseline: %s %s (%s), IntelliJ IDEA Community %s"
            name (plist-get spec :tag) (plist-get spec :commit) (plist-get budgets-intellij :version))
  (write-region (budgets-intellij-properties state) nil props nil 'silent)
  (unwind-protect
      (with-temp-buffer
        ;; Timed here, and the IDE's JVM polled for its peak while it runs:
        ;; its VmHWM is gone from /proc once it exits.
        (let* ((t0 (float-time))
               (proc (apply #'start-process "intellij" (current-buffer)
                            (budgets-intellij-command home proj)))
               ide peak)
          (while (and (process-live-p proc) (< (- (float-time) t0) timeout))
            (accept-process-output proc 1)
            (setq ide (or ide (budgets-find-in-tree (process-id proc)
                                                       budgets-intellij-process-regexp)))
            (when-let* ((mb (and ide (budgets-peak-mb ide))))
              (setq peak (max mb (or peak 0)))))
          (let ((secs (- (float-time) t0))
                (status (if (process-live-p proc)
                            (progn (delete-process proc) 'timeout)
                          (process-exit-status proc))))
            (setq measured (and (eql status 0) peak))
            (if (not measured)
                (e2e--say "  FAIL  IntelliJ's import (exit %s%s); last output:\n%s" status
                          (if ide "" ", the IDE never started")
                          (mapconcat (lambda (l) (concat "       | " l))
                                     (last (split-string (string-trim (buffer-string)) "\n") 25)
                                     "\n"))
              (e2e--say "  PASS  IntelliJ imported and indexed the project")
              (e2e--say "     METRIC IntelliJ first import: %.1fs" secs)
              (e2e--say "     METRIC IntelliJ memory: %.0f MB peak" peak)
              (budgets-record 'intellij-import-seconds secs)
              (budgets-record 'intellij-memory-mb peak)))))
    ;; The Gradle daemon IntelliJ started outlives it.
    (let ((default-directory proj)
          (gradlew (expand-file-name "gradlew" proj)))
      (when (file-executable-p gradlew)
        (ignore-errors (call-process gradlew nil nil nil "--stop" "--quiet"))))
    (delete-directory state t)
    ;; The copy (and IntelliJ's .idea in it): gigabytes once built.
    (unless (member (getenv "HELLMACS_E2E_KEEP") '(nil ""))
      (setq proj nil))
    (when proj
      (delete-directory (file-name-directory (directory-file-name proj)) t)))
  (kill-emacs (if measured 0 1)))

;;; intellij-baseline.el ends here
