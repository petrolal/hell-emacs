;;; hellmacs-jdk.el --- Find the JDKs installed on this machine -*- lexical-binding: t; -*-

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

;; Several JDKs side by side (Phase 12.3). `bin/hellmacs sync' looks for
;; them where JDKs get installed -- SDKMAN, /usr/lib/jvm, macOS's
;; JavaVirtualMachines, asdf, jenv, mise -- and JAVA_HOME, and stores what
;; it found (`hellmacs-jdk-file'). :lang java hands them to JDTLS as
;; `lsp-java-configuration-runtimes', so each project compiles against the
;; release it targets while JDTLS itself runs on 21+.
;;
;; A JDK is a directory with a `release' file (every JDK since 9 has one,
;; and 8's builds from Adoptium, Azul, Corretto and the distributions do);
;; its JAVA_VERSION names the release, in JDTLS's words ("JavaSE-1.8",
;; "JavaSE-21"). One JDK is kept per release.
;;
;; Also here: what Maven's toolchains.xml and a Gradle build's toolchain
;; block ask for, in the same words.
;;
;; Not loaded at startup: its entry points are autoloaded (hellmacs-modules.el).

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar hellmacs-data-dir)              ; early-init.el

;;; Release names ----------------------------------------------------------------

(defun hellmacs-jdk--major (version)
  "The major release of VERSION (\"1.8.0_402\", \"21.0.2+13-LTS\", 17), or nil."
  (let ((version (if (numberp version) (number-to-string version) version)))
    (when (and (stringp version)
               (string-match "\\`\\([0-9]+\\)\\(?:\\.\\([0-9]+\\)\\)?" version))
      (let ((major (string-to-number (match-string 1 version))))
        ;; Java 8 and older call themselves 1.8, 1.7...
        (if (and (= major 1) (match-string 2 version))
            (string-to-number (match-string 2 version))
          major)))))

;;;###autoload
(defun hellmacs-jdk-release-name (version)
  "JDTLS's name for the release of VERSION: \"J2SE-1.5\", \"JavaSE-1.8\", \"JavaSE-21\".
VERSION is a string (\"1.8\", \"8\", \"17.0.9\") or a number; nil if it
isn't a Java version."
  (when-let* ((major (hellmacs-jdk--major version)))
    (cond ((< major 5) nil)
          ((= major 5) "J2SE-1.5")
          ((<= major 8) (format "JavaSE-1.%d" major))
          (t (format "JavaSE-%d" major)))))

(defun hellmacs-jdk--name-major (name)
  "The major release a JDTLS release NAME (\"JavaSE-1.8\") stands for."
  (hellmacs-jdk--major (replace-regexp-in-string "\\`[A-Za-z0-9]+-" "" name)))

;;;###autoload
(defun hellmacs-jdk-parse-release-content (content)
  "The release name in CONTENT, a JDK's `release' file, from its JAVA_VERSION."
  (when (string-match "^JAVA_VERSION=[\"']?\\([^\"'\n]+\\)" content)
    (hellmacs-jdk-release-name (match-string 1 content))))

(defun hellmacs-jdk-home-release (home)
  "The release name of the JDK in HOME, or nil if HOME isn't a JDK."
  (let ((file (expand-file-name "release" home)))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (hellmacs-jdk-parse-release-content (buffer-string))))))

(defun hellmacs-jdk-home-major (home)
  "The major release of the JDK in HOME (8, 21...), or nil if HOME isn't one."
  (when-let* ((name (and home (hellmacs-jdk-home-release home))))
    (hellmacs-jdk--name-major name)))

(defun hellmacs-jdk-pick (homes min max)
  "The first of HOMES holding a JDK of release MIN to MAX, or nil."
  (seq-find (lambda (home)
              (when-let* ((major (hellmacs-jdk-home-major home)))
                (<= min major max)))
            homes))

;;; Finding them -------------------------------------------------------------------

(defvar hellmacs-jdk-roots nil
  "Directories holding one JDK per subdirectory, searched by `bin/hellmacs sync'.
nil searches `hellmacs-jdk-default-roots'.")

(defvar hellmacs-jdk-file (expand-file-name "jvm/jdks.eld" hellmacs-data-dir)
  "Where `bin/hellmacs sync' stores the JDKs it found.")

;;;###autoload
(defun hellmacs-jdk-default-roots ()
  "Where JDK installers put JDKs, following their own variables when set."
  (let ((env (lambda (var default)
               (let ((value (getenv var)))
                 (expand-file-name (if (and value (not (string-empty-p value))) value default))))))
    (list (expand-file-name "candidates/java" (funcall env "SDKMAN_DIR" "~/.sdkman"))
          "/usr/lib/jvm"
          "/usr/lib64/jvm"
          "/Library/Java/JavaVirtualMachines"
          (expand-file-name "~/Library/Java/JavaVirtualMachines")
          (expand-file-name "installs/java" (funcall env "ASDF_DATA_DIR" "~/.asdf"))
          (expand-file-name "versions" (funcall env "JENV_ROOT" "~/.jenv"))
          (expand-file-name "installs/java" (funcall env "MISE_DATA_DIR" "~/.local/share/mise")))))

(defun hellmacs-jdk--homes (root)
  "The JDK homes directly under ROOT; macOS keeps a JDK's in Contents/Home."
  (when (file-directory-p root)
    (cl-loop for dir in (directory-files root t directory-files-no-dot-files-regexp)
             for mac = (expand-file-name "Contents/Home" dir)
             when (file-directory-p dir)
             collect (if (file-directory-p mac) mac dir))))

(defun hellmacs-jdk--collect (homes)
  "(NAME . HOME) for each JDK among HOMES: the first one per release, sorted.
A link is recorded as where it leads, and counts once with it."
  (let ((seen-names nil) (seen-dirs nil) found)
    (dolist (home homes)
      (let ((true (file-truename (directory-file-name home))))
        (unless (member true seen-dirs)
          (push true seen-dirs)
          (when-let* ((name (hellmacs-jdk-home-release home)))
            (unless (member name seen-names)
              (push name seen-names)
              (push (cons name (if (file-symlink-p (directory-file-name home))
                                   true
                                 (directory-file-name home)))
                    found))))))
    (sort (nreverse found)
          (lambda (a b) (< (hellmacs-jdk--name-major (car a)) (hellmacs-jdk--name-major (car b)))))))

;;;###autoload
(defun hellmacs-jdk-scan-roots (roots)
  "The JDKs in ROOTS (each holding JDKs), as (NAME . HOME), one per release."
  (hellmacs-jdk--collect (mapcan #'hellmacs-jdk--homes roots)))

(defun hellmacs-jdk--path-home ()
  "The JDK home of the java on the PATH, or nil."
  (when-let* ((java (executable-find "java")))
    (file-name-directory (directory-file-name (file-name-directory (file-truename java))))))

;;;###autoload
(defun hellmacs-jdk-detect ()
  "Every JDK on this machine, as (NAME . HOME) sorted by release.
JAVA_HOME's comes first for its release, then the PATH's java, then
those in `hellmacs-jdk-roots'."
  (hellmacs-jdk--collect
   (append (delq nil (list (let ((home (getenv "JAVA_HOME")))
                             (and home (not (string-empty-p home)) (expand-file-name home)))
                           (hellmacs-jdk--path-home)))
           (mapcan #'hellmacs-jdk--homes (or hellmacs-jdk-roots (hellmacs-jdk-default-roots))))))

;;; What sync found ------------------------------------------------------------

;;;###autoload
(defun hellmacs-jdk-write (jdks)
  "Store JDKS, as found by `hellmacs-jdk-detect', in `hellmacs-jdk-file'."
  (make-directory (file-name-directory hellmacs-jdk-file) t)
  (with-temp-file hellmacs-jdk-file
    (insert ";; -*- mode: lisp-data -*-\n;; The JDKs `bin/hellmacs sync' found; don't edit.\n")
    (let ((print-length nil) (print-level nil))
      (prin1 jdks (current-buffer)))
    (insert "\n")))

;;;###autoload
(defun hellmacs-jdk-read ()
  "The JDKs stored by the last sync, or nil."
  (when (file-readable-p hellmacs-jdk-file)
    (with-temp-buffer
      (insert-file-contents hellmacs-jdk-file)
      (let ((data (ignore-errors (read (current-buffer)))))
        (and (listp data) (seq-every-p #'consp data) data)))))

;;;###autoload
(defun hellmacs-jdk-lsp-runtimes (jdks default-home)
  "JDKS as `lsp-java-configuration-runtimes': a vector of (:name :path :default).
The JDK in DEFAULT-HOME is the default (for projects that name no
release); without one among JDKS, the newest is."
  (let* ((norm (lambda (dir) (and dir (directory-file-name (expand-file-name dir)))))
         (default (or (seq-find (lambda (jdk) (equal (funcall norm (cdr jdk)) (funcall norm default-home)))
                                jdks)
                      (car (last jdks)))))
    (vconcat (mapcar (lambda (jdk)
                       (list :name (car jdk) :path (cdr jdk)
                             :default (if (eq jdk default) t :json-false)))
                     jdks))))

;;; What builds ask for -------------------------------------------------------------

;;;###autoload
(defun hellmacs-jdk-parse-toolchains-xml (file)
  "The releases Maven's toolchains.xml FILE provides JDKs for, or nil.
A version range (\"[11,)\") names its lower bound."
  (when (file-readable-p file)
    (require 'xml)
    (let ((root (car (ignore-errors (xml-parse-file file))))
          releases)
      (dolist (toolchain (and root (xml-get-children root 'toolchain)))
        (let* ((type (car (xml-node-children (car (xml-get-children toolchain 'type)))))
               (provides (car (xml-get-children toolchain 'provides)))
               (version (car (xml-node-children (car (xml-get-children provides 'version))))))
          (when (and (stringp type) (equal (string-trim type) "jdk") (stringp version)
                     (string-match "[0-9][0-9.]*" version))
            (when-let* ((name (hellmacs-jdk-release-name (match-string 0 version))))
              (cl-pushnew name releases :test #'equal)))))
      (nreverse releases))))

;;;###autoload
(defun hellmacs-jdk-parse-gradle-toolchain (content)
  "The release a Gradle build script's CONTENT asks its toolchain for, or nil."
  (when (string-match "JavaLanguageVersion\\.of(\\s-*\\([0-9]+\\)\\s-*)" content)
    (hellmacs-jdk-release-name (match-string 1 content))))

(provide 'hellmacs-jdk)
;;; hellmacs-jdk.el ends here
