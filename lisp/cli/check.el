;;; lisp/cli/check.el --- Static Analysis and Linting Quality Gate -*- lexical-binding: t; -*-

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

;; Unified Static Analysis and Linting Quality Gate module for `hell check'
;; and `hell lint'.
;;
;; Features:
;; 1. Target auto-detection and dual-layer routing (surface style linters +
;;    deep AST/semantic analyzers) across:
;;    - Clojure: kibit + clj-kondo
;;    - Kotlin: ktlint + detekt
;;    - Java: checkstyle + spotbugs
;;    - Scala: scalafmt + scalafix
;;    - Groovy & Gradle: npm-groovy-lint / codenarc
;;    - Emacs Lisp: package-lint + elsa, relint, byte-compile
;;    - Common Lisp: sblint via SBCL batch runner
;; 2. Execution architecture:
;;    - Community wrappers: trunk check, pre-commit
;;    - Gradle-managed JVM projects: ./gradlew check, ./gradlew detekt
;;    - Headless batch pipelines: Elisp (internal/batch), CL (SBCL batch)
;; 3. Automated Report Generation:
;;    - Markdown report default to .hell/reports/lint-report.md
;;    - JSON report support via --format=json or .json extension
;;    - Custom path selection via --output <path> / -o <path>
;; 4. Terminal Output & Quality Gate:
;;    - Clean console summary with clickable file:line:col locations
;;    - Exit code 0 on pass, exit code 1 on errors or strict threshold violations

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)
(require 'hell-lib)
(require 'hell-static-analysis)

(defvar hell-cli--problems 0)
(defvar hell-cli-commands (make-hash-table :test #'equal))

(unless (fboundp 'hell-cli--say)
  (defun hell-cli--say (format-string &rest args)
    "Fallback print when hell-cli is not loaded."
    (princ (concat (apply #'format format-string args) "\n"))))

(unless (fboundp 'hell-cli--run)
  (defun hell-cli--run (program &rest args)
    "Fallback run when hell-cli is not loaded."
    (with-temp-buffer
      (let ((code (condition-case nil
                      (apply #'call-process program nil t nil args)
                    (file-missing 127))))
        (cons code (string-trim (buffer-string)))))))

(declare-function hell-cli-help "hell-cli" (&optional command &rest _))

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

(defun hell-check-discover-files (targets)
  "Scan TARGETS (list of files or directories).
Return a plist (:files ALL-FILES :by-language ALIST-OF-(LANG . FILES))."
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
      (maphash (lambda (k v) (push (cons k (nreverse v)) lang-alist)) by-lang)
      (list :files (sort (nreverse all-files) #'string<)
            :by-language lang-alist))))

;;; Diagnostic Structure ------------------------------------------------------

(defun hell-check--make-diag (lang tool severity file line col rule-id message)
  "Create a unified diagnostic plist."
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

(defun hell-check-run-elisp (files)
  "Run the Emacs Lisp dual-layer static analysis suite across FILES.
Covers `package-lint' (linter) and `elsa', `relint', `byte-compile'
\(AST and static analysis)."
  (let (diags)
    (dolist (file files)
      ;; 1. Byte-compile (AST / compiler diagnostics, warnings-as-errors)
      (condition-case err
          (let ((res (hell-static-analysis--check-byte-compile file)))
            (dolist (d res)
              (push (hell-check--make-diag
                     "Emacs Lisp"
                     "byte-compile"
                     (plist-get d :severity)
                     (plist-get d :file)
                     (plist-get d :line)
                     (plist-get d :col)
                     "byte-compile"
                     (plist-get d :message))
                    diags)))
        (error
         (push (hell-check--make-diag "Emacs Lisp" "byte-compile" "Error" file 1 1 "byte-compile"
                                      (format "Byte-compilation failure: %s" err))
               diags)))

      ;; 2. Package-lint (style & packaging standard linter)
      (condition-case _
          (let ((res (hell-static-analysis--check-package-lint file)))
            (dolist (d res)
              (push (hell-check--make-diag
                     "Emacs Lisp"
                     "package-lint"
                     (plist-get d :severity)
                     (plist-get d :file)
                     (plist-get d :line)
                     (plist-get d :col)
                     "package-lint"
                     (plist-get d :message))
                    diags)))
        (error nil))

      ;; 3. Relint (regular expression vulnerability & syntax analyzer)
      (condition-case _
          (let ((res (hell-static-analysis--check-relint file)))
            (dolist (d res)
              (push (hell-check--make-diag
                     "Emacs Lisp"
                     "relint"
                     (plist-get d :severity)
                     (plist-get d :file)
                     (plist-get d :line)
                     (plist-get d :col)
                     "relint"
                     (plist-get d :message))
                    diags)))
        (error nil))

      ;; 4. Elsa (gradual typing and semantic AST analysis)
      (condition-case _
          (let ((res (hell-static-analysis--check-elsa file)))
            (dolist (d res)
              (push (hell-check--make-diag
                     "Emacs Lisp"
                     "elsa"
                     (plist-get d :severity)
                     (plist-get d :file)
                     (plist-get d :line)
                     (plist-get d :col)
                     "elsa"
                     (plist-get d :message))
                    diags)))
        (error nil)))
    (nreverse diags)))

(defun hell-check-run-common-lisp (files)
  "Execute Common Lisp analysis (sblint via SBCL batch runner) across FILES."
  (let (diags)
    (cond
     ;; Priority 1: Native `sblint' executable if present
     ((executable-find "sblint")
      (dolist (file files)
        (let* ((cmd-output (cdr (hell-cli--run "sblint" file)))
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
               (res (cdr (hell-cli--run "sbcl" "--noinform" "--non-interactive" "--eval" sbcl-script)))
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
  "Parse standard file:line:col or file:line diagnostic lines from OUTPUT."
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
  "Run Clojure quality checks: kibit (linter) & clj-kondo (AST analysis)."
  (let (diags)
    ;; 1. clj-kondo
    (if (executable-find "clj-kondo")
        (let* ((res (cdr (apply #'hell-cli--run "clj-kondo" "--lint" files)))
               (parsed (hell-check--parse-standard-diagnostics "Clojure" "clj-kondo" res)))
          (setq diags (append diags parsed)))
      (dolist (f files)
        (push (hell-check--make-diag "Clojure" "clj-kondo" "Info" f 1 1 "tool-missing"
                                     "clj-kondo native binary not found on PATH")
              diags)))
    ;; 2. kibit
    (if (executable-find "kibit")
        (let* ((res (cdr (apply #'hell-cli--run "kibit" files)))
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
  "Run Kotlin quality checks: ktlint (linter) & detekt (AST/complexity)."
  (let (diags)
    ;; 1. ktlint
    (if (executable-find "ktlint")
        (let* ((res (cdr (apply #'hell-cli--run "ktlint" "--reporter=plain" files)))
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
          (let* ((res (cdr (apply #'hell-cli--run detekt-bin "--input" (mapconcat #'identity files ","))))
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
  "Run Java quality checks: checkstyle (linter) & spotbugs (AST/bytecode)."
  (let (diags)
    ;; 1. checkstyle
    (if (executable-find "checkstyle")
        (let* ((res (cdr (apply #'hell-cli--run "checkstyle" files)))
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
        (let* ((res (cdr (apply #'hell-cli--run "spotbugs" "-textui" files)))
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
  "Run Scala quality checks: scalafmt (linter) & scalafix (semantic analysis)."
  (let (diags)
    ;; 1. scalafmt
    (if (executable-find "scalafmt")
        (let* ((res (cdr (apply #'hell-cli--run "scalafmt" "--test" files)))
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
        (let* ((res (cdr (apply #'hell-cli--run "scalafix" "--check" files)))
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
  "Run Groovy & Gradle quality checks: npm-groovy-lint / codenarc."
  (let (diags)
    (cond
     ((executable-find "npm-groovy-lint")
      (let* ((res (cdr (apply #'hell-cli--run "npm-groovy-lint" "--files" (mapconcat #'identity files ",") "--output" "txt")))
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
      (let* ((res (cdr (apply #'hell-cli--run "codenarc" files)))
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
  "Invoke Gradle wrapper standard check tasks (`check', `detekt') on JVM project."
  (let* ((root (file-name-directory wrapper))
         (default-directory root)
         ;; Attempt ./gradlew check detekt as specified in Requirement 2
         (res (hell-cli--run wrapper "check" "detekt" "--console=plain"))
         ;; Fallback to just `check` if task `detekt` is not configured
         (actual-res (if (and (/= (car res) 0)
                              (string-match-p "Task 'detekt' not found" (cdr res)))
                         (hell-cli--run wrapper "check" "--console=plain")
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
      (let* ((res (apply #'hell-cli--run "trunk" "check" "--no-fix" "--output=json" targets))
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
      (let* ((res (apply #'hell-cli--run "pre-commit" "run" "--files" targets))
             (code (car res))
             (out (cdr res)))
        (unless (zerop code)
          (hell-check--parse-standard-diagnostics "Pre-Commit" "pre-commit" out))))))

;;; Quality Gate Coordinator --------------------------------------------------

(defun hell-check-run-all (targets)
  "Coordinate quality gate checks across TARGETS.
Returns a plist containing results, summary, tool listing, and diagnostics."
  (let* ((start-time (current-time))
         (discovery (hell-check-discover-files targets))
         (files (plist-get discovery :files))
         (by-lang (plist-get discovery :by-language))
         (search-dir (hell-check--target-dir targets))
         (tools-invoked nil)
         (all-diags nil))

    ;; 1. Check community wrappers first
    (when-let* ((trunk-diags (hell-check-run-trunk targets)))
      (push "trunk" tools-invoked)
      (setq all-diags (append all-diags trunk-diags)))

    (when-let* ((pc-diags (hell-check-run-pre-commit files)))
      (push "pre-commit" tools-invoked)
      (setq all-diags (append all-diags pc-diags)))

    ;; 2. Gradle-managed JVM project detection
    (let* ((jvm-files (append (alist-get 'java by-lang)
                              (alist-get 'kotlin by-lang)
                              (alist-get 'groovy-gradle by-lang)))
           (gradlew (and jvm-files (hell-check--find-gradle-wrapper search-dir))))
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
      (setq tools-invoked (append tools-invoked '("package-lint" "elsa" "relint" "byte-compile")))
      (setq all-diags (append all-diags (hell-check-run-elisp el-files))))

    ;; 6. Common Lisp (sblint via SBCL batch runner)
    (when-let* ((cl-files (alist-get 'common-lisp by-lang)))
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

;;; Automated Report Generation -----------------------------------------------

(defun hell-check-format-markdown (results)
  "Format RESULTS as a Markdown diagnostic report."
  (let* ((timestamp (plist-get results :timestamp))
         (targets (plist-get results :targets))
         (tools (plist-get results :tools))
         (files-count (plist-get results :total-files))
         (errors (plist-get results :errors))
         (warnings (plist-get results :warnings))
         (info (plist-get results :info))
         (total (+ errors warnings info))
         (diags (plist-get results :diagnostics)))
    (with-temp-buffer
      (insert "# Static Analysis and Linting Quality Gate Report\n\n")
      (insert (format "- **Execution Timestamp:** `%s`\n" timestamp))
      (insert (format "- **Target Paths:** `%s`\n" (mapconcat #'identity targets ", ")))
      (insert (format "- **Tools Invoked:** %s\n\n"
                      (if tools
                          (mapconcat (lambda (t-name) (format "`%s`" t-name)) tools ", ")
                        "None")))

      (insert "## Summary\n\n")
      (insert (format "- **Total Scanned Files:** %d\n" files-count))
      (insert (format "- **Total Issues:** %d\n" total))
      (insert (format "  - **Error:** %d\n" errors))
      (insert (format "  - **Warning:** %d\n" warnings))
      (insert (format "  - **Info:** %d\n\n" info))

      (insert "## Breakdown\n\n")
      (insert "| Language | Tool | Severity | Location (file:line:col) | Rule ID | Message |\n")
      (insert "|:---|:---|:---|:---|:---|:---|\n")
      (if (null diags)
          (insert "\n*No issues detected across all scanned files. Quality gate passed!*\n")
        (dolist (d diags)
          (let ((lang (plist-get d :language))
                (tool (plist-get d :tool))
                (sev (plist-get d :severity))
                (loc (plist-get d :location))
                (rule (plist-get d :rule-id))
                (msg (replace-regexp-in-string "|" "\\\\|" (plist-get d :message))))
            (insert (format "| %s | %s | %s | `%s` | `%s` | %s |\n"
                            lang tool sev loc rule msg)))))
      (insert "\n---\n*Report generated by Hell Emacs Quality Gate.*\n")
      (buffer-string))))

(defun hell-check-format-json (results)
  "Format RESULTS as a JSON diagnostic report."
  (let* ((timestamp (plist-get results :timestamp))
         (targets (plist-get results :targets))
         (tools (plist-get results :tools))
         (files-count (plist-get results :total-files))
         (errors (plist-get results :errors))
         (warnings (plist-get results :warnings))
         (info (plist-get results :info))
         (total (+ errors warnings info))
         (diags (plist-get results :diagnostics))
         (issues (mapcar (lambda (d)
                           (list (cons "language" (plist-get d :language))
                                 (cons "tool" (plist-get d :tool))
                                 (cons "severity" (plist-get d :severity))
                                 (cons "location" (plist-get d :location))
                                 (cons "file" (plist-get d :file))
                                 (cons "line" (plist-get d :line))
                                 (cons "col" (plist-get d :col))
                                 (cons "rule_id" (plist-get d :rule-id))
                                 (cons "message" (plist-get d :message))))
                         diags))
         (tree (list (cons "timestamp" timestamp)
                     (cons "target_paths" (vconcat targets))
                     (cons "tools_invoked" (vconcat tools))
                     (cons "summary" (list (cons "total_scanned_files" files-count)
                                           (cons "total_issues" total)
                                           (cons "errors" errors)
                                           (cons "warnings" warnings)
                                           (cons "info" info)))
                     (cons "breakdown" (vconcat issues)))))
    (let ((json-encoding-pretty-print t))
      (json-encode tree))))

(defun hell-check-write-report (results output-path format-type)
  "Write RESULTS to OUTPUT-PATH using FORMAT-TYPE (`markdown' or `json')."
  (let* ((out (expand-file-name output-path))
         (dir (file-name-directory out))
         (content (if (eq format-type 'json)
                      (hell-check-format-json results)
                    (hell-check-format-markdown results))))
    (when dir
      (make-directory dir t))
    (with-temp-file out
      (insert content (if (string-suffix-p "\n" content) "" "\n")))
    out))

;;; Terminal Output & Quality Gate --------------------------------------------

(defun hell-check-render-terminal (results report-file strict-p)
  "Render a clean terminal summary with clickable file locations and counts.
Returns non-nil if quality gate passes, nil otherwise."
  (let* ((targets (plist-get results :targets))
         (tools (plist-get results :tools))
         (files-count (plist-get results :total-files))
         (errors (plist-get results :errors))
         (warnings (plist-get results :warnings))
         (info (plist-get results :info))
         (diags (plist-get results :diagnostics))
         (by-lang (plist-get results :by-language))
         (passed (and (zerop errors)
                      (or (not strict-p) (zerop warnings)))))

    (hell-cli--say "")
    (hell-cli--say "================================================================================")
    (hell-cli--say "Hell Quality Gate: Static Analysis & Linting")
    (hell-cli--say "================================================================================")
    (hell-cli--say "Targets:   %s" (mapconcat #'identity targets ", "))
    (if by-lang
        (let (lang-summaries)
          (dolist (pair by-lang)
            (let* ((spec (assq (car pair) hell-check-languages))
                   (name (or (plist-get (cdr spec) :name) (symbol-name (car pair)))))
              (push (format "%s (%d files)" name (length (cdr pair))) lang-summaries)))
          (hell-cli--say "Detected:  %s" (mapconcat #'identity (nreverse lang-summaries) ", ")))
      (hell-cli--say "Detected:  None"))
    (hell-cli--say "Tools:     %s" (if tools (mapconcat #'identity tools ", ") "none"))
    (hell-cli--say "--------------------------------------------------------------------------------")

    (if (null diags)
        (hell-cli--say "No issues found across %d scanned file(s)." files-count)
      (hell-cli--say "Diagnostics:")
      (dolist (d diags)
        (let* ((sev (plist-get d :severity))
               (loc (plist-get d :location))
               (lang (plist-get d :language))
               (tool (plist-get d :tool))
               (rule (plist-get d :rule-id))
               (msg (plist-get d :message))
               (mark (pcase sev ("Error" "✗") ("Warning" "!") (_ "·"))))
          ;; Clickable terminal location: file:line:col
          (hell-cli--say "  %s %s: [%s/%s] (%s) %s"
                         mark loc lang tool rule msg))))

    (hell-cli--say "--------------------------------------------------------------------------------")
    (hell-cli--say "Summary: Scanned Files: %d | Issues: %d (Errors: %d, Warnings: %d, Info: %d)"
                   files-count (+ errors warnings info) errors warnings info)
    (hell-cli--say "Report:  %s" (abbreviate-file-name report-file))
    (hell-cli--say "================================================================================")
    (if passed
        (hell-cli--say "Quality Gate: PASSED (all checks succeeded)")
      (hell-cli--say "Quality Gate: FAILED (%d error%s%s)"
                     errors
                     (if (= errors 1) "" "s")
                     (if (and strict-p (> warnings 0))
                         (format ", strict threshold violated: %d warning%s"
                                 warnings (if (= warnings 1) "" "s"))
                       "")))
    passed))

;;; CLI Command Entrypoint ----------------------------------------------------

(defun hell-cli-check (&rest args)
  "Static Analysis and Linting Quality Gate.
Evaluates code against surface style linters and deep AST/semantic analyzers.

Options:
  -o, --output FILE   Write diagnostic report to FILE
                      (default: .hell/reports/lint-report.md)
  --format FORMAT     Report format: `markdown' (default) or `json'
  --strict            Fail quality gate on warnings as well as errors
  -h, --help          Show command usage"
  (let ((output-file nil)
        (format-type nil)
        (strict-p nil)
        (targets nil)
        (rest args))
    (while rest
      (let ((arg (pop rest)))
        (cond
         ((or (string= arg "-o") (string= arg "--output"))
          (if (and rest (not (string-prefix-p "-" (car rest))))
              (setq output-file (pop rest))
            (user-error "%s requires a file path" arg)))
         ((string-prefix-p "--output=" arg)
          (setq output-file (substring arg (length "--output="))))
         ((or (string= arg "--format") (string= arg "-f"))
          (if (and rest (not (string-prefix-p "-" (car rest))))
              (setq format-type (intern (downcase (pop rest))))
            (user-error "%s requires a format (markdown or json)" arg)))
         ((string-prefix-p "--format=" arg)
          (setq format-type (intern (downcase (substring arg (length "--format="))))))
         ((string= arg "--strict")
          (setq strict-p t))
         ((or (string= arg "-h") (string= arg "--help"))
          (hell-cli-help "check")
          (kill-emacs 0))
         ((string-prefix-p "-" arg)
          (user-error "Unknown option: %s" arg))
         (t
          (push arg targets)))))

    (setq targets (if targets (nreverse targets) (list default-directory)))

    ;; Auto-detect format from file extension if not explicitly specified
    (unless format-type
      (setq format-type (if (and output-file (string-suffix-p ".json" output-file))
                            'json
                          'markdown)))

    ;; Default report file if not provided
    (unless output-file
      (setq output-file (if (eq format-type 'json)
                            (expand-file-name ".hell/reports/lint-report.json" default-directory)
                          (expand-file-name ".hell/reports/lint-report.md" default-directory))))

    ;; Run quality gate
    (let* ((results (hell-check-run-all targets))
           (written-report (hell-check-write-report results output-file format-type))
           (passed (hell-check-render-terminal results written-report strict-p)))
      (if noninteractive
          (if passed
              (progn
                (setq hell-cli--problems 0)
                (kill-emacs 0))
            (setq hell-cli--problems (plist-get results :errors))
            (kill-emacs 1))
        (setq hell-cli--problems (if passed 0 (plist-get results :errors)))
        (when (file-exists-p written-report)
          (view-file written-report))
        passed))))

(defalias 'hell-cli-lint #'hell-cli-check
  "Alias for `hell-cli-check'.")

;;;###autoload
(defun hell-check (&optional target)
  "Run the unified Static Analysis and Linting Quality Gate on TARGET.
Interactively, prompt for target directory or file (defaults to project root)."
  (interactive
   (list (if current-prefix-arg
             (read-file-name "Target to check: " default-directory default-directory t)
           (or (when-let* ((proj (project-current))) (project-root proj))
               default-directory))))
  (hell-cli-check (or target default-directory)))

;;;###autoload
(defalias 'hell-lint #'hell-check
  "Alias for `hell-check'.")

;; Bind leader keys C-c c x (quality check) and C-c c l (quality lint)
(with-eval-after-load 'hell-keybinds
  (when (fboundp 'hell-leader-def)
    (hell-leader-def
      "c x" '("quality check" . hell-check)
      "c l" '("quality lint" . hell-lint))))

;; Direct keymap bindings on mode-specific-map (C-c)
(keymap-set mode-specific-map "c x" #'hell-check)
(keymap-set mode-specific-map "c l" #'hell-lint)
(keymap-set mode-specific-map "h c" #'hell-check)

;; Register with defcli! if available
(eval-after-load 'hell-cli
  '(progn
     (puthash "check"
              (list :name 'check
                    :fn 'hell-cli-check
                    :doc (documentation #'hell-cli-check t)
                    :arglist '(&rest args))
              hell-cli-commands)
     (puthash "lint"
              (list :name 'lint
                    :fn 'hell-cli-lint
                    :doc (documentation #'hell-cli-lint t)
                    :arglist '(&rest args))
              hell-cli-commands)))

(provide 'hell-cli-check)
;;; check.el ends here
