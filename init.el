;;; init.el --- Hellmacs bootstrap -*- lexical-binding: t; -*-

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

;; This file only orchestrates: it wires `load-path', brings up the
;; package manager, and loads modules and the user's config in a fixed
;; order. It holds no configuration of its own -- that lives in
;; `lisp/' (engine internals), `modules/<group>/<name>/' (user-facing
;; features) and `hellmacs-user-dir' (your config, outside this repo).
;;
;; Load order matters and is intentional:
;;   1. lisp/hellmacs-lib.el       -- macros/helpers (after!, add-hook!, ...), session context
;;   2. lisp/hellmacs.el           -- lifecycle hooks, GC, dir isolation
;;      lisp/hellmacs-emacs.el     -- stock Emacs with saner defaults
;;   3. lisp/hellmacs-packages.el  -- use-package settings (Elpaca itself loads on demand)
;;   4. lisp/hellmacs-keybinds.el  -- the C-c leader (`hellmacs-leader-def')
;;   5. lisp/hellmacs-modules.el   -- module system: `hellmacs!', `modulep!', `package!'
;;      lisp/hellmacs-splash.el    -- the Altar splash screen (`initial-buffer-choice')
;;      lisp/hellmacs-ux.el        -- themed quit prompt and error reporting
;;      lisp/hellmacs-treesit.el   -- pinned tree-sitter grammars (built by sync)
;;   (lisp/lib/ and lisp/cli/ load on demand: `hellmacs-require')
;;   6. $HELLMACSDIR/init.el       -- user: `hellmacs!' block choosing modules
;;                                    (static/init.example.el if there isn't one)
;;   7. packages: activated from the profile `bin/hellmacs sync' wrote --
;;      or, if it's missing or out of date, every packages.el is read and
;;      Elpaca installs/activates the packages before going on
;;   8. every enabled module's autoload.el + init.el, in `hellmacs!' order
;;   9. every enabled module's config.el, in `hellmacs!' order
;;  10. $HELLMACSDIR/config.el     -- user: everything else
;;  11. `custom-file', once every package is activated

;;; Code:

;; `--init-directory', `keymap-set' and `defvar-keymap' are all 29.1+.
(when (< emacs-major-version 29)
  (error "Hellmacs needs Emacs 29.1 or newer; this is %s" emacs-version))

(add-to-list 'load-path hellmacs-core-dir)

;; Core as `bin/hellmacs sync' byte-compiled it, when that's still current
;; (see `hellmacs-compiled-dir'): all of it, or none, since compiled files
;; carry each other's macros.
(defvar hellmacs--compiled-core-p (hellmacs-compiled-core-current-p)
  "Non-nil if core was loaded byte-compiled, from `hellmacs-compiled-dir'.")
(when hellmacs--compiled-core-p
  (add-to-list 'load-path (expand-file-name "lisp/" hellmacs-compiled-dir)))

(require 'hellmacs-lib)
(hellmacs-context-push 'startup)
(hellmacs-context-push (if noninteractive 'cli 'emacs))

(require 'hellmacs)
(require 'hellmacs-emacs)
(require 'hellmacs-packages)

(require 'hellmacs-keybinds)
(require 'hellmacs-modules)
(require 'hellmacs-splash)
(require 'hellmacs-ux)
(require 'hellmacs-treesit)   ; only points Emacs at the grammars `hellmacs sync' builds

;; Your init.el chooses modules with `hellmacs!'. Without one (or if it
;; doesn't call `hellmacs!'), the starter file's defaults apply, so
;; there's a single definition of Hellmacs' default module set.
(hellmacs-modules-read-config)

(hellmacs-modules-startup)
(hellmacs-load-user-file "config.el")

;; Named, so `hellmacs-reload' re-adding it doesn't stack copies.
(add-hook 'hellmacs-after-init-hook
          (defun hellmacs--report-ready-h ()
            (message "Hellmacs%s ready in %.2fs (%d GCs)"
                     (if hellmacs-profile (format " [%s]" hellmacs-profile) "")
                     hellmacs-init-time gcs-done)))

(provide 'init)
;;; init.el ends here
