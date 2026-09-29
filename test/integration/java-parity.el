;;; java-parity.el --- IntelliJ parity checklist and measurements -*- lexical-binding: t; -*-

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

;; Phase 6.8: works through the IntelliJ feature checklist on any Maven
;; or Gradle project, and records what a working day would feel like:
;; Emacs' startup time, the time until JDTLS is ready, and JDTLS' memory.
;; Everything is read-only against the language server (rename is asked
;; for but not applied), and the project is copied to a temporary
;; directory first, because JDTLS and the build tool write into it.
;;
;;   HELLMACS_PARITY_PROJECT=/path/to/project \
;;     emacs --batch -l early-init.el -l init.el \
;;           -l test/integration/java-parity.el
;;
;; Or, instead of a project of your own, a pinned reference project
;; (Phase 12.7; see reference.el), cloned on the first run:
;;
;;   HELLMACS_PARITY_REFERENCE=spring-framework HELLMACS_PARITY_TIMEOUT=1800 \
;;     emacs --batch -l early-init.el -l init.el \
;;           -l test/integration/java-parity.el
;;
;; Its pin supplies the file to work in and the build command, unless
;; the variables below say otherwise. With $HELLMACS_BUDGET_OUT set, the
;; import time, completion latency and memory are also recorded there
;; for Phase 12.7's budgets (budgets.el, .github/workflows/budgets.yml).
;;
;; Optional variables:
;;   HELLMACS_PARITY_FILE   a Java file, relative to the project, to work
;;                          in (default: the biggest under src/main/java)
;;   HELLMACS_PARITY_BUILD  the build command (default: the one
;;                          `:tools build' proposes for the project)
;;   HELLMACS_PARITY_TIMEOUT  seconds to wait for each slow step (600)
;;   HELLMACS_E2E_KEEP      keep the project copy after the run (it's
;;                          deleted, and taken out of the lsp session)
;;
;; Run it inside throwaway XDG_*_HOME/HELLMACSDIR directories, like
;; java-e2e.el. A project without Java sources (Kotlin only) skips the
;; language-server items and still runs the build and Git ones.

;;; Code:

(require 'cl-lib)
(load (expand-file-name "e2e-lib" (file-name-directory (or load-file-name buffer-file-name))) nil t)
(load (expand-file-name "reference" (file-name-directory (or load-file-name buffer-file-name))) nil t)
(load (expand-file-name "budgets" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defvar parity--start (float-time))
(defvar parity--reference
  (when-let* ((name (getenv "HELLMACS_PARITY_REFERENCE"))
              ((not (string-empty-p name))))
    (cons (intern name) (e2e-reference (intern name))))
  "The reference project being measured, as (NAME . SPEC), or nil.")
(when parity--reference
  (let ((spec (cdr parity--reference)))
    (unless (getenv "HELLMACS_PARITY_FILE") (setenv "HELLMACS_PARITY_FILE" (plist-get spec :file)))
    (unless (getenv "HELLMACS_PARITY_BUILD") (setenv "HELLMACS_PARITY_BUILD" (plist-get spec :build)))))
(defvar parity--source
  (cond (parity--reference (e2e-reference-fetch (car parity--reference)))
        ((getenv "HELLMACS_PARITY_PROJECT"))
        (t (error "Set HELLMACS_PARITY_PROJECT to a Maven or Gradle project, or HELLMACS_PARITY_REFERENCE to one of: %s"
                  (mapconcat (lambda (e) (symbol-name (car e))) e2e-reference-projects ", ")))))

(defun parity--java-files (proj)
  "PROJ's Java sources under src/main/java; nil in a multi-project build's root."
  (let ((dir (expand-file-name "src/main/java" proj)))
    (and (file-directory-p dir) (directory-files-recursively dir "\\.java\\'"))))

(defun parity--jdtls-pid ()
  (when-let* ((ws (car (lsp-workspaces))))
    (process-id (lsp--workspace-cmd-proc ws))))

(defun parity--range-of-line (line-regexp)
  "An LSP range covering the first line matching LINE-REGEXP, or nil."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward line-regexp nil t)
      (let ((beg (line-beginning-position)) (end (line-end-position)))
        (lsp--region-to-range (+ beg (- (length (buffer-substring beg end))
                                        (length (string-trim-left (buffer-substring beg end)))))
                              end)))))

(defun parity--completion-latency (buf samples)
  "Time SAMPLES completion requests in BUF, spread over it; report the p95.
One request before them warms the server up and isn't counted. A request
that fails or times out counts with the time it took."
  (with-current-buffer buf
    (let* ((points (budgets-completion-points (1+ samples)))
           (times
            (mapcar (lambda (pt)
                      (goto-char pt)
                      (let ((t0 (float-time)))
                        (condition-case err
                            (lsp-request "textDocument/completion" (lsp--text-document-position-params))
                          (error (e2e--say "     completion at %d failed: %S" pt err)))
                        (* 1000 (- (float-time) t0))))
                    points))
           (p95 (budgets-percentile (cdr times) 95)))
      (e2e--say "     METRIC completion latency: p95 %s ms over %d request(s), max %s ms"
                (and p95 (format "%.0f" p95)) (length (cdr times))
                (and (cdr times) (format "%.0f" (apply #'max (cdr times)))))
      (when p95 (budgets-record 'completion-p95-ms p95)))))

(defun parity--wait-for-symbol (query secs)
  "Wait up to SECS for a workspace symbol search for QUERY to find something.
Asked asynchronously, one request at a time: while JDTLS imports, a
synchronous `lsp-request' times out, and its late answer then throws to
a catch that's gone (\"No catch for tag: lsp-done\"), ending the run."
  (let ((state 'idle) answered)
    (e2e--wait (lambda ()
                 (when (eq state 'idle)
                   (setq state 'pending)
                   (lsp-request-async "workspace/symbol" (list :query query)
                                      (lambda (result)
                                        (if (> (length result) 0)
                                            (setq answered t)
                                          ;; Not indexed yet: ask again shortly.
                                          (run-at-time 2 nil (lambda () (setq state 'idle)))))
                                      :error-handler (lambda (_) (run-at-time 2 nil (lambda () (setq state 'idle))))
                                      :mode 'detached))
                 answered)
               secs)))

(defun parity--lsp-checks (proj file)
  (let ((buf (find-file-noselect file)) ready-secs)
    (switch-to-buffer buf)
    (e2e--say "\n== Import and index")
    (let ((t0 (float-time)))
      (e2e-check "JDTLS starts and reports ready"
        (e2e-add-project proj)
        (lsp)
        ;; Until it's ready, or failed for good: a failed import stops the
        ;; wait at once (a reimport, as for Gradle 9, is waited for).
        (e2e--wait (lambda () (hellmacs-jvm-import-settled-p proj)) e2e-parity-timeout)
        (setq ready-secs (and (eq (hellmacs-jvm-state proj) 'ready)
                              (- (float-time) t0)))))
    (when (eq (hellmacs-jvm-state proj) 'failed)
      (e2e--say "     the import failed; see the JDTLS log (*lsp-log*)"))
    (e2e--say "     METRIC time until [DAEMON READY]: %s"
              (if ready-secs (format "%.1fs" ready-secs) "not reached"))
    (when ready-secs
      ;; JDTLS says ServiceReady before it has imported the project, so
      ;; also time how long until a symbol query is answered.
      (let* ((class (file-name-sans-extension (file-name-nondirectory file)))
             (t1 (float-time))
             (answered (parity--wait-for-symbol class e2e-parity-timeout)))
        (e2e--say "     METRIC time from ready until symbol search answers: %s"
                  (if answered (format "%.1fs" (- (float-time) t1)) "never"))
        ;; The first import: from starting JDTLS until the project answers.
        (when answered
          (budgets-record 'jdtls-import-seconds (+ ready-secs (- (float-time) t1)))))
      (accept-process-output nil 8)     ; let diagnostics settle
      (parity--completion-latency buf 20)
      (when-let* ((pid (parity--jdtls-pid)))
        (let ((emacs (e2e-rss-mb (emacs-pid) "VmHWM"))
              (jdtls (e2e-rss-mb pid "VmHWM")))
          (e2e--say "     METRIC memory after import: Emacs %.0f MB + JDTLS %.0f MB (peaks)" emacs jdtls)
          (budgets-record 'hellmacs-memory-mb (+ emacs jdtls))))
      (parity--navigation-checks buf)
      (parity--editing-checks buf)
      (let ((pid (parity--jdtls-pid)))
        (e2e--say "     METRIC JDTLS memory: %s MB now, %s MB peak (pid %s)"
                  (and pid (format "%.0f" (e2e-rss-mb pid "VmRSS")))
                  (and pid (format "%.0f" (e2e-rss-mb pid "VmHWM")))
                  pid)))
    (parity--build-checks proj buf)))

(defun parity--navigation-checks (buf)
  (with-current-buffer buf
    (let ((class (file-name-sans-extension (file-name-nondirectory buffer-file-name))))
      (e2e--say "\n== Navigation")
      (e2e-check (format "workspace symbol search finds %s" class)
        (let ((res (lsp-request "workspace/symbol" (list :query class))))
          (cl-some (lambda (s) (string-match-p (regexp-quote class) (lsp-get s :name)))
                   (append res nil))))
      (e2e-check "document outline lists symbols"
        (> (length (lsp-request "textDocument/documentSymbol"
                                (list :textDocument (lsp--text-document-identifier))))
           0))
      (e2e-check "hover shows documentation or a signature"
        (and (e2e-goto-identifier (format "\\(?:class\\|interface\\|record\\|enum\\)[ \t]+\\(%s\\)" class))
             (lsp-request "textDocument/hover" (lsp--text-document-position-params))))
      (e2e-check "references of the class are found"
        (e2e-goto-identifier (format "\\(?:class\\|interface\\|record\\|enum\\)[ \t]+\\(%s\\)" class))
        (let ((refs (lsp-request "textDocument/references"
                                 (append (lsp--text-document-position-params)
                                         (list :context (list :includeDeclaration t))))))
          (e2e--say "     %d reference(s)" (length refs))
          (> (length refs) 0)))
      (e2e-check "definition of String reaches decompiled JDK source"
        (when (e2e-goto-identifier "[ (\t]\\(String\\)[ \t>]")
          (let* ((loc (car (append (lsp-request "textDocument/definition"
                                                (lsp--text-document-position-params)) nil)))
                 (uri (lsp-get loc :uri))
                 (src (and uri (string-prefix-p "jdt:" uri)
                           (lsp-request "java/classFileContents" (list :uri uri)))))
            (and (stringp src) (string-match-p "class String" src)))))
      (e2e-check "call hierarchy is available"
        (e2e-goto-identifier (format "\\(?:class\\|interface\\|record\\|enum\\)[ \t]+\\(%s\\)" class))
        (lsp-request "textDocument/prepareTypeHierarchy" (lsp--text-document-position-params))
        t))))

(defun parity--editing-checks (buf)
  (with-current-buffer buf
    (e2e--say "\n== Editing and refactoring")
    (e2e-check "no compile errors reported in the file"
      (null (cl-remove-if-not (lambda (d) (eq (flymake-diagnostic-type d) :error))
                              (flymake-diagnostics))))
    (e2e-check "completion inside a method offers String"
      (goto-char (point-min))
      (when (re-search-forward "^[ \t]+\\(?:public\\|private\\|protected\\)[^=;(]*(.*{[ \t]*$" nil t)
        (end-of-line) (insert "\nStr")
        (let* ((res (lsp-request "textDocument/completion" (lsp--text-document-position-params)))
               (items (e2e-completion-items res)))
          (delete-region (line-end-position 0) (point))
          (set-buffer-modified-p nil)
          (cl-some (lambda (i) (equal (lsp-get i :label) "String")) items))))
    (revert-buffer t t t)
    (accept-process-output nil 3)       ; JDTLS must see the reverted text
    (let ((name-re "^[ \t]+public[ \t][][A-Za-z0-9_<>,? ]*[ \t]\\([a-z][A-Za-z0-9_]*\\)("))
      (if (not (save-excursion (goto-char (point-min)) (re-search-forward name-re nil t)))
          (e2e-skip "rename is planned across files" "no explicit public method in this file")
        (e2e-check "rename is planned across files (not applied)"
          (e2e-goto-identifier name-re)
          (let* ((edit (lsp-request "textDocument/rename"
                                    (append (lsp--text-document-position-params)
                                            (list :newName "renamedByParity"))))
                 (changes (e2e-edit-changes edit))
                 (n (if (hash-table-p changes) (hash-table-count changes) (length changes))))
            (e2e--say "     rename touches %d file(s)" n)
            (> n 0)))))
    (e2e-check "extract-method / local variable is offered for some statement"
      ;; JDTLS offers extraction for expressions and statement groups, not
      ;; for every line, so try the first few plausible ones.
      (goto-char (point-min))
      (let ((tries 0) found)
        (while (and (not found) (< tries 12)
                    (re-search-forward "^[ \t]+\\(?:return \\|[A-Za-z][][A-Za-z0-9_<>,.? ]* [a-z][A-Za-z0-9_]* = \\)[^;]*;$" nil t))
          (cl-incf tries)
          (let ((end (line-end-position))
                (beg (progn (beginning-of-line) (skip-chars-forward " \t") (point))))
            (goto-char end)
            (setq found
                  (cl-some (lambda (title) (string-match-p "Extract" title))
                           (e2e-code-action-titles
                            (lsp--region-to-range beg end))))))
        found))
    (e2e-check "quick fix offers an import for an unresolved type"
      (goto-char (point-min))
      (when (re-search-forward "^\\(?:public \\)?\\(?:final \\)?\\(?:class\\|record\\|enum\\|interface\\)[^{]*{[ \t]*$" nil t)
        ;; A JDK class the file doesn't already resolve: Spring Framework's
        ;; file imports ArrayList, so inserting that offered nothing.
        (let* ((type (or (e2e-unimported-jdk-type) (error "Every candidate type is already in the file")))
               (wanted (concat "Import '" type "'"))
               (line (progn (end-of-line)
                            (insert (format "\n    java.util.List<String> parityOk; %s parityUnresolved;\n" type))
                            (line-number-at-pos (1- (point)))))
               titles)
          (e2e--say "     unresolved type: %s" type)
          ;; Asked as C-c l a asks (`lsp-code-actions-at-point'): with the
          ;; diagnostics at point, which JDTLS computes its quick fixes from.
          (e2e--wait (lambda ()
                       (setq titles nil)
                       (dolist (d (flymake-diagnostics))
                         (when (eq (flymake-diagnostic-type d) :error)
                           (save-excursion
                             (goto-char (flymake-diagnostic-beg d))
                             (setq titles (append titles (mapcar (lambda (a) (lsp-get a :title))
                                                                 (lsp-code-actions-at-point)))))))
                       (cl-some (lambda (title) (string-prefix-p wanted title)) titles))
                     60)
          (unless (cl-some (lambda (title) (string-prefix-p wanted title)) titles)
            (e2e--say "     code actions on the errors: %S" titles))
          (prog1 (cl-some (lambda (title) (string-prefix-p wanted title)) titles)
            (ignore line)
            (set-buffer-modified-p nil)))))
    (revert-buffer t t t)
    (accept-process-output nil 3)
    (e2e-check "organize imports is offered"
      (e2e-code-action-titles (lsp--region-to-range (point-min) (1+ (point-min)))
                                  '("source.organizeImports")))
    (e2e-check "formatting request succeeds"
      (progn (lsp-request "textDocument/formatting"
                          (list :textDocument (lsp--text-document-identifier)
                                :options (list :tabSize 4 :insertSpaces t)))
             t))
    (e2e-check "generate getters/setters, toString, equals and constructors are offered"
      (when-let* ((range (parity--range-of-line "\\(?:class\\|record\\|enum\\)[ \t]+[A-Za-z]+")))
        (let ((titles (e2e-code-action-titles range '("source"))))
          (e2e--say "     %d source action(s), e.g. %s" (length titles) (car titles))
          (cl-some (lambda (title) (string-match-p "Generate" title)) titles))))))

(defun parity--build-checks (proj buf)
  (e2e--say "\n== Build")
  (with-current-buffer buf
    (let ((cmd (or (getenv "HELLMACS_PARITY_BUILD") compile-command)))
      (e2e--say "     build command: %s" cmd)
      (let ((t0 (float-time)) (default-directory proj) finished)
        (e2e-check "the project's build finishes successfully"
          (let ((hook (lambda (_b msg) (setq finished msg))))
            (add-hook 'compilation-finish-functions hook)
            (unwind-protect
                (progn (compile cmd)
                       (e2e--wait (lambda () finished) e2e-parity-timeout)
                       (and finished (string-match-p "^finished" finished)))
              (remove-hook 'compilation-finish-functions hook))))
        (unless (and finished (string-match-p "^finished" finished))
          (when-let* ((b (get-buffer "*compilation*")))
            (with-current-buffer b
              (e2e--say "     last build output:\n%s"
                        (mapconcat (lambda (l) (concat "       | " l))
                                   (last (split-string (string-trim (buffer-string)) "\n") 15)
                                   "\n")))))
        (e2e--say "     METRIC build time: %.1fs" (- (float-time) t0))))))

(defun parity--magit-checks (proj file)
  (e2e--say "\n== Git")
  (if (not (locate-dominating-file proj ".git"))
      (e2e-skip "Magit status, log and blame" "the project is not a git repository")
    (let ((default-directory (file-name-as-directory proj)))
      (e2e-check "status shows the working tree"
        (call-interactively (key-binding (kbd "C-x g")))
        (derived-mode-p 'magit-status-mode))
      (e2e-check "log lists the history"
        (magit-log-current nil nil)
        (> (count-lines (point-min) (point-max)) 0))
      (when (and file (file-exists-p file))
        (e2e-check "blame annotates the Java file"
          (with-current-buffer (find-file-noselect file)
            (magit-blame-addition nil)
            (e2e--wait (lambda () (cl-some (lambda (o) (overlay-get o 'magit-blame-chunk))
                                           (overlays-in (point-min) (point-max))))
                       60)))))))

(let* ((proj (e2e-copy-project parity--source))
       (file (ignore-errors (e2e-pick-file proj (parity--java-files proj)))))
  (e2e--say "Hellmacs parity run: %s (copied to %s)" (file-name-nondirectory (directory-file-name parity--source)) proj)
  (when-let* ((spec (cdr parity--reference)))
    (e2e--say "     reference: %s %s (%s)" (car parity--reference)
              (plist-get spec :tag) (plist-get spec :commit)))
  (e2e--say "     METRIC Emacs startup (init.el done): %.2fs" (float-time (time-subtract (current-time) before-init-time)))
  (e2e--say "     working file: %s" (and file (file-relative-name file proj)))
  (cond ((and file (file-exists-p file))
         (parity--lsp-checks proj file))
        (t
         (e2e-skip "language-server items" "no Java sources under src/main/java")
         (let ((default-directory proj)
               (compile-command (or (getenv "HELLMACS_PARITY_BUILD") "./gradlew build")))
           (parity--build-checks proj (current-buffer)))))
  (parity--magit-checks proj file)
  (e2e--say "\n%s (%d skipped)" (if (zerop e2e--failures) "ALL PASSED" (format "%d FAILED" e2e--failures)) e2e--skipped)
  (kill-emacs (if (zerop e2e--failures) 0 1)))

;;; java-parity.el ends here
