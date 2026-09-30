;;; test-coverage.el --- Tests for :tools test's coverage marks (Phase 12.5) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'compile)
(require 'hellmacs-modules)

;; :tools test's code, and :tools build's, which runs the tests.
(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools build test))
  (hellmacs-module--load '(:tools . build) "autoload.el")
  (hellmacs-module--load '(:tools . test) "autoload.el"))

(defmacro test-cov--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-cov" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (ignore-errors (hellmacs-coverage-hide))
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
           (kill-buffer b)))
       (delete-directory root t))))

(defconst test-cov--report
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<!DOCTYPE report PUBLIC \"-//JACOCO//DTD Report 1.1//EN\" \"report.dtd\">
<report name=\"demo\">
  <package name=\"com/example\">
    <sourcefile name=\"App.java\">
      <line nr=\"5\" mi=\"0\" ci=\"1\" mb=\"0\" cb=\"0\"/>
      <line nr=\"6\" mi=\"1\" ci=\"0\" mb=\"0\" cb=\"0\"/>
      <line nr=\"7\" mi=\"0\" ci=\"1\" mb=\"1\" cb=\"1\"/>
    </sourcefile>
  </package>
</report>")

(defconst test-cov--app (mapconcat (lambda (n) (format "line %d" n)) (number-sequence 1 10) "\n"))

(defun test-cov--marks ()
  "This buffer's coverage marks, as ((LINE . STATUS) ...)."
  (sort (mapcar (lambda (o) (cons (line-number-at-pos (overlay-start o))
                                  (overlay-get o 'hellmacs-coverage)))
                (seq-filter (lambda (o) (overlay-get o 'hellmacs-coverage))
                            (overlays-in (point-min) (point-max))))
        (lambda (a b) (< (car a) (car b)))))

(ert-deftest test-coverage/parse-jacoco-xml ()
  "Parses JaCoCo XML coverage report into per-line coverage statuses."
  (test-cov--with-tree `(("target/site/jacoco/jacoco.xml" . ,test-cov--report))
    (let* ((xml-file (expand-file-name "target/site/jacoco/jacoco.xml" root))
           (cov-data (hellmacs-coverage-parse-jacoco-xml xml-file)))
      (should (assoc "com/example/App.java" cov-data))
      (let ((file-lines (cdr (assoc "com/example/App.java" cov-data))))
        ;; Line 5: covered
        (should (eq (alist-get 5 file-lines) 'covered))
        ;; Line 6: missed
        (should (eq (alist-get 6 file-lines) 'missed))
        ;; Line 7: partial
        (should (eq (alist-get 7 file-lines) 'partial))))))

(ert-deftest test-coverage/locate-jacoco-files ()
  "Finds JaCoCo XML reports in Maven target and Gradle build locations."
  (test-cov--with-tree
      '(("target/site/jacoco/jacoco.xml" . "<report name=\"maven\"/>")
        ("build/reports/jacoco/test/jacocoTestReport.xml" . "<report name=\"gradle\"/>")
        ("build/reports/tests/test/index.html" . "<html/>")
        ("src/main/resources/jacoco.xml" . "<report/>"))
    (let ((reports (hellmacs-coverage-find-reports root)))
      (should (= (length reports) 2)))))

(ert-deftest test-coverage/marks-in-source-buffers ()
  "show marks each reported line of open buffers, and files opened later; hide removes them."
  (test-cov--with-tree `(("target/site/jacoco/jacoco.xml" . ,test-cov--report)
                         ("src/main/java/com/example/App.java" . ,test-cov--app)
                         ("src/main/java/com/example/Other.java" . ,test-cov--app))
    (let ((app (find-file-noselect (expand-file-name "src/main/java/com/example/App.java" root))))
      (hellmacs-coverage-show root)
      (with-current-buffer app
        (should (equal (test-cov--marks) '((5 . covered) (6 . missed) (7 . partial)))))
      (with-current-buffer (find-file-noselect (expand-file-name "src/main/java/com/example/Other.java" root))
        (should-not (test-cov--marks)))
      ;; Opened after `show': marked too.
      (kill-buffer app)
      (with-current-buffer (find-file-noselect (expand-file-name "src/main/java/com/example/App.java" root))
        (should (= (length (test-cov--marks)) 3))
        (hellmacs-coverage-hide)
        (should-not (test-cov--marks))
        (should (= left-margin-width 0)))
      (kill-buffer "App.java")
      (with-current-buffer (find-file-noselect (expand-file-name "src/main/java/com/example/App.java" root))
        (should-not (test-cov--marks))))))

(defvar hellmacs-coverage--data)
(defvar hellmacs-coverage-root-limit)

(ert-deftest test-coverage/kept-for-recent-projects-only ()
  "Coverage is kept for the last few projects shown: each holds every covered
line of every report in it."
  (let ((roots nil) (hellmacs-coverage-root-limit 2))
    (unwind-protect
        (progn
          (dotimes (_ 3)
            (let ((root (file-name-as-directory (make-temp-file "hellmacs-test-cov" t))))
              (push root roots)
              (let ((report (expand-file-name "target/site/jacoco/jacoco.xml" root)))
                (make-directory (file-name-directory report) t)
                (with-temp-file report (insert test-cov--report)))
              (let ((inhibit-message t)) (hellmacs-coverage-show root))))
          (should (= (length hellmacs-coverage--data) 2))
          ;; The oldest project's went; the two latest stay.
          (should-not (seq-some (lambda (e) (string-prefix-p (car (last roots)) (car e)))
                                hellmacs-coverage--data))
          (should (seq-some (lambda (e) (string-prefix-p (car roots) (car e)))
                            hellmacs-coverage--data)))
      (hellmacs-coverage-hide)
      (mapc (lambda (r) (delete-directory r t)) roots))))

(ert-deftest test-coverage/fringe-or-margin ()
  "A graphical frame gets fringe marks; a terminal, margin marks."
  (test-cov--with-tree `(("target/site/jacoco/jacoco.xml" . ,test-cov--report)
                         ("src/main/java/com/example/App.java" . ,test-cov--app))
    (with-current-buffer (find-file-noselect (expand-file-name "src/main/java/com/example/App.java" root))
      (cl-letf (((symbol-function 'display-graphic-p) #'ignore))
        (hellmacs-coverage-show root))
      (let ((mark (seq-find (lambda (o) (overlay-get o 'hellmacs-coverage)) (overlays-in 1 (point-max)))))
        (should (equal (car (get-text-property 0 'display (overlay-get mark 'before-string)))
                       '(margin left-margin)))
        (should (> left-margin-width 0)))
      (hellmacs-coverage-hide)
      (cl-letf (((symbol-function 'display-graphic-p) #'always))
        (hellmacs-coverage-show root))
      (let ((mark (seq-find (lambda (o) (overlay-get o 'hellmacs-coverage)) (overlays-in 1 (point-max)))))
        (should (eq (car (get-text-property 0 'display (overlay-get mark 'before-string)))
                    'left-fringe))))))

(ert-deftest test-coverage/modules ()
  "A module's report marks that module's sources, not another's of the same name."
  (test-cov--with-tree `(("lib/target/site/jacoco/jacoco.xml" . ,test-cov--report)
                         ("lib/src/main/java/com/example/App.java" . ,test-cov--app)
                         ("app/src/main/java/com/example/App.java" . ,test-cov--app))
    (let ((lib (find-file-noselect (expand-file-name "lib/src/main/java/com/example/App.java" root)))
          (app (find-file-noselect (expand-file-name "app/src/main/java/com/example/App.java" root))))
      (hellmacs-coverage-show root)
      (should (= 3 (length (with-current-buffer lib (test-cov--marks)))))
      (should-not (with-current-buffer app (test-cov--marks))))))

(ert-deftest test-coverage/summary ()
  "Per file: lines covered (JaCoCo's rule: some instruction ran) of lines with code."
  (test-cov--with-tree `(("target/site/jacoco/jacoco.xml" . ,test-cov--report))
    (should (equal (hellmacs-coverage-summary-rows root)
                   '(("com/example/App.java" 2 3))))
    (with-current-buffer (hellmacs-coverage-summary root)
      (should (derived-mode-p 'tabulated-list-mode))
      (goto-char (point-min))
      (should (equal (aref (tabulated-list-get-entry) 0) "com/example/App.java"))
      (should (equal (aref (tabulated-list-get-entry) 1) "66.7%"))
      (kill-buffer))))

(ert-deftest test-coverage/commands ()
  "JaCoCo comes in on the command line, never in the build file."
  (test-cov--with-tree '(("gradlew" . "") ("build.gradle" . ""))
    (let ((command (hellmacs-coverage--command)))
      (should (string-prefix-p "./gradlew test jacocoTestReport --console=plain --init-script " command))
      (let ((script (car (last (split-string-shell-command command)))))
        (should (file-exists-p script))
        (with-temp-buffer
          (insert-file-contents script)
          (should (search-forward "apply plugin: 'jacoco'" nil t))
          (should (search-forward "xml.required = true" nil t))))))
  (test-cov--with-tree '(("pom.xml" . ""))
    (should (equal (hellmacs-coverage--command)
                   (concat "mvn -B org.jacoco:jacoco-maven-plugin:" hellmacs-coverage-jacoco-version
                           ":prepare-agent test org.jacoco:jacoco-maven-plugin:"
                           hellmacs-coverage-jacoco-version ":report")))))

(ert-deftest test-coverage/shown-after-a-coverage-run ()
  "The build `hellmacs-coverage-run' starts shows its marks when it's done."
  (test-cov--with-tree `(("target/site/jacoco/jacoco.xml" . ,test-cov--report)
                         ("src/main/java/com/example/App.java" . ,test-cov--app)
                         ("pom.xml" . ""))
    (let ((app (find-file-noselect (expand-file-name "src/main/java/com/example/App.java" root))))
      (with-temp-buffer
        (setq default-directory root)
        (compilation-mode)
        (hellmacs-coverage--after-build-h (current-buffer) "finished\n")
        (should-not (with-current-buffer app (test-cov--marks)))  ; not a coverage run
        (setq hellmacs-coverage--run-root root)
        (hellmacs-coverage--after-build-h (current-buffer) "exited abnormally\n") ; failing tests too
        (should (= 3 (length (with-current-buffer app (test-cov--marks)))))))))

(provide 'test-coverage)
;;; test-coverage.el ends here
