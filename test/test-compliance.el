;;; test-compliance.el --- Tests for SBOM and license reporting (Phase 12.9) -*- lexical-binding: t; -*-

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
(require 'json)
(require 'hellmacs-modules)

(defvar elpaca-builds-directory)
(defvar elpaca-sources-directory)

(defmacro test-compliance--with-install (&rest body)
  "Run BODY over a fake installation in a temporary directory, bound to `root'.
One Emacs package (a git checkout, built by symlink as Elpaca does), a
declared jar that is installed and one that isn't, an npm server with
its lockfile, and a built tree-sitter grammar."
  (declare (indent 0))
  ;; Under HOME, as a real install is: Emacs then abbreviates its paths to
  ;; ~/..., which git -C doesn't expand.
  `(let* ((root (file-name-as-directory
                 (let ((temporary-file-directory (file-name-as-directory (expand-file-name "~"))))
                   (make-temp-file "hellmacs-compliance" t))))
          (elpaca-sources-directory (expand-file-name "sources/" root))
          (elpaca-builds-directory (expand-file-name "builds/" root))
          (hellmacs-treesit-dir (expand-file-name "treesit/" root))
          (hellmacs-components nil)
          (hellmacs-treesit-declarations nil)
          (hellmacs-treesit-sources nil))
     (unwind-protect
         (let ((src (expand-file-name "demo/" elpaca-sources-directory))
               (build (expand-file-name "demo/" elpaca-builds-directory))
               (npm (expand-file-name "npm-ls/" root)))
           (make-directory src t)
           (make-directory build t)
           (with-temp-file (expand-file-name "demo.el" src)
             (insert ";;; demo.el --- A demo -*- lexical-binding: t; -*-\n"
                     ";; This program is free software; you can redistribute it and/or modify\n"
                     ";; it under the terms of the GNU General Public License as published by\n"
                     ";; the Free Software Foundation, either version 3 of the License, or\n"
                     ";; (at your option) any later version.\n"))
           (let ((default-directory src))
             (dolist (args '(("init" "-q") ("add" "demo.el")
                             ("-c" "user.name=t" "-c" "user.email=t@t" "commit" "-qm" "demo")
                             ("remote" "add" "origin" "https://github.com/someone/demo.git")))
               (should (zerop (apply #'call-process "git" nil nil nil args)))))
           (make-symbolic-link (expand-file-name "demo.el" src) (expand-file-name "demo.el" build))
           (with-temp-file (expand-file-name "tool.jar" root) (insert "jar"))
           (hellmacs-component! :name "tool" :version "1.0" :license "Apache-2.0"
                                :url "https://example.com/tool-1.0.jar"
                                :sha256 (make-string 64 ?a)
                                :path (expand-file-name "tool.jar" root))
           (hellmacs-component! :name "absent" :version "2.0" :license "MIT"
                                :url "https://example.com/absent.jar" :sha256 (make-string 64 ?b)
                                :path (expand-file-name "absent.jar" root))
           (make-directory npm t)
           (with-temp-file (expand-file-name "package-lock.json" npm)
             (insert (json-encode
                      '((name . "wrapper") (lockfileVersion . 3)
                        (packages
                         . (("" . ((name . "wrapper") (dependencies . ((npm-ls . "1.2.3")))))
                            ("node_modules/npm-ls"
                             . ((version . "1.2.3") (license . "MIT")
                                (resolved . "https://registry.npmjs.org/npm-ls/-/npm-ls-1.2.3.tgz")
                                (integrity . "sha512-AAEC")))
                            ("node_modules/@scope/dep"
                             . ((version . "0.1.0") (license . "ISC")
                                (resolved . "https://registry.npmjs.org/@scope/dep/-/dep-0.1.0.tgz")
                                (integrity . "sha512-AAEC")))
                            ("node_modules/npm-ls/node_modules/nolicense"
                             . ((version . "3.0.0")))))))))
           (hellmacs-component! :name "npm-ls" :version "1.2.3" :license "MIT" :npm t :path npm)
           (let ((hellmacs--current-module '(:lang . demo)))
             (hellmacs-treesit! :grammars ((demo "https://github.com/someone/tree-sitter-demo"
                                                 "v0.1.0" "0123456789abcdef0123456789abcdef01234567"
                                                 :license "MIT"))))
           (make-directory hellmacs-treesit-dir t)
           (with-temp-file (hellmacs-treesit-library 'demo) (insert "so"))
           (hellmacs-marker-write (concat (hellmacs-treesit-library 'demo) ".commit")
                                  "0123456789abcdef0123456789abcdef01234567")
           ,@body)
       (delete-directory root t))))

(defun test-compliance--find (name components)
  (seq-find (lambda (c) (equal (plist-get c :name) name)) components))

(ert-deftest test-compliance/license-from-file-headers ()
  "SPDX identifiers, the GPL notice, and common license texts are recognised."
  (hellmacs-require 'hellmacs-cli 'compliance)
  (cl-flet ((license-of (text)
              (with-temp-buffer (insert text) (hellmacs-compliance-text-license))))
    (should (equal (license-of ";; SPDX-License-Identifier: GPL-3.0-or-later\n") "GPL-3.0-or-later"))
    (should (equal (license-of "// SPDX-License-Identifier: MIT OR Apache-2.0\n") "MIT OR Apache-2.0"))
    (should (equal (license-of ";; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.") "GPL-3.0-or-later"))
    (should (equal (license-of ";; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.") "GPL-2.0-or-later"))
    (should (equal (license-of ";; it under the terms of the GNU General Public License version 3.")
                   "GPL-3.0-only"))
    (should (equal (license-of "Permission is hereby granted, free of charge, to any person obtaining a copy")
                   "MIT"))
    (should (equal (license-of "                                 Apache License\n                           Version 2.0, January 2004")
                   "Apache-2.0"))
    (should (equal (license-of "                    GNU GENERAL PUBLIC LICENSE\n                       Version 3, 29 June 2007")
                   "GPL-3.0-only"))
    ;; restclient: no SPDX identifier for it, so a reference, flagged for review.
    (should (equal (license-of ";;; restclient.el --- An interactive HTTP client for Emacs\n;;\n;; Public domain.\n")
                   "LicenseRef-PublicDomain"))
    (should (equal (license-of ";; This file is public domain software. Do what you want.\n")
                   "LicenseRef-PublicDomain"))
    (should-not (license-of "(defun f () \"Put it in the public domain.\")\n"))
    (should-not (license-of ";;; foo.el --- no license at all\n"))))

(ert-deftest test-compliance/component-declarations ()
  "`hellmacs-component!' records a component once, by name."
  (let ((hellmacs-components nil))
    (hellmacs-component! :name "x" :version "1" :license "MIT")
    (hellmacs-component! :name "x" :version "2" :license "MIT")
    (should (= (length hellmacs-components) 1))
    (should (equal (plist-get (car hellmacs-components) :version) "2"))
    (should-error (hellmacs-component! :version "1"))))

(ert-deftest test-compliance/inventory-of-what-is-installed ()
  "Packages at their commits, installed downloads, npm packages and grammars."
  (test-compliance--with-install
    (let* ((components (hellmacs-compliance-components))
           (demo (test-compliance--find "demo" components))
           (tool (test-compliance--find "tool" components))
           (dep (test-compliance--find "@scope/dep" components))
           (grammar (test-compliance--find "tree-sitter-demo" components)))
      ;; The package: its checkout's commit, origin, and its header's license.
      (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" (plist-get demo :version)))
      (should (equal (plist-get demo :url) "https://github.com/someone/demo.git"))
      (should (equal (plist-get demo :license) "GPL-3.0-or-later"))
      (should (equal (plist-get demo :purl)
                     (concat "pkg:github/someone/demo@" (plist-get demo :version))))
      ;; Declared downloads: only what's installed.
      (should (equal (plist-get tool :sha256) (make-string 64 ?a)))
      (should (equal (plist-get tool :license) "Apache-2.0"))
      (should-not (test-compliance--find "absent" components))
      ;; npm: the server and everything its lockfile installs, nested too.
      (should (equal (plist-get (test-compliance--find "npm-ls" components) :license) "MIT"))
      (should (equal (plist-get dep :version) "0.1.0"))
      (should (equal (plist-get dep :purl) "pkg:npm/%40scope/dep@0.1.0"))
      (should (equal (plist-get dep :sha512) "000102"))
      (should (test-compliance--find "nolicense" components))
      (should-not (plist-get (test-compliance--find "nolicense" components) :license))
      ;; The grammar, built from its pinned commit.
      (should (equal (plist-get grammar :version) "v0.1.0"))
      (should (equal (plist-get grammar :license) "MIT"))
      (should (equal (plist-get grammar :commit) "0123456789abcdef0123456789abcdef01234567")))))

(ert-deftest test-compliance/cyclonedx-sbom-structure ()
  "Generates valid CycloneDX SBOM JSON representation."
  (let ((sbom (hellmacs-compliance-cyclonedx-sbom)))
    (should (equal (cdr (assq 'bomFormat sbom)) "CycloneDX"))
    (should (equal (cdr (assq 'specVersion sbom)) "1.5"))
    (should (vectorp (cdr (assq 'components sbom))))))

(ert-deftest test-compliance/cyclonedx-components ()
  "Each component's CycloneDX entry: ids, hashes, licenses, references."
  (test-compliance--with-install
    (let* ((sbom (json-read-from-string (json-encode (hellmacs-compliance-cyclonedx-sbom))))
           (components (append (alist-get 'components sbom) nil))
           (entry (lambda (name) (seq-find (lambda (c) (equal (alist-get 'name c) name)) components)))
           (refs (mapcar (lambda (c) (alist-get 'bom-ref c)) components)))
      (should (string-match-p "\\`urn:uuid:[0-9a-f-]\\{36\\}\\'" (alist-get 'serialNumber sbom)))
      (should (equal (alist-get 'name (alist-get 'component (alist-get 'metadata sbom))) "hellmacs"))
      (should (equal (length refs) (length (seq-uniq refs))))
      (let ((tool (funcall entry "tool")))
        (should (equal (alist-get 'hashes tool)
                       (vector `((alg . "SHA-256") (content . ,(make-string 64 ?a))))))
        (should (equal (alist-get 'licenses tool) [((license (id . "Apache-2.0")))]))
        (should (equal (alist-get 'type (aref (alist-get 'externalReferences tool) 0)) "distribution")))
      (let ((demo (funcall entry "demo")))
        (should (equal (alist-get 'type (aref (alist-get 'externalReferences demo) 0)) "vcs")))
      ;; Expressions and names outside SPDX's list are written the way the schema wants.
      (should (equal (hellmacs-compliance--cyclonedx-licenses "MPL-2.0 OR EPL-1.0")
                     [((expression . "MPL-2.0 OR EPL-1.0"))]))
      (should (equal (hellmacs-compliance--cyclonedx-licenses "LicenseRef-Oracle-FUTC")
                     [((license (name . "LicenseRef-Oracle-FUTC")))]))
      (should (equal (hellmacs-compliance--cyclonedx-licenses nil) [])))))

(ert-deftest test-compliance/components-are-unique ()
  "Each component once, with its own bom-ref, as CycloneDX requires.
Two packages built from one repository (magit and magit-section) share
its package URL; an npm package two servers install is listed once."
  (test-compliance--with-install
    (let ((build (expand-file-name "demo-extra/" elpaca-builds-directory))
          (npm2 (expand-file-name "npm-two/" root)))
      (make-directory build t)
      (make-symbolic-link (expand-file-name "demo/demo.el" elpaca-sources-directory)
                          (expand-file-name "demo-extra.el" build))
      (make-directory npm2 t)
      (copy-file (expand-file-name "npm-ls/package-lock.json" root) (expand-file-name "package-lock.json" npm2))
      (hellmacs-component! :name "npm-two" :version "1" :license "MIT" :npm t :path npm2)
      (let* ((components (hellmacs-compliance-components))
             (entries (append (alist-get 'components (hellmacs-compliance-cyclonedx-sbom components)) nil))
             (refs (mapcar (lambda (c) (alist-get 'bom-ref c)) entries)))
        (should (test-compliance--find "demo-extra" components))
        (should (= (cl-count "@scope/dep" components :key (lambda (c) (plist-get c :name)) :test #'equal) 1))
        (should (equal refs (seq-uniq refs)))
        (should (equal entries (seq-uniq entries)))))))

(ert-deftest test-compliance/license-reporting ()
  "Verifies license summary aggregation across installed packages."
  (let ((report (hellmacs-compliance-collect-licenses)))
    (should (listp report))
    (should (cl-every (lambda (entry) (stringp (cdr entry))) report))))

(ert-deftest test-compliance/license-problems ()
  "Unknown licenses fail the report; ones outside SPDX's list are flagged for review."
  (test-compliance--with-install
    (let ((report (hellmacs-compliance-collect-licenses)))
      (should (equal (cdr (assoc "tool 1.0" report)) "Apache-2.0"))
      (should (equal (cdr (assoc "nolicense 3.0.0" report)) "UNKNOWN")))
    (hellmacs-component! :name "vendor" :version "9" :license "LicenseRef-Vendor"
                         :path (expand-file-name "tool.jar" root))
    (let ((problems (hellmacs-compliance-license-problems (hellmacs-compliance-components))))
      (should (equal (mapcar (lambda (p) (list (plist-get (car p) :name) (cdr p))) problems)
                     '(("nolicense" unknown) ("vendor" unlisted)))))))

(ert-deftest test-compliance/every-pin-is-declared ()
  "Every SHA-256 pinned in a module's +paths.el belongs to a declared component.
A download that isn't declared is missing from the SBOM and the license
report."
  (let ((hellmacs-components nil)
        (lsp-server-install-dir (make-temp-file "hellmacs-lsp" t))
        pinned)
    (defvar lsp-server-install-dir)
    (unwind-protect
        (dolist (file (file-expand-wildcards (expand-file-name "sources/hellmacs+/modules/*/*/+paths.el" hellmacs-dir)))
          (load file nil t)
          (with-temp-buffer
            (insert-file-contents file)
            (while (re-search-forward "\"\\([0-9a-f]\\{64\\}\\)\"" nil t)
              (push (cons (match-string 1) (file-relative-name file hellmacs-dir)) pinned))))
      (delete-directory lsp-server-install-dir t))
    (should pinned)
    (let ((declared (mapcan (lambda (c) (copy-sequence (cons (plist-get c :sha256) (plist-get c :sha256s))))
                            hellmacs-components)))
      (should (equal (seq-remove (lambda (pin) (member (car pin) declared)) pinned) nil))
      (dolist (c hellmacs-components)
        (should (plist-get c :license))
        (should (plist-get c :version))))))

(ert-deftest test-compliance/elpaca-bootstrap-is-pinned ()
  "Elpaca, which installs every other package, is cloned at a pinned commit.
A full clone: a shallow one only has the branch's tip, and the pin stops
being one as soon as the branch moves."
  (let ((order (with-temp-buffer
                 (insert-file-contents (expand-file-name "hellmacs-elpaca.el" hellmacs-core-dir))
                 (catch 'found
                   (while t
                     (let ((form (read (current-buffer))))
                       (when (and (eq (car-safe form) 'defvar) (eq (cadr form) 'elpaca-order))
                         (throw 'found (eval (nth 2 form) t)))))))))
    (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" (or (plist-get (cdr order) :ref) "")))
    (should-not (plist-get (cdr order) :depth))))

(defconst test-compliance--network-functions
  '(url-retrieve url-retrieve-synchronously url-copy-file url-insert-file-contents
    make-network-process open-network-stream network-stream-open)
  "Functions that reach the network from Emacs itself.")

(defun test-compliance--calls (file functions)
  "The FUNCTIONS FILE calls, as symbols, read from its code (not its comments)."
  (with-temp-buffer
    (insert-file-contents file)
    (let (found)
      (condition-case nil
          (while t
            (let ((form (read (current-buffer))))
              (named-let walk ((x form))
                (when (consp x)
                  (when (memq (car x) functions) (cl-pushnew (car x) found))
                  (while (consp x) (walk (car x)) (setq x (cdr x)))))))
        (end-of-file nil))
      found)))

(ert-deftest test-compliance/network-only-through-hellmacs-net ()
  "Hellmacs sends nothing of its own: only lisp/lib/net.el reaches the
network (pinned downloads, and doctor's reachability probe), through the
proxy, CA and mirrors you set. A call anywhere else fails this test."
  (let ((offenders nil))
    (dolist (file (append (directory-files-recursively (expand-file-name "lisp" hellmacs-dir) "\\.el\\'")
                          (directory-files-recursively (expand-file-name "modules" hellmacs-dir) "\\.el\\'")
                          (directory-files-recursively (expand-file-name "sources" hellmacs-dir) "\\.el\\'")
                          (list (expand-file-name "init.el" hellmacs-dir)
                                (expand-file-name "early-init.el" hellmacs-dir))))
      (unless (equal file (expand-file-name "lisp/lib/net.el" hellmacs-dir))
        (when-let* ((calls (test-compliance--calls file test-compliance--network-functions)))
          (push (cons (file-relative-name file hellmacs-dir) calls) offenders))))
    (should-not offenders)
    ;; And the check finds one.
    (should (memq 'url-copy-file
                  (test-compliance--calls (expand-file-name "lisp/lib/net.el" hellmacs-dir)
                                          test-compliance--network-functions)))))

(ert-deftest test-compliance/cli-sbom ()
  "`bin/hellmacs sbom FILE' writes the bill of materials there; without FILE, to stdout."
  (require 'hellmacs-cli)
  (test-compliance--with-install
    (let* ((file (expand-file-name "bom.json" root))
           (out (with-output-to-string (hellmacs-cli-sbom file)))
           (sbom (json-read-file file)))
      (should (string-match-p "Wrote [0-9]+ components to " out))
      (should (equal (alist-get 'bomFormat sbom) "CycloneDX"))
      (should (seq-find (lambda (c) (equal (alist-get 'name c) "tool")) (alist-get 'components sbom))))
    (let ((sbom (json-read-from-string (with-output-to-string (hellmacs-cli-sbom)))))
      (should (equal (alist-get 'specVersion sbom) "1.5")))
    (should-error (hellmacs-cli-sbom "a.json" "b.json"))))

(ert-deftest test-compliance/cli-licenses ()
  "`bin/hellmacs licenses' lists each component's license; an unknown one fails it."
  (require 'hellmacs-cli)
  (test-compliance--with-install
    (hellmacs-component! :name "vendor" :version "9" :license "LicenseRef-Vendor"
                         :path (expand-file-name "tool.jar" root))
    (let* ((hellmacs-cli--problems 0)
           (out (with-output-to-string (hellmacs-cli-licenses))))
      (should (string-match-p "Apache-2\\.0 .*tool 1\\.0" out))
      (should (string-match-p "✗ nolicense 3\\.0\\.0 .*no license found" out))
      (should (string-match-p "! vendor 9 .*LicenseRef-Vendor" out))
      (should (= hellmacs-cli--problems 1)))))

(ert-deftest test-compliance/every-grammar-declares-a-license ()
  "Every tree-sitter grammar a module's packages.el declares has a :license."
  (let (grammars)
    (dolist (file (file-expand-wildcards (expand-file-name "sources/hellmacs+/modules/*/*/packages.el" hellmacs-dir)))
      (with-temp-buffer
        (insert-file-contents file)
        (while (search-forward "(hellmacs-treesit!" nil t)
          (goto-char (match-beginning 0))
          (let ((form (read (current-buffer))))
            (dolist (grammar (plist-get (cdr form) :grammars))
              (push (cons (car grammar) (cadr (memq :license grammar))) grammars))))))
    (should grammars)
    (should (equal (seq-remove #'cdr grammars) nil))))

(provide 'test-compliance)
;;; test-compliance.el ends here
