;;; hell-test.el --- Tests for Hell Emacs' core -*- lexical-binding: t; -*-

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

;; ERT tests for the engine in lisp/. Run them with `make test', which
;; loads early-init.el and hell-cli as bin/hell does, with HELLDIR and
;; the XDG directories in a throwaway directory.

;;; Code:

(require 'ert)
(require 'hell-cli)
(require 'hell-modules)
(require 'hell-plugins)
(eval-and-compile (hell-require 'hell-cli 'config))
(eval-and-compile (hell-require 'hell-lib 'net))

(defmacro hell-test--with-modules (&rest body)
  "Run BODY with an empty module table, restored afterwards."
  (declare (indent 0))
  `(let ((hell-modules (make-hash-table :test #'equal))
         (hell-packages nil))
     ,@body))

;;; hell-lib ---------------------------------------------------------------

(ert-deftest hell-test-resolve-hooks ()
  (should (equal (hell--resolve-hooks 'prog-mode) '(prog-mode-hook)))
  (should (equal (hell--resolve-hooks '(text-mode prog-mode))
                 '(text-mode-hook prog-mode-hook)))
  (should (equal (hell--resolve-hooks ''after-init-hook) '(after-init-hook)))
  (should (equal (hell--resolve-hooks ''(a-hook b-hook)) '(a-hook b-hook))))

(ert-deftest hell-test-add-hook! ()
  (defvar hell-test--hook nil)
  (let ((hell-test--hook nil))
    (add-hook! 'hell-test--hook #'ignore)
    (should (memq #'ignore hell-test--hook))
    (remove-hook! 'hell-test--hook #'ignore)
    (should-not (memq #'ignore hell-test--hook))))

;;; hell-core --------------------------------------------------------------

(ert-deftest hell-test-state-file ()
  (should (equal (hell-state-file "foo") (expand-file-name "foo" hell-state-dir))))

;;; hell-modules -----------------------------------------------------------

(ert-deftest hell-test-module-key-string ()
  (should (equal (hell-module-key-string '(:ui . theme)) ":ui theme"))
  (should (equal (hell-module-key-string '(:hell)) ":hell")))

(ert-deftest hell-test-module-p ()
  (hell-test--with-modules
    (puthash '(:completion . corfu) '(:flags (+tab)) hell-modules)
    (should (hell-module-p :completion 'corfu))
    (should (hell-module-p :completion 'corfu '(+tab)))
    (should-not (hell-module-p :completion 'corfu '(-tab)))
    (should-not (hell-module-p :completion 'corfu '(+orderless)))
    (should-not (hell-module-p :completion 'vertico))))

(ert-deftest hell-test-package-disabled-p ()
  (hell-test--with-modules
    (setq hell-packages '((foo :disable t) (bar)))
    (should (hell-package-disabled-p 'foo))
    (should-not (hell-package-disabled-p 'bar))
    (should-not (hell-package-disabled-p 'baz))))

(ert-deftest hell-test-lock-file-in-use ()
  (let* ((dir (make-temp-file "hell-test-lock" t))
         (hell-lock-file (expand-file-name "user.eld" dir))
         (hell-default-lock-file (expand-file-name "default.eld" dir)))
    (unwind-protect
        (progn
          (should-not (hell-lock-file-in-use))
          (write-region "()" nil hell-default-lock-file)
          (should (equal (hell-lock-file-in-use) hell-default-lock-file))
          (write-region "()" nil hell-lock-file)
          (should (equal (hell-lock-file-in-use) hell-lock-file)))
      (delete-directory dir t))))

;;; hell-cli ---------------------------------------------------------------

(ert-deftest hell-test-cli-flag ()
  (should (eq (hell-cli--flag '("--color") "color") t))
  (should (eq (hell-cli--flag '("--no-color") "color") 'no))
  (should-not (hell-cli--flag '("--other") "color")))

(ert-deftest hell-test-cli-force-p ()
  (let ((process-environment (cons "HELL_FORCE" process-environment)))
    (should (hell-cli-force-p '("-!")))
    (should (hell-cli-force-p '("--force")))
    (should-not (hell-cli-force-p '("sync")))
    (should-not (hell-cli-force-p nil))
    (setenv "HELL_FORCE" "1")
    (should (hell-cli-force-p nil))))

;;; lib/net ----------------------------------------------------------------

(ert-deftest hell-test-net-rewrite ()
  (let ((hell-mirrors '(("https://github.com/" . "https://mirror.example/gh/"))))
    (should (equal (hell-net-rewrite "https://github.com/foo/bar")
                   "https://mirror.example/gh/foo/bar"))
    (should (equal (hell-net-rewrite "https://gitlab.com/foo")
                   "https://gitlab.com/foo"))))

;;; cli/check and hell-static-analysis --------------------------------------

(ert-deftest hell-test-check-autoloaded ()
  ;; A fresh session, as Emacs starts one: lisp/cli/check.el isn't loaded,
  ;; yet `C-c c x' and `C-c c l' (:config default) must find their commands.
  (with-temp-buffer
    (should (zerop (call-process
                    (expand-file-name invocation-name invocation-directory) nil t nil
                    "-Q" "--batch" "-l" (expand-file-name "early-init.el" hell-dir)
                    "--eval" "(prin1 (list (autoloadp (symbol-function 'hell-check))
                                         (commandp 'hell-check) (commandp 'hell-lint)
                                         (hell-featurep 'hell-cli 'check)))")))
    (should (equal (car (read-from-string (buffer-string))) '(t t t nil)))))

(ert-deftest hell-test-static-analysis-run-autoloaded ()
  ;; Core's loaddefs (profile part 10) must autoload it, for `C-c c s'.
  (let ((forms (hell-profile--scan-autoloads
                (list (expand-file-name "hell-static-analysis.el" hell-core-dir))
                #'file-name-base)))
    (should (seq-some (lambda (form)
                        (and (eq (car-safe form) 'autoload)
                             (equal (nth 1 form) ''hell-static-analysis-run)
                             (nth 4 form)))   ; interactive
                      forms))))

(ert-deftest hell-test-check-is-a-cli-part ()
  ;; Loaded (by hell-cli) as a part, so `hell-require' loads it once ...
  (should (hell-featurep 'hell-cli 'check))
  (should-not (featurep 'hell-cli-check))
  ;; ... and loading it binds no keys: :config default does that.
  (dolist (key '("c x" "c l" "c s" "h c"))
    ;; nil, or a number when the key's prefix isn't bound either.
    (should-not (commandp (keymap-lookup mode-specific-map key)))))

(defmacro hell-test--with-checked-project (&rest body)
  "Run BODY with `dir', a project whose x.el writes `marker' when compiled.
No one to ask (no terminal, no -!), and nothing trusted beforehand."
  (declare (indent 0))
  `(let* ((dir (file-name-as-directory (make-temp-file "hell-test-check" t)))
          (marker (expand-file-name "ran" dir))
          (hell-check-trust nil)
          (hell-check-trusted-directories nil)
          (process-environment (seq-remove (lambda (e) (string-match-p "\\`\\(?:__HELLTTY\\|HELL_FORCE\\)=" e))
                                           process-environment))
          (inhibit-message t))
     (unwind-protect
         (progn
           (with-temp-file (expand-file-name "x.el" dir)
             (insert ";;; x.el --- test -*- lexical-binding: t; -*-\n"
                     (format "(eval-when-compile (with-temp-file %S (insert \"ran\")))\n" marker)))
           ,@body)
       (delete-directory dir t))))

(ert-deftest hell-test-check-untrusted-skips-project-code ()
  (hell-test--with-checked-project
    (let ((results (hell-check-run-all (list dir))))
      (should-not (file-exists-p marker))
      (should-not (member "byte-compile" (plist-get results :tools)))
      ;; Said in the report, as information: the gate doesn't fail for it.
      (should (seq-find (lambda (d) (equal (plist-get d :rule-id) "untrusted"))
                        (plist-get results :diagnostics)))
      (should (zerop (plist-get results :errors))))))

(ert-deftest hell-test-check-trusted-runs-project-code ()
  (hell-test--with-checked-project
    (let ((hell-check-trust t))
      (should (member "byte-compile" (plist-get (hell-check-run-all (list dir)) :tools)))
      (should (file-exists-p marker))))
  (hell-test--with-checked-project
    (let ((hell-check-trusted-directories (list dir)))
      (hell-check-run-all (list dir))
      (should (file-exists-p marker)))))

(ert-deftest hell-test-check-command-and-links ()
  (let ((hell-profile nil))
    (should (equal (hell-check--command "/p/x y" t)
                   (concat (shell-quote-argument (expand-file-name "bin/hell" hell-dir))
                           " check /p/x\\ y --trust"))))
  ;; *hell-check*'s diagnostics are links, of their severity.
  (with-temp-buffer
    (insert "  ✗ /tmp/a.el:12:3: [Emacs Lisp/byte-compile] (r) broken\n"
            "  ! /tmp/b.el:4:1: [Java/checkstyle] (r) style\n"
            "  · /tmp/c.el:1:1: [-/hell-check] (untrusted) skipped\n")
    (hell-check-mode)
    (compilation--ensure-parse (point-max))
    (goto-char (point-min))
    (should (equal (cl-loop repeat 3
                            collect (let ((msg (get-text-property (+ (point) 4) 'compilation-message)))
                                      (forward-line 1)
                                      (and msg (compilation--message->type msg))))
                   '(2 1 0)))))

;;; bin/hell-env -----------------------------------------------------------

(declare-function hell-env--savable "../bin/hell-env" (environment))

(ert-deftest hell-test-env-withholds-secrets ()
  (hell-cli-load "env")
  (should (equal (hell-env--savable
                  '("PATH=/usr/bin" "HTTP_PROXY=http://proxy:3128" "GIT_AUTHOR_NAME=Me"
                    "REPO=git@github.com:a/b.git" "SSH_URL=ssh://git@host/x" "EMPTY="
                    "HTTPS_PROXY=http://me:pw@proxy:3128" "DATABASE_URL=postgres://me:pw@db/x"
                    "GITHUB_TOKEN=x" "NPM_CONFIG__AUTH=x" "GH_PAT=x"))
                 '(("PATH=/usr/bin" "HTTP_PROXY=http://proxy:3128" "GIT_AUTHOR_NAME=Me"
                    "REPO=git@github.com:a/b.git" "SSH_URL=ssh://git@host/x" "EMPTY=")
                   . ("DATABASE_URL" "HTTPS_PROXY")))))

;;; cli/bundle -------------------------------------------------------------

(defmacro hell-test--with-bundle-root (&rest body)
  "Run BODY with `root', an unpacked bundle's data/: a/b.txt, \"hello\".
`manifest' lists it, as `hell-bundle-create' would."
  (declare (indent 0))
  `(let ((root (make-temp-file "hell-test-bundle" t)))
     (unwind-protect
         (progn
           (make-directory (expand-file-name "a" root))
           (with-temp-file (expand-file-name "a/b.txt" root) (insert "hello"))
           (let ((manifest
                  (list :roots '("a")
                        :entries `(("a" :dir)
                                   ("a/b.txt" :file 5 ,(secure-hash 'sha256 "hello"))))))
             ,@body))
       (delete-directory root t))))

(ert-deftest hell-test-bundle-verify ()
  (hell-test--with-bundle-root
    (should-not (hell-bundle-verify manifest root))
    ;; A changed file, same size.
    (with-temp-file (expand-file-name "a/b.txt" root) (insert "jello"))
    (should-error (hell-bundle-verify manifest root))))

(ert-deftest hell-test-bundle-verify-roots ()
  (hell-test--with-bundle-root
    ;; A root that leaves the data directory, or that no entry vouches for.
    (should-error (hell-bundle-verify (plist-put (copy-sequence manifest) :roots '("../a")) root))
    (should-error (hell-bundle-verify (plist-put (copy-sequence manifest) :roots '("c")) root))))

(ert-deftest hell-test-bundle-check-sha256 ()
  (let ((file (make-temp-file "hell-test-bundle" nil ".tar" "bundle")))
    (unwind-protect
        (let ((sum (secure-hash 'sha256 "bundle")))
          (should-not (hell-bundle-check-sha256 file sum))
          (should-not (hell-bundle-check-sha256 file (upcase sum)))
          (should-error (hell-bundle-check-sha256 file (secure-hash 'sha256 "other")))
          (should-error (hell-bundle-check-sha256 file "abc"))
          (let ((hell-bundle-require-sha256 t))
            (should-error (hell-bundle-check-sha256 file nil))))
      (delete-file file))))

;;; hell-plugins -----------------------------------------------------------

(defconst hell-test--init "\
(hell! :ui         theme
       :editor
       ;;multiple-cursors ; idea
       :tools
       ;;docker           ; containers
       ;; docker notes: prose, never a module
       lsp                ; code intelligence
       :lang
       (java +lombok)     ; Java
       docker             ; Dockerfile
       :config     default)
"
  "An init.el for the plugin tests: `docker' in two groups, flags, prose.")

(defmacro hell-test--with-init (&rest body)
  "Run BODY with `hell-user-dir' holding `hell-test--init' as init.el.
`modules' returns the (GROUP . NAME)s its block enables now."
  (declare (indent 0))
  `(let* ((hell-user-dir (file-name-as-directory (make-temp-file "hell-test-init" t)))
          (init (expand-file-name "init.el" hell-user-dir))
          (inhibit-message t))
     (unwind-protect
         (cl-flet ((modules () (mapcar #'car (hell-config--modules (hell-config--block-spec init)))))
           (with-temp-file init (insert hell-test--init))
           ,@body)
       (delete-directory hell-user-dir t))))

(ert-deftest hell-test-plugins-respect-group ()
  (hell-test--with-init
    ;; :tools docker is already off: :lang docker mustn't go with it.
    (should-not (hell-plugin-disable 'tools 'docker))
    (should (member '(:lang . docker) (modules)))
    (should (hell-plugin-enable 'tools 'docker))
    (should (member '(:tools . docker) (modules)))
    (should (hell-plugin-disable 'lang 'docker))
    (should (member '(:tools . docker) (modules)))
    (should-not (member '(:lang . docker) (modules)))
    ;; The prose comment stayed one.
    (should (with-temp-buffer (insert-file-contents init)
                              (search-forward ";; docker notes: prose" nil t)))
    ;; The previous version is kept.
    (should (file-exists-p (concat init "~")))
    ;; Sharing the line with the closing paren (`:config default)'): its
    ;; comment stays in :config, so it can come back there.
    (should (with-temp-buffer (insert-file-contents init)
                              (search-forward ":config     default)" nil t)))
    (dotimes (_ 2)
      (should (hell-plugin-disable 'config 'default))
      (should-not (member '(:config . default) (modules)))
      (should (hell-plugin-enable 'config 'default))
      (should (member '(:config . default) (modules))))))

(ert-deftest hell-test-plugins-flags-and-groups ()
  (hell-test--with-init
    (should (hell-plugin-disable :lang 'java))
    (should-not (assoc '(:lang . java) (hell-config--modules (hell-config--block-spec init))))
    (should (hell-plugin-enable "lang" 'java))   ; back, flags and all
    (should (member '((:lang . java) . (java +lombok))
                    (hell-config--modules (hell-config--block-spec init))))
    (should (hell-plugin-enable 'editor 'multiple-cursors))
    (should (member '(:editor . multiple-cursors) (modules)))
    ;; A group the block lacks is made.
    (should (hell-plugin-enable 'term 'eshell))
    (should (member '(:term . eshell) (modules)))
    ;; Sharing a line with its group's keyword (`(hell! :ui theme').
    (should (hell-plugin-disable 'ui 'theme))
    (should-not (member '(:ui . theme) (modules)))
    (should (equal (hell-plugin-find-in-init init 'ui 'theme) '(t . t)))
    (should (hell-plugin-enable 'ui 'theme))
    (should (member '(:ui . theme) (modules)))
    (should (equal (hell-plugin-find-in-init init 'ui 'theme) '(t . nil)))))

;;; bin/hell-upgrade -------------------------------------------------------

(declare-function hell-cli--upgrade-to-release "../bin/hell-upgrade" (git))
(declare-function hell-cli--upgrade-packages "../bin/hell-upgrade" ())

(defun hell-test--fake-git (verify-code calls)
  "A git for `hell-cli--upgrade-to-release': releases v1.0.0 and v1.1.0,
HEAD at neither, `verify-tag' exiting VERIFY-CODE. Each call's
arguments are pushed onto the symbol CALLS' value."
  (lambda (&rest args)
    (set calls (cons args (symbol-value calls)))
    (pcase (car args)
      ("tag" '(0 . "v1.0.0\nv1.1.0\nnot-a-release"))
      ("describe" '(128 . ""))
      ("rev-parse" '(0 . "0123456789abcdef"))
      ("verify-tag" (cons verify-code "gpg: Can't check signature: No public key"))
      (_ '(0 . "")))))

(ert-deftest hell-test-upgrade-verifies-tags ()
  (hell-cli-load "upgrade")
  (should (eq (default-value 'hell-upgrade-verify-tags) t))
  (defvar hell-test--git-calls)
  (let ((hell-test--git-calls nil)
        (hell-upgrade-verify-tags t))
    ;; Unsigned: refused, and never checked out.
    (should-error (hell-cli--upgrade-to-release (hell-test--fake-git 1 'hell-test--git-calls)))
    (should (member '("verify-tag" "v1.1.0") hell-test--git-calls))
    (should-not (assoc "checkout" hell-test--git-calls))
    ;; Signed: checked out.
    (setq hell-test--git-calls nil)
    (hell-cli--upgrade-to-release (hell-test--fake-git 0 'hell-test--git-calls))
    (should (member '("checkout" "--quiet" "v1.1.0") hell-test--git-calls))))

(ert-deftest hell-test-upgrade-runs-sync-steps ()
  (hell-cli-load "upgrade")
  (let ((steps nil)
        (hell-packages nil))
    (cl-flet ((step (name) (lambda (&rest _) (push name steps) nil)))
      (let ((hell-sync-functions (list (step 'sync-functions))))
        (cl-letf (((symbol-function 'hell-packages-bootstrap) #'ignore)
                  ((symbol-function 'hell-sync--check-elpaca) #'ignore)
                  ((symbol-function 'hell-modules-install-packages) #'ignore)
                  ((symbol-function 'elpaca--queued) #'ignore)
                  ((symbol-function 'elpaca-process-queues) #'ignore)
                  ((symbol-function 'hell--elpaca-wait) #'ignore)
                  ((symbol-function 'hell-cli--detached) #'ignore)
                  ((symbol-function 'hell-sync--log) #'ignore)
                  ((symbol-function 'hell-modules-check-dependencies) (step 'dependencies))
                  ((symbol-function 'hell-sync--check-failures) (step 'failures))
                  ((symbol-function 'hell-sync--write-profile) (step 'profile))
                  ((symbol-function 'hell-verify-record-installed) (step 'record)))
          (hell-cli--upgrade-packages))))
    ;; As `hell-sync--run': the sync steps after the profile, the record last.
    (should (equal (nreverse steps)
                   '(dependencies failures profile sync-functions record)))))

;;; bin/hell ---------------------------------------------------------------

(ert-deftest hell-test-sandbox-removed-on-failure ()
  (skip-unless (executable-find "sh"))
  (let* ((dir (make-temp-file "hell-test-emacs" t))
         (fake (expand-file-name "emacs" dir)))
    (unwind-protect
        (progn
          ;; An "Emacs" that prints its sandbox's data directory, checks it
          ;; exists, and exits with $FAKE_EXIT.
          (with-temp-file fake
            (insert "#!/bin/sh\n"
                    "[ -d \"$XDG_DATA_HOME\" ] || exit 99\n"
                    "printf '%s' \"$XDG_DATA_HOME\"\n"
                    "exit \"${FAKE_EXIT:-0}\"\n"))
          (set-file-modes fake #o755)
          (dolist (code '(0 3))
            (with-temp-buffer
              (let ((process-environment
                     (append (list (concat "EMACS=" fake) (format "FAKE_EXIT=%d" code))
                             process-environment)))
                (should (eql code (call-process "sh" nil '(t nil) nil
                                                (expand-file-name "bin/hell" hell-dir)
                                                "emacs" "--sandbox"))))
              (let ((sandbox (file-name-directory (directory-file-name (buffer-string)))))
                (should (string-match-p "hell-sandbox\\." sandbox))
                (should-not (file-exists-p sandbox))))))
      (delete-directory dir t))))

(provide 'hell-test)
;;; hell-test.el ends here
