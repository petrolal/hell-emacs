;;; hell-elpaca.el --- Elpaca bootstrap -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Hell Emacs uses Elpaca (https://github.com/progfolio/elpaca) rather
;; than straight.el.  Both give reproducible, git-based installs
;; instead of package.el's tarball snapshots, but Elpaca installs
;; packages asynchronously/in parallel, which matters directly for
;; Hell Emacs' startup-time goals, and its `elpaca-use-package-mode'
;; integration keeps every module's `use-package' block declarative
;; with no separate recipe step. straight.el remains the better
;; choice if you need its build-caching across machines or its
;; longer track record; Elpaca is the better choice for a
;; startup-performance-first, single-machine distribution, which is
;; Hell Emacs' goal.
;;
;; Loaded on demand by `hell-packages-bootstrap', never at a synced
;; startup: Elpaca is only needed to install and build packages.
;;
;; The bootstrap block below is Elpaca's official installer (see its
;; README's "Installer" section), adapted only to redirect Elpaca's
;; own directory into `hell-data-dir' instead of
;; `user-emacs-directory' (the git checkout), and to pin Elpaca itself:
;; `:ref' is a commit (it installs every other package, so it's never
;; fetched from wherever master is), cloned in full (`:depth' nil),
;; since a shallow clone only holds the branch's tip.
;; Do not hand-edit it piecemeal; replace the whole block from
;; upstream when updating Elpaca's installer version.

;;; Code:

(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" hell-data-dir))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                               :ref "78b8e7cc98c198c8dbeb18140649e2d668126712" ; 2026-09-11
                               :depth nil :inherit ignore
                               :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                               :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                   ,@(when-let* ((depth (plist-get order :depth)))
                                                       (list (format "--depth=%d" depth) "--no-single-branch"))
                                                   ,(plist-get order :repo) ,repo))))
                  ;; At the pin, without git's page of detached-HEAD advice.
                  ((zerop (call-process "git" nil buffer t "-c" "advice.detachedHead=false" "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; `elpaca-use-package-mode' makes an explicit `:ensure t' route through
;; Elpaca instead of package.el. Modules don't use it -- they declare
;; packages with `package!' -- but a user's config.el may.
(elpaca elpaca-use-package
  (elpaca-use-package-mode))

;; Block until Elpaca + elpaca-use-package are installed and activated.
(elpaca-wait)

(provide 'hell-elpaca)
;;; hell-elpaca.el ends here
