;;; hellmacs-profiles.el --- The profile's generated init file -*- lexical-binding: t; -*-

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

;; As Doom v3's lisp/doom-profiles.el: `bin/hellmacs sync' generates the
;; profile's init file, and Emacs starts from it (the entry point in
;; lisp/hellmacs-emacs.el, or `hellmacs-start' in batch). Hellmacs has no
;; init.el of its own, and no startup sequence written out by hand: the
;; generated file *is* the startup.
;;
;; Each function in `hellmacs-profile-generate-functions' writes one or
;; more numbered parts into <profile>/init.d/; they're concatenated, in
;; order, into <profile>/init.MAJOR.MINOR.el (one per Emacs version, so a
;; different Emacs never loads another's), which is then byte-compiled.
;; Most parts add a function to `hellmacs-startup-functions', at the
;; depth of their number, which `hellmacs-startup' runs:
;;
;;   05-hellmacs.init.el                 profile data, packages' load-path
;;   10-hellmacs-loaddefs.init.el        core's autoloads
;;   20-user.init.el                     your init.el (its settings)
;;   30-hellmacs-package-envs.init.el    packages' :env
;;   60-hellmacs-module-loaddefs.init.el lisp/lib/ and modules' autoloads
;;   70-hellmacs-package-loaddefs.init.el packages' autoloads
;;   80-hellmacs-modules.init.el         the modules, then your config.el
;;
;; Everything the startup needs is decided here, at sync time: which
;; modules are enabled, where every package is, what to autoload. So
;; after changing your `hellmacs!' block or a packages.el, run
;; `bin/hellmacs sync' again, as with `doom sync'.

;;; Code:

(require 'hellmacs-lib)
(require 'hellmacs-modules)

(defvar hellmacs-profile-dir)  ; early-init.el
(defvar hellmacs-compiled-dir) ; early-init.el
(defvar hellmacs-core-dir)     ; early-init.el
(defvar hellmacs-profile)      ; early-init.el

(defvar hellmacs-profile-init-dir-name "init.d/"
  "The subdirectory of `hellmacs-profile-dir' holding the init file's parts.")

(defvar hellmacs-profile-generate-functions
  '(hellmacs-profile--generate-init
    hellmacs-profile--generate-loaddefs-hellmacs
    hellmacs-profile--generate-user-init-loader
    hellmacs-profile--generate-package-envs
    hellmacs-profile--generate-loaddefs-modules
    hellmacs-profile--generate-loaddefs-packages
    hellmacs-profile--generate-module-loader)
  "Functions that write the parts of the profile's init file.
Each is called with DATA, a plist from `hellmacs-sync' (:load-path, the
packages' build directories; :autoloads, the packages' combined autoloads
file), in the part directory (`hellmacs-profile-init-dir-name'). A part is
a file named NN-NAME.init.el; parts are concatenated in NN order.")

;;; Profile data --------------------------------------------------------------

(defun hellmacs-profile-file (name)
  "Return the path of file NAME in `hellmacs-profile-dir'."
  (expand-file-name name hellmacs-profile-dir))

(defun hellmacs-profile--modules ()
  "Describe the enabled modules for staleness checks: key, flags, path."
  (mapcar (lambda (key)
            (list key (hellmacs-module-get key :flags) (hellmacs-module-get key :path)))
          (hellmacs-module-list)))

(defun hellmacs-profile--inputs ()
  "Return the files a profile depends on, each paired with its mtime.
The mtime is nil for files that don't exist, so creating one counts
as a change too."
  (mapcar (lambda (file)
            (cons file (when-let* ((attrs (file-attributes file)))
                         (float-time (file-attribute-modification-time attrs)))))
          (cl-list* (expand-file-name "packages.el" hellmacs-core-dir)
                    (expand-file-name "init.el" hellmacs-user-dir)
                    (expand-file-name "packages.el" hellmacs-user-dir)
                    (append
                     (when (bound-and-true-p hellmacs-team-dir)
                       (list (expand-file-name "init.el" hellmacs-team-dir)
                             (expand-file-name "packages.el" hellmacs-team-dir)))
                     (cl-loop for key in (hellmacs-module-list)
                              for dir = (hellmacs-module-get key :path)
                              collect (expand-file-name "packages.el" dir)
                              append (hellmacs-module-autoload-files key))))))

(defun hellmacs-profile--stale-reason (profile)
  "Return why PROFILE doesn't match the current config, or nil if it does.
Only `bin/hellmacs doctor' asks: startup never checks, as in Doom."
  (cond ((not (equal (plist-get profile :emacs-version) emacs-version))
         (format "Emacs changed from %s to %s" (plist-get profile :emacs-version) emacs-version))
        ((not (equal (plist-get profile :modules) (hellmacs-profile--modules)))
         "the enabled modules changed")
        ((when-let* ((changed (seq-difference (hellmacs-profile--inputs)
                                              (plist-get profile :inputs))))
           (format "%s changed" (abbreviate-file-name (car (car changed))))))
        ((seq-find (lambda (dir) (not (file-directory-p dir))) (plist-get profile :load-path))
         "an installed package is missing")))

(defun hellmacs-profile-read ()
  "Return the synced profile's data, or nil if it's missing or unreadable."
  (let ((file (hellmacs-profile-file "profile.eld")))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (ignore-errors (read (current-buffer)))))))

;;; Writing parts ---------------------------------------------------------------

(defun hellmacs-profile--print (forms)
  "FORMS printed readably, one per line."
  (with-output-to-string
    (let ((print-length nil) (print-level nil) (print-circle nil)
          (print-escape-newlines t) (print-quoted t))
      (dolist (form forms)
        (prin1 form)
        (terpri)))))

(defun hellmacs-profile--write-part (name forms)
  "Write FORMS as part NAME (NN-NAME.init.el) in the current directory."
  (with-temp-file name
    (insert ";; -*- lexical-binding: t; -*-\n"
            (hellmacs-profile--print forms))))

(defun hellmacs-profile--scan-autoloads (files &optional load-name)
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

(defun hellmacs-profile--generate-init (data)
  "Part 05: the profile's data, and the packages on `load-path'."
  (hellmacs-profile--write-part
   "05-hellmacs.init.el"
   `((setq hellmacs-profile-generated
           ',(list :version hellmacs-version
                   :emacs emacs-version
                   :time (format-time-string "%F %T")))
     (defun hellmacs--startup-vars (_profile)
       (setq hellmacs-packages ',hellmacs-packages
             hellmacs-unpinned-packages ',hellmacs-unpinned-packages
             hellmacs-module-dependencies ',hellmacs-module-dependencies
             hellmacs-treesit-declarations ',hellmacs-treesit-declarations)
       (dolist (dir ',(reverse (plist-get data :load-path)))
         (add-to-list 'load-path dir)))
     (add-hook 'hellmacs-startup-functions #'hellmacs--startup-vars 5))))

(defun hellmacs-profile--generate-loaddefs-hellmacs (_data)
  "Part 10: autoloads of core's own files (lisp/hellmacs-*.el)."
  (hellmacs-profile--write-part
   "10-hellmacs-loaddefs.init.el"
   (hellmacs-profile--scan-autoloads
    (file-expand-wildcards (expand-file-name "hellmacs-*.el" hellmacs-core-dir))
    ;; By feature name: `load-path' has the compiled core first.
    #'file-name-base)))

(defun hellmacs-profile--generate-user-init-loader (_data)
  "Part 20: team init.el (if any) and user init.el, for their settings.
The modules its `hellmacs!' block enables are the ones part 80 loads,
as recorded at sync time."
  (hellmacs-profile--write-part
   "20-user.init.el"
   `((when (and (bound-and-true-p hellmacs-team-dir)
                (file-exists-p (expand-file-name "init.el" hellmacs-team-dir)))
       (load (expand-file-name "init.el" hellmacs-team-dir) nil 'nomessage))
     (hellmacs-load-user-file "init.el")
     ;; The proxy and CA you set there, for all of Emacs.
     (hellmacs-net-setup))))

(defun hellmacs-profile--generate-package-envs (_data)
  "Part 30: environment variables packages declared with `:env'."
  (hellmacs-profile--write-part
   "30-hellmacs-package-envs.init.el"
   (cl-loop for (_name . plist) in hellmacs-packages
            unless (plist-get plist :disable)
            append (cl-loop for (var . value) in (plist-get plist :env)
                            collect `(setenv ,var ,value)))))

(defun hellmacs-profile--generate-loaddefs-modules (_data)
  "Part 60: autoloads of lisp/lib/ and of every enabled module."
  (hellmacs-profile--write-part
   "60-hellmacs-module-loaddefs.init.el"
   `((defun hellmacs--startup-loaddefs-modules (_profile)
       ,@(hellmacs-profile--scan-autoloads
          (file-expand-wildcards (expand-file-name "lib/*.el" hellmacs-core-dir))
          ;; lib/jdk: `load-path' has the compiled core first.
          (lambda (file) (concat "lib/" (file-name-base file))))
       ,@(hellmacs-profile--scan-autoloads
          (mapcan #'hellmacs-module-autoload-files (hellmacs-module-list))))
     (add-hook 'hellmacs-startup-functions #'hellmacs--startup-loaddefs-modules 60))))

(defun hellmacs-profile--generate-loaddefs-packages (data)
  "Part 70: every package's autoloads (one compiled file, written by sync),
and their Info manuals."
  (let ((info-dirs (seq-filter (lambda (dir) (file-exists-p (expand-file-name "dir" dir)))
                               (plist-get data :load-path))))
    (hellmacs-profile--write-part
     "70-hellmacs-package-loaddefs.init.el"
     `((defun hellmacs--startup-loaddefs-packages (_profile)
         ,@(when-let* ((autoloads (plist-get data :autoloads)))
             `((load ,(file-name-sans-extension autoloads) nil 'nomessage)))
         ,@(when info-dirs
             `((with-eval-after-load 'info
                 (info-initialize)
                 (dolist (dir ',info-dirs)
                   (add-to-list 'Info-directory-list dir))))))
       (add-hook 'hellmacs-startup-functions #'hellmacs--startup-loaddefs-packages 70)))))

(defun hellmacs-profile--generate-module-loader (_data)
  "Part 80: the enabled modules, as sync saw them, then team and your config.el."
  (let ((init-modules (hellmacs-module-list :init))
        (config-modules (hellmacs-module-list :config)))
    (hellmacs-profile--write-part
     "80-hellmacs-modules.init.el"
     `((setq hellmacs-modules ,hellmacs-modules)
       (defun hellmacs--startup-modules (_profile)
         (setq hellmacs--use-compiled (bound-and-true-p hellmacs--compiled-core-p))
         (hellmacs-modules-check-dependencies)
         (hellmacs-treesit-apply)
         (with-hellmacs-context 'module
           (hellmacs-run-hooks 'hellmacs-before-modules-init-hook)
           ,@(cl-loop for key in init-modules
                      for path = (expand-file-name "init.el" (hellmacs-module-get key :path))
                      if (and (file-exists-p path) (hellmacs-file-active-p path))
                      collect `(hellmacs-module--load ',key "init.el"))
           (hellmacs-run-hooks 'hellmacs-after-modules-init-hook)
           (hellmacs-run-hooks 'hellmacs-before-modules-config-hook)
           ,@(cl-loop for key in config-modules
                      for path = (expand-file-name "config.el" (hellmacs-module-get key :path))
                      if (and (file-exists-p path) (hellmacs-file-active-p path))
                      collect `(hellmacs-module--load ',key "config.el"))
           (hellmacs-run-hooks 'hellmacs-after-modules-config-hook))
         (when (and (bound-and-true-p hellmacs-team-dir)
                    (file-exists-p (expand-file-name "config.el" hellmacs-team-dir)))
           (load (expand-file-name "config.el" hellmacs-team-dir) nil 'nomessage))
         (hellmacs-load-user-file "config.el"))
       (add-hook 'hellmacs-startup-functions #'hellmacs--startup-modules 80)))))

;;; Generating ---------------------------------------------------------------

(defun hellmacs-profile-delete-init ()
  "Delete the generated init files (every Emacs version's), legacy pre-16.8 init files, and their parts."
  (dolist (file (file-expand-wildcards (hellmacs-profile-file "init.*.el*")))
    (delete-file file))
  (dolist (file (list (hellmacs-profile-file "init.el")
                      (hellmacs-profile-file "init.elc")))
    (when (file-exists-p file)
      (delete-file file)))
  (let ((parts (hellmacs-profile-file hellmacs-profile-init-dir-name)))
    (when (file-directory-p parts)
      (delete-directory parts t))))

(defun hellmacs-profile-generate (data &optional compile)
  "Write the profile's init file from its parts, and return its name.
DATA is passed to every `hellmacs-profile-generate-functions'. With
COMPILE, byte-compile it too (sync does, once core compiled)."
  (let ((parts (hellmacs-profile-file hellmacs-profile-init-dir-name))
        (file (hellmacs-init-file)))
    (dolist (old (file-expand-wildcards (concat file "*")))
      (delete-file old))
    (when (file-directory-p parts)
      (delete-directory parts t))
    (make-directory parts t)
    (let ((default-directory parts))
      (dolist (fn hellmacs-profile-generate-functions)
        (funcall fn data)))
    (with-temp-file file
      ;; no-native-compile: Emacs' JIT would compile it again in a child
      ;; Emacs without Hellmacs' macros, and get it wrong; it's byte-compiled.
      (insert (format ";;; %s --- Generated by `bin/hellmacs sync'; don't edit -*- lexical-binding: t; no-native-compile: t; -*-\n"
                      (file-name-nondirectory file))
              (format ";; Profile: %s. Hellmacs %s. Emacs %s. See lisp/hellmacs-profiles.el.\n"
                      (or hellmacs-profile "default") hellmacs-version emacs-version))
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

(provide 'hellmacs-profiles)
;;; hellmacs-profiles.el ends here
