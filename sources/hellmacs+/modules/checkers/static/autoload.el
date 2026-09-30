;;; checkers/static/autoload.el -*- lexical-binding: t; -*-

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

;; Static analysis results from the build tool's own reports: Checkstyle,
;; PMD and SpotBugs, with the rules the build configures. Nothing runs in
;; Emacs; it reads what the build wrote.
;;
;; A finding is a plist: :file (absolute), :line, :column, :end-line,
;; :end-column (each may be nil), :severity (:error, :warning or :note),
;; :message, :tool ("Checkstyle", "PMD" or "SpotBugs") and :rule.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function dom-tag "dom")
(declare-function dom-attr "dom")
(declare-function dom-children "dom")
(declare-function dom-texts "dom")
(declare-function xml-parse-region "xml")
(declare-function project-root "project")
(declare-function flymake-make-diagnostic "flymake")
(declare-function flymake-diag-region "flymake")
(declare-function flymake-start "flymake")
(defvar flymake-mode)

;;; Reading reports ------------------------------------------------------------------

(defun hellmacs-static--xml (file)
  "The root element of the XML FILE, as a dom, or nil if it can't be read.
With libxml when Emacs has it (reports can be big), else xml.el."
  (require 'dom)
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file)
      (if (libxml-available-p)
          (libxml-parse-xml-region (point-min) (point-max))
        (require 'xml)
        (car (xml-parse-region (point-min) (point-max)))))))

(defun hellmacs-static--children (node tag)
  "NODE's own child elements named TAG."
  (seq-filter (lambda (child) (and (consp child) (eq (dom-tag child) tag)))
              (dom-children node)))

(defun hellmacs-static--number (node attribute)
  "NODE's ATTRIBUTE as a number, or nil."
  (when-let* ((value (dom-attr node attribute)))
    (string-to-number value)))

(defun hellmacs-static--module-dir (report)
  "The directory of the module whose build wrote REPORT."
  (if (string-match "/\\(?:target\\|build\\)/.*\\'" report)
      (substring report 0 (1+ (match-beginning 0)))
    (file-name-directory report)))

(defun hellmacs-static--checkstyle (dom report)
  (cl-loop
   for file in (hellmacs-static--children dom 'file)
   for name = (expand-file-name (dom-attr file 'name) (hellmacs-static--module-dir report))
   append (cl-loop
           for error in (hellmacs-static--children file 'error)
           for severity = (pcase (dom-attr error 'severity)
                            ("error" :error) ("warning" :warning) ("info" :note))
           when severity
           collect (list :file name
                         :line (hellmacs-static--number error 'line)
                         :column (hellmacs-static--number error 'column)
                         :severity severity
                         :message (dom-attr error 'message)
                         :tool "Checkstyle"
                         ;; com.puppycrawl...naming.ConstantNameCheck -> ConstantName
                         :rule (let ((check (car (last (split-string (or (dom-attr error 'source) "") "\\.")))))
                                 (string-remove-suffix "Check" check))))))

(defun hellmacs-static--pmd (dom report)
  (cl-loop
   for file in (hellmacs-static--children dom 'file)
   for name = (expand-file-name (dom-attr file 'name) (hellmacs-static--module-dir report))
   append (cl-loop
           for violation in (hellmacs-static--children file 'violation)
           for priority = (or (hellmacs-static--number violation 'priority) 3)
           collect (list :file name
                         :line (hellmacs-static--number violation 'beginline)
                         :column (hellmacs-static--number violation 'begincolumn)
                         :end-line (hellmacs-static--number violation 'endline)
                         :end-column (hellmacs-static--number violation 'endcolumn)
                         :severity (cond ((<= priority 2) :error) ((<= priority 4) :warning) (t :note))
                         :message (string-trim (dom-texts violation ""))
                         :tool "PMD"
                         :rule (dom-attr violation 'rule)))))

(defun hellmacs-static--spotbugs-line (bug)
  "BUG's own source line: its primary <SourceLine>, else its method's, else its class's."
  (seq-find (lambda (line) (dom-attr line 'start))
            (append (hellmacs-static--children bug 'SourceLine)
                    (mapcan (lambda (tag)
                              (mapcan (lambda (node) (hellmacs-static--children node 'SourceLine))
                                      (hellmacs-static--children bug tag)))
                            '(Method Field Class)))))

(defun hellmacs-static--field-line (bug file line)
  "The line declaring BUG's field in FILE, within the class LINE spans; or nil.
Class files have no line for a field, so SpotBugs gives none."
  (when-let* ((field (car (hellmacs-static--children bug 'Field)))
              (name (dom-attr field 'name))
              (start (hellmacs-static--number line 'start)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (forward-line (1- start))
      (let ((end (save-excursion
                   (forward-line (- (or (hellmacs-static--number line 'end) start) start -1))
                   (point))))
        (when (re-search-forward (concat "\\_<" (regexp-quote name) "\\_>[ \t]*[;=,]") end t)
          (line-number-at-pos))))))

(defun hellmacs-static--spotbugs (dom _report)
  (let ((source-dirs (mapcar (lambda (dir) (string-trim (dom-texts dir "")))
                             (mapcan (lambda (project) (hellmacs-static--children project 'SrcDir))
                                     (hellmacs-static--children dom 'Project)))))
    (cl-loop
     for bug in (hellmacs-static--children dom 'BugInstance)
     for line = (hellmacs-static--spotbugs-line bug)
     for path = (and line (dom-attr line 'sourcepath))
     ;; Sources under the build's own source directories; a class whose
     ;; source isn't there (generated, or gone) is left out.
     for file = (and path (seq-some (lambda (dir)
                                      (let ((file (expand-file-name path dir)))
                                        (and (file-exists-p file) file)))
                                    source-dirs))
     for priority = (or (hellmacs-static--number bug 'priority) 2)
     for long = (car (hellmacs-static--children bug 'LongMessage))
     for field-line = (and file (not (hellmacs-static--children bug 'Method))
                           (hellmacs-static--field-line bug file line))
     when file
     collect (list :file file
                   :line (or field-line (hellmacs-static--number line 'start))
                   :end-line (if field-line field-line (hellmacs-static--number line 'end))
                   :severity (pcase priority (1 :error) (2 :warning) (_ :note))
                   :message (if long
                                (string-trim (dom-texts long ""))
                              (format "%s (%s)" (dom-attr bug 'type) (dom-attr bug 'category)))
                   :tool "SpotBugs"
                   :rule (dom-attr bug 'type)))))

;;;###autoload
(defun hellmacs-static-parse-report (report)
  "The findings in the Checkstyle, PMD or SpotBugs XML REPORT; nil if it's none."
  (when-let* ((dom (hellmacs-static--xml report))
              (reader (and (consp dom)
                           (pcase (dom-tag dom)
                             ('checkstyle #'hellmacs-static--checkstyle)
                             ('pmd #'hellmacs-static--pmd)
                             ('BugCollection #'hellmacs-static--spotbugs)))))
    (ignore-errors (funcall reader dom report))))

;;; Finding reports --------------------------------------------------------------------

(defconst hellmacs-static--report-regexp
  (concat "/\\(?:target/\\(?:checkstyle-result\\|pmd\\|spotbugsXml\\)"
          "\\|build/reports/\\(?:checkstyle\\|pmd\\|spotbugs\\)/[^/]+\\)\\.xml\\'")
  "Where Maven's and Gradle's Checkstyle, PMD and SpotBugs plugins write XML.")

(defconst hellmacs-static--skipped-dirs
  (append hellmacs-ignored-dirs
          '(".gradle" "src" "classes" "test-classes"
            "generated-sources" "generated-test-sources" "test-results" "surefire-reports"
            "failsafe-reports" "tmp" "libs" "maven-status"))
  "Directories that never hold a report, not walked into.")

;;;###autoload
(defun hellmacs-static-report-files (root)
  "The Checkstyle, PMD and SpotBugs XML reports under ROOT, in every module."
  (seq-filter (lambda (file) (string-match-p hellmacs-static--report-regexp file))
              (directory-files-recursively
               root "\\.xml\\'" nil
               (lambda (dir) (not (member (file-name-nondirectory dir) hellmacs-static--skipped-dirs))))))

(defconst hellmacs-static--build-files hellmacs-build-files
  "Files that mark a build's directory.")

(defun hellmacs-static--root (&optional dir)
  "The project around DIR (default: `default-directory'): its root, else its outermost build."
  (let ((dir (or dir default-directory)))
    (or (when-let* ((project (project-current nil dir))) (expand-file-name (project-root project)))
        (let (top)
          (while dir
            (when (seq-some (lambda (f) (file-exists-p (expand-file-name f dir))) hellmacs-static--build-files)
              (setq top dir))
            (let ((parent (file-name-directory (directory-file-name dir))))
              (setq dir (and (not (equal parent dir)) parent))))
          top))))

(defvar hellmacs-static--cache (make-hash-table :test #'equal)
  "Project root -> its reports, ((REPORT MTIME . FINDINGS) ...).
The reports are looked for again after a build; each is read again when
its file changes.")

;;;###autoload
(defun hellmacs-static-project-findings (root)
  "Every finding in the reports of the project at ROOT."
  (let ((reports (or (gethash root hellmacs-static--cache)
                     (mapcar (lambda (report) (list report nil)) (hellmacs-static-report-files root)))))
    (dolist (entry reports)
      (let ((mtime (file-attribute-modification-time (file-attributes (car entry)))))
        (unless (equal mtime (nth 1 entry))
          (setcdr entry (cons mtime (hellmacs-static-parse-report (car entry)))))))
    (puthash root reports hellmacs-static--cache)
    (mapcan (lambda (entry) (copy-sequence (nthcdr 2 entry))) reports)))

(defun hellmacs-static--current-findings (file root)
  "ROOT's findings for FILE, from the reports written since FILE was saved."
  (cl-loop for (report _mtime . findings) in (progn (hellmacs-static-project-findings root)
                                                    (gethash root hellmacs-static--cache))
           unless (file-newer-than-file-p file report)
           append (seq-filter (lambda (f) (equal (plist-get f :file) file)) findings)))

;;; Flymake ------------------------------------------------------------------------------

(defun hellmacs-static--text (finding)
  (format "%s: %s [%s]" (plist-get finding :tool) (plist-get finding :message) (plist-get finding :rule)))

;;;###autoload
(defun hellmacs-static-flymake (report-fn &rest _)
  "Flymake backend: the build's Checkstyle, PMD and SpotBugs findings for this file.
Only while the buffer is as the build saw it: once it's edited, or saved
since, the reports' line numbers no longer hold, and their findings go
until the next build."
  (funcall report-fn
           (when-let* ((file buffer-file-name)
                       ((not (buffer-modified-p)))
                       (root (hellmacs-static--root)))
             (let ((file (expand-file-name file)))
               (mapcar (lambda (finding)
                         (pcase-let ((`(,beg . ,end)
                                      (flymake-diag-region (current-buffer) (or (plist-get finding :line) 1)
                                                           (plist-get finding :column))))
                           (flymake-make-diagnostic (current-buffer) beg end
                                                    (plist-get finding :severity)
                                                    (hellmacs-static--text finding))))
                       (sort (hellmacs-static--current-findings file root)
                             (lambda (a b) (< (or (plist-get a :line) 0) (or (plist-get b :line) 0)))))))))

;;;###autoload
(defun hellmacs-static-setup-h ()
  "Add the build's findings to this buffer's flymake diagnostics."
  (add-hook 'flymake-diagnostic-functions #'hellmacs-static-flymake nil t)
  (when (and buffer-file-name (not (bound-and-true-p flymake-mode)))
    (flymake-mode 1)))

;;;###autoload
(defun hellmacs-static--after-build-h (buffer _status)
  "A build finished: look for its reports again, and check the open buffers anew.
For `compilation-finish-functions'."
  (clrhash hellmacs-static--cache)
  (ignore buffer)
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when (and (bound-and-true-p flymake-mode)
                 (memq #'hellmacs-static-flymake flymake-diagnostic-functions))
        (flymake-start)))))

;;; The project's findings ---------------------------------------------------------------

;;;###autoload
(defun hellmacs-static-findings (&optional root)
  "List the project's Checkstyle, PMD and SpotBugs findings, from its last build.
In a compilation buffer: `M-g n' and `M-g p' go through them. Returns it."
  (interactive)
  (let* ((root (file-name-as-directory
                (or root (hellmacs-static--root) (user-error "Not in a project"))))
         (findings (sort (hellmacs-static-project-findings root)
                         (lambda (a b)
                           (let ((fa (plist-get a :file)) (fb (plist-get b :file)))
                             (if (equal fa fb)
                                 (< (or (plist-get a :line) 0) (or (plist-get b :line) 0))
                               (string< fa fb))))))
         (buffer (get-buffer-create "*hellmacs-static*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq default-directory root)
        (insert (format "Static analysis of %s: %d finding%s, from the last build's reports\n\n"
                        (abbreviate-file-name root) (length findings) (if (= 1 (length findings)) "" "s")))
        (dolist (f findings)
          (insert (format "%s:%s%s: %s: %s\n"
                          (file-relative-name (plist-get f :file) root)
                          (or (plist-get f :line) 1)
                          (if (plist-get f :column) (format ":%d" (plist-get f :column)) "")
                          (pcase (plist-get f :severity) (:error "error") (:warning "warning") (_ "info"))
                          (hellmacs-static--text f)))))
      (compilation-mode)
      (goto-char (point-min)))
    (display-buffer buffer)
    buffer))

;;; checkers/static/autoload.el ends here
