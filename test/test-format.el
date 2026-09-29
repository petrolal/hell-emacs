;;; test-format.el --- Tests for :editor format (Phase 10.2, 12.8) -*- lexical-binding: t; -*-

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
(require 'hellmacs-modules)
(require 'hellmacs-sync)
(require 'hellmacs-jdk)                 ; loaded first, so its defuns don't replace the mocks

(defvar lsp-java-format-settings-url)
(defvar lsp-java-format-settings-profile)

(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:editor format :lang java kotlin clojure))
  (hellmacs-module--load '(:editor . format) "autoload.el")
  (hellmacs-module--load '(:editor . format) "config.el")
  (hellmacs-module--load '(:editor . format) "cli.el"))

(defmacro test-format--with-tree (files &rest body)
  "Run BODY in a temporary directory ROOT holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-format" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p root (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil))
           (kill-buffer b)))
       (delete-directory root t))))

(defconst test-format--eclipse-profile
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<profiles version=\"12\">
  <profile kind=\"CodeFormatterProfile\" name=\"HellmacsStyle\" version=\"12\">
    <setting id=\"org.eclipse.jdt.core.formatter.tabulation.char\" value=\"space\"/>
    <setting id=\"org.eclipse.jdt.core.formatter.tabulation.size\" value=\"4\"/>
    <setting id=\"org.eclipse.jdt.core.formatter.lineSplit\" value=\"120\"/>
  </profile>
</profiles>")

(ert-deftest test-format/pinned-jars ()
  "Formatter jar versions and SHA-256 hashes are pinned."
  (let ((spec (hellmacs-format-jar-spec 'google-java-format)))
    (should (plist-get spec :version))
    (should (plist-get spec :sha256)))
  (dolist (name '(google-java-format ktfmt))
    (let ((spec (hellmacs-format-jar-spec name)))
      (should (string-match-p "\\`[0-9a-f]\\{64\\}\\'" (plist-get spec :sha256)))
      (should (string-prefix-p "https://repo1.maven.org/maven2/" (plist-get spec :url)))
      (should (string-match-p (regexp-quote (plist-get spec :version)) (plist-get spec :url)))
      (should (string-prefix-p hellmacs-data-dir (plist-get spec :file)))
      (should (integerp (plist-get spec :jdk)))))
  (should (= (plist-get (hellmacs-format-jar-spec 'google-java-format) :jdk) 21)))

(ert-deftest test-format/mode-associations ()
  "Apheleia formatters are mapped to major modes without hijacking stock keys."
  (should (eq (hellmacs-format-for-mode 'java-mode) 'google-java-format))
  (should (eq (hellmacs-format-for-mode 'kotlin-mode) 'ktfmt))
  (should (eq (hellmacs-format-for-mode 'clojure-mode) 'cljfmt))
  (should (eq (hellmacs-format-for-mode 'java-ts-mode) 'google-java-format))
  (should (eq (hellmacs-format-for-mode 'kotlin-ts-mode) 'ktfmt))
  (should (eq (hellmacs-format-for-mode 'clojure-ts-mode) 'cljfmt))
  ;; XML, YAML, JSON: their language server formats them.
  (should-not (hellmacs-format-for-mode 'nxml-mode)))

(ert-deftest test-format/keys-remap-only ()
  "The format keys lsp-mode already has run the pinned formatter; no new keys."
  (should (eq (keymap-lookup hellmacs-format-mode-map "<remap> <lsp-format-buffer>") #'hellmacs-format-buffer))
  (should (eq (keymap-lookup hellmacs-format-mode-map "<remap> <eglot-format-buffer>") #'hellmacs-format-buffer))
  (map-keymap (lambda (event _) (should (eq event 'remap))) hellmacs-format-mode-map)
  (dolist (hook '(java-mode-hook java-ts-mode-hook kotlin-mode-hook kotlin-ts-mode-hook
                  clojure-mode-hook clojure-ts-mode-hook))
    (should (memq #'hellmacs-format-mode (default-value hook))))
  ;; Off by default: no format on save.
  (should-not (memq #'hellmacs-format--onsave-h (default-value 'java-mode-hook))))

(defun test-format--jdk (root name major)
  "A fake JDK NAME of release MAJOR under ROOT; returns its home."
  (let ((home (expand-file-name name root)))
    (make-directory (expand-file-name "bin" home) t)
    (with-temp-file (expand-file-name "release" home) (insert (format "JAVA_VERSION=\"%d.0.1\"\n" major)))
    (with-temp-file (expand-file-name "bin/java" home) (insert "#!/bin/sh\n"))
    (set-file-modes (expand-file-name "bin/java" home) #o755)
    home))

(ert-deftest test-format/java-new-enough ()
  "Each jar runs on a JDK new enough for it, among those sync found."
  (test-format--with-tree nil
    (let ((jdk17 (test-format--jdk root "jdk17" 17))
          (jdk25 (test-format--jdk root "jdk25" 25)))
      (cl-letf (((symbol-function 'hellmacs-jdk-read)
                 (lambda () (list (cons "17" jdk17) (cons "25" jdk25)))))
        (let ((process-environment (cons (concat "JAVA_HOME=" jdk17) process-environment)))
          ;; JAVA_HOME's 17 is enough for ktfmt, not for google-java-format.
          (should (equal (car (hellmacs-format--jar-command 'ktfmt)) (expand-file-name "bin/java" jdk17)))
          (should (equal (hellmacs-format--jar-command 'google-java-format)
                         (list (expand-file-name "bin/java" jdk25) "-jar"
                               (plist-get (hellmacs-format-jar-spec 'google-java-format) :file)))))))))

(ert-deftest test-format/apheleia-commands ()
  "The formatters apheleia gets: pinned jars from stdin, clojure-lsp in place."
  (let ((formatters (hellmacs-format-apheleia-formatters)))
    (should (equal (alist-get 'google-java-format formatters)
                   '((hellmacs-format--jar-command 'google-java-format) "-")))
    (should (equal (alist-get 'ktfmt formatters)
                   '((hellmacs-format--jar-command 'ktfmt) hellmacs-format-ktfmt-style "-")))
    (should (memq 'inplace (alist-get 'cljfmt formatters)))
    (should (member "--project-root" (alist-get 'cljfmt formatters))))
  (should (equal hellmacs-format-ktfmt-style "--kotlinlang-style")))

(ert-deftest test-format/format-buffer ()
  "The pinned formatter where there is one, else the language server's."
  (let (calls)
    (cl-letf (((symbol-function 'apheleia-format-buffer) (lambda (formatter &rest _) (push (list 'apheleia formatter) calls)))
              ((symbol-function 'lsp-format-buffer) (lambda () (interactive) (push '(lsp) calls))))
      (test-format--with-tree '(("src/A.java" . "class A {}\n") ("pom.xml" . "<project/>\n"))
        (with-current-buffer (find-file-noselect (expand-file-name "src/A.java" root))
          (setq major-mode 'java-mode)
          (hellmacs-format-buffer)
          (should (equal (car calls) '(apheleia google-java-format))))
        (with-current-buffer (find-file-noselect (expand-file-name "pom.xml" root))
          (setq major-mode 'nxml-mode)
          (hellmacs-format-buffer)
          (should (equal (car calls) '(lsp)))))
      ;; A project that keeps an Eclipse profile formats Java with it, through JDTLS.
      (test-format--with-tree `(("src/A.java" . "class A {}\n") ("pom.xml" . "<project/>\n")
                                ("config/eclipse-formatter.xml" . ,test-format--eclipse-profile))
        (with-current-buffer (find-file-noselect (expand-file-name "src/A.java" root))
          (setq major-mode 'java-mode)
          (hellmacs-format-buffer)
          (should (equal (car calls) '(lsp))))))))

(ert-deftest test-format/onsave ()
  "+onsave: apheleia-mode where a formatter is pinned, the server's formatter elsewhere."
  (let (enabled)
    (cl-letf (((symbol-function 'apheleia-mode) (lambda (&optional arg) (setq enabled (or arg 1)))))
      (test-format--with-tree '(("A.java" . "class A {}\n") ("x.json" . "{}\n"))
        (with-current-buffer (find-file-noselect (expand-file-name "A.java" root))
          (setq major-mode 'java-mode)
          (hellmacs-format--onsave-h)
          (should enabled)
          (should-not (memq #'lsp-format-buffer before-save-hook)))
        (setq enabled nil)
        (with-current-buffer (find-file-noselect (expand-file-name "x.json" root))
          (setq major-mode 'js-json-mode)
          (let ((lsp-mode t))
            (hellmacs-format--onsave-h))
          (should-not enabled)
          (should (memq #'hellmacs-format--lsp-before-save-h before-save-hook)))))))

(ert-deftest test-format/eclipse-code-style-import ()
  "Parses Eclipse formatter XML profile."
  (let* ((xml-sample "<profiles version=\"12\">
  <profile kind=\"CodeFormatterProfile\" name=\"HellmacsStyle\" version=\"12\">
    <setting id=\"org.eclipse.jdt.core.formatter.tabulation.char\" value=\"space\"/>
    <setting id=\"org.eclipse.jdt.core.formatter.tabulation.size\" value=\"4\"/>
    <setting id=\"org.eclipse.jdt.core.formatter.lineSplit\" value=\"120\"/>
  </profile>
</profiles>")
         (parsed (hellmacs-format-parse-eclipse-profile xml-sample)))
    (should (equal (plist-get parsed :tab-char) "space"))
    (should (= (plist-get parsed :tab-size) 4))
    (should (= (plist-get parsed :line-split) 120))
    (should (equal (plist-get parsed :name) "HellmacsStyle")))
  (should-not (hellmacs-format-parse-eclipse-profile "<beans/>"))
  (should-not (hellmacs-format-parse-eclipse-profile "<profiles")))

(ert-deftest test-format/eclipse-profile-in-project ()
  "A project's committed Eclipse profile is found, and JDTLS is set to use it."
  (test-format--with-tree `(("pom.xml" . "<project/>\n")
                            ("src/main/resources/beans.xml" . "<beans/>")
                            ("config/eclipse-formatter.xml" . ,test-format--eclipse-profile))
    (let ((found (hellmacs-format-eclipse-profile-file root)))
      (should (equal (car found) (expand-file-name "config/eclipse-formatter.xml" root)))
      (should (equal (cdr found) "HellmacsStyle")))
    (let ((lsp-java-format-settings-url nil) (lsp-java-format-settings-profile nil))
      (with-temp-buffer
        (setq default-directory (expand-file-name "src/" root))
        (make-directory default-directory t)
        (hellmacs-format--java-profile-h)
        (should (equal lsp-java-format-settings-url
                       (concat "file://" (expand-file-name "config/eclipse-formatter.xml" root))))
        (should (equal lsp-java-format-settings-profile "HellmacsStyle")))))
  (test-format--with-tree '(("pom.xml" . "<project/>\n") ("formatter.xml" . "<beans/>"))
    (should-not (hellmacs-format-eclipse-profile-file root))))

(ert-deftest test-format/sync-installs-the-jars-its-languages-need ()
  (let (downloads)
    (cl-letf (((symbol-function 'hellmacs-sync-download-verified)
               (lambda (url dest sha256 _label) (push (list url sha256) downloads)
                 (make-directory (file-name-directory dest) t)
                 (with-temp-file dest (insert "x"))))
              ((symbol-function 'hellmacs-sync--log) #'ignore)
              ((symbol-function 'hellmacs-file-pinned-p) (lambda (&rest _) nil)))
      (let ((hellmacs-format-jars
             (mapcar (lambda (entry)
                       (cons (car entry) (plist-put (copy-sequence (cdr entry)) :file
                                                    (make-temp-file "hellmacs-format-jar"))))
                     hellmacs-format-jars)))
        (hellmacs-format-sync-install)
        (should (member (list (plist-get (hellmacs-format-jar-spec 'google-java-format) :url)
                              (plist-get (hellmacs-format-jar-spec 'google-java-format) :sha256))
                        downloads))
        (should (= (length downloads) 2))))))

(provide 'test-format)
;;; test-format.el ends here
