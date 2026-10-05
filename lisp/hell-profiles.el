;;; hell-profiles.el --- The profile's generated init file -*- lexical-binding: t; -*-

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

;; As Doom v3's lisp/doom-profiles.el: `bin/hell sync' generates the
;; profile's init file, and Emacs starts from it (the entry point in
;; lisp/hell-emacs.el, or `hell-start' in batch). Hell Emacs has no
;; init.el of its own, and no startup sequence written out by hand: the
;; generated file *is* the startup.
;;
;; Each function in `hell-profile-generate-functions' writes one or
;; more numbered parts into <profile>/init.d/; they're concatenated, in
;; order, into <profile>/init.MAJOR.MINOR.el (one per Emacs version, so a
;; different Emacs never loads another's), which is then byte-compiled.
;; Most parts add a function to `hell-startup-functions', at the
;; depth of their number, which `hell-startup' runs:
;;
;;   05-hell.init.el                     profile data, packages' load-path
;;   10-hell-loaddefs.init.el        core's autoloads
;;   20-user.init.el                     your init.el (its settings)
;;   30-hell-package-envs.init.el    packages' :env
;;   60-hell-module-loaddefs.init.el lisp/lib/ and modules' autoloads
;;   70-hell-package-loaddefs.init.el packages' autoloads
;;   80-hell-modules.init.el         the modules, then your config.el
;;
;; Everything the startup needs is decided here, at sync time: which
;; modules are enabled, where every package is, what to autoload. So
;; after changing your `hell!` block or a packages.el, run
;; `bin/hell sync' again, as with `doom sync'.

;;; Code:

(require 'hell-lib)
(require 'hell-modules)

(defvar hell-profile-dir)  ; early-init.el
(defvar hell-compiled-dir) ; early-init.el
(defvar hell-core-dir)     ; early-init.el
(defvar hell-profile)      ; early-init.el

(defvar hell-profile-init-dir-name "init.d/"
  "The subdirectory of `hell-profile-dir' holding the init file's parts.")

(defvar hell-profile-generate-functions
  '(hell-profile--generate-init
    hell-profile--generate-loaddefs-hell
    hell-profile--generate-user-init-loader
    hell-profile--generate-package-envs
    hell-profile--generate-loaddefs-modules
    hell-profile--generate-loaddefs-packages
    hell-profile--generate-module-loader)
  "Functions that write the parts of the profile's init file.
Each is called with DATA, a plist from `hell-sync' (:load-path, the
packages' build directories; :autoloads, the packages' combined autoloads
file), in the part directory (`hell-profile-init-dir-name'). A part is
a file named NN-NAME.init.el; parts are concatenated in NN order.")

;;; Profile data --------------------------------------------------------------

(defun hell-profile-file (name)
  "Return the path of file NAME in `hell-profile-dir'."
  (expand-file-name name hell-profile-dir))

(defun hell-profile--modules ()
  "Describe the enabled modules for staleness checks: key, flags, path."
  (mapcar (lambda (key)
            (list key (hell-module-get key :flags) (hell-module-get key :path)))
          (hell-module-list)))

(defun hell-profile--inputs ()
  "Return the files a profile depends on, each paired with its mtime.
The mtime is nil for files that don't exist, so creating one counts
as a change too."
  (mapcar (lambda (file)
            (cons file (when-let* ((attrs (file-attributes file)))
                         (float-time (file-attribute-modification-time attrs)))))
          (cl-list* (expand-file-name "packages.el" hell-core-dir)
                    (expand-file-name "init.el" hell-user-dir)
                    (expand-file-name "packages.el" hell-user-dir)
                    (append
                     (when (bound-and-true-p hell-team-dir)
                       (list (expand-file-name "init.el" hell-team-dir)
                             (expand-file-name "packages.el" hell-team-dir)))
                     (cl-loop for key in (hell-module-list)
                              for dir = (hell-module-get key :path)
                              collect (expand-file-name "packages.el" dir)
                              append (hell-module-autoload-files key))))))

(defun hell-profile--stale-reason (profile)
  "Return why PROFILE doesn't match the current config, or nil if it does.
Only `bin/hell doctor' asks: startup never checks, as in Doom."
  (cond ((not (equal (plist-get profile :emacs-version) emacs-version))
         (format "Emacs changed from %s to %s" (plist-get profile :emacs-version) emacs-version))
        ((not (equal (plist-get profile :modules) (hell-profile--modules)))
         "the enabled modules changed")
        ((when-let* ((changed (seq-difference (hell-profile--inputs)
                                              (plist-get profile :inputs))))
           (format "%s changed" (abbreviate-file-name (car (car changed))))))
        ((seq-find (lambda (dir) (not (file-directory-p dir))) (plist-get profile :load-path))
         "an installed package is missing")))

(defun hell-profile-read ()
  "Return the synced profile's data, or nil if it's missing or unreadable."
  (let ((file (hell-profile-file "profile.eld")))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (ignore-errors (read (current-buffer)))))))

;;; Writing parts ---------------------------------------------------------------

(defun hell-profile--print (forms)
  "FORMS printed readably, one per line."
  (with-output-to-string
    (let ((print-length nil) (print-level nil) (print-circle nil)
          (print-escape-newlines t) (print-quoted t))
      (dolist (form forms)
        (prin1 form)
        (terpri)))))

(defun hell-profile--write-part (name forms)
  "Write FORMS as part NAME (NN-NAME.init.el) in the current directory."
  (with-temp-file name
    (insert ";; -*- lexical-binding: t; -*-\n"
            (hell-profile--print forms))))

(defun hell-profile--scan-autoloads (files &optional load-name)
  "Autoload forms for every `;;;###autoload' in FILES.
A cookie before a definition yields an `autoload' form; before any other
form, the form itself is kept, as in Emacs' own loaddefs. LOAD-NAME,
called with a file, returns the name the autoloads load it by (default:
the file without its extension)."
  (require 'loaddefs-gen)
  (let (forms)
    (dolist (file files)
      (when (file-exists-p file)
        (let ((name (if load-name (funcall load-name file) (file-name-sans-extension file))))
          (with-temp-buffer
            (insert-file-contents file)
            (emacs-lisp-mode)
            (goto-char (point-min))
            (while (re-search-forward "^;;;###autoload[ \t]*$" nil t)
              (let ((form (read (current-buffer))))
                (push (or (funcall (if (fboundp 'loaddefs-generate--make-autoload)
                                       #'loaddefs-generate--make-autoload
                                     'make-autoload)
                                   form name)
                          form)
                      forms)))))))
    (nreverse forms)))

;;; The parts ---------------------------------------------------------------

(defun hell-profile--generate-init (data)
  "Part 05: the profile's DATA, and the packages on `load-path'."
  (hell-profile--write-part
   "05-hell.init.el"
   `((setq hell-profile-generated
           ',(list :version hell-version
                   :emacs emacs-version
                   :time (format-time-string "%F %T")))
     (defun hell--startup-vars (_profile)
       ;; Before part 60: module autoloads name compiled files too.
       (setq hell--use-compiled (bound-and-true-p hell--compiled-core-p))
       (setq hell-packages ',hell-packages
             hell-unpinned-packages ',hell-unpinned-packages
             hell-module-dependencies ',hell-module-dependencies
             hell-treesit-declarations ',hell-treesit-declarations)
       (dolist (dir ',(reverse (plist-get data :load-path)))
         (add-to-list 'load-path dir)))
     (add-hook 'hell-startup-functions #'hell--startup-vars 5))))

(defun hell-profile--generate-loaddefs-hell (_data)
  "Part 10: autoloads of core's own files (lisp/hell-*.el)."
  (hell-profile--write-part
   "10-hell-loaddefs.init.el"
   (hell-profile--scan-autoloads
    (file-expand-wildcards (expand-file-name "hell-*.el" hell-core-dir))
    ;; By feature name: `load-path' has the compiled core first.
    #'file-name-base)))


(defun hell-profile--generate-user-init-loader (_data)
  "Part 20: team init.el (if any) and user init.el, for their settings.
The modules its `hell!' block enables are the ones part 80 loads,
as recorded at sync time."
  (hell-profile--write-part
   "20-user.init.el"
   `((when (and (bound-and-true-p hell-team-dir)
                (file-exists-p (expand-file-name "init.el" hell-team-dir)))
       (load (expand-file-name "init.el" hell-team-dir) nil 'nomessage))
     (hell-load-user-file "init.el")
     ;; The proxy and CA you set there, for all of Emacs.
     (hell-net-setup))))

(defun hell-profile--generate-package-envs (_data)
  "Part 30: environment variables packages declared with `:env'."
  (hell-profile--write-part
   "30-hell-package-envs.init.el"
   (cl-loop for (_name . plist) in hell-packages
            unless (plist-get plist :disable)
            append (cl-loop for (var . value) in (plist-get plist :env)
                            collect `(setenv ,var ,value)))))

(defun hell-profile--generate-loaddefs-modules (_data)
  "Part 60: autoloads of lisp/lib/ and of every enabled module."
  (hell-profile--write-part
   "60-hell-module-loaddefs.init.el"
   `((defun hell--startup-loaddefs-modules (_profile)
       ,@(hell-profile--scan-autoloads
          (file-expand-wildcards (expand-file-name "lib/*.el" hell-core-dir))
          ;; lib/jdk: `load-path' has the compiled core first.
          (lambda (file) (concat "lib/" (file-name-base file))))
       ,@(hell-profile--module-autoloads))
     (add-hook 'hell-startup-functions #'hell--startup-loaddefs-modules 60))))

(defun hell-profile--module-autoloads ()
  "Autoload forms of every enabled module, one `let' per file.
Each file's autoloads load it by the name `hell-module--autoload-name'
gives at startup: its compiled copy from the sync, unless the source
was edited since."
  (let ((placeholder (make-string 1 0)))
    (cl-loop for key in (hell-module-list)
             for dir = (hell-module-get key :path)
             append (cl-loop for file in (hell-module-autoload-files key)
                             for forms = (hell-profile--scan-autoloads
                                          (list file) (lambda (_) placeholder))
                             when forms
                             collect `(let ((hell--autoload-file
                                             (hell-module--autoload-name
                                              ',key ,(file-relative-name file dir))))
                                        ,@(cl-subst 'hell--autoload-file placeholder
                                                    forms :test #'equal))))))

(defun hell-profile--generate-loaddefs-packages (data)
  "Part 70: every package's autoloads and Info manuals.
The autoloads are one compiled file, written by sync; the packages are
DATA's."
  (let ((info-dirs (seq-filter (lambda (dir) (file-exists-p (expand-file-name "dir" dir)))
                               (plist-get data :load-path))))
    (hell-profile--write-part
     "70-hell-package-loaddefs.init.el"
     `((defun hell--startup-loaddefs-packages (_profile)
         ,@(when-let* ((autoloads (plist-get data :autoloads)))
             ;; Never native-compiled: JIT off, as for the init file.
             `((let ((native-comp-jit-compilation nil))
                 (load ,(file-name-sans-extension autoloads) nil 'nomessage))))
         ,@(when info-dirs
             `((with-eval-after-load 'info
                 (info-initialize)
                 (dolist (dir ',info-dirs)
                   (add-to-list 'Info-directory-list dir))))))
       (add-hook 'hell-startup-functions #'hell--startup-loaddefs-packages 70)))))

(defun hell-profile--module-load (key file path)
  "The form part 80 loads module KEY's FILE (at PATH) with.
Without a `;;;###if' line in it now, it's marked unconditional: startup
then doesn't read it again while it's unchanged (`hell-module--load')."
  (if (hell-file-condition path)
      `(hell-module--load ',key ,file)
    `(hell-module--load ',key ,file 'unconditional)))

(defun hell-profile--generate-module-loader (_data)
  "Part 80: enabled modules as sync saw them, then team and your config.el."
  (let ((init-modules (hell-module-list :init))
        (config-modules (hell-module-list :config)))
    (hell-profile--write-part
     "80-hell-modules.init.el"
     `((setq hell-modules ,hell-modules)
       (defun hell--startup-modules (_profile)
         (hell-modules-check-dependencies)
         (hell-treesit-apply)
         (with-hell-context 'module
           (hell-run-hooks 'hell-before-modules-init-hook)
           ,@(cl-loop for key in init-modules
                      for path = (expand-file-name "init.el" (hell-module-get key :path))
                      if (and (file-exists-p path) (hell-file-active-p path))
                      collect (hell-profile--module-load key "init.el" path))
           (hell-run-hooks 'hell-after-modules-init-hook)
           (hell-run-hooks 'hell-before-modules-config-hook)
           ,@(cl-loop for key in config-modules
                      for path = (expand-file-name "config.el" (hell-module-get key :path))
                      if (and (file-exists-p path) (hell-file-active-p path))
                      collect (hell-profile--module-load key "config.el" path))
           (hell-run-hooks 'hell-after-modules-config-hook))
         (when (and (bound-and-true-p hell-team-dir)
                    (file-exists-p (expand-file-name "config.el" hell-team-dir)))
           (load (expand-file-name "config.el" hell-team-dir) nil 'nomessage))
         (hell-load-user-file "config.el"))
       (add-hook 'hell-startup-functions #'hell--startup-modules 80)))))

;;; Generating ---------------------------------------------------------------

(defun hell-profile-delete-init ()
  "Delete generated init files (all Emacs versions), legacy files, and parts."
  (dolist (file (file-expand-wildcards (hell-profile-file "init.*.el*")))
    (delete-file file))
  (dolist (file (list (hell-profile-file "init.el")
                      (hell-profile-file "init.elc")))
    (when (file-exists-p file)
      (delete-file file)))
  (let ((parts (hell-profile-file hell-profile-init-dir-name)))
    (when (file-directory-p parts)
      (delete-directory parts t))))

(defun hell-profile-generate (data &optional compile)
  "Write the profile's init file from its parts, and return its name.
DATA is passed to every `hell-profile-generate-functions'. With
COMPILE, byte-compile it too (sync does, once core compiled)."
  (let ((parts (hell-profile-file hell-profile-init-dir-name))
        (file (hell-init-file)))
    (dolist (old (file-expand-wildcards (concat file "*")))
      (delete-file old))
    (when (file-directory-p parts)
      (delete-directory parts t))
    (make-directory parts t)
    (let ((default-directory parts))
      (dolist (fn hell-profile-generate-functions)
        (funcall fn data)))
    (with-temp-file file
      ;; no-native-compile: Emacs' JIT would compile it again in a child
      ;; Emacs without Hell Emacs' macros, and get it wrong; it's byte-compiled.
      (insert (format ";;; %s --- Generated by `bin/hell sync'; don't edit -*- lexical-binding: t; no-native-compile: t; -*-\n"
                      (file-name-nondirectory file))
              (format ";; Profile: %s. Hell Emacs %s. Emacs %s. See lisp/hell-profiles.el.\n"
                      (or hell-profile "default") hell-version emacs-version))
      (dolist (part (directory-files parts t "\\`[0-9][0-9]-.*\\.init\\.el\\'"))
        (insert "\n;;; " (file-name-nondirectory part) "\n\n")
        (let ((start (point)))
          (insert-file-contents part)
          ;; Drop the part's own header line.
          (goto-char start)
          (delete-region start (line-beginning-position 2))
          (goto-char (point-max))))
      (insert "\n;;; " (file-name-nondirectory file) " ends here\n"))
    (when compile
      (let ((byte-compile-warnings nil)
            (inhibit-message t))
        (byte-compile-file file)))
    file))

(provide 'hell-profiles)
;;; hell-profiles.el ends here
