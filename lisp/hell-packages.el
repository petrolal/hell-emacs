;;; hell-packages.el --- Package management settings -*- lexical-binding: t; -*-

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

;; Hell Emacs uses Elpaca (https://github.com/progfolio/elpaca), not
;; package.el or straight.el. Both Elpaca and straight.el give
;; reproducible, git-based installs instead of package.el's tarball
;; snapshots, but Elpaca installs in parallel and its
;; `elpaca-use-package-mode' integration is simple.
;;
;; Elpaca itself is only loaded when something has to be installed or
;; built: by `hell-sync' (bin/hell sync). Startup never loads it:
;; as in Doom, the profile's generated init file puts the recorded build
;; directories on `load-path' and loads their autoloads -- no package
;; manager involved.

;;; Code:

(defvar elpaca-directory (expand-file-name "elpaca/" hell-data-dir))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))

;; Batch sessions (bin/hell) never open Elpaca's log UI. It would show in
;; the batch frame's window, and Elpaca then re-renders all of it on every
;; package's every status change: memory and time that grow with the
;; square of the package count (tens of GB for the whole catalog). Sync
;; reports failures itself (`hell-sync--check-failures').
(defvar elpaca-log-functions)
(when noninteractive
  (setq elpaca-log-functions nil))

(defun hell-packages-bootstrap ()
  "Load Elpaca, installing it first if needed. Safe to call repeatedly."
  (require 'hell-elpaca))

;;; use-package ------------------------------------------------------------

;; Installing and configuring are separate, as in Doom: modules declare
;; what to install with `package!' in their packages.el (see
;; `hell-modules'), and configure it with `use-package' in their
;; config.el. So `use-package' doesn't install anything by default.
(require 'use-package)

;; Modules should never eagerly load a package just by mentioning it.
;; Every `use-package' block opts into loading explicitly via
;; `:demand t', `:defer t' + `:hook'/`:bind'/`:commands', or
;; autoloading -- never by omission.
(setq use-package-always-defer t
      use-package-always-ensure nil
      use-package-expand-minimally t)

;; An explicit `:ensure' only works when Elpaca is loaded (where
;; `elpaca-use-package-mode' takes it over). On a synced startup it
;; would otherwise fall through to package.el, so point it here.
(setq use-package-ensure-function #'hell--use-package-ensure)

;; `:defer-incrementally', as in Doom: load a deferred package (or the
;; features it needs) in the background while Emacs is idle, so its
;; first use is instant. `t' means the package itself:
;;
;;   (use-package consult :defer-incrementally t ...)
;;   (use-package cider :defer-incrementally (clojure-mode sesman) ...)
(push :defer-incrementally use-package-deferring-keywords)
(setq use-package-keywords
      (use-package-list-insert :defer-incrementally use-package-keywords :after))

(defalias 'use-package-normalize/:defer-incrementally #'use-package-normalize-symlist)

(defun use-package-handler/:defer-incrementally (name _keyword features rest state)
  "Queue FEATURES (and package NAME) for `hell-load-incrementally'."
  (use-package-concat
   `((hell-load-incrementally
      ',(append (remq t features) (list (use-package-as-symbol name)))))
   (use-package-process-keywords name rest state)))

(defun hell--use-package-ensure (name args _state &optional _no-refresh)
  "Warn that `:ensure' ARGS for NAME are ignored; `package!' replaces it."
  (when (car args)
    (display-warning
     'hell
     (format "`use-package %s :ensure' is ignored. Declare it with `(package! %s)' \
in packages.el, then run `bin/hell sync'." name name))))

(autoload 'plugin! "hell-plugins" "Declare a third-party Hell Emacs plugin." nil t)

(provide 'hell-packages)
;;; hell-packages.el ends here
