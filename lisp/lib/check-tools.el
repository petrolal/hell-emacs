;;; lisp/lib/check-tools.el --- The quality gate's tools and runs -*- lexical-binding: t; -*-

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

;; What `bin/hell check' (lisp/cli/check.el) and `hell-check' run:
;; finding the files and their languages, each language's tools (style
;; linters and deeper analyzers), the community wrappers (trunk,
;; pre-commit) and Gradle, whether the target is trusted to run its own
;; code, and `hell-check-run-all', which runs them and returns the
;; diagnostics. Emacs Lisp's tools are hell-static-analysis.el's.
;;
;; Part `check-tools' of `hell-lib': (hell-require 'hell-lib 'check-tools).

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)
(require 'hell-lib)
(require 'hell-static-analysis)

;;; Supported Languages & Tool Routing ----------------------------------------

(defconst hell-check-languages
  '((clojure
     :name "Clojure"
     :extensions (".clj" ".cljs" ".cljc" ".edn")
     :style-linters ("kibit")
     :static-analyzers ("clj-kondo"))
    (kotlin
     :name "Kotlin"
     :extensions (".kt" ".kts")
     :style-linters ("ktlint")
     :static-analyzers ("detekt"))
    (java
     :name "Java"
     :extensions (".java")
     :style-linters ("checkstyle")
     :static-analyzers ("spotbugs"))
    (scala
     :name "Scala"
     :extensions (".scala" ".sc")
     :style-linters ("scalafmt")
     :static-analyzers ("scalafix"))
    (groovy-gradle
     :name "Groovy & Gradle"
     :extensions (".groovy" "build.gradle" ".gradle.kts" ".gradle")
     :style-linters ("npm-groovy-lint" "codenarc")
     :static-analyzers ("npm-groovy-lint" "codenarc"))
    (elisp
     :name "Emacs Lisp"
     :extensions (".el")
     :style-linters ("package-lint")
     :static-analyzers ("elsa" "relint" "byte-compile"))
    (common-lisp
     :name "Common Lisp"
     :extensions (".lisp" ".cl")
     :style-linters ("sblint")
     :static-analyzers ("sblint"))))

(defcustom hell-check-ignored-directories
  '(".git" ".svn" ".hg" "elpaca" "builds" "sources" "compiled"
    "eln-cache" ".cache" ".local" "node_modules" "target" "dist"
    "build" ".gradle" ".idea" ".vscode" ".hell" ".elsa" ".cpcache"
    ".bloop" ".metals" ".bsp")
  "Directories to skip when scanning target paths."
  :type '(repeat string)
  :group 'hell-static-analysis)

(defcustom hell-check-ignored-files
  '(".*-autoloads\\.el\\'" "loaddefs\\.el\\'" "custom\\.el\\'"
    ".*\\.class\\'" ".*\\.jar\\'" ".*\\.elc\\'" ".*\\.eln\\'")
  "Regexps of filenames to skip during check scanning."
  :type '(repeat regexp)
  :group 'hell-static-analysis)

;;; Target Auto-Detection -----------------------------------------------------

(defun hell-check--ignored-dir-p (dir)
  "Return non-nil if DIR is an ignored directory."
  (let ((name (file-name-nondirectory (directory-file-name dir))))
    (seq-some (lambda (ignored) (string= name ignored))
              hell-check-ignored-directories)))

(defun hell-check--ignored-file-p (file)
  "Return non-nil if FILE should be ignored."
  (let ((base (file-name-nondirectory file)))
    (or (string-prefix-p ".#" base)
        (string-prefix-p "#" base)
        (string-suffix-p "~" base)
        (seq-some (lambda (re) (string-match-p re base))
                  hell-check-ignored-files))))

(defun hell-check--detect-file-language (file)
  "Return the language key for FILE, or nil if unsupported."
  (let ((base (file-name-nondirectory file)))
    (cond
     ((or (string= base "build.gradle")
          (string= base "settings.gradle")
          (string-suffix-p ".gradle.kts" base)
          (string-suffix-p ".gradle" base)
          (string-suffix-p ".groovy" base))
      'groovy-gradle)
     ((string-suffix-p ".clj" base) 'clojure)
     ((string-suffix-p ".cljs" base) 'clojure)
     ((string-suffix-p ".cljc" base) 'clojure)
     ((string-suffix-p ".edn" base) 'clojure)
     ((or (string-suffix-p ".kt" base) (string-suffix-p ".kts" base)) 'kotlin)
     ((string-suffix-p ".java" base) 'java)
     ((or (string-suffix-p ".scala" base) (string-suffix-p ".sc" base)) 'scala)
     ((string-suffix-p ".el" base) 'elisp)
     ((or (string-suffix-p ".lisp" base) (string-suffix-p ".cl" base)) 'common-lisp)
     (t nil))))

(defvar hell-check-only nil
  "The languages this check is limited to (`check --only'), or nil for all.
Symbols of `hell-check-languages'. Limited, the whole-project wrappers
(trunk, pre-commit) don't run.")

(defun hell-check-discover-files (targets)
  "Scan TARGETS (list of files or directories).
Return a plist (:files ALL-FILES :by-language ALIST-OF-(LANG . FILES)),
only of `hell-check-only''s languages when it's set."
  (let ((all-files nil)
        (by-lang (make-hash-table :test 'eq)))
    (dolist (target targets)
      (let ((target (expand-file-name target)))
        (cond
         ((file-regular-p target)
          (unless (hell-check--ignored-file-p target)
            (when-let* ((lang (hell-check--detect-file-language target)))
              (push target all-files)
              (puthash lang (cons target (gethash lang by-lang nil)) by-lang))))
         ((file-directory-p target)
          (cl-labels ((walk (dir)
                        (unless (hell-check--ignored-dir-p dir)
                          (let ((entries (condition-case nil
                                             (directory-files dir t directory-files-no-dot-files-regexp t)
                                           (error nil))))
                            (dolist (entry entries)
                              (cond
                               ((file-directory-p entry)
                                (walk entry))
                               ((and (file-regular-p entry)
                                     (not (hell-check--ignored-file-p entry)))
                                (when-let* ((lang (hell-check--detect-file-language entry)))
                                  (push entry all-files)
                                  (puthash lang (cons entry (gethash lang by-lang nil)) by-lang)))))))))
            (walk target))))))
    (let (lang-alist)
      (maphash (lambda (k v)
                 (when (or (null hell-check-only) (memq k hell-check-only))
                   (push (cons k (nreverse v)) lang-alist)))
               by-lang)
      (list :files (sort (apply #'append (mapcar #'cdr lang-alist)) #'string<)
            :by-language lang-alist))))

;;; Diagnostic Structure ------------------------------------------------------

(defun hell-check--make-diag (lang tool severity file line col rule-id message)
  "Create a unified diagnostic plist.
LANG and TOOL say what reported it; SEVERITY, FILE, LINE, COL, RULE-ID
and MESSAGE what was reported."
  (let* ((sev (pcase (if (symbolp severity) (symbol-name severity) (downcase (or severity "warning")))
                ((or "error" "err" "e") "Error")
                ((or "warning" "warn" "w" "smell") "Warning")
                (_ "Info")))
         (f (if (stringp file) file ""))
         (l (if (numberp line) line (string-to-number (or line "1"))))
         (c (if (numberp col) col (string-to-number (or col "1"))))
         (clean-msg (string-trim (replace-regexp-in-string "\n[ \t]*" " " (or message "")))))
    (when (zerop l) (setq l 1))
    (when (zerop c) (setq c 1))
    (list :language lang
          :tool tool
          :severity sev
          :file f
          :line l
          :col c
          :location (format "%s:%d:%d" f l c)
          :rule-id (or rule-id "-")
          :message clean-msg)))

;;; Headless Lisp Pipelines ---------------------------------------------------

(defun hell-check--run-tool (lang tool file thunk)
  "THUNK's diagnostics, from TOOL checking FILE (or a project) in LANG.
If TOOL crashes, one Info diagnostic says so, rather than its silence
reading as \"no issues\"."
  (condition-case err
      (funcall thunk)
    (error
     (list (hell-check--make-diag lang tool "Info" file 1 1 "tool-crashed"
                                  (format "%s crashed: %s" tool (error-message-string err)))))))

(defconst hell-check--elisp-tools
  '((byte-compile hell-static-analysis--check-byte-compile t)
    (package-lint hell-static-analysis--check-package-lint nil)
    (relint hell-static-analysis--check-relint nil)
    (elsa hell-static-analysis--check-elsa t))
  "Emacs Lisp's tools, as (NAME FUNCTION RUNS-CODE), in order.
FUNCTION returns hell-static-analysis.el's diagnostics for a file.
RUNS-CODE: it runs the file's macros and `eval-when-compile' forms.")

(defun hell-check--elisp-tool-names (run-code)
  "The Emacs Lisp tools that run: in `hell-static-analysis-linters', and
only with RUN-CODE those that run the files' code."
  (cl-loop for (name _ runs-code) in hell-check--elisp-tools
           when (and (memq name hell-static-analysis-linters) (or run-code (not runs-code)))
           collect (symbol-name name)))

(defun hell-check-run-elisp (files &optional run-code)
  "Run Emacs Lisp's tools (`hell-check--elisp-tools') on FILES.
package-lint and relint always; with RUN-CODE, also byte-compile and
Elsa, which run the files' code (see `hell-check--code-runners'). Only
the tools in `hell-static-analysis-linters'."
  (let ((tools (hell-check--elisp-tool-names run-code))
        diags)
    (dolist (file files)
      (pcase-dolist (`(,name ,fn ,_) hell-check--elisp-tools)
        (let ((tool (symbol-name name)))
          (when (member tool tools)
            (dolist (d (hell-check--run-tool
                        "Emacs Lisp" tool file
                        (lambda ()
                          (mapcar (lambda (d)
                                    (hell-check--make-diag
                                     "Emacs Lisp" tool (plist-get d :severity) (plist-get d :file)
                                     (plist-get d :line) (plist-get d :col) tool (plist-get d :message)))
                                  (funcall fn file)))))
              (push d diags))))))
    (nreverse diags)))

(defun hell-check-run-common-lisp (files)
  "Execute Common Lisp analysis (sblint via SBCL batch runner) across FILES."
  (let (diags)
    (cond
     ;; Priority 1: Native `sblint' executable if present
     ((executable-find "sblint")
      (dolist (file files)
        (let* ((cmd-output (cdr (hell-process-output "sblint" file)))
               (lines (split-string cmd-output "\n" t)))
          (dolist (line lines)
            (if (string-match "\\`\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)\\'" line)
                (let ((f (match-string 1 line))
                      (l (string-to-number (match-string 2 line)))
                      (c (string-to-number (match-string 3 line)))
                      (sev (match-string 4 line))
                      (msg (match-string 5 line)))
                  (push (hell-check--make-diag "Common Lisp" "sblint" (or sev "Warning") f l c "sblint" msg) diags))
              (push (hell-check--make-diag "Common Lisp" "sblint" "Warning" file 1 1 "sblint" line) diags))))))

     ;; Priority 2: Headless SBCL batch runner
     ((executable-find "sbcl")
      (dolist (file files)
        (let* ((sbcl-script
                (format "(handler-bind ((style-warning (lambda (c)
                                                        (format t \"~A:1:1: [Warning] ~A~%%\" %S c)
                                                        (muffle-warning c)))
                                       (warning (lambda (c)
                                                  (format t \"~A:1:1: [Warning] ~A~%%\" %S c)
                                                  (muffle-warning c)))
                                       (error (lambda (c)
                                                (format t \"~A:1:1: [Error] ~A~%%\" %S c))))
                           (let ((fasl (compile-file %S :print nil :verbose nil)))
                             (when (and fasl (probe-file fasl))
                               (delete-file fasl))))"
                        file file file file))
               (res (cdr (hell-process-output "sbcl" "--noinform" "--non-interactive" "--eval" sbcl-script)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\`\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)\\'" line)
              (let ((f (match-string 1 line))
                    (l (string-to-number (match-string 2 line)))
                    (c (string-to-number (match-string 3 line)))
                    (sev (match-string 4 line))
                    (msg (match-string 5 line)))
                (push (hell-check--make-diag "Common Lisp" "sblint" (or sev "Warning") f l c "sbcl-sblint" msg) diags)))))))
     (t
      (dolist (file files)
        (push (hell-check--make-diag "Common Lisp" "sblint" "Info" file 1 1 "tool-missing"
                                     "sblint and sbcl executables not found on PATH")
              diags))))
    (nreverse diags)))

;;; JVM & Other Language Runners ----------------------------------------------

(defun hell-check--parse-standard-diagnostics (lang tool output)
  "Parse standard file:line:col or file:line diagnostic lines from OUTPUT.
LANG and TOOL are what produced it."
  (let (diags
        (lines (split-string output "\n" t)))
    (dolist (line lines)
      (cond
       ;; Format: file:line:col: [sev]: [rule] msg
       ((string-match "\\`\\([^:\n\t]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:\\(error\\|warning\\|info\\): \\)?\\(?:(?:\\[\\([^]]+\\)\\]) \\)?\\(.*\\)\\'" line)
        (let ((f (match-string 1 line))
              (l (string-to-number (match-string 2 line)))
              (c (string-to-number (match-string 3 line)))
              (sev (or (match-string 4 line) "Warning"))
              (rule (match-string 5 line))
              (msg (match-string 6 line)))
          (push (hell-check--make-diag lang tool sev f l c (or rule tool) msg) diags)))
       ;; Format: file:line: msg
       ((string-match "\\`\\([^:\n\t]+\\):\\([0-9]+\\): \\(?:\\(error\\|warning\\|info\\): \\)?\\(.*\\)\\'" line)
        (let ((f (match-string 1 line))
              (l (string-to-number (match-string 2 line)))
              (sev (or (match-string 3 line) "Warning"))
              (msg (match-string 4 line)))
          (push (hell-check--make-diag lang tool sev f l 1 tool msg) diags)))))
    (nreverse diags)))

(defun hell-check-run-clojure (files)
  "Run Clojure quality checks on FILES: kibit & clj-kondo."
  (let (diags)
    ;; 1. clj-kondo
    (if (executable-find "clj-kondo")
        (let* ((res (cdr (apply #'hell-process-output "clj-kondo" "--lint" files)))
               (parsed (hell-check--parse-standard-diagnostics "Clojure" "clj-kondo" res)))
          (setq diags (append diags parsed)))
      (dolist (f files)
        (push (hell-check--make-diag "Clojure" "clj-kondo" "Info" f 1 1 "tool-missing"
                                     "clj-kondo native binary not found on PATH")
              diags)))
    ;; 2. kibit
    (if (executable-find "kibit")
        (let* ((res (cdr (apply #'hell-process-output "kibit" files)))
               (lines (split-string res "\n" t))
               cur-file cur-line cur-msg)
          (dolist (line lines)
            (cond
             ((string-match "At \\([^:\n]+\\):\\([0-9]+\\):" line)
              (when (and cur-file cur-msg)
                (push (hell-check--make-diag "Clojure" "kibit" "Warning" cur-file cur-line 1 "kibit/idiom" (string-trim cur-msg)) diags)
                (setq cur-msg nil))
              (setq cur-file (match-string 1 line)
                    cur-line (string-to-number (match-string 2 line))))
             ((and cur-file (not (string-empty-p line)))
              (setq cur-msg (concat (or cur-msg "") " " (string-trim line))))))
          (when (and cur-file cur-msg)
            (push (hell-check--make-diag "Clojure" "kibit" "Warning" cur-file cur-line 1 "kibit/idiom" (string-trim cur-msg)) diags)))
      (dolist (f files)
        (push (hell-check--make-diag "Clojure" "kibit" "Info" f 1 1 "tool-missing"
                                     "kibit executable not found on PATH")
              diags)))
    diags))

(defun hell-check-run-kotlin (files)
  "Run Kotlin quality checks on FILES: ktlint & detekt."
  (let (diags)
    ;; 1. ktlint
    (if (executable-find "ktlint")
        (let* ((res (cdr (apply #'hell-process-output "ktlint" "--reporter=plain" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (if (string-match "\\`\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(.*?\\)\\(?: (\\([^)]+\\))\\)?\\'" line)
                (let ((f (match-string 1 line))
                      (l (string-to-number (match-string 2 line)))
                      (c (string-to-number (match-string 3 line)))
                      (msg (match-string 4 line))
                      (rule (match-string 5 line)))
                  (push (hell-check--make-diag "Kotlin" "ktlint" "Warning" f l c (or rule "ktlint") msg) diags))
              (push (hell-check--make-diag "Kotlin" "ktlint" "Warning" (car files) 1 1 "ktlint" line) diags))))
      (dolist (f files)
        (push (hell-check--make-diag "Kotlin" "ktlint" "Info" f 1 1 "tool-missing"
                                     "ktlint not found on PATH")
              diags)))
    ;; 2. detekt
    (let ((detekt-bin (or (executable-find "detekt") (executable-find "detekt-cli"))))
      (if detekt-bin
          (let* ((res (cdr (apply #'hell-process-output detekt-bin "--input" (mapconcat #'identity files ","))))
                 (lines (split-string res "\n" t)))
            (dolist (line lines)
              (when (string-match "\\([^:\n\t ]+\\.kts?\\):\\([0-9]+\\):\\([0-9]+\\): \\([A-Za-z0-9_-]+\\) - \\(.*\\)" line)
                (let ((f (match-string 1 line))
                      (l (string-to-number (match-string 2 line)))
                      (c (string-to-number (match-string 3 line)))
                      (rule (match-string 4 line))
                      (msg (match-string 5 line)))
                  (push (hell-check--make-diag "Kotlin" "detekt" "Warning" f l c rule msg) diags)))))
        (dolist (f files)
          (push (hell-check--make-diag "Kotlin" "detekt" "Info" f 1 1 "tool-missing"
                                       "detekt not found on PATH")
                diags))))
    diags))

(defun hell-check-run-java (files)
  "Run Java quality checks on FILES: checkstyle & spotbugs."
  (let (diags)
    ;; 1. checkstyle
    (if (executable-find "checkstyle")
        (let* ((res (cdr (apply #'hell-process-output "checkstyle" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\[\\(WARN\\|ERROR\\|INFO\\)\\] \\([^:\n]+\\):\\([0-9]+\\):\\(?:\\([0-9]+\\):\\)? \\(.*?\\)\\(?: \\[\\([^]]+\\)\\]\\)?\\'" line)
              (let ((sev (match-string 1 line))
                    (f (match-string 2 line))
                    (l (string-to-number (match-string 3 line)))
                    (c (if (match-string 4 line) (string-to-number (match-string 4 line)) 1))
                    (msg (match-string 5 line))
                    (rule (match-string 6 line)))
                (push (hell-check--make-diag "Java" "checkstyle" sev f l c (or rule "checkstyle") msg) diags)))))
      (dolist (f files)
        (push (hell-check--make-diag "Java" "checkstyle" "Info" f 1 1 "tool-missing"
                                     "checkstyle not found on PATH")
              diags)))
    ;; 2. spotbugs
    (if (executable-find "spotbugs")
        (let* ((res (cdr (apply #'hell-process-output "spotbugs" "-textui" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\([MHL]\\) \\([A-Z]+\\) \\([A-Z0-9_]+\\): \\(.*\\) in \\([^ \n\t]+\\) at \\[line \\([0-9]+\\)\\]" line)
              (let* ((p (match-string 1 line))
                     (rule (match-string 3 line))
                     (msg (match-string 4 line))
                     (f (match-string 5 line))
                     (l (string-to-number (match-string 6 line)))
                     (sev (if (string= p "H") "Error" "Warning")))
                (push (hell-check--make-diag "Java" "spotbugs" sev f l 1 rule msg) diags)))))
      (dolist (f files)
        (push (hell-check--make-diag "Java" "spotbugs" "Info" f 1 1 "tool-missing"
                                     "spotbugs not found on PATH")
              diags)))
    diags))

(defun hell-check-run-scala (files)
  "Run Scala quality checks on FILES: scalafmt & scalafix."
  (let (diags)
    ;; 1. scalafmt
    (if (executable-find "scalafmt")
        (let* ((res (cdr (apply #'hell-process-output "scalafmt" "--test" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\([^:\n]+\\):\\([0-9]+\\):\\(?:\\([0-9]+\\):\\)? \\(.*\\)" line)
              (push (hell-check--make-diag "Scala" "scalafmt" "Warning"
                                           (match-string 1 line)
                                           (string-to-number (match-string 2 line))
                                           (if (match-string 3 line) (string-to-number (match-string 3 line)) 1)
                                           "scalafmt" (match-string 4 line))
                    diags))))
      (dolist (f files)
        (push (hell-check--make-diag "Scala" "scalafmt" "Info" f 1 1 "tool-missing"
                                     "scalafmt not found on PATH")
              diags)))
    ;; 2. scalafix
    (if (executable-find "scalafix")
        (let* ((res (cdr (apply #'hell-process-output "scalafix" "--check" files)))
               (lines (split-string res "\n" t)))
          (dolist (line lines)
            (when (string-match "\\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(?:error\\|warning\\): \\(?:\\[\\(.*?\\)\\] \\)?\\(.*\\)" line)
              (push (hell-check--make-diag "Scala" "scalafix" "Error"
                                           (match-string 1 line)
                                           (string-to-number (match-string 2 line))
                                           (string-to-number (match-string 3 line))
                                           (or (match-string 4 line) "scalafix")
                                           (match-string 5 line))
                    diags))))
      (dolist (f files)
        (push (hell-check--make-diag "Scala" "scalafix" "Info" f 1 1 "tool-missing"
                                     "scalafix not found on PATH")
              diags)))
    diags))

(defun hell-check-run-groovy-gradle (files)
  "Run Groovy & Gradle quality checks on FILES: npm-groovy-lint / codenarc."
  (let (diags)
    (cond
     ((executable-find "npm-groovy-lint")
      (let* ((res (cdr (apply #'hell-process-output "npm-groovy-lint" "--files" (mapconcat #'identity files ",") "--output" "txt")))
             (lines (split-string res "\n" t)))
        (dolist (line lines)
          (when (string-match "\\([^:\n]+\\): line \\([0-9]+\\), col \\([0-9]+\\), \\(error\\|warning\\|info\\) - \\(.*?\\)\\(?: (\\([^)]+\\))\\)?\\'" line)
            (let ((f (match-string 1 line))
                  (l (string-to-number (match-string 2 line)))
                  (c (string-to-number (match-string 3 line)))
                  (sev (match-string 4 line))
                  (msg (match-string 5 line))
                  (rule (match-string 6 line)))
              (push (hell-check--make-diag "Groovy & Gradle" "npm-groovy-lint" sev f l c (or rule "npm-groovy-lint") msg) diags))))))
     ((executable-find "codenarc")
      (let* ((res (cdr (apply #'hell-process-output "codenarc" files)))
             (lines (split-string res "\n" t)))
        (dolist (line lines)
          (when (string-match "Violation: Rule=\\([^ \n\t]+\\) P=\\([0-9]+\\) Line=\\([0-9]+\\) Msg=\\(.*\\)" line)
            (let ((rule (match-string 1 line))
                  (p (match-string 2 line))
                  (l (string-to-number (match-string 3 line)))
                  (msg (match-string 4 line)))
              (push (hell-check--make-diag "Groovy & Gradle" "codenarc" (if (string= p "1") "Error" "Warning")
                                           (car files) l 1 rule msg) diags))))))
     (t
      (dolist (f files)
        (push (hell-check--make-diag "Groovy & Gradle" "codenarc" "Info" f 1 1 "tool-missing"
                                     "npm-groovy-lint and codenarc not found on PATH")
              diags))))
    diags))

;;; Community Wrappers & Gradle Dispatch --------------------------------------

(defun hell-check--find-gradle-wrapper (dir)
  "Locate gradlew executable in DIR or parent directories."
  (let ((found (locate-dominating-file dir "gradlew")))
    (when found
      (let ((wrapper (expand-file-name "gradlew" found)))
        (and (file-executable-p wrapper) wrapper)))))

(defun hell-check--target-dir (targets)
  "Derive dominating base directory from TARGETS."
  (let ((first-target (car targets)))
    (if first-target
        (let ((expanded (expand-file-name first-target)))
          (if (file-directory-p expanded)
              expanded
            (file-name-directory expanded)))
      default-directory)))

(defun hell-check-run-gradle (wrapper jvm-files)
  "Run the Gradle WRAPPER's check tasks (`check', `detekt') on its project.
JVM-FILES are the project's source files."
  (let* ((root (file-name-directory wrapper))
         (default-directory root)
         ;; Attempt ./gradlew check detekt as specified in Requirement 2
         (res (hell-process-output wrapper "check" "detekt" "--console=plain"))
         ;; Fallback to just `check` if task `detekt` is not configured
         (actual-res (if (and (/= (car res) 0)
                              (string-match-p "Task 'detekt' not found" (cdr res)))
                         (hell-process-output wrapper "check" "--console=plain")
                       res))
         (code (car actual-res))
         (output (cdr actual-res))
         (diags nil))
    (if (zerop code)
        diags
      (let ((parsed (hell-check--parse-standard-diagnostics "JVM" "gradle" output)))
        (if parsed
            parsed
          (list (hell-check--make-diag "JVM" "gradle" "Error"
                                       (or (car jvm-files) (expand-file-name "build.gradle" root))
                                       1 1 "gradle/check"
                                       (format "Gradle check failed with exit code %d" code))))))))

(defun hell-check-run-trunk (targets)
  "Run `trunk check` across TARGETS if available and configured."
  (let ((search-dir (hell-check--target-dir targets)))
    (when (and (executable-find "trunk")
               (locate-dominating-file search-dir ".trunk"))
      (let* ((res (apply #'hell-process-output "trunk" "check" "--no-fix" "--output=json" targets))
             (out (cdr res)))
        (condition-case nil
            (let* ((json-object-type 'alist)
                   (data (json-read-from-string out))
                   (issues (alist-get 'issues data))
                   diags)
              (seq-doseq (iss issues)
                (let* ((f (alist-get 'file iss))
                       (l (or (alist-get 'line iss) 1))
                       (c (or (alist-get 'column iss) 1))
                       (sev (alist-get 'severity iss))
                       (msg (alist-get 'message iss))
                       (linter (or (alist-get 'linter iss) "trunk"))
                       (rule (or (alist-get 'rule iss) linter))
                       (lang (if f (hell-check--detect-file-language f) 'unknown))
                       (lang-name (symbol-name (or lang 'unknown))))
                  (push (hell-check--make-diag lang-name linter sev f l c rule msg) diags)))
              diags)
          (error nil))))))

(defun hell-check-run-pre-commit (targets)
  "Run `pre-commit` across TARGETS if configured."
  (let ((search-dir (hell-check--target-dir targets)))
    (when (and (executable-find "pre-commit")
               (locate-dominating-file search-dir ".pre-commit-config.yaml"))
      (let* ((res (apply #'hell-process-output "pre-commit" "run" "--files" targets))
             (code (car res))
             (out (cdr res)))
        (unless (zerop code)
          (hell-check--parse-standard-diagnostics "Pre-Commit" "pre-commit" out))))))

;;; Trusting the target ----------------------------------------------------------
;;
;; Most checks only read the files. Some run code the checked project
;; controls: its build scripts, its hooks, its macros. On a repository you
;; just cloned that is running a stranger's code, so those wait for your
;; word: --trust, `hell-check-trusted-directories', or a yes on a terminal.
;; Without it they're skipped, and the report says so.

(defcustom hell-check-trusted-directories nil
  "Directories whose own code `bin/hell check' and `hell-check' may run.
A target inside one runs ./gradlew, pre-commit, trunk, byte-compile and
the like without asking (see `hell-check--code-runners')."
  :type '(repeat directory)
  :group 'hell-static-analysis)

(defvar hell-check-trust nil
  "Non-nil if this check may run the target's own code: `check --trust'.")

(declare-function hell-cli--yes-p "hell-cli" (prompt &optional default))

(defun hell-check--code-runners (targets by-lang)
  "The checks of TARGETS that would run code the checked project controls.
BY-LANG is `hell-check-discover-files''s :by-language. Each is a string
naming the tool and what of the project's it runs."
  (let ((dir (hell-check--target-dir targets)))
    (delq nil
          (list (and (null hell-check-only) (executable-find "trunk") (locate-dominating-file dir ".trunk")
                     "trunk (the linters .trunk/ sets up)")
                (and (null hell-check-only) (executable-find "pre-commit")
                     (locate-dominating-file dir ".pre-commit-config.yaml")
                     "pre-commit (the hooks .pre-commit-config.yaml names)")
                (and (or (alist-get 'java by-lang) (alist-get 'kotlin by-lang)
                         (alist-get 'groovy-gradle by-lang))
                     (hell-check--find-gradle-wrapper dir)
                     "./gradlew (the build's own scripts)")
                (and (alist-get 'elisp by-lang)
                     "byte-compile and Elsa (the files' macros and eval-when-compile)")
                (and (alist-get 'common-lisp by-lang)
                     "sblint (it loads the files into SBCL)")))))

(defun hell-check--trusted-p (dir)
  "Non-nil if DIR's own code may run.
That's with `hell-check-trust', or DIR in `hell-check-trusted-directories'."
  (or hell-check-trust
      (seq-some (lambda (trusted) (file-in-directory-p dir trusted))
                hell-check-trusted-directories)))

(defun hell-check--allow-code-p (dir runners)
  "Non-nil if RUNNERS, checks running DIR's own code, may run.
Trusted (`hell-check--trusted-p'), or yes on a terminal (`bin/hell -!'
answers yes); with no one to ask, no."
  (or (null runners)
      (hell-check--trusted-p dir)
      (and (fboundp 'hell-cli--yes-p)
           (hell-cli--yes-p (format "Checking %s runs its own code: %s. Trust it? "
                                    (abbreviate-file-name dir) (string-join runners ", "))))))

;;; Quality Gate Coordinator --------------------------------------------------

(defun hell-check-run-all (targets)
  "Coordinate quality gate checks across TARGETS.
Returns a plist containing results, summary, tool listing, and diagnostics."
  (let* ((start-time (current-time))
         (discovery (hell-check-discover-files targets))
         (files (plist-get discovery :files))
         (by-lang (plist-get discovery :by-language))
         (search-dir (hell-check--target-dir targets))
         (runners (hell-check--code-runners targets by-lang))
         (run-code (hell-check--allow-code-p search-dir runners))
         (tools-invoked nil)
         (all-diags nil))

    ;; 0. What was skipped for want of trust, said where it's seen.
    (unless run-code
      (dolist (runner runners)
        (push (hell-check--make-diag
               "-" "hell-check" "Info" search-dir 1 1 "untrusted"
               (format "Skipped %s: it runs this project's own code. Pass --trust, \
or add the directory to `hell-check-trusted-directories'" runner))
              all-diags)))

    ;; 1. Check community wrappers first
    (when-let* ((trunk-diags (and run-code (null hell-check-only) (hell-check-run-trunk targets))))
      (push "trunk" tools-invoked)
      (setq all-diags (append all-diags trunk-diags)))

    (when-let* ((pc-diags (and run-code (null hell-check-only) (hell-check-run-pre-commit files))))
      (push "pre-commit" tools-invoked)
      (setq all-diags (append all-diags pc-diags)))

    ;; 2. Gradle-managed JVM project detection; untrusted, the native tools.
    (let* ((jvm-files (append (alist-get 'java by-lang)
                              (alist-get 'kotlin by-lang)
                              (alist-get 'groovy-gradle by-lang)))
           (gradlew (and run-code jvm-files (hell-check--find-gradle-wrapper search-dir))))
      (if gradlew
          (progn
            (push "gradlew" tools-invoked)
            (setq all-diags (append all-diags (hell-check-run-gradle gradlew jvm-files))))
        ;; Otherwise route JVM languages to native tools
        (when-let* ((java-files (alist-get 'java by-lang)))
          (setq tools-invoked (append tools-invoked '("checkstyle" "spotbugs")))
          (setq all-diags (append all-diags (hell-check-run-java java-files))))
        (when-let* ((kotlin-files (alist-get 'kotlin by-lang)))
          (setq tools-invoked (append tools-invoked '("ktlint" "detekt")))
          (setq all-diags (append all-diags (hell-check-run-kotlin kotlin-files))))
        (when-let* ((groovy-files (alist-get 'groovy-gradle by-lang)))
          (setq tools-invoked (append tools-invoked '("npm-groovy-lint" "codenarc")))
          (setq all-diags (append all-diags (hell-check-run-groovy-gradle groovy-files))))))

    ;; 3. Clojure
    (when-let* ((clj-files (alist-get 'clojure by-lang)))
      (setq tools-invoked (append tools-invoked '("kibit" "clj-kondo")))
      (setq all-diags (append all-diags (hell-check-run-clojure clj-files))))

    ;; 4. Scala
    (when-let* ((scala-files (alist-get 'scala by-lang)))
      (setq tools-invoked (append tools-invoked '("scalafmt" "scalafix")))
      (setq all-diags (append all-diags (hell-check-run-scala scala-files))))

    ;; 5. Emacs Lisp (custom Lisp batch pipeline)
    (when-let* ((el-files (alist-get 'elisp by-lang)))
      (setq tools-invoked (append tools-invoked (hell-check--elisp-tool-names run-code)))
      (setq all-diags (append all-diags (hell-check-run-elisp el-files run-code))))

    ;; 6. Common Lisp (sblint via SBCL batch runner)
    (when-let* ((cl-files (and run-code (alist-get 'common-lisp by-lang))))
      (setq tools-invoked (append tools-invoked '("sblint")))
      (setq all-diags (append all-diags (hell-check-run-common-lisp cl-files))))

    ;; Remove duplicate tools from tools-invoked
    (setq tools-invoked (delete-dups tools-invoked))

    ;; Sort diagnostics by file, line, col
    (setq all-diags
          (sort all-diags
                (lambda (a b)
                  (let ((fa (plist-get a :file))
                        (fb (plist-get b :file))
                        (la (plist-get a :line))
                        (lb (plist-get b :line))
                        (ca (plist-get a :col))
                        (cb (plist-get b :col)))
                    (cond
                     ((not (string= fa fb)) (string< fa fb))
                     ((/= la lb) (< la lb))
                     (t (< ca cb)))))))

    ;; Calculate summaries
    (let ((error-count 0)
          (warning-count 0)
          (info-count 0))
      (dolist (d all-diags)
        (pcase (plist-get d :severity)
          ("Error" (cl-incf error-count))
          ("Warning" (cl-incf warning-count))
          (_ (cl-incf info-count))))

      (list :timestamp (format-time-string "%FT%T%z" start-time)
            :targets targets
            :tools tools-invoked
            :total-files (length files)
            :total-issues (+ error-count warning-count info-count)
            :errors error-count
            :warnings warning-count
            :info info-count
            :diagnostics all-diags
            :by-language by-lang))))


(hell-provide 'hell-lib 'check-tools)
;;; check-tools.el ends here
