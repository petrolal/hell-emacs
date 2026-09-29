;;; hellmacs-compliance.el --- SBOM and license report (Phase 12.9) -*- lexical-binding: t; -*-

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

;;; Commentary:

;; What is installed, for `bin/hellmacs sbom' (a CycloneDX 1.5 bill of
;; materials) and `bin/hellmacs licenses'. It reads the installation
;; itself, not what should be there:
;;
;;   - every Emacs package Elpaca built, at its checkout's commit, with
;;     the license its header (or its LICENSE file) states;
;;   - every download a module declared with `hellmacs-component!' whose
;;     file is in place, with its pin and license; for npm installs, every
;;     package their package-lock.json installed;
;;   - every tree-sitter grammar built from its pinned commit.
;;
;; Nothing is fetched: it works offline, on what a sync left.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'hellmacs-lib)
(require 'hellmacs-core)
(require 'hellmacs-treesit)

(defvar elpaca-builds-directory)
(defvar elpaca-sources-directory)

;;; Licenses -------------------------------------------------------------------

(defconst hellmacs-compliance--license-texts
  '(("Permission is hereby granted, free of charge, to any person" . "MIT")
    ("Apache License[ \t\n]+Version 2\\.0" . "Apache-2.0")
    ("Eclipse Public License[ -]+v\\(?:ersion\\)? ?2\\.0" . "EPL-2.0")
    ("Eclipse Public License[ -]+v\\(?:ersion\\)? ?1\\.0" . "EPL-1.0")
    ("Mozilla Public License,? Version 2\\.0" . "MPL-2.0")
    ("Permission to use, copy, modify, and/or distribute this software for any" . "ISC")
    ("This is free and unencumbered software released into the public domain" . "Unlicense")
    ("CC0 1\\.0 Universal" . "CC0-1.0")
    ;; A comment saying so (restclient): SPDX has no identifier for it.
    ("^;+.*\\<[Pp]ublic domain\\>" . "LicenseRef-PublicDomain"))
  "(REGEXP . SPDX): license texts, as LICENSE files and headers carry them.")

(defun hellmacs-compliance--gnu-license ()
  "The GNU license the current buffer's notice or text states, or nil."
  (let ((case-fold-search nil))
    (goto-char (point-min))
    (cond
     ;; A license file: its title. It can't say "or later" by itself.
     ((re-search-forward "GNU \\(LESSER \\|LIBRARY \\|AFFERO \\)?GENERAL PUBLIC LICENSE[ \t\n]+Version \\([0-9]\\)" nil t)
      (format "%s-%s.0-only" (hellmacs-compliance--gnu-prefix (match-string 1)) (match-string 2)))
     ;; A file's notice: "... GNU General Public License ... version 3 ... any later version".
     ((re-search-forward "GNU \\(Lesser \\|Library \\|Affero \\)?General Public License" nil t)
      (let ((prefix (hellmacs-compliance--gnu-prefix (match-string 1)))
            (start (point)))
        (when (re-search-forward "[Vv]ersion \\([0-9]\\)" (+ start 200) t)
          (let ((version (match-string 1)))
            (format "%s-%s.0-%s" prefix version
                    (if (re-search-forward "any later[ \t\n;#/*]+version" (+ (point) 200) t)
                        "or-later" "only")))))))))

(defun hellmacs-compliance--gnu-prefix (qualifier)
  (pcase (and qualifier (upcase (string-trim qualifier)))
    ((or "LESSER" "LIBRARY") "LGPL") ("AFFERO" "AGPL") (_ "GPL")))

(defun hellmacs-compliance-text-license ()
  "The license the current buffer (a source file or a LICENSE file) states.
An SPDX expression, or nil if none is recognised. In order: an
SPDX-License-Identifier line, a \"License:\" header naming one, a GNU
license's text or notice, then other common license texts."
  (save-excursion
    (let ((case-fold-search nil))
      (goto-char (point-min))
      (or (and (re-search-forward "SPDX-License-Identifier:[ \t]*\\(.+?\\)[ \t]*\\(?:\\*/\\)?$" nil t)
               (match-string-no-properties 1))
          (progn (goto-char (point-min))
                 (and (re-search-forward "^;+[ \t]*License:[ \t]*\\([A-Za-z0-9.+-]+\\)[ \t]*$" nil t)
                      (hellmacs-compliance--normalize (match-string-no-properties 1))))
          (hellmacs-compliance--gnu-license)
          (cl-some (lambda (entry)
                     (goto-char (point-min))
                     (and (re-search-forward (car entry) nil t) (cdr entry)))
                   hellmacs-compliance--license-texts)))))

(defun hellmacs-compliance--normalize (name)
  "NAME, a package header's license, as SPDX; nil if it doesn't look like one."
  (cond ((string-match "\\`\\(L?GPL\\)[-v]?\\([0-9]\\)\\(?:\\.0\\)?\\(\\+\\)?\\'" name)
         (format "%s-%s.0-%s" (match-string 1 name) (match-string 2 name)
                 (if (match-string 3 name) "or-later" "only")))
        ((string-match-p "\\`[A-Za-z][A-Za-z0-9.+]*-[A-Za-z0-9.+-]*[0-9][A-Za-z0-9.+-]*\\'" name) name)
        ((member name '("MIT" "ISC" "Unlicense" "0BSD")) name)))

(defun hellmacs-compliance-file-license (file &optional limit)
  "The license FILE states (see `hellmacs-compliance-text-license'), or nil.
Only its first LIMIT characters are read, if given."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file nil 0 limit)
      (hellmacs-compliance-text-license))))

;;; Emacs packages -------------------------------------------------------------

(defun hellmacs-compliance--git (dir &rest args)
  "The first line git ARGS prints in DIR, or nil."
  ;; Expanded: git doesn't expand the ~/ Emacs abbreviates paths to.
  (ignore-errors (car (apply #'process-lines "git" "-C" (expand-file-name dir) args))))

(defun hellmacs-compliance--vcs-purl (name url commit)
  "A package URL for NAME at COMMIT of the repository at URL."
  (if (and url (string-match "\\`\\(?:https://\\|git@\\)\\(github\\|gitlab\\)\\.com[/:]\\([^/]+\\)/\\(.+?\\)\\(?:\\.git\\)?/?\\'" url))
      (format "pkg:%s/%s/%s@%s" (match-string 1 url) (downcase (match-string 2 url))
              (downcase (match-string 3 url)) commit)
    (format "pkg:generic/%s@%s%s" name commit
            (if url (concat "?vcs_url=" (url-hexify-string url)) ""))))

(defun hellmacs-compliance--package (build)
  "The Emacs package Elpaca built in BUILD, a directory: a component plist."
  (let* ((name (file-name-nondirectory (directory-file-name build)))
         (main (let ((file (expand-file-name (concat name ".el") build)))
                 (if (file-exists-p file) file
                   (car (directory-files build t "\\.el\\'")))))
         (source (and main (file-truename main)))
         (repo (or (and source (locate-dominating-file source ".git"))
                   (let ((dir (expand-file-name name elpaca-sources-directory)))
                     (and (file-directory-p dir) dir))))
         (commit (and repo (hellmacs-compliance--git repo "rev-parse" "HEAD")))
         (url (and repo (hellmacs-compliance--git repo "remote" "get-url" "origin"))))
    (list :kind 'package :type "library" :name name :version commit :commit commit :url url
          :purl (and commit (hellmacs-compliance--vcs-purl name url commit))
          :license (or (and source (hellmacs-compliance-file-license source 20000))
                       (and repo
                            (cl-some #'hellmacs-compliance-file-license
                                     (directory-files repo t "\\`\\(?:LICENSE\\|LICENCE\\|COPYING\\)")))))))

(defun hellmacs-compliance--packages ()
  "Every Emacs package Elpaca built."
  (when-let* ((dir (bound-and-true-p elpaca-builds-directory))
              ((file-directory-p dir)))
    (mapcar #'hellmacs-compliance--package
            (seq-filter #'file-directory-p (directory-files dir t "\\`[^.]")))))

;;; Downloads ------------------------------------------------------------------

(defun hellmacs-compliance--download-purl (url version)
  "A package URL for the download at URL, VERSION of it; nil if there's none."
  (cond ((and url (string-match "/maven2/\\(.+\\)/\\([^/]+\\)/\\([^/]+\\)/[^/]+\\'" url))
         (format "pkg:maven/%s/%s@%s" (replace-regexp-in-string "/" "." (match-string 1 url))
                 (match-string 2 url) (match-string 3 url)))
        ((and url (string-match "\\`https://github\\.com/\\([^/]+\\)/\\([^/]+\\)/releases/download/" url))
         (format "pkg:github/%s/%s@%s" (downcase (match-string 1 url)) (downcase (match-string 2 url))
                 version))))

(defun hellmacs-compliance--integrity-hex (integrity)
  "npm's sha512-BASE64 INTEGRITY as a hex string, or nil."
  (when (and integrity (string-prefix-p "sha512-" integrity))
    (mapconcat (lambda (b) (format "%02x" b))
               (base64-decode-string (substring integrity 7)) "")))

(defun hellmacs-compliance--npm (declared)
  "The npm packages DECLARED's install holds, from its package-lock.json.
DECLARED's own entry takes its license from the declaration if the
lockfile has none."
  (let* ((lock (expand-file-name "package-lock.json" (plist-get declared :path)))
         (json-object-type 'alist) (json-key-type 'string) (json-array-type 'list)
         (packages (and (file-exists-p lock) (alist-get "packages" (json-read-file lock) nil nil #'equal))))
    (delq nil
          (mapcar (lambda (entry)
                    (let* ((key (car entry)) (props (cdr entry))
                           (name (car (last (split-string key "node_modules/"))))
                           (version (alist-get "version" props nil nil #'equal)))
                      (unless (or (string-empty-p key) (alist-get "link" props nil nil #'equal))
                        (list :kind 'npm :type "library" :name name :version version
                              :license (or (let ((l (alist-get "license" props nil nil #'equal)))
                                             (and (stringp l) l))
                                           (and (equal name (plist-get declared :name))
                                                (plist-get declared :license)))
                              :url (alist-get "resolved" props nil nil #'equal)
                              :sha512 (hellmacs-compliance--integrity-hex
                                       (alist-get "integrity" props nil nil #'equal))
                              :purl (format "pkg:npm/%s@%s"
                                            (replace-regexp-in-string "@" "%40" name)
                                            version)))))
                  packages))))

(defun hellmacs-compliance--downloads ()
  "Every declared download that is installed, npm installs expanded."
  (mapcan (lambda (c)
            (when-let* ((path (plist-get c :path))
                        ((file-exists-p path)))
              (let ((npm (and (plist-get c :npm) (hellmacs-compliance--npm c))))
                (append
                 (unless (seq-find (lambda (p) (equal (plist-get p :name) (plist-get c :name))) npm)
                   (list (list :kind 'download :type (or (plist-get c :type) "application")
                               :name (plist-get c :name) :version (plist-get c :version)
                               :license (plist-get c :license) :url (plist-get c :url)
                               :sha256 (plist-get c :sha256)
                               :purl (hellmacs-compliance--download-purl (plist-get c :url)
                                                                          (plist-get c :version)))))
                 npm))))
          (reverse hellmacs-components)))

;;; Grammars -------------------------------------------------------------------

(defun hellmacs-compliance--grammars ()
  "Every tree-sitter grammar built from its pinned commit."
  (delq nil
        (mapcar (lambda (lang)
                  (when (hellmacs-treesit-current-p lang)
                    (pcase-let* ((`(,url ,label ,commit ,directory) (hellmacs-treesit--source lang))
                                 ;; A grammar in a subdirectory is named by it:
                                 ;; tree-sitter-markdown holds two.
                                 (name (file-name-nondirectory
                                        (directory-file-name (if (stringp directory) directory url)))))
                      (list :kind 'grammar :type "library" :name name :version label
                            :commit commit :url url
                            :license (hellmacs-treesit-source-license lang)
                            :purl (hellmacs-compliance--vcs-purl name url commit)))))
                (hellmacs-treesit-wanted))))

;;; Inventory ------------------------------------------------------------------

;;;###autoload
(defun hellmacs-compliance-components ()
  "Everything installed, as component plists.
Each has :kind (`package', `download', `npm' or `grammar'), :name,
:version, :license (nil if unknown), and where known :url, :purl,
:commit, :sha256 and :sha512."
  (seq-uniq (append (hellmacs-compliance--packages)
                    (hellmacs-compliance--downloads)
                    (hellmacs-compliance--grammars))
            ;; An npm package two servers install is one component.
            (lambda (a b) (equal (hellmacs-compliance--ref a) (hellmacs-compliance--ref b)))))

(defun hellmacs-compliance--ref (component)
  "COMPONENT's bom-ref: unique, where package URLs aren't (magit and
magit-section come from one repository)."
  (format "%s:%s@%s" (plist-get component :kind) (plist-get component :name)
          (or (plist-get component :version) "")))

(defun hellmacs-compliance--label (component)
  (format "%s %s" (plist-get component :name) (or (plist-get component :version) "")))

;;;###autoload
(defun hellmacs-compliance-collect-licenses (&optional components)
  "Each of COMPONENTS (default: everything installed) with its license.
A list of (\"NAME VERSION\" . LICENSE), LICENSE \"UNKNOWN\" if not known."
  (mapcar (lambda (c) (cons (hellmacs-compliance--label c) (or (plist-get c :license) "UNKNOWN")))
          (or components (hellmacs-compliance-components))))

;;;###autoload
(defun hellmacs-compliance-license-problems (components)
  "The COMPONENTS whose license needs a look: a list of (COMPONENT . WHY).
WHY is `unknown' (no license found) or `unlisted' (a LicenseRef-,
outside SPDX's list: a vendor's own terms, or public domain). Unknown
ones come first."
  (let (unknown unlisted)
    (dolist (c components)
      (let ((license (plist-get c :license)))
        (cond ((null license) (push (cons c 'unknown) unknown))
              ((string-match-p "LicenseRef-" license) (push (cons c 'unlisted) unlisted)))))
    (append (nreverse unknown) (nreverse unlisted))))

;;; CycloneDX ------------------------------------------------------------------

(defun hellmacs-compliance--uuid ()
  "A random (version 4) UUID."
  (let ((hex (secure-hash 'sha256 (format "%s%s%s" (random t) (float-time) (emacs-pid)))))
    (format "%s-%s-4%s-%x%s-%s" (substring hex 0 8) (substring hex 8 12) (substring hex 13 16)
            (logior 8 (logand 3 (string-to-number (substring hex 16 17) 16)))
            (substring hex 17 20) (substring hex 20 32))))

(defun hellmacs-compliance--cyclonedx-licenses (license)
  "LICENSE as CycloneDX's `licenses': an SPDX id, an expression, or a name."
  (cond ((null license) [])
        ((string-match-p " \\(?:OR\\|AND\\|WITH\\) " license) (vector `((expression . ,license))))
        ((string-prefix-p "LicenseRef-" license) (vector `((license (name . ,license)))))
        (t (vector `((license (id . ,license)))))))

(defun hellmacs-compliance--compact (alist)
  "ALIST without its nil values."
  (seq-remove (lambda (cell) (null (cdr cell))) alist))

(defun hellmacs-compliance--cyclonedx-component (c)
  (let ((url (plist-get c :url)))
    (hellmacs-compliance--compact
     `((type . ,(plist-get c :type))
       (bom-ref . ,(hellmacs-compliance--ref c))
       (name . ,(plist-get c :name))
       (version . ,(plist-get c :version))
       (licenses . ,(let ((l (hellmacs-compliance--cyclonedx-licenses (plist-get c :license))))
                      (and (> (length l) 0) l)))
       (purl . ,(plist-get c :purl))
       (hashes . ,(let ((hashes (delq nil (list (when-let* ((h (plist-get c :sha256)))
                                                  `((alg . "SHA-256") (content . ,h)))
                                                (when-let* ((h (plist-get c :sha512)))
                                                  `((alg . "SHA-512") (content . ,h)))))))
                    (and hashes (vconcat hashes))))
       (externalReferences
        . ,(and url (vector `((type . ,(if (memq (plist-get c :kind) '(package grammar))
                                           "vcs" "distribution"))
                              (url . ,url)))))))))

;;;###autoload
(defun hellmacs-compliance-cyclonedx-sbom (&optional components)
  "A CycloneDX 1.5 bill of materials for COMPONENTS (default: everything installed).
An alist for `json-encode'."
  (let ((version (ignore-errors (car (process-lines "git" "-C" hellmacs-dir "describe" "--tags" "--always")))))
    `((bomFormat . "CycloneDX")
      (specVersion . "1.5")
      (serialNumber . ,(concat "urn:uuid:" (hellmacs-compliance--uuid)))
      (version . 1)
      (metadata
       . ((timestamp . ,(format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t))
          (tools . ((components . [((type . "application") (name . "hellmacs")
                                    ,@(and version `((version . ,version)))
                                    (description . "bin/hellmacs sbom"))])))
          (component . ,(hellmacs-compliance--compact
                         `((type . "application") (bom-ref . "hellmacs") (name . "hellmacs")
                           (version . ,version)
                           (licenses . [((license (id . "GPL-3.0-or-later")))]))))))
      (components . ,(vconcat (mapcar #'hellmacs-compliance--cyclonedx-component
                                      (or components (hellmacs-compliance-components))))))))

(provide 'hellmacs-compliance)
;;; hellmacs-compliance.el ends here
