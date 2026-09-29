;;; test-treesit.el --- Tests for tree-sitter support (core/hellmacs-treesit.el) -*- lexical-binding: t; -*-

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


;; Run with `bin/hellmacs test'. The pin and build logic runs against a
;; tiny local git repository; real grammars are checked by the Phase 8.1
;; probes (see docs/roadmap.md).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-treesit)
(require 'hellmacs-modules)

(defun test-treesit--git (dir &rest args)
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory dir)))
      (unless (zerop (apply #'call-process "git" nil t nil
                            "-c" "user.name=t" "-c" "user.email=t@example.invalid" args))
        (error "git %s: %s" args (buffer-string)))
      (string-trim (buffer-string)))))

(defun test-treesit--fake-grammar (root)
  "Make a git repo under ROOT with a compilable src/parser.c, tagged v1.
Returns (URL TAG COMMIT)."
  (let ((repo (expand-file-name "fake-grammar" root)))
    (make-directory (expand-file-name "src" repo) t)
    (with-temp-file (expand-file-name "src/parser.c" repo)
      (insert "const void *tree_sitter_fake(void) { return 0; }\n"))
    (test-treesit--git repo "init" "-q")
    (test-treesit--git repo "add" ".")
    (test-treesit--git repo "commit" "-q" "-m" "grammar")
    (test-treesit--git repo "tag" "v1")
    (list (concat "file://" repo) "v1" (test-treesit--git repo "rev-parse" "HEAD"))))

(defmacro test-treesit--with-fake (&rest body)
  "Run BODY with `fake' pinned in `hellmacs-treesit-sources' and a temp install dir."
  (declare (indent 0))
  `(progn
     (skip-unless (and (executable-find "git") (executable-find "cc")))
     (let* ((root (make-temp-file "hellmacs-test-treesit" t))
            (source (test-treesit--fake-grammar root))
            (hellmacs-treesit-dir (expand-file-name "out/" root))
            (hellmacs-treesit-sources (list (cons 'fake source))))
       (unwind-protect (progn ,@body)
         (delete-directory root t)))))

(ert-deftest test-treesit/builds-the-pinned-commit ()
  (test-treesit--with-fake
    (should-not (file-exists-p (hellmacs-treesit-library 'fake)))
    (hellmacs-treesit-install 'fake)
    (should (file-exists-p (hellmacs-treesit-library 'fake)))
    (should (hellmacs-treesit-current-p 'fake))
    ;; Nothing but the library and its commit marker is left.
    (should (equal (sort (directory-files hellmacs-treesit-dir nil "\\`[^.]") #'string<)
                   (sort (list (file-name-nondirectory (hellmacs-treesit-library 'fake))
                               (file-name-nondirectory (hellmacs-treesit--marker 'fake)))
                         #'string<)))
    ;; A library built from another commit (an older pin) isn't current.
    (with-temp-file (hellmacs-treesit--marker 'fake) (insert "0000\n"))
    (should-not (hellmacs-treesit-current-p 'fake))
    (delete-file (hellmacs-treesit--marker 'fake))
    (should-not (hellmacs-treesit-current-p 'fake))))

(ert-deftest test-treesit/builds-a-grammar-in-a-subdirectory ()
  "A DIRECTORY entry compiles that subdirectory's src/, as markdown-inline needs."
  (skip-unless (and (executable-find "git") (executable-find "cc")))
  (let* ((root (make-temp-file "hellmacs-test-treesit" t))
         (repo (expand-file-name "mono" root))
         (hellmacs-treesit-dir (expand-file-name "out/" root)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "inner/src" repo) t)
          (with-temp-file (expand-file-name "inner/src/parser.c" repo)
            (insert "const void *tree_sitter_fake(void) { return 0; }\n"))
          (test-treesit--git repo "init" "-q")
          (test-treesit--git repo "add" ".")
          (test-treesit--git repo "commit" "-q" "-m" "x")
          (let ((hellmacs-treesit-sources
                 (list (list 'fake (concat "file://" repo) "main"
                             (test-treesit--git repo "rev-parse" "HEAD") "inner"))))
            (hellmacs-treesit-install 'fake)
            (should (file-exists-p (hellmacs-treesit-library 'fake)))))
      (delete-directory root t))))

(ert-deftest test-treesit/refuses-a-commit-that-is-not-there ()
  "A pin the source can't supply installs nothing."
  (test-treesit--with-fake
    (setcar (nthcdr 2 (cdr (assq 'fake hellmacs-treesit-sources)))
            "0000000000000000000000000000000000000000")
    (should-error (hellmacs-treesit-install 'fake))
    (should-not (file-exists-p (hellmacs-treesit-library 'fake)))
    (should-not (and (file-directory-p hellmacs-treesit-dir)
                     (directory-files hellmacs-treesit-dir nil "\\`[^.]")))))

(ert-deftest test-treesit/declarations ()
  "Modules declare their pinned grammars; yours override them."
  (let ((hellmacs-modules (make-hash-table :test #'equal))
        (hellmacs-packages nil)
        (hellmacs-module-dependencies nil)
        (hellmacs-treesit-declarations nil)
        (warning-minimum-log-level :emergency))
    (hellmacs--enable-modules '(:tools lsp :lang (java +tree-sitter) (kotlin +tree-sitter)
                                (clojure +tree-sitter)))
    (hellmacs-modules-read-packages)
    (should (seq-set-equal-p (hellmacs-treesit-wanted) '(java kotlin clojure markdown-inline regex)))
    (should (equal (hellmacs-treesit-module-languages '(:lang . clojure))
                   '(clojure markdown-inline regex)))
    ;; Every shipped grammar names a label, a full commit and its license.
    (dolist (lang (hellmacs-treesit-wanted))
      (pcase-let ((`(,url ,label ,commit ,dir) (hellmacs-treesit--source lang)))
        (should (string-prefix-p "https://" url))
        (should (stringp label))
        (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" commit))
        (should (or (null dir) (stringp dir) (eq dir :license)))
        (should (stringp (hellmacs-treesit-source-license lang)))))
    (let ((hellmacs-treesit-sources '((kotlin "https://example.invalid/k" "mine" "c0ffee"))))
      (should (equal (hellmacs-treesit--source 'kotlin) '("https://example.invalid/k" "mine" "c0ffee"))))
    ;; Without the flag, nothing is declared.
    (hellmacs--enable-modules '(:tools lsp :lang java kotlin clojure))
    (hellmacs-modules-read-packages)
    (should-not (hellmacs-treesit-wanted)))
  (should-error (hellmacs-treesit-install 'no-such-language))
  (let ((hellmacs--current-module nil))
    (should-error (hellmacs-treesit! :grammars ((x "u" "l" "c"))))))

(ert-deftest test-treesit/apply-remaps-only-built-grammars ()
  "A module's modes are remapped once all its grammars are built; else it warns."
  (let ((hellmacs-treesit-declarations
         '(((:lang . ready) :grammars ((a "u" "l" "c") (b "u" "l" "c")) :remap ((a-mode . a-ts-mode)))
           ((:lang . half) :grammars ((b "u" "l" "c") (c "u" "l" "c")) :remap ((c-mode . c-ts-mode)))))
        (major-mode-remap-alist nil)
        (warnings nil))
    (cl-letf (((symbol-function 'hellmacs-treesit-current-p) (lambda (lang) (memq lang '(a b))))
              ((symbol-function 'display-warning)
               (lambda (_type message &rest _) (push message warnings))))
      (hellmacs-treesit-apply))
    (should (equal major-mode-remap-alist '((a-mode . a-ts-mode))))
    (should (equal warnings '("Module :lang half +tree-sitter: the c grammar isn't built yet; run `bin/hellmacs sync'")))))

(provide 'test-treesit)
;;; test-treesit.el ends here
