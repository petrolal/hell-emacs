;;; tools/test/autoload.el -*- lexical-binding: t; -*-

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


;; Test results and coverage (Phase 12.5), from the reports every JVM
;; build tool already writes, so it works for Java, Kotlin, Groovy and
;; Scala alike:
;; - JUnit XML (Gradle's build/test-results/*/, Maven's
;;   target/surefire-reports/ and failsafe-reports/) into a
;;   `tabulated-list-mode' buffer, *hell-tests*;
;; - JaCoCo's XML report into fringe marks (margin marks in a terminal).

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar hell-cache-dir)
(defvar hell-forge--started)
(declare-function hell-forge-build-tool "../build/autoload")
(declare-function hell-forge--run "../build/autoload")
(declare-function hell-forge--find-source "../build/autoload")
(declare-function project-root "project")
(declare-function xml-parse-region "xml")
(declare-function dom-by-tag "dom")
(declare-function dom-attr "dom")
(declare-function dom-children "dom")
(declare-function dom-tag "dom")
(defvar hell-forge-source-extensions)

;;; Finding reports ------------------------------------------------------------------

(defconst hell-test--skipped-dirs
  (append hell-ignored-dirs
          '(".gradle" ".mvn" "src" "classes" "libs" "tmp" "generated" "kotlin" "html"))
  "Directories never searched for reports: sources, VCS, compiled classes.")

(defun hell-test--report-files (root regexp)
  "Files under ROOT whose path matches REGEXP, sorted, skipping sources and VCS."
  (sort (seq-filter (lambda (file) (string-match-p regexp file))
                    (directory-files-recursively
                     (expand-file-name root) "\\.xml\\'" nil
                     (lambda (dir)
                       (not (member (file-name-nondirectory dir) hell-test--skipped-dirs)))))
        #'string<))

(defun hell-test--root ()
  "The root of the build (or project) around `default-directory'."
  (or (nth 1 (hell-forge-build-tool))
      (when-let* ((project (project-current nil default-directory)))
        (expand-file-name (project-root project)))
      default-directory))

;;; JUnit XML --------------------------------------------------------------------------

(defconst hell-test-results--report-regexp
  "/\\(?:build/test-results/[^/]+\\|target/\\(?:surefire\\|failsafe\\)-reports\\)/[^/]+\\.xml\\'"
  "Where Gradle and Maven write JUnit XML reports, in any module.")

;;;###autoload
(defun hell-test-results-find-reports (root)
  "The JUnit XML reports under ROOT, Gradle's and Maven's, of every module."
  (hell-test--report-files root hell-test-results--report-regexp))

;; Both kinds of report are read into the same `dom' shape, with libxml
;; when Emacs has it (JaCoCo's reports are big), else xml.el.
(defun hell-test--xml (file)
  "The root element of the XML FILE, as a dom.
Loads dom.el, which reading the result needs, only when a report is read."
  (require 'dom)
  (with-temp-buffer
    (insert-file-contents file)
    (if (libxml-available-p)
        (libxml-parse-xml-region (point-min) (point-max))
      (require 'xml)
      (car (xml-parse-region (point-min) (point-max))))))

(defun hell-test--children (node tag)
  "NODE's own child elements named TAG (`dom-by-tag' looks at every descendant)."
  (seq-filter (lambda (child) (and (consp child) (eq (dom-tag child) tag)))
              (dom-children node)))

(defun hell-test-results--text (node)
  "The text inside NODE, trimmed."
  (string-trim (apply #'concat (seq-filter #'stringp (dom-children node)))))

(defun hell-test-results--case (node file)
  "The test case in NODE, a <testcase> element of FILE's report."
  (let* ((problem (or (car (hell-test--children node 'failure)) (car (hell-test--children node 'error))))
         (trace (and problem (hell-test-results--text problem)))
         (message (and problem (or (dom-attr problem 'message)
                                   (car (split-string trace "\n")) ""))))
    (list :name (or (dom-attr node 'name) "")
          :class (or (dom-attr node 'classname) "")
          :time (string-to-number (or (dom-attr node 'time) "0"))
          :status (cond (problem 'fail)
                        ((hell-test--children node 'skipped) 'skip)
                        (t 'pass))
          :failure message
          :trace trace
          :file file)))

;;;###autoload
(defun hell-test-results-parse-junit-xml (file)
  "The test suite in the JUnit XML report FILE, or nil if it isn't one.
A plist: :suite (its name), :total, :failures (failed or in error),
:skipped, :time and :cases, each a plist of :name, :class, :time,
:status (`pass', `fail' or `skip'), :failure (the message) and :trace."
  (let ((root (ignore-errors (hell-test--xml file))))
    (when (and (consp root) (memq (dom-tag root) '(testsuite testsuites)))
      (let* ((suites (if (eq (dom-tag root) 'testsuite) (list root)
                       (hell-test--children root 'testsuite)))
             (cases (cl-loop for suite in suites
                             append (mapcar (lambda (node) (hell-test-results--case node file))
                                            (hell-test--children suite 'testcase)))))
        (list :suite (or (dom-attr root 'name) (file-name-base file))
              :total (length cases)
              :failures (seq-count (lambda (c) (eq (plist-get c :status) 'fail)) cases)
              :skipped (seq-count (lambda (c) (eq (plist-get c :status) 'skip)) cases)
              :time (string-to-number (or (dom-attr root 'time) "0"))
              :file file
              :cases cases)))))

(defun hell-test-results--test-id (case)
  "CASE as the build's test filter names it: \"pkg.Class#method\".
Without parentheses or a parameter index; a case with no method name
of its own (a parameterized one named \"[1] ...\") is its class."
  (let ((method (string-trim (car (split-string (plist-get case :name) "[([]")))))
    (if (string-empty-p method)
        (plist-get case :class)
      (concat (plist-get case :class) "#" method))))

;;; The results view --------------------------------------------------------------

(defvar-local hell-test-results--root nil
  "The build root this view's reports are from.")

(defvar-local hell-test-results--since nil
  "Only reports written since this time (`float-time') are shown; nil for all.")

(defvar hell-test-results-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "RET" #'hell-test-results-jump)
    (keymap-set map "r" #'hell-test-results-rerun-at-point)
    (keymap-set map "f" #'hell-test-results-rerun-failures)
    (keymap-set map "c" #'hell-coverage-summary)
    map)
  "Keys of the test results view.")

;;;###autoload
(define-derived-mode hell-test-results-mode tabulated-list-mode "Tests"
  "The tests of the last run, from the build's JUnit XML reports.
\\<hell-test-results-mode-map>\\[hell-test-results-jump] goes to the test (the failing line), \
\\[hell-test-results-rerun-at-point] reruns it, \\[hell-test-results-rerun-failures] reruns the failing ones,
\\[revert-buffer] reads every report again, \\[hell-coverage-summary] shows coverage per file."
  (setq tabulated-list-format [("" 4 t) ("Suite" 24 t) ("Test" 36 t)
                               ("Time" 7 t :right-align t) ("Message" 0 nil)]
        tabulated-list-padding 1)
  ;; `g' is tabulated-list-mode's `revert-buffer', as in any list.
  (setq-local revert-buffer-function #'hell-test-results--revert)
  (tabulated-list-init-header))

(defconst hell-test-results--status-cells
  '((fail "FAIL" error) (skip "SKIP" shadow) (pass "PASS" success))
  "Each status, in the order the view lists them: its label and face.")

(defun hell-test-results--entry (case)
  (pcase-let ((`(,label ,face) (alist-get (plist-get case :status) hell-test-results--status-cells)))
    (list case
          (vector (propertize label 'face face)
                  (car (last (split-string (plist-get case :class) "\\.")))
                  (plist-get case :name)
                  (format "%.2f" (plist-get case :time))
                  (car (split-string (or (plist-get case :failure) "") "\n"))))))

(defun hell-test-results--reports ()
  "This view's reports: under its root, and written since its time if it has one."
  (seq-filter (lambda (file)
                (or (null hell-test-results--since)
                    ;; A second of slack: some file systems round times down.
                    (>= (float-time (file-attribute-modification-time (file-attributes file)))
                        (1- hell-test-results--since))))
              (hell-test-results-find-reports hell-test-results--root)))

(defun hell-test-results--fill ()
  "Read this view's reports into its entries."
  (let* ((cases (cl-loop for report in (hell-test-results--reports)
                         append (plist-get (hell-test-results-parse-junit-xml report) :cases)))
         (ranked (cl-loop for (status) in hell-test-results--status-cells
                          append (seq-filter (lambda (c) (eq (plist-get c :status) status)) cases)))
         (count (lambda (status) (seq-count (lambda (c) (eq (plist-get c :status) status)) cases))))
    (setq tabulated-list-entries (mapcar #'hell-test-results--entry ranked)
          mode-line-process (format " %d failed of %d tests, %d skipped"
                                    (funcall count 'fail) (length cases) (funcall count 'skip)))
    (tabulated-list-print t)))

;;;###autoload
(defun hell-test-results-show (root &optional since)
  "Fill *hell-tests* with ROOT's test reports (those written since SINCE); return it.
It isn't displayed; `hell-test-results' does that."
  (with-current-buffer (get-buffer-create "*hell-tests*")
    (unless (derived-mode-p 'hell-test-results-mode)
      (hell-test-results-mode))
    (setq default-directory (file-name-as-directory (expand-file-name root))
          hell-test-results--root default-directory
          hell-test-results--since since)
    (hell-test-results--fill)
    (goto-char (point-min))
    (current-buffer)))

;;;###autoload
(defun hell-test-results ()
  "Show the project's test results, from every JUnit XML report its build wrote."
  (interactive)
  (pop-to-buffer (hell-test-results-show (hell-test--root))))

(defun hell-test-results--revert (&rest _)
  "Read the project's test reports again: every one of them, the latest of each class."
  (hell-test-results-show hell-test-results--root))

(defun hell-test-results--case-at-point ()
  (or (tabulated-list-get-id) (user-error "No test on this line")))

(defun hell-test-results-rerun-at-point ()
  "Run the test on this line again, with the build tool."
  (interactive)
  (let ((default-directory hell-test-results--root))
    (hell-forge--run 'test (hell-test-results--test-id (hell-test-results--case-at-point)))))

;;;###autoload
(defun hell-test-results-rerun-failures ()
  "Run every failing test again, in one build.
Outside the results view, the failing tests of the project's reports."
  (interactive)
  (with-current-buffer (if (derived-mode-p 'hell-test-results-mode)
                           (current-buffer)
                         (hell-test-results-show (hell-test--root)))
    (let ((failing (delete-dups
                    (cl-loop for (case) in tabulated-list-entries
                             when (eq (plist-get case :status) 'fail)
                             collect (hell-test-results--test-id case))))
          (default-directory hell-test-results--root))
      (unless failing (user-error "No failing tests"))
      (hell-forge--run 'test failing))))

(defun hell-test-results--class-file (class)
  "The source file of CLASS (\"pkg.Outer$Inner\") in the project, or nil."
  (let* ((outer (car (split-string class "\\$")))
         (dot (string-match-p "\\.[^.]*\\'" outer))
         (package (and dot (substring outer 0 dot)))
         (simple (if dot (substring outer (1+ dot)) outer)))
    (seq-some (lambda (ext) (hell-forge--find-source (concat simple "." ext) package))
              hell-forge-source-extensions)))

(defun hell-test-results--failure-line (case)
  "The line of CASE's own class where it failed, from its stack trace, or nil."
  (when-let* ((trace (plist-get case :trace)))
    (when (string-match (concat "at \\(?:[^ \t\n/(]+/\\)?" (regexp-quote (plist-get case :class))
                                "\\(?:\\$[^.(\n]*\\)?\\.[^.(\n]+([^():\n]+:\\([0-9]+\\))")
                        trace)
      (string-to-number (match-string 1 trace)))))

(defun hell-test-results-jump ()
  "Go to the test on this line: where it failed, or else its declaration."
  (interactive)
  (let* ((case (hell-test-results--case-at-point))
         (file (or (hell-test-results--class-file (plist-get case :class))
                   (user-error "Can't find %s in the project" (plist-get case :class))))
         (line (hell-test-results--failure-line case))
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

(defconst hell-test-results--ran-tests-regexp
  "^> Task [^ \n]*:test\\b\\|Tests run: [0-9]\\|[0-9]+ tests? completed"
  "Output of a build that ran tests: Gradle's test task, Surefire's counts.")

;;;###autoload
(defun hell-test-results--after-build-h (buffer _status)
  "Read the reports a build in BUFFER wrote into the results view.
For `compilation-finish-functions'. Only reports written by this build
are shown: the tests it ran. The view isn't displayed; the failing
tests' message points to it."
  (with-current-buffer buffer
    (when (and (derived-mode-p 'compilation-mode)
               (save-excursion
                 (goto-char (point-min))
                 (re-search-forward hell-test-results--ran-tests-regexp nil t)))
      (let* ((root (hell-test--root))
             (since (bound-and-true-p hell-forge--started))
             (fresh (with-temp-buffer
                      (setq hell-test-results--root root
                            hell-test-results--since since)
                      (hell-test-results--reports))))
        (when fresh
          (hell-test-results-show root since))))))

;;; Continuous testing (+watch) ---------------------------------------------------

(defvar hell-forge-test-class-function)

(defconst hell-test-watch--test-file-regexp
  "/src/[^/]*[tT]est[^/]*/\\|\\(?:Tests?\\|IT\\|Spec\\)\\.[a-z]+\\'"
  "Test sources: under a test source set (src/test/, src/integrationTest/), or named so.")

(defun hell-test-watch--target ()
  "The tests to run when this buffer is saved, as a class name, or nil.
A test file is its own class; any other, its class's \"...Test\" if the
project has one."
  (when-let* ((file buffer-file-name)
              (class (ignore-errors (funcall hell-forge-test-class-function))))
    (if (string-match-p hell-test-watch--test-file-regexp file)
        class
      (let ((test (concat class "Test")))
        (and (hell-test-results--class-file test) test)))))

(defun hell-test-watch--after-save-h ()
  (when-let* ((class (hell-test-watch--target)))
    (hell-forge--run 'test class)))

;;;###autoload
(define-minor-mode hell-test-watch-mode
  "Rerun the tests of this buffer's class each time it's saved.
Through the build tool's own test filter: a test class runs itself, any
other class its ...Test class, when there's one."
  :lighter " Watch"
  (if hell-test-watch-mode
      (add-hook 'after-save-hook #'hell-test-watch--after-save-h nil t)
    (remove-hook 'after-save-hook #'hell-test-watch--after-save-h t)))

;;; Coverage (JaCoCo) ---------------------------------------------------------------

(defgroup hell-coverage nil
  "Test coverage marks, from JaCoCo's reports."
  :group 'hell)

(defface hell-coverage-covered '((t :inherit success))
  "Lines the tests ran."
  :group 'hell-coverage)

(defface hell-coverage-partial '((t :inherit warning))
  "Lines the tests ran, but not every branch or instruction of."
  :group 'hell-coverage)

(defface hell-coverage-missed '((t :inherit error))
  "Lines the tests never ran."
  :group 'hell-coverage)

(defconst hell-coverage-jacoco-version "0.8.15"
  "The JaCoCo Maven plugin a coverage run uses (Gradle's jacoco plugin brings its own).")

(defconst hell-coverage--report-regexp
  "\\(/\\)\\(?:target/site/jacoco[^/]*/jacoco\\.xml\\|build/reports/jacoco/[^/]+/[^/]+\\.xml\\)\\'"
  "Where JaCoCo's XML reports are: Maven's jacoco:report, Gradle's jacocoTestReport.
Group 1 ends the module's directory.")

;;;###autoload
(defun hell-coverage-find-reports (root)
  "The JaCoCo XML reports under ROOT, of every module."
  (hell-test--report-files root hell-coverage--report-regexp))

(defun hell-coverage--module-root (report)
  "The directory of the module REPORT covers."
  (string-match hell-coverage--report-regexp report)
  (substring report 0 (match-end 1)))

(defun hell-coverage--line-status (line)
  "The status of a JaCoCo <line>: `covered', `partial', `missed', or nil (no code)."
  (let ((mi (string-to-number (or (dom-attr line 'mi) "0")))
        (ci (string-to-number (or (dom-attr line 'ci) "0")))
        (mb (string-to-number (or (dom-attr line 'mb) "0"))))
    (cond ((and (zerop ci) (zerop mi)) nil)
          ((zerop ci) 'missed)
          ((or (> mi 0) (> mb 0)) 'partial)
          (t 'covered))))

;;;###autoload
(defun hell-coverage-parse-jacoco-xml (file)
  "The line coverage in JaCoCo's XML report FILE.
An alist: (\"pkg/dir/File.java\" . ((LINE . STATUS) ...)), STATUS being
`covered', `partial' (some branch or instruction missed) or `missed'."
  (when-let* ((dom (ignore-errors (hell-test--xml file))))
    (cl-loop for package in (dom-by-tag dom 'package)
             for dir = (dom-attr package 'name)
             append (cl-loop for source in (dom-children package)
                             when (and (consp source) (eq (dom-tag source) 'sourcefile))
                             collect (cons (concat (if (member dir '(nil "")) "" (concat dir "/"))
                                                   (dom-attr source 'name))
                                           (cl-loop for line in (dom-children source)
                                                    for status = (and (consp line) (eq (dom-tag line) 'line)
                                                                      (hell-coverage--line-status line))
                                                    when status
                                                    collect (cons (string-to-number (dom-attr line 'nr))
                                                                  status)))))))

(defvar hell-coverage--data nil
  "The coverage shown: ((MODULE-ROOT . PARSED-REPORT) ...).")

(defvar hell-coverage-root-limit 4
  "How many projects' coverage is kept shown.
Each holds every covered line of every report in the project.")

(defvar hell-coverage--roots nil
  "The project roots whose coverage is shown, most recently shown first.")

(defvar-local hell-coverage--saved-margin nil
  "`left-margin-width' before this buffer got margin marks, or nil.")

(defvar hell-coverage--bitmap
  (or (and (fboundp 'define-fringe-bitmap)
           (ignore-errors
             (define-fringe-bitmap 'hell-coverage-bar (make-vector 8 #b11100000) nil nil '(center t))))
      'vertical-bar)
  "The fringe bitmap of a coverage mark.")

(defun hell-coverage--mark-string (status)
  (let ((face (intern (format "hell-coverage-%s" status))))
    (if (display-graphic-p)
        (propertize " " 'display `(left-fringe ,hell-coverage--bitmap ,face))
      (propertize " " 'display `((margin left-margin) ,(propertize "▌" 'face face))))))

(defun hell-coverage--clear ()
  "Remove this buffer's coverage marks."
  (dolist (o (overlays-in (point-min) (point-max)))
    (when (overlay-get o 'hell-coverage) (delete-overlay o)))
  (when hell-coverage--saved-margin
    (setq left-margin-width (car hell-coverage--saved-margin)
          hell-coverage--saved-margin nil)
    (hell-coverage--redisplay)))

(defun hell-coverage--redisplay ()
  "Show this buffer's new margin in its windows."
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-buffer window (current-buffer))))

(defun hell-coverage--lines (file)
  "The coverage of FILE, from the report of the module it's in: ((LINE . STATUS) ...)."
  (cl-loop for (module . report) in hell-coverage--data
           when (string-prefix-p module file)
           thereis (cdr (seq-find (lambda (entry) (string-suffix-p (concat "/" (car entry)) file))
                                  report))))

(defun hell-coverage--mark-buffer ()
  "Mark this buffer's lines with the coverage shown."
  (when buffer-file-name
    (hell-coverage--clear)
    (when-let* ((lines (hell-coverage--lines (expand-file-name buffer-file-name))))
      (unless (display-graphic-p)
        (setq hell-coverage--saved-margin (list left-margin-width)
              left-margin-width (max left-margin-width 1))
        (hell-coverage--redisplay))
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
                  (overlay-put o 'hell-coverage status)
                  (overlay-put o 'before-string (hell-coverage--mark-string status)))))))))))

;;;###autoload
(defun hell-coverage-show (&optional root)
  "Mark covered, partly covered and missed lines, from ROOT's JaCoCo reports.
In every source buffer of the project, and in those opened later, until
`hell-coverage-hide'."
  (interactive)
  (let* ((root (file-name-as-directory (expand-file-name (or root (hell-test--root)))))
         (reports (or (hell-coverage-find-reports root)
                      (user-error "No JaCoCo report in %s; `hell-coverage-run' writes one"
                                  (abbreviate-file-name root)))))
    (setq hell-coverage--data
          (append (mapcar (lambda (report)
                            (cons (hell-coverage--module-root report)
                                  (hell-coverage-parse-jacoco-xml report)))
                          reports)
                  (seq-remove (lambda (entry) (string-prefix-p root (car entry)))
                              hell-coverage--data))
          hell-coverage--roots (cons root (delete root hell-coverage--roots)))
    ;; The least recently shown projects' beyond the limit go.
    (dolist (gone (nthcdr hell-coverage-root-limit hell-coverage--roots))
      (setq hell-coverage--data
            (seq-remove (lambda (entry) (string-prefix-p gone (car entry))) hell-coverage--data)))
    (setq hell-coverage--roots (seq-take hell-coverage--roots hell-coverage-root-limit))
    (add-hook 'find-file-hook #'hell-coverage--mark-buffer)
    (dolist (buffer (buffer-list))
      (when-let* ((file (buffer-file-name buffer)))
        (when (string-prefix-p root (expand-file-name file))
          (with-current-buffer buffer (hell-coverage--mark-buffer)))))
    (message "Coverage from %d JaCoCo report%s" (length reports) (if (cdr reports) "s" ""))))

;;;###autoload
(defun hell-coverage-hide ()
  "Remove every coverage mark."
  (interactive)
  (setq hell-coverage--data nil
        hell-coverage--roots nil)
  (remove-hook 'find-file-hook #'hell-coverage--mark-buffer)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (or hell-coverage--saved-margin
                (seq-some (lambda (o) (overlay-get o 'hell-coverage))
                          (overlays-in (point-min) (point-max))))
        (hell-coverage--clear)))))

;;;###autoload
(defun hell-coverage-summary-rows (root)
  "ROOT's coverage per file: ((FILE COVERED-LINES LINES) ...), least covered first.
A line is covered when some of its code ran (JaCoCo's own rule)."
  (sort (cl-loop for report in (hell-coverage-find-reports root)
                 append (cl-loop for (file . lines) in (hell-coverage-parse-jacoco-xml report)
                                 collect (list file
                                               (seq-count (lambda (l) (not (eq (cdr l) 'missed))) lines)
                                               (length lines))))
        (lambda (a b) (< (/ (float (nth 1 a)) (max 1 (nth 2 a)))
                         (/ (float (nth 1 b)) (max 1 (nth 2 b)))))))

(define-derived-mode hell-coverage-summary-mode tabulated-list-mode "Coverage"
  "Line coverage per file, from JaCoCo's reports."
  (setq tabulated-list-format [("File" 60 t) ("Lines" 7 nil :right-align t) ("Covered" 12 nil)]
        tabulated-list-padding 1)
  (tabulated-list-init-header))

;;;###autoload
(defun hell-coverage-summary (&optional root)
  "Show line coverage per file from ROOT's JaCoCo reports, least covered first."
  (interactive (list (or (bound-and-true-p hell-test-results--root) (hell-test--root))))
  (let ((rows (hell-coverage-summary-rows (or root (hell-test--root)))))
    (with-current-buffer (get-buffer-create "*hell-coverage*")
      (hell-coverage-summary-mode)
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

(defconst hell-coverage--gradle-init-script
  "// Written by Hell Emacs (:tools test): JaCoCo for this run only, from the
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

(defun hell-coverage--gradle-init-file ()
  "The init script's file, written if it isn't there or has changed."
  (let ((file (expand-file-name "hell/jacoco.gradle" hell-cache-dir)))
    (unless (and (file-exists-p file)
                 (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                        hell-coverage--gradle-init-script))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert hell-coverage--gradle-init-script)))
    file))

(defun hell-coverage--command (&optional build)
  "The command running the tests with JaCoCo and writing its XML report.
JaCoCo is added on the command line, never to the build file. BUILD is
the build's (TOOL ROOT PROGRAM), if already known."
  (pcase-let ((`(,tool ,_root ,program) (or build (hell-forge-build-tool)
                                            (user-error "No Gradle or Maven build here"))))
    (pcase tool
      ('gradle (concat program " test jacocoTestReport --console=plain --init-script "
                       (shell-quote-argument (hell-coverage--gradle-init-file))))
      ('maven (let ((plugin (concat "org.jacoco:jacoco-maven-plugin:" hell-coverage-jacoco-version)))
                (concat program " -B " plugin ":prepare-agent test " plugin ":report"))))))

(defvar-local hell-coverage--run-root nil
  "In a coverage run's compilation buffer: the root whose coverage to show when it's done.")

;;;###autoload
(defun hell-coverage-run ()
  "Run the project's tests with JaCoCo, then mark the coverage in its buffers."
  (interactive)
  (let* ((build (or (hell-forge-build-tool) (user-error "No Gradle or Maven build here")))
         (default-directory (nth 1 build)))
    (with-current-buffer (compile (hell-coverage--command build))
      (setq hell-coverage--run-root (nth 1 build)))))

;;;###autoload
(defun hell-coverage--after-build-h (buffer _status)
  "Show the coverage a coverage run in BUFFER wrote. For `compilation-finish-functions'."
  (when-let* ((root (buffer-local-value 'hell-coverage--run-root buffer)))
    (when (hell-coverage-find-reports root)
      (hell-coverage-show root))))

;;; tools/test/autoload.el ends here
