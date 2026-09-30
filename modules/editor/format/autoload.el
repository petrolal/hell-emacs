;;; editor/format/autoload.el -*- lexical-binding: t; -*-

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


;; Formatting with each language's own formatter, through apheleia:
;; google-java-format (Java) and ktfmt (Kotlin) from pinned jars, cljfmt
;; through clojure-lsp (Clojure). XML, YAML and JSON use their language
;; server's formatter. A Java project that commits an Eclipse formatter
;; profile (Phase 12.8) is formatted with it, by JDTLS, as Eclipse and
;; IntelliJ users of the same project do.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(hellmacs-module-load "+paths")

(defvar apheleia-formatter)
(defvar lsp-mode)
(defvar lsp-java-format-settings-url)
(defvar lsp-java-format-settings-profile)
(defvar hellmacs-clojure-lsp-executable)
(declare-function apheleia-format-buffer "apheleia")
(declare-function apheleia-mode "apheleia")
(declare-function lsp-format-buffer "lsp-mode")
(declare-function lsp-feature? "lsp-mode")
(declare-function eglot-managed-p "eglot")
(declare-function project-root "project")
(declare-function hellmacs-jdk-home-major "hellmacs-jdk")
(declare-function hellmacs-jdk-java-executable "hellmacs-jdk")
(declare-function xml-parse-region "xml")
(declare-function xml-get-children "xml")
(declare-function xml-get-attribute-or-nil "xml")
(declare-function xml-node-name "xml")

(defvar hellmacs-format-ktfmt-style "--kotlinlang-style"
  "ktfmt's style: \"--kotlinlang-style\" (the Kotlin conventions, IntelliJ's
default), \"--google-style\" or \"--meta-style\" (ktfmt's own default).")

(defvar hellmacs-format-java-formatter 'google-java-format
  "Java's formatter: `google-java-format', or `jdtls' for JDTLS's (Eclipse's).
A project that commits an Eclipse formatter profile uses JDTLS anyway.")

(defconst hellmacs-format-mode-alist
  '((java-mode . google-java-format) (java-ts-mode . google-java-format)
    (kotlin-mode . ktfmt) (kotlin-ts-mode . ktfmt)
    (clojure-mode . cljfmt) (clojure-ts-mode . cljfmt))
  "Major modes with a pinned formatter, and the formatter (modes derived from
these too: `clojurescript-mode' is a `clojure-mode').")

;;;###autoload
(defun hellmacs-format-for-mode (mode)
  "The pinned formatter for major MODE, or nil if its language server formats it."
  (cdr (seq-find (lambda (entry) (provided-mode-derived-p mode (car entry)))
                 hellmacs-format-mode-alist)))

;;; Running them -----------------------------------------------------------------

(defun hellmacs-format--jar-command (name)
  "The command running formatter NAME's pinned jar, on a JDK new enough for it."
  (let ((spec (hellmacs-format-jar-spec name)))
    (list (hellmacs-jdk-java-executable (plist-get spec :jdk)) "-jar" (plist-get spec :file))))

(defun hellmacs-format--clojure-lsp ()
  "clojure-lsp: the PATH's, else the one :lang clojure pins."
  (or (executable-find "clojure-lsp")
      (and (boundp 'hellmacs-clojure-lsp-executable)
           (file-executable-p hellmacs-clojure-lsp-executable)
           hellmacs-clojure-lsp-executable)
      "clojure-lsp"))

(defconst hellmacs-format--build-files
  '("mvnw" "gradlew" "pom.xml" "settings.gradle" "settings.gradle.kts" "build.gradle"
    "build.gradle.kts" "deps.edn" "project.clj" "bb.edn" "shadow-cljs.edn")
  "Files marking a build's (a project's) root.")

(defun hellmacs-format--root ()
  "The project around `default-directory': its VCS root, else its outermost build."
  (expand-file-name
   (or (when-let* ((project (project-current nil default-directory))) (project-root project))
       (let ((dir default-directory) top)
         (while dir
           (when (seq-some (lambda (f) (file-exists-p (expand-file-name f dir))) hellmacs-format--build-files)
             (setq top dir))
           (let ((parent (file-name-directory (directory-file-name dir))))
             (setq dir (and parent (not (equal parent dir)) parent))))
         top)
       default-directory)))

;;;###autoload
(defun hellmacs-format-apheleia-formatters ()
  "The formatters for `apheleia-formatters': (NAME . COMMAND).
Lisp forms in COMMAND are evaluated per run, so each run finds its JDK
and project."
  '((google-java-format . ((hellmacs-format--jar-command 'google-java-format) "-"))
    (ktfmt . ((hellmacs-format--jar-command 'ktfmt) hellmacs-format-ktfmt-style "-"))
    ;; clojure-lsp can't read stdin: it formats a copy in place, with the
    ;; project's .cljfmt.edn.
    (cljfmt . ((hellmacs-format--clojure-lsp) "format" "--project-root" (hellmacs-format--root)
               "--filenames" inplace "--raw"))))

;;; Eclipse formatter profiles (Phase 12.8) ---------------------------------------

;;;###autoload
(defun hellmacs-format-parse-eclipse-profile (xml)
  "The first formatter profile in XML (an Eclipse/IntelliJ export), or nil.
A plist: :name, :settings (an alist of id -> value), and the common ones
as :tab-char, :tab-size and :line-split."
  (require 'xml)
  (let* ((root (with-temp-buffer
                 (insert xml)
                 (car (ignore-errors (xml-parse-region (point-min) (point-max))))))
         (profile (and (consp root) (eq (xml-node-name root) 'profiles)
                       (seq-find (lambda (p) (equal (xml-get-attribute-or-nil p 'kind) "CodeFormatterProfile"))
                                 (xml-get-children root 'profile)))))
    (when profile
      (let* ((settings (mapcar (lambda (s) (cons (xml-get-attribute-or-nil s 'id)
                                                 (xml-get-attribute-or-nil s 'value)))
                               (xml-get-children profile 'setting)))
             (get (lambda (key) (cdr (assoc (concat "org.eclipse.jdt.core.formatter." key) settings))))
             (number (lambda (key) (let ((v (funcall get key))) (and v (string-to-number v))))))
        (list :name (xml-get-attribute-or-nil profile 'name)
              :settings settings
              :tab-char (funcall get "tabulation.char")
              :tab-size (funcall number "tabulation.size")
              :line-split (funcall number "lineSplit"))))))

(defconst hellmacs-format--profile-dirs '("" "config/" ".settings/" "etc/" "codestyle/" "build-config/")
  "Where, under a project's root, teams keep their Eclipse formatter profile.")

;;;###autoload
(defun hellmacs-format-eclipse-profile-file (root)
  "The Eclipse formatter profile committed in the project at ROOT, or nil.
Returns (FILE . PROFILE-NAME)."
  (cl-loop for dir in hellmacs-format--profile-dirs
           for path = (expand-file-name dir root)
           thereis (and (file-directory-p path)
                        (cl-loop for file in (directory-files path t "\\.xml\\'")
                                 for attributes = (file-attributes file)
                                 thereis (and (file-regular-p file)
                                              (< (file-attribute-size attributes) 1000000)
                                              (let ((text (with-temp-buffer (insert-file-contents file) (buffer-string))))
                                                (and (string-search "CodeFormatterProfile" text)
                                                     (when-let* ((profile (hellmacs-format-parse-eclipse-profile text)))
                                                       (cons file (plist-get profile :name))))))))))

(defvar hellmacs-format--project-profiles (make-hash-table :test #'equal)
  "Project root -> (STAMP . PROFILE): its Eclipse profile, (FILE . NAME) or nil.
STAMP is the modification times of the directories a profile may be in,
and of the profile: the lookup reads every XML file there, once per
project until one of them changes. Kept for the last
`hellmacs-format-profile-cache-limit' projects.")

(defvar hellmacs-format-profile-cache-limit 16
  "How many projects' Eclipse profile lookups are remembered.")

(defvar hellmacs-format--profile-roots nil
  "The roots in `hellmacs-format--project-profiles', most recently used first.")

(defun hellmacs-format--profile-stamp (root profile)
  "What changes when ROOT's Eclipse profile may have: see `hellmacs-format--project-profiles'."
  (mapcar (lambda (file) (file-attribute-modification-time (file-attributes file)))
          (append (mapcar (lambda (dir) (expand-file-name dir root)) hellmacs-format--profile-dirs)
                  (and profile (list (car profile))))))

(defun hellmacs-format--eclipse-profile ()
  "The Eclipse profile of the project around `default-directory', (FILE . NAME) or nil."
  (let* ((root (hellmacs-format--root))
         (cached (gethash root hellmacs-format--project-profiles)))
    (setq hellmacs-format--profile-roots (cons root (delete root hellmacs-format--profile-roots)))
    (dolist (gone (nthcdr hellmacs-format-profile-cache-limit hellmacs-format--profile-roots))
      (remhash gone hellmacs-format--project-profiles))
    (setq hellmacs-format--profile-roots
          (seq-take hellmacs-format--profile-roots hellmacs-format-profile-cache-limit))
    (if (and cached (equal (car cached) (hellmacs-format--profile-stamp root (cdr cached))))
        (cdr cached)
      (let ((profile (hellmacs-format-eclipse-profile-file root)))
        (puthash root (cons (hellmacs-format--profile-stamp root profile) profile)
                 hellmacs-format--project-profiles)
        profile))))

(defun hellmacs-format--file-uri (file)
  "FILE (absolute) as a file: URI; a Windows path gets the slash before its drive."
  (concat "file://" (unless (string-prefix-p "/" file) "/") file))

;;;###autoload
(defun hellmacs-format--java-profile-h ()
  "Have JDTLS format with the project's Eclipse profile, if it commits one.
For Java buffers, before JDTLS starts (it reads the setting then). A
project without one clears the setting, so another project's profile
isn't used for it."
  (let ((profile (hellmacs-format--eclipse-profile)))
    (setq lsp-java-format-settings-url (and profile (hellmacs-format--file-uri (car profile)))
          lsp-java-format-settings-profile (cdr profile))))

;;; Commands ---------------------------------------------------------------------

(defun hellmacs-format--formatter ()
  "The pinned formatter for this buffer, or nil to use the language server's."
  (let ((formatter (hellmacs-format-for-mode major-mode)))
    (if (and (eq formatter 'google-java-format)
             (or (eq hellmacs-format-java-formatter 'jdtls) (hellmacs-format--eclipse-profile)))
        nil
      formatter)))

;;;###autoload
(defun hellmacs-format-buffer ()
  "Format the buffer with its language's formatter, else its language server's.
On lsp-mode's own format keys (`C-c l = =') in buffers with a pinned formatter,
and eglot's command: the server's is eglot's where eglot manages the buffer."
  (interactive)
  (if-let* ((formatter (hellmacs-format--formatter)))
      (progn (unless (fboundp 'apheleia-format-buffer) (require 'apheleia))
             (apheleia-format-buffer formatter))
    (call-interactively (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
                            #'eglot-format-buffer
                          #'lsp-format-buffer))))

(defvar hellmacs-format-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "<remap> <lsp-format-buffer>" #'hellmacs-format-buffer)
    (keymap-set map "<remap> <eglot-format-buffer>" #'hellmacs-format-buffer)
    map)
  "Remaps only: the format commands you already have run the pinned formatter.")

;;;###autoload
(define-minor-mode hellmacs-format-mode
  "Format this buffer with its language's own formatter on the usual format keys."
  :keymap hellmacs-format-mode-map)

(defun hellmacs-format--lsp-before-save-h ()
  "Format with the language server before saving, when it can."
  (when (and (bound-and-true-p lsp-mode) (lsp-feature? "textDocument/formatting"))
    (lsp-format-buffer)))

;;;###autoload
(defun hellmacs-format--onsave-h ()
  "+onsave: format this buffer each time it's saved.
With apheleia where a formatter is pinned (after saving, asynchronously),
else with the language server (before saving)."
  (if-let* ((formatter (hellmacs-format--formatter)))
      (progn (setq-local apheleia-formatter formatter)
             (apheleia-mode 1))
    (add-hook 'before-save-hook #'hellmacs-format--lsp-before-save-h nil t)))

;;; editor/format/autoload.el ends here
