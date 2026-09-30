;;; tools/test/autoload.el -*- lexical-binding: t; -*-

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


;; Test results and coverage (Phase 12.5), from the reports every JVM
;; build tool already writes, so it works for Java, Kotlin, Groovy and
;; Scala alike:
;; - JUnit XML (Gradle's build/test-results/*/, Maven's
;;   target/surefire-reports/ and failsafe-reports/) into a
;;   `tabulated-list-mode' buffer, *hellmacs-tests*;
;; - JaCoCo's XML report into fringe marks (margin marks in a terminal).

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar hellmacs-cache-dir)
(defvar hellmacs-forge--started)
(declare-function hellmacs-forge-build-tool "../build/autoload")
(declare-function hellmacs-forge--run "../build/autoload")
(declare-function hellmacs-forge--find-source "../build/autoload")
(declare-function project-root "project")
(declare-function xml-parse-region "xml")
(declare-function dom-by-tag "dom")
(declare-function dom-attr "dom")
(declare-function dom-children "dom")
(declare-function dom-tag "dom")
(defvar hellmacs-forge-source-extensions)

;;; Finding reports ------------------------------------------------------------------

(defconst hellmacs-test--skipped-dirs
  (append hellmacs-ignored-dirs
          '(".gradle" ".mvn" "src" "classes" "libs" "tmp" "generated" "kotlin" "html"))
  "Directories never searched for reports: sources, VCS, compiled classes.")

(defun hellmacs-test--report-files (root regexp)
  "Files under ROOT whose path matches REGEXP, sorted, skipping sources and VCS."
  (sort (seq-filter (lambda (file) (string-match-p regexp file))
                    (directory-files-recursively
                     (expand-file-name root) "\\.xml\\'" nil
                     (lambda (dir)
                       (not (member (file-name-nondirectory dir) hellmacs-test--skipped-dirs)))))
        #'string<))

(defun hellmacs-test--root ()
  "The root of the build (or project) around `default-directory'."
  (or (nth 1 (hellmacs-forge-build-tool))
      (when-let* ((project (project-current nil default-directory)))
        (expand-file-name (project-root project)))
      default-directory))

;;; JUnit XML --------------------------------------------------------------------------

(defconst hellmacs-test-results--report-regexp
  "/\\(?:build/test-results/[^/]+\\|target/\\(?:surefire\\|failsafe\\)-reports\\)/[^/]+\\.xml\\'"
  "Where Gradle and Maven write JUnit XML reports, in any module.")

;;;###autoload
(defun hellmacs-test-results-find-reports (root)
  "The JUnit XML reports under ROOT, Gradle's and Maven's, of every module."
  (hellmacs-test--report-files root hellmacs-test-results--report-regexp))

;; Both kinds of report are read into the same `dom' shape, with libxml
;; when Emacs has it (JaCoCo's reports are big), else xml.el.
(defun hellmacs-test--xml (file)
  "The root element of the XML FILE, as a dom.
Loads dom.el, which reading the result needs, only when a report is read."
  (require 'dom)
  (with-temp-buffer
    (insert-file-contents file)
    (if (libxml-available-p)
        (libxml-parse-xml-region (point-min) (point-max))
      (require 'xml)
      (car (xml-parse-region (point-min) (point-max))))))

(defun hellmacs-test--children (node tag)
  "NODE's own child elements named TAG (`dom-by-tag' looks at every descendant)."
  (seq-filter (lambda (child) (and (consp child) (eq (dom-tag child) tag)))
              (dom-children node)))

(defun hellmacs-test-results--text (node)
  "The text inside NODE, trimmed."
  (string-trim (apply #'concat (seq-filter #'stringp (dom-children node)))))

(defun hellmacs-test-results--case (node file)
  "The test case in NODE, a <testcase> element of FILE's report."
  (let* ((problem (or (car (hellmacs-test--children node 'failure)) (car (hellmacs-test--children node 'error))))
         (trace (and problem (hellmacs-test-results--text problem)))
         (message (and problem (or (dom-attr problem 'message)
                                   (car (split-string trace "\n")) ""))))
    (list :name (or (dom-attr node 'name) "")
          :class (or (dom-attr node 'classname) "")
          :time (string-to-number (or (dom-attr node 'time) "0"))
          :status (cond (problem 'fail)
                        ((hellmacs-test--children node 'skipped) 'skip)
                        (t 'pass))
          :failure message
          :trace trace
          :file file)))

;;;###autoload
(defun hellmacs-test-results-parse-junit-xml (file)
  "The test suite in the JUnit XML report FILE, or nil if it isn't one.
A plist: :suite (its name), :total, :failures (failed or in error),
:skipped, :time and :cases, each a plist of :name, :class, :time,
:status (`pass', `fail' or `skip'), :failure (the message) and :trace."
  (let ((root (ignore-errors (hellmacs-test--xml file))))
    (when (and (consp root) (memq (dom-tag root) '(testsuite testsuites)))
      (let* ((suites (if (eq (dom-tag root) 'testsuite) (list root)
                       (hellmacs-test--children root 'testsuite)))
             (cases (cl-loop for suite in suites
                             append (mapcar (lambda (node) (hellmacs-test-results--case node file))
                                            (hellmacs-test--children suite 'testcase)))))
        (list :suite (or (dom-attr root 'name) (file-name-base file))
              :total (length cases)
              :failures (seq-count (lambda (c) (eq (plist-get c :status) 'fail)) cases)
              :skipped (seq-count (lambda (c) (eq (plist-get c :status) 'skip)) cases)
              :time (string-to-number (or (dom-attr root 'time) "0"))
              :file file
              :cases cases)))))

(defun hellmacs-test-results--test-id (case)
  "CASE as the build's test filter names it: \"pkg.Class#method\".
Without parentheses or a parameter index; a case with no method name
of its own (a parameterized one named \"[1] ...\") is its class."
  (let ((method (string-trim (car (split-string (plist-get case :name) "[([]")))))
    (if (string-empty-p method)
        (plist-get case :class)
      (concat (plist-get case :class) "#" method))))

;;; The results view --------------------------------------------------------------

(defvar-local hellmacs-test-results--root nil
  "The build root this view's reports are from.")

(defvar-local hellmacs-test-results--since nil
  "Only reports written since this time (`float-time') are shown; nil for all.")

(defvar hellmacs-test-results-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "RET" #'hellmacs-test-results-jump)
    (keymap-set map "r" #'hellmacs-test-results-rerun-at-point)
    (keymap-set map "f" #'hellmacs-test-results-rerun-failures)
    (keymap-set map "c" #'hellmacs-coverage-summary)
    map)
  "Keys of the test results view.")

;;;###autoload
(define-derived-mode hellmacs-test-results-mode tabulated-list-mode "Tests"
  "The tests of the last run, from the build's JUnit XML reports.
\\<hellmacs-test-results-mode-map>\\[hellmacs-test-results-jump] goes to the test (the failing line), \
\\[hellmacs-test-results-rerun-at-point] reruns it, \\[hellmacs-test-results-rerun-failures] reruns the failing ones,
\\[revert-buffer] reads every report again, \\[hellmacs-coverage-summary] shows coverage per file."
  (setq tabulated-list-format [("" 4 t) ("Suite" 24 t) ("Test" 36 t)
                               ("Time" 7 t :right-align t) ("Message" 0 nil)]
        tabulated-list-padding 1)
  ;; `g' is tabulated-list-mode's `revert-buffer', as in any list.
  (setq-local revert-buffer-function #'hellmacs-test-results--revert)
  (tabulated-list-init-header))

(defconst hellmacs-test-results--status-cells
  '((fail "FAIL" error) (skip "SKIP" shadow) (pass "PASS" success))
  "Each status, in the order the view lists them: its label and face.")

(defun hellmacs-test-results--entry (case)
  (pcase-let ((`(,label ,face) (alist-get (plist-get case :status) hellmacs-test-results--status-cells)))
    (list case
          (vector (propertize label 'face face)
                  (car (last (split-string (plist-get case :class) "\\.")))
                  (plist-get case :name)
                  (format "%.2f" (plist-get case :time))
                  (car (split-string (or (plist-get case :failure) "") "\n"))))))

(defun hellmacs-test-results--reports ()
  "This view's reports: under its root, and written since its time if it has one."
  (seq-filter (lambda (file)
                (or (null hellmacs-test-results--since)
                    ;; A second of slack: some file systems round times down.
                    (>= (float-time (file-attribute-modification-time (file-attributes file)))
                        (1- hellmacs-test-results--since))))
              (hellmacs-test-results-find-reports hellmacs-test-results--root)))

(defun hellmacs-test-results--fill ()
  "Read this view's reports into its entries."
  (let* ((cases (cl-loop for report in (hellmacs-test-results--reports)
                         append (plist-get (hellmacs-test-results-parse-junit-xml report) :cases)))
         (ranked (cl-loop for (status) in hellmacs-test-results--status-cells
                          append (seq-filter (lambda (c) (eq (plist-get c :status) status)) cases)))
         (count (lambda (status) (seq-count (lambda (c) (eq (plist-get c :status) status)) cases))))
    (setq tabulated-list-entries (mapcar #'hellmacs-test-results--entry ranked)
          mode-line-process (format " %d failed of %d tests, %d skipped"
                                    (funcall count 'fail) (length cases) (funcall count 'skip)))
    (tabulated-list-print t)))

;;;###autoload
(defun hellmacs-test-results-show (root &optional since)
  "Fill *hellmacs-tests* with ROOT's test reports (those written since SINCE); return it.
It isn't displayed; `hellmacs-test-results' does that."
  (with-current-buffer (get-buffer-create "*hellmacs-tests*")
    (unless (derived-mode-p 'hellmacs-test-results-mode)
      (hellmacs-test-results-mode))
    (setq default-directory (file-name-as-directory (expand-file-name root))
          hellmacs-test-results--root default-directory
          hellmacs-test-results--since since)
    (hellmacs-test-results--fill)
    (goto-char (point-min))
    (current-buffer)))

;;;###autoload
(defun hellmacs-test-results ()
  "Show the project's test results, from every JUnit XML report its build wrote."
  (interactive)
  (pop-to-buffer (hellmacs-test-results-show (hellmacs-test--root))))

(defun hellmacs-test-results--revert (&rest _)
  "Read the project's test reports again: every one of them, the latest of each class."
  (hellmacs-test-results-show hellmacs-test-results--root))

(defun hellmacs-test-results--case-at-point ()
  (or (tabulated-list-get-id) (user-error "No test on this line")))

(defun hellmacs-test-results-rerun-at-point ()
  "Run the test on this line again, with the build tool."
  (interactive)
  (let ((default-directory hellmacs-test-results--root))
    (hellmacs-forge--run 'test (hellmacs-test-results--test-id (hellmacs-test-results--case-at-point)))))

;;;###autoload
(defun hellmacs-test-results-rerun-failures ()
  "Run every failing test again, in one build.
Outside the results view, the failing tests of the project's reports."
  (interactive)
  (with-current-buffer (if (derived-mode-p 'hellmacs-test-results-mode)
                           (current-buffer)
                         (hellmacs-test-results-show (hellmacs-test--root)))
    (let ((failing (delete-dups
                    (cl-loop for (case) in tabulated-list-entries
                             when (eq (plist-get case :status) 'fail)
                             collect (hellmacs-test-results--test-id case))))
          (default-directory hellmacs-test-results--root))
      (unless failing (user-error "No failing tests"))
      (hellmacs-forge--run 'test failing))))

(defun hellmacs-test-results--class-file (class)
  "The source file of CLASS (\"pkg.Outer$Inner\") in the project, or nil."
  (let* ((outer (car (split-string class "\\$")))
         (dot (string-match-p "\\.[^.]*\\'" outer))
         (package (and dot (substring outer 0 dot)))
         (simple (if dot (substring outer (1+ dot)) outer)))
    (seq-some (lambda (ext) (hellmacs-forge--find-source (concat simple "." ext) package))
              hellmacs-forge-source-extensions)))

(defun hellmacs-test-results--failure-line (case)
  "The line of CASE's own class where it failed, from its stack trace, or nil."
  (when-let* ((trace (plist-get case :trace)))
    (when (string-match (concat "at \\(?:[^ \t\n/(]+/\\)?" (regexp-quote (plist-get case :class))
                                "\\(?:\\$[^.(\n]*\\)?\\.[^.(\n]+([^():\n]+:\\([0-9]+\\))")
                        trace)
      (string-to-number (match-string 1 trace)))))

(defun hellmacs-test-results-jump ()
  "Go to the test on this line: where it failed, or else its declaration."
  (interactive)
  (let* ((case (hellmacs-test-results--case-at-point))
         (file (or (hellmacs-test-results--class-file (plist-get case :class))
                   (user-error "Can't find %s in the project" (plist-get case :class))))
         (line (hellmacs-test-results--failure-line case))
         (method (regexp-quote (string-trim (car (split-string (plist-get case :name) "[([]"))))))
    (find-file-other-window file)
    (goto-char (point-min))
    (cond (line (forward-line (1- line)))
          ((and (not (string-empty-p method))
                ;; Java/Kotlin/Scala names, Kotlin's `backticks`, Groovy's "strings".
                (re-search-forward (concat "\\(?:\\_<" method "\\_>\\|`" method "`\\|\"" method "\"\\)"
                                           "[ \t]*(")
                                   nil t))
           (beginning-of-line)))))

(defconst hellmacs-test-results--ran-tests-regexp
  "^> Task [^ \n]*:test\\b\\|Tests run: [0-9]\\|[0-9]+ tests? completed"
  "Output of a build that ran tests: Gradle's test task, Surefire's counts.")

;;;###autoload
(defun hellmacs-test-results--after-build-h (buffer _status)
  "Read the reports a build in BUFFER wrote into the results view.
For `compilation-finish-functions'. Only reports written by this build
are shown: the tests it ran. The view isn't displayed; the failing
tests' message points to it."
  (with-current-buffer buffer
    (when (and (derived-mode-p 'compilation-mode)
               (save-excursion
                 (goto-char (point-min))
                 (re-search-forward hellmacs-test-results--ran-tests-regexp nil t)))
      (let* ((root (hellmacs-test--root))
             (since (bound-and-true-p hellmacs-forge--started))
             (fresh (with-temp-buffer
                      (setq hellmacs-test-results--root root
                            hellmacs-test-results--since since)
                      (hellmacs-test-results--reports))))
        (when fresh
          (hellmacs-test-results-show root since))))))

;;; Continuous testing (+watch) ---------------------------------------------------

(defvar hellmacs-forge-test-class-function)

(defconst hellmacs-test-watch--test-file-regexp
  "/src/[^/]*[tT]est[^/]*/\\|\\(?:Tests?\\|IT\\|Spec\\)\\.[a-z]+\\'"
  "Test sources: under a test source set (src/test/, src/integrationTest/), or named so.")

(defun hellmacs-test-watch--target ()
  "The tests to run when this buffer is saved, as a class name, or nil.
A test file is its own class; any other, its class's \"...Test\" if the
project has one."
  (when-let* ((file buffer-file-name)
              (class (ignore-errors (funcall hellmacs-forge-test-class-function))))
    (if (string-match-p hellmacs-test-watch--test-file-regexp file)
        class
      (let ((test (concat class "Test")))
        (and (hellmacs-test-results--class-file test) test)))))

(defun hellmacs-test-watch--after-save-h ()
  (when-let* ((class (hellmacs-test-watch--target)))
    (hellmacs-forge--run 'test class)))

;;;###autoload
(define-minor-mode hellmacs-test-watch-mode
  "Rerun the tests of this buffer's class each time it's saved.
Through the build tool's own test filter: a test class runs itself, any
other class its ...Test class, when there's one."
  :lighter " Watch"
  (if hellmacs-test-watch-mode
      (add-hook 'after-save-hook #'hellmacs-test-watch--after-save-h nil t)
    (remove-hook 'after-save-hook #'hellmacs-test-watch--after-save-h t)))

;;; Coverage (JaCoCo) ---------------------------------------------------------------

(defgroup hellmacs-coverage nil
  "Test coverage marks, from JaCoCo's reports."
  :group 'hellmacs)

(defface hellmacs-coverage-covered '((t :inherit success))
  "Lines the tests ran."
  :group 'hellmacs-coverage)

(defface hellmacs-coverage-partial '((t :inherit warning))
  "Lines the tests ran, but not every branch or instruction of."
  :group 'hellmacs-coverage)

(defface hellmacs-coverage-missed '((t :inherit error))
  "Lines the tests never ran."
  :group 'hellmacs-coverage)

(defconst hellmacs-coverage-jacoco-version "0.8.15"
  "The JaCoCo Maven plugin a coverage run uses (Gradle's jacoco plugin brings its own).")

(defconst hellmacs-coverage--report-regexp
  "\\(/\\)\\(?:target/site/jacoco[^/]*/jacoco\\.xml\\|build/reports/jacoco/[^/]+/[^/]+\\.xml\\)\\'"
  "Where JaCoCo's XML reports are: Maven's jacoco:report, Gradle's jacocoTestReport.
Group 1 ends the module's directory.")

;;;###autoload
(defun hellmacs-coverage-find-reports (root)
  "The JaCoCo XML reports under ROOT, of every module."
  (hellmacs-test--report-files root hellmacs-coverage--report-regexp))

(defun hellmacs-coverage--module-root (report)
  "The directory of the module REPORT covers."
  (string-match hellmacs-coverage--report-regexp report)
  (substring report 0 (match-end 1)))

(defun hellmacs-coverage--line-status (line)
  "The status of a JaCoCo <line>: `covered', `partial', `missed', or nil (no code)."
  (let ((mi (string-to-number (or (dom-attr line 'mi) "0")))
        (ci (string-to-number (or (dom-attr line 'ci) "0")))
        (mb (string-to-number (or (dom-attr line 'mb) "0"))))
    (cond ((and (zerop ci) (zerop mi)) nil)
          ((zerop ci) 'missed)
          ((or (> mi 0) (> mb 0)) 'partial)
          (t 'covered))))

;;;###autoload
(defun hellmacs-coverage-parse-jacoco-xml (file)
  "The line coverage in JaCoCo's XML report FILE.
An alist: (\"pkg/dir/File.java\" . ((LINE . STATUS) ...)), STATUS being
`covered', `partial' (some branch or instruction missed) or `missed'."
  (when-let* ((dom (ignore-errors (hellmacs-test--xml file))))
    (cl-loop for package in (dom-by-tag dom 'package)
             for dir = (dom-attr package 'name)
             append (cl-loop for source in (dom-children package)
                             when (and (consp source) (eq (dom-tag source) 'sourcefile))
                             collect (cons (concat (if (member dir '(nil "")) "" (concat dir "/"))
                                                   (dom-attr source 'name))
                                           (cl-loop for line in (dom-children source)
                                                    for status = (and (consp line) (eq (dom-tag line) 'line)
                                                                      (hellmacs-coverage--line-status line))
                                                    when status
                                                    collect (cons (string-to-number (dom-attr line 'nr))
                                                                  status)))))))

(defvar hellmacs-coverage--data nil
  "The coverage shown: ((MODULE-ROOT . PARSED-REPORT) ...).")

(defvar hellmacs-coverage-root-limit 4
  "How many projects' coverage is kept shown.
Each holds every covered line of every report in the project.")

(defvar hellmacs-coverage--roots nil
  "The project roots whose coverage is shown, most recently shown first.")

(defvar-local hellmacs-coverage--saved-margin nil
  "`left-margin-width' before this buffer got margin marks, or nil.")

(defvar hellmacs-coverage--bitmap
  (or (and (fboundp 'define-fringe-bitmap)
           (ignore-errors
             (define-fringe-bitmap 'hellmacs-coverage-bar (make-vector 8 #b11100000) nil nil '(center t))))
      'vertical-bar)
  "The fringe bitmap of a coverage mark.")

(defun hellmacs-coverage--mark-string (status)
  (let ((face (intern (format "hellmacs-coverage-%s" status))))
    (if (display-graphic-p)
        (propertize " " 'display `(left-fringe ,hellmacs-coverage--bitmap ,face))
      (propertize " " 'display `((margin left-margin) ,(propertize "▌" 'face face))))))

(defun hellmacs-coverage--clear ()
  "Remove this buffer's coverage marks."
  (dolist (o (overlays-in (point-min) (point-max)))
    (when (overlay-get o 'hellmacs-coverage) (delete-overlay o)))
  (when hellmacs-coverage--saved-margin
    (setq left-margin-width (car hellmacs-coverage--saved-margin)
          hellmacs-coverage--saved-margin nil)
    (hellmacs-coverage--redisplay)))

(defun hellmacs-coverage--redisplay ()
  "Show this buffer's new margin in its windows."
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-buffer window (current-buffer))))

(defun hellmacs-coverage--lines (file)
  "The coverage of FILE, from the report of the module it's in: ((LINE . STATUS) ...)."
  (cl-loop for (module . report) in hellmacs-coverage--data
           when (string-prefix-p module file)
           thereis (cdr (seq-find (lambda (entry) (string-suffix-p (concat "/" (car entry)) file))
                                  report))))

(defun hellmacs-coverage--mark-buffer ()
  "Mark this buffer's lines with the coverage shown."
  (when buffer-file-name
    (hellmacs-coverage--clear)
    (when-let* ((lines (hellmacs-coverage--lines (expand-file-name buffer-file-name))))
      (unless (display-graphic-p)
        (setq hellmacs-coverage--saved-margin (list left-margin-width)
              left-margin-width (max left-margin-width 1))
        (hellmacs-coverage--redisplay))
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          ;; In line order, each from the last: one pass over the buffer.
          (let ((at 1))
            (pcase-dolist (`(,line . ,status) (sort (copy-sequence lines) #'car-less-than-car))
              (when (zerop (forward-line (- line at)))
                (setq at line)
                (let ((o (make-overlay (point) (point))))
                  (overlay-put o 'hellmacs-coverage status)
                  (overlay-put o 'before-string (hellmacs-coverage--mark-string status)))))))))))

;;;###autoload
(defun hellmacs-coverage-show (&optional root)
  "Mark covered, partly covered and missed lines, from ROOT's JaCoCo reports.
In every source buffer of the project, and in those opened later, until
`hellmacs-coverage-hide'."
  (interactive)
  (let* ((root (file-name-as-directory (expand-file-name (or root (hellmacs-test--root)))))
         (reports (or (hellmacs-coverage-find-reports root)
                      (user-error "No JaCoCo report in %s; `hellmacs-coverage-run' writes one"
                                  (abbreviate-file-name root)))))
    (setq hellmacs-coverage--data
          (append (mapcar (lambda (report)
                            (cons (hellmacs-coverage--module-root report)
                                  (hellmacs-coverage-parse-jacoco-xml report)))
                          reports)
                  (seq-remove (lambda (entry) (string-prefix-p root (car entry)))
                              hellmacs-coverage--data))
          hellmacs-coverage--roots (cons root (delete root hellmacs-coverage--roots)))
    ;; The least recently shown projects' beyond the limit go.
    (dolist (gone (nthcdr hellmacs-coverage-root-limit hellmacs-coverage--roots))
      (setq hellmacs-coverage--data
            (seq-remove (lambda (entry) (string-prefix-p gone (car entry))) hellmacs-coverage--data)))
    (setq hellmacs-coverage--roots (seq-take hellmacs-coverage--roots hellmacs-coverage-root-limit))
    (add-hook 'find-file-hook #'hellmacs-coverage--mark-buffer)
    (dolist (buffer (buffer-list))
      (when-let* ((file (buffer-file-name buffer)))
        (when (string-prefix-p root (expand-file-name file))
          (with-current-buffer buffer (hellmacs-coverage--mark-buffer)))))
    (message "Coverage from %d JaCoCo report%s" (length reports) (if (cdr reports) "s" ""))))

;;;###autoload
(defun hellmacs-coverage-hide ()
  "Remove every coverage mark."
  (interactive)
  (setq hellmacs-coverage--data nil
        hellmacs-coverage--roots nil)
  (remove-hook 'find-file-hook #'hellmacs-coverage--mark-buffer)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (or hellmacs-coverage--saved-margin
                (seq-some (lambda (o) (overlay-get o 'hellmacs-coverage))
                          (overlays-in (point-min) (point-max))))
        (hellmacs-coverage--clear)))))

;;;###autoload
(defun hellmacs-coverage-summary-rows (root)
  "ROOT's coverage per file: ((FILE COVERED-LINES LINES) ...), least covered first.
A line is covered when some of its code ran (JaCoCo's own rule)."
  (sort (cl-loop for report in (hellmacs-coverage-find-reports root)
                 append (cl-loop for (file . lines) in (hellmacs-coverage-parse-jacoco-xml report)
                                 collect (list file
                                               (seq-count (lambda (l) (not (eq (cdr l) 'missed))) lines)
                                               (length lines))))
        (lambda (a b) (< (/ (float (nth 1 a)) (max 1 (nth 2 a)))
                         (/ (float (nth 1 b)) (max 1 (nth 2 b)))))))

(define-derived-mode hellmacs-coverage-summary-mode tabulated-list-mode "Coverage"
  "Line coverage per file, from JaCoCo's reports."
  (setq tabulated-list-format [("File" 60 t) ("Lines" 7 nil :right-align t) ("Covered" 12 nil)]
        tabulated-list-padding 1)
  (tabulated-list-init-header))

;;;###autoload
(defun hellmacs-coverage-summary (&optional root)
  "Show line coverage per file from ROOT's JaCoCo reports, least covered first."
  (interactive (list (or (bound-and-true-p hellmacs-test-results--root) (hellmacs-test--root))))
  (let ((rows (hellmacs-coverage-summary-rows (or root (hellmacs-test--root)))))
    (with-current-buffer (get-buffer-create "*hellmacs-coverage*")
      (hellmacs-coverage-summary-mode)
      (setq tabulated-list-entries
            (mapcar (pcase-lambda (`(,file ,covered ,total))
                      (list file (vector file
                                         (format "%.1f%%" (* 100.0 (/ (float covered) (max 1 total))))
                                         (format "%d/%d" covered total))))
                    rows))
      (tabulated-list-print)
      (goto-char (point-min))
      (when (called-interactively-p 'any) (pop-to-buffer (current-buffer)))
      (current-buffer))))

;;; Running the tests with coverage -------------------------------------------------------

(defconst hellmacs-coverage--gradle-init-script
  "// Written by Hellmacs (:tools test): JaCoCo for this run only, from the
// command line, so the build files stay as they are.
allprojects {
    plugins.withId('java') {
        apply plugin: 'jacoco'
        tasks.named('jacocoTestReport') {
            dependsOn tasks.named('test')
            reports { xml.required = true }
        }
    }
}
"
  "The Gradle init script a coverage run adds JaCoCo with.")

(defun hellmacs-coverage--gradle-init-file ()
  "The init script's file, written if it isn't there or has changed."
  (let ((file (expand-file-name "hellmacs/jacoco.gradle" hellmacs-cache-dir)))
    (unless (and (file-exists-p file)
                 (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                        hellmacs-coverage--gradle-init-script))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert hellmacs-coverage--gradle-init-script)))
    file))

(defun hellmacs-coverage--command (&optional build)
  "The command running the tests with JaCoCo and writing its XML report.
JaCoCo is added on the command line, never to the build file. BUILD is
the build's (TOOL ROOT PROGRAM), if already known."
  (pcase-let ((`(,tool ,_root ,program) (or build (hellmacs-forge-build-tool)
                                            (user-error "No Gradle or Maven build here"))))
    (pcase tool
      ('gradle (concat program " test jacocoTestReport --console=plain --init-script "
                       (shell-quote-argument (hellmacs-coverage--gradle-init-file))))
      ('maven (let ((plugin (concat "org.jacoco:jacoco-maven-plugin:" hellmacs-coverage-jacoco-version)))
                (concat program " -B " plugin ":prepare-agent test " plugin ":report"))))))

(defvar-local hellmacs-coverage--run-root nil
  "In a coverage run's compilation buffer: the root whose coverage to show when it's done.")

;;;###autoload
(defun hellmacs-coverage-run ()
  "Run the project's tests with JaCoCo, then mark the coverage in its buffers."
  (interactive)
  (let* ((build (or (hellmacs-forge-build-tool) (user-error "No Gradle or Maven build here")))
         (default-directory (nth 1 build)))
    (with-current-buffer (compile (hellmacs-coverage--command build))
      (setq hellmacs-coverage--run-root (nth 1 build)))))

;;;###autoload
(defun hellmacs-coverage--after-build-h (buffer _status)
  "Show the coverage a coverage run in BUFFER wrote. For `compilation-finish-functions'."
  (when-let* ((root (buffer-local-value 'hellmacs-coverage--run-root buffer)))
    (when (hellmacs-coverage-find-reports root)
      (hellmacs-coverage-show root))))

;;; tools/test/autoload.el ends here
