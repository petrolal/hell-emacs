;;; editor/format/autoload.el -*- lexical-binding: t; -*-

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


;; Formatting with each language's own formatter, through apheleia:
;; google-java-format (Java) and ktfmt (Kotlin) from pinned jars, cljfmt
;; through clojure-lsp (Clojure). XML, YAML and JSON use their language
;; server's formatter. A Java project that commits an Eclipse formatter
;; profile (Phase 12.8) is formatted with it, by JDTLS, as Eclipse and
;; IntelliJ users of the same project do.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(hell-module-load "+paths")

(defvar apheleia-formatter)
(defvar lsp-mode)
(defvar lsp-java-format-settings-url)
(defvar lsp-java-format-settings-profile)
(defvar hell-clojure-lsp-executable)
(declare-function apheleia-format-buffer "apheleia")
(declare-function apheleia-mode "apheleia")
(declare-function lsp-format-buffer "lsp-mode")
(declare-function lsp-feature? "lsp-mode")
(declare-function eglot-managed-p "eglot")
(declare-function project-root "project")
(declare-function hell-jdk-home-major "../../../lisp/lib/jdk")
(declare-function hell-jdk-java-executable "../../../lisp/lib/jdk")
(declare-function xml-parse-region "xml")
(declare-function xml-get-children "xml")
(declare-function xml-get-attribute-or-nil "xml")
(declare-function xml-node-name "xml")

(defvar hell-format-ktfmt-style "--kotlinlang-style"
  "ktfmt's style: \"--kotlinlang-style\" (the Kotlin conventions, IntelliJ's
default), \"--google-style\" or \"--meta-style\" (ktfmt's own default).")

(defvar hell-format-java-formatter 'google-java-format
  "Java's formatter: `google-java-format', or `jdtls' for JDTLS's (Eclipse's).
A project that commits an Eclipse formatter profile uses JDTLS anyway.")

(defconst hell-format-mode-alist
  '((java-mode . google-java-format) (java-ts-mode . google-java-format)
    (kotlin-mode . ktfmt) (kotlin-ts-mode . ktfmt)
    (clojure-mode . cljfmt) (clojure-ts-mode . cljfmt))
  "Major modes with a pinned formatter, and the formatter (modes derived from
these too: `clojurescript-mode' is a `clojure-mode').")

;;;###autoload
(defun hell-format-for-mode (mode)
  "The pinned formatter for major MODE, or nil if its language server formats it."
  (cdr (seq-find (lambda (entry) (provided-mode-derived-p mode (car entry)))
                 hell-format-mode-alist)))

;;; Running them -----------------------------------------------------------------

(defun hell-format--jar-command (name)
  "The command running formatter NAME's pinned jar, on a JDK new enough for it."
  (let ((spec (hell-format-jar-spec name)))
    (list (hell-jdk-java-executable (plist-get spec :jdk)) "-jar" (plist-get spec :file))))

(defun hell-format--clojure-lsp ()
  "clojure-lsp: the PATH's, else the one :lang clojure pins."
  (or (executable-find "clojure-lsp")
      (and (boundp 'hell-clojure-lsp-executable)
           (file-executable-p hell-clojure-lsp-executable)
           hell-clojure-lsp-executable)
      "clojure-lsp"))

(defconst hell-format--build-files
  '("mvnw" "gradlew" "pom.xml" "settings.gradle" "settings.gradle.kts" "build.gradle"
    "build.gradle.kts" "deps.edn" "project.clj" "bb.edn" "shadow-cljs.edn")
  "Files marking a build's (a project's) root.")

(defun hell-format--root ()
  "The project around `default-directory': its VCS root, else its outermost build."
  (expand-file-name
   (or (when-let* ((project (project-current nil default-directory))) (project-root project))
       (let ((dir default-directory) top)
         (while dir
           (when (seq-some (lambda (f) (file-exists-p (expand-file-name f dir))) hell-format--build-files)
             (setq top dir))
           (let ((parent (file-name-directory (directory-file-name dir))))
             (setq dir (and parent (not (equal parent dir)) parent))))
         top)
       default-directory)))

;;;###autoload
(defun hell-format-apheleia-formatters ()
  "The formatters for `apheleia-formatters': (NAME . COMMAND).
Lisp forms in COMMAND are evaluated per run, so each run finds its JDK
and project."
  '((google-java-format . ((hell-format--jar-command 'google-java-format) "-"))
    (ktfmt . ((hell-format--jar-command 'ktfmt) hell-format-ktfmt-style "-"))
    ;; clojure-lsp can't read stdin: it formats a copy in place, with the
    ;; project's .cljfmt.edn.
    (cljfmt . ((hell-format--clojure-lsp) "format" "--project-root" (hell-format--root)
               "--filenames" inplace "--raw"))))

;;; Eclipse formatter profiles (Phase 12.8) ---------------------------------------

;;;###autoload
(defun hell-format-parse-eclipse-profile (xml)
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

(defconst hell-format--profile-dirs '("" "config/" ".settings/" "etc/" "codestyle/" "build-config/")
  "Where, under a project's root, teams keep their Eclipse formatter profile.")

;;;###autoload
(defun hell-format-eclipse-profile-file (root)
  "The Eclipse formatter profile committed in the project at ROOT, or nil.
Returns (FILE . PROFILE-NAME)."
  (cl-loop for dir in hell-format--profile-dirs
           for path = (expand-file-name dir root)
           thereis (and (file-directory-p path)
                        (cl-loop for file in (directory-files path t "\\.xml\\'")
                                 for attributes = (file-attributes file)
                                 thereis (and (file-regular-p file)
                                              (< (file-attribute-size attributes) 1000000)
                                              (let ((text (with-temp-buffer (insert-file-contents file) (buffer-string))))
                                                (and (string-search "CodeFormatterProfile" text)
                                                     (when-let* ((profile (hell-format-parse-eclipse-profile text)))
                                                       (cons file (plist-get profile :name))))))))))

(defvar hell-format--project-profiles (make-hash-table :test #'equal)
  "Project root -> (STAMP . PROFILE): its Eclipse profile, (FILE . NAME) or nil.
STAMP is the modification times of the directories a profile may be in,
and of the profile: the lookup reads every XML file there, once per
project until one of them changes. Kept for the last
`hell-format-profile-cache-limit' projects.")

(defvar hell-format-profile-cache-limit 16
  "How many projects' Eclipse profile lookups are remembered.")

(defvar hell-format--profile-roots nil
  "The roots in `hell-format--project-profiles', most recently used first.")

(defun hell-format--profile-stamp (root profile)
  "What changes when ROOT's Eclipse profile may have: see `hell-format--project-profiles'."
  (mapcar (lambda (file) (file-attribute-modification-time (file-attributes file)))
          (append (mapcar (lambda (dir) (expand-file-name dir root)) hell-format--profile-dirs)
                  (and profile (list (car profile))))))

(defun hell-format--eclipse-profile ()
  "The Eclipse profile of the project around `default-directory', (FILE . NAME) or nil."
  (let* ((root (hell-format--root))
         (cached (gethash root hell-format--project-profiles)))
    (setq hell-format--profile-roots (cons root (delete root hell-format--profile-roots)))
    (dolist (gone (nthcdr hell-format-profile-cache-limit hell-format--profile-roots))
      (remhash gone hell-format--project-profiles))
    (setq hell-format--profile-roots
          (seq-take hell-format--profile-roots hell-format-profile-cache-limit))
    (if (and cached (equal (car cached) (hell-format--profile-stamp root (cdr cached))))
        (cdr cached)
      (let ((profile (hell-format-eclipse-profile-file root)))
        (puthash root (cons (hell-format--profile-stamp root profile) profile)
                 hell-format--project-profiles)
        profile))))

(defun hell-format--file-uri (file)
  "FILE (absolute) as a file: URI; a Windows path gets the slash before its drive."
  (concat "file://" (unless (string-prefix-p "/" file) "/") file))

;;;###autoload
(defun hell-format--java-profile-h ()
  "Have JDTLS format with the project's Eclipse profile, if it commits one.
For Java buffers, before JDTLS starts (it reads the setting then). A
project without one clears the setting, so another project's profile
isn't used for it."
  (let ((profile (hell-format--eclipse-profile)))
    (setq lsp-java-format-settings-url (and profile (hell-format--file-uri (car profile)))
          lsp-java-format-settings-profile (cdr profile))))

;;; Commands ---------------------------------------------------------------------

(defun hell-format--formatter ()
  "The pinned formatter for this buffer, or nil to use the language server's."
  (let ((formatter (hell-format-for-mode major-mode)))
    (if (and (eq formatter 'google-java-format)
             (or (eq hell-format-java-formatter 'jdtls) (hell-format--eclipse-profile)))
        nil
      formatter)))

;;;###autoload
(defun hell-format-buffer ()
  "Format the buffer with its language's formatter, else its language server's.
On the format keys (`C-c c f', lsp-mode's `s-l = =') and eglot's
command, in buffers with a pinned formatter: the server's is eglot's
where eglot manages the buffer."
  (interactive)
  (if-let* ((formatter (hell-format--formatter)))
      (progn (unless (fboundp 'apheleia-format-buffer) (require 'apheleia))
             (apheleia-format-buffer formatter))
    (call-interactively (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
                            #'eglot-format-buffer
                          #'lsp-format-buffer))))

(defvar hell-format-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "<remap> <lsp-format-buffer>" #'hell-format-buffer)
    (keymap-set map "<remap> <eglot-format-buffer>" #'hell-format-buffer)
    map)
  "Remaps only: the format commands you already have run the pinned formatter.")

;;;###autoload
(define-minor-mode hell-format-mode
  "Format this buffer with its language's own formatter on the usual format keys."
  :keymap hell-format-mode-map)

(defun hell-format--lsp-before-save-h ()
  "Format with the language server before saving, when it can."
  (when (and (bound-and-true-p lsp-mode) (lsp-feature? "textDocument/formatting"))
    (lsp-format-buffer)))

;;;###autoload
(defun hell-format--onsave-h ()
  "+onsave: format this buffer each time it's saved.
With apheleia where a formatter is pinned (after saving, asynchronously),
else with the language server (before saving)."
  (if-let* ((formatter (hell-format--formatter)))
      (progn (setq-local apheleia-formatter formatter)
             (apheleia-mode 1))
    (add-hook 'before-save-hook #'hell-format--lsp-before-save-h nil t)))

;;; editor/format/autoload.el ends here
