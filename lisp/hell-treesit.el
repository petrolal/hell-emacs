;;; hell-treesit.el --- Pinned tree-sitter grammars -*- lexical-binding: t; -*-

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

;; Modules that offer a `+tree-sitter' flag (`:lang java', `:lang kotlin',
;; `:lang clojure') need a compiled grammar per language. Emacs can build
;; them itself (`treesit-install-language-grammar'), but it prompts, puts
;; them under `user-emacs-directory', and follows a branch or tag that can
;; move. This does the same job the Hell Emacs way:
;;
;;   - Each grammar is pinned to one commit, fetched by its hash (the tag
;;     or branch it came from is only a label); anything else is refused.
;;   - Grammars are built by `bin/hell sync' (never at startup) into
;;     `hell-treesit-dir' under the data directory, and found through
;;     `treesit-extra-load-path'.
;;   - A module declares its grammars (with their pins) and the modes they
;;     enable with `hell-treesit!', in its packages.el under its
;;     `+tree-sitter' flag. From that one declaration, sync builds them,
;;     doctor checks them, and startup remaps the modes -- or, until they
;;     are built, warns instead, so a file never opens in a broken mode.
;;
;; Building needs git and a C compiler (and a C++ one for grammars with a
;; C++ scanner); `bin/hell doctor' checks for them.

;;; Code:

(require 'cl-lib)
(require 'hell-lib)
(require 'hell-core)
(eval-and-compile (hell-require 'hell-lib 'net))

(defcustom hell-treesit-sources nil
  "Grammar sources you pin yourself, over the modules' own.
A list of \(LANGUAGE URL LABEL COMMIT [DIRECTORY] :license SPDX), as in
`hell-treesit!'. Set it in your init.el to pin a different release."
  :type '(repeat sexp)
  :group 'hell)

(defvar hell-treesit-declarations nil
  "Alist: module key -> (:grammars GRAMMARS :remap REMAP), from `hell-treesit!'.
Filled in as packages.el files are read, and restored from the synced
profile otherwise.")

(defvar hell--current-module)       ; hell-modules.el

(defvar hell-treesit-dir (expand-file-name "treesit/" hell-data-dir)
  "Where compiled grammars live (data: reinstallable, but needed to run).")

(defvar treesit-extra-load-path)

;; Emacs finds grammars here from now on, whether or not any is installed.
(when (fboundp 'treesit-available-p)
  (add-to-list 'treesit-extra-load-path hell-treesit-dir))

;; Emacs 31's tree-sitter modes offer to download a missing grammar
;; (`treesit-ensure-installed'), unpinned and mid-session; `bin/hell sync'
;; builds the pinned ones instead. Navigation (`C-M-a', `C-M-e', `C-M-f')
;; is Emacs' own in every `*-ts-mode' (`treesit-major-mode-setup').
(defvar treesit-auto-install-grammar)
(setq treesit-auto-install-grammar 'never)

(defmacro hell-treesit! (&rest args)
  "Declare this module's tree-sitter grammars and the modes they enable.
ARGS is a plist of :grammars and :remap. Use it in the module's
packages.el, under its +tree-sitter flag:

  (when (modulep! +tree-sitter)
    (hell-treesit!
     :grammars ((kotlin \"https://github.com/fwcd/tree-sitter-kotlin\"
                        \"v0.3.8\" \"<the tag's full commit>\"))
     :remap ((kotlin-mode . kotlin-ts-mode))))

Each grammar is (LANGUAGE URL LABEL COMMIT [DIRECTORY] :license SPDX):
COMMIT is what gets fetched, LABEL only says what it is (a release tag,
or a branch and date), DIRECTORY is the subdirectory holding src/ when
the grammar isn't at the top of the repository, and SPDX the grammar's
license, for the SBOM and license report. `bin/hell sync' builds them and
`bin/hell doctor' checks them. At startup, each (MODE . TS-MODE) in
:remap goes into `major-mode-remap-alist' once every grammar is built;
until then a warning says to sync."
  `(hell-treesit-declare ',(plist-get args :grammars) ',(plist-get args :remap)))

(defun hell-treesit-declare (grammars remap)
  "Record the current module's GRAMMARS and REMAP. See `hell-treesit!'."
  (let ((key (or (bound-and-true-p hell--current-module)
                 (error "`hell-treesit!': not inside a module's packages.el"))))
    (setf (alist-get key hell-treesit-declarations nil nil #'equal)
          (list :grammars grammars :remap remap))))

(defun hell-treesit-module-languages (key)
  "The languages module KEY declared grammars for."
  (mapcar #'car (plist-get (alist-get key hell-treesit-declarations nil nil #'equal) :grammars)))

(defun hell-treesit-wanted ()
  "Every language the enabled modules declared a grammar for, in order."
  (seq-uniq (mapcan (lambda (decl) (mapcar #'car (plist-get (cdr decl) :grammars)))
                    (reverse hell-treesit-declarations))))

(defun hell-treesit--source (lang)
  "The (URL LABEL COMMIT [DIRECTORY]) for LANG, or an error if it isn't known.
Yours (`hell-treesit-sources') first, then the modules'."
  (or (cdr (assq lang hell-treesit-sources))
      (seq-some (lambda (decl) (cdr (assq lang (plist-get (cdr decl) :grammars))))
                hell-treesit-declarations)
      (error "No tree-sitter grammar source for `%s'; see `hell-treesit!'" lang)))

(defun hell-treesit-source-license (lang)
  "The license LANG's grammar source declares with :license, or nil."
  (cadr (memq :license (hell-treesit--source lang))))

(defun hell-treesit-apply ()
  "Remap each module's modes to their tree-sitter ones, if its grammars are built.
Otherwise warn, and leave the module on its classic modes: without its
grammar, a tree-sitter mode fails on every file. Run at startup."
  (pcase-dolist (`(,key . ,decl) hell-treesit-declarations)
    (let ((missing (seq-remove #'hell-treesit-current-p
                               (mapcar #'car (plist-get decl :grammars)))))
      (if missing
          (display-warning
           'hell
           (format "Module %s: the tree-sitter %s grammar%s built yet; run `bin/hell sync'"
                   (hell-module-key-string key) (mapconcat #'symbol-name missing ", ")
                   (if (cdr missing) "s aren't" " isn't")))
        (dolist (remap (plist-get decl :remap))
          (add-to-list 'major-mode-remap-alist remap))))))

(defun hell-treesit-library (lang)
  "The path of LANG's compiled grammar."
  (expand-file-name (format "libtree-sitter-%s%s" lang (car dynamic-library-suffixes))
                    hell-treesit-dir))

(defun hell-treesit--marker (lang)
  "The file recording the commit LANG's grammar was built from."
  (concat (hell-treesit-library lang) ".commit"))

(defun hell-treesit-current-p (lang)
  "Non-nil if LANG's library exists and was built from the pinned commit.
A library left by an older pin (or by Emacs' own installer) isn't current."
  (and (file-exists-p (hell-treesit-library lang))
       (hell-marker-current-p (hell-treesit--marker lang)
                              (nth 2 (hell-treesit--source lang)))))

(defun hell-treesit-installed-p (lang)
  "Non-nil if LANG's grammar is built from the pinned commit and loads."
  (and (hell-treesit-current-p lang)
       (fboundp 'treesit-language-available-p)
       (treesit-language-available-p lang)))

(defun hell-treesit--run (dir program &rest args)
  "Run PROGRAM with ARGS in DIR; return its output, or signal an error."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory dir)))
      (unless (zerop (apply #'call-process program nil t nil args))
        (error "`%s %s' failed: %s" program (string-join args " ")
               (string-trim (buffer-string))))
      (string-trim (buffer-string)))))

(defun hell-treesit--compiler (&rest names)
  "The first of NAMES found on the PATH, or an error."
  (or (seq-some #'executable-find names)
      (error "No C compiler found (looked for %s); grammars are built from C sources"
             (string-join names ", "))))

(defun hell-treesit--build (src out)
  "Compile the grammar in SRC's src/ directory into the library OUT."
  (let* ((srcdir (expand-file-name "src/" src))
         (cc (hell-treesit--compiler "cc" "gcc" "clang"))
         (c++ (seq-some #'executable-find '("c++" "g++" "clang++")))
         (cpp-scanner (file-exists-p (expand-file-name "scanner.cc" srcdir)))
         (objects nil))
    (unless (file-exists-p (expand-file-name "parser.c" srcdir))
      (error "%s has no src/parser.c" src))
    (dolist (file '("parser.c" "scanner.c" "scanner.cc"))
      (when (file-exists-p (expand-file-name file srcdir))
        (let ((obj (concat file ".o")))
          (hell-treesit--run srcdir (if (string-suffix-p ".cc" file)
                                            (or c++ (error "A C++ compiler is needed for %s" file))
                                      cc)
                             "-fPIC" "-O2" "-I." "-c" file "-o" obj)
          (push obj objects))))
    (make-directory (file-name-directory out) t)
    (let ((tmp (concat out ".part")))
      (apply #'hell-treesit--run srcdir (if cpp-scanner c++ cc)
             "-shared" "-o" tmp (nreverse objects))
      (rename-file tmp out t))))

(defun hell-treesit-install (lang)
  "Build LANG's pinned grammar into `hell-treesit-dir'.
Fetches exactly the pinned commit (refusing anything else), compiles it
in a temporary directory, and only then puts the library in place."
  (pcase-let* ((`(,url ,_label ,commit ,directory) (hell-treesit--source lang))
               (directory (and (stringp directory) directory)) ; not :license
               (tmp (make-temp-file "hell-treesit" t)))
    (unless (executable-find "git") (error "Git is needed to fetch tree-sitter grammars"))
    (with-hell-network               ; the proxy, CA and mirrors, for git
      (unwind-protect
          (let ((src (expand-file-name (format "tree-sitter-%s" lang) tmp)))
            (make-directory src t)
            (hell-treesit--run src "git" "init" "--quiet")
            (hell-treesit--run src "git" "remote" "add" "origin" url)
            (hell-treesit--run src "git" "fetch" "--quiet" "--depth" "1" "origin" commit)
            (hell-treesit--run src "git" "checkout" "--quiet" "FETCH_HEAD")
            (let ((head (hell-treesit--run src "git" "rev-parse" "HEAD")))
              (unless (equal head commit)
                (error "Grammar `%s' fetched %s, not the pinned %s; not installed" lang head commit)))
            (hell-treesit--build (if directory (expand-file-name directory src) src)
                                 (hell-treesit-library lang))
            ;; Written last: without it the library isn't taken for current.
            (hell-marker-write (hell-treesit--marker lang) commit))
        (delete-directory tmp t)))))

(defun hell-treesit-ensure (lang)
  "Make sure LANG's grammar is installed, building it if it isn't.
Returns non-nil when it is available afterwards."
  (unless (hell-treesit-current-p lang)
    (hell-treesit-install lang))
  (hell-treesit-installed-p lang))

(declare-function hell-sync--log "cli/sync")

(defun hell-treesit-sync ()
  "Build the grammars the enabled modules asked for. For `hell-sync-functions'."
  (dolist (lang (hell-treesit-wanted))
    (if (hell-treesit-installed-p lang)
        (hell-sync--log "tree-sitter %s grammar is installed" lang)
      (hell-sync--log "Building the tree-sitter %s grammar..." lang)
      ;; One grammar failing (no C compiler, say) doesn't stop the rest of
      ;; the sync: its files still open in their mode, without highlighting,
      ;; until a later sync builds it; `bin/hell doctor' says why.
      (condition-case err
          (progn
            (unless (hell-treesit-ensure lang)
              (error "The %s grammar was built but Emacs can't load it (%s)"
                     lang (abbreviate-file-name (hell-treesit-library lang))))
            (hell-sync--log "tree-sitter %s grammar installed (commit pinned)" lang))
        (error
         (hell-sync--log "Warning: the tree-sitter %s grammar wasn't built: %s; its files open without highlighting until `bin/hell sync' builds it (`bin/hell doctor' says what's missing)"
                         lang (error-message-string err)))))))

(provide 'hell-treesit)
;;; hell-treesit.el ends here
