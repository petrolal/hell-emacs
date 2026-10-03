;;; config/default/autoload.el -*- lexical-binding: t; -*-

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

;; Commands behind the `C-c h' (Hell Emacs) group.

;;;###autoload
(defun hell-reload ()
  "Sync, then reload the profile's init file, and with it your config.
As Doom's `doom/reload': `bin/hell sync' runs in a child Emacs (its
output in *hell-sync*), so this session never loads the package
manager; then the new init file loads here."
  (interactive)
  (let ((buffer (get-buffer-create "*hell-sync*")))
    (with-current-buffer buffer (erase-buffer))
    (message "Hell Emacs: syncing...")
    (if (zerop (apply #'call-process (expand-file-name "bin/hell" hell-dir) nil buffer t
                      (append (and hell-profile (list "--profile" hell-profile))
                              '("sync"))))
        (progn
          (with-hell-context 'reload
            (hell-start))
          (message "Hell Emacs: synced and reloaded"))
      (pop-to-buffer buffer)
      (user-error "Sync failed; see *hell-sync*"))))

;;;###autoload
(defun hell-sync-child ()
  "Sync in a child Emacs process (output in *hell-sync*), as `C-c h R' does."
  (interactive)
  (let ((buffer (get-buffer-create "*hell-sync*")))
    (with-current-buffer buffer (erase-buffer))
    (message "Hell Emacs: syncing...")
    (if (zerop (apply #'call-process (expand-file-name "bin/hell" hell-dir) nil buffer t
                      (append (and hell-profile (list "--profile" hell-profile))
                              '("sync"))))
        (message "Hell Emacs: synced successfully")
      (pop-to-buffer buffer)
      (user-error "Sync failed; see *hell-sync*"))))

;;;###autoload
(defun hell-list-modules ()
  "Display the enabled Hell Emacs modules, in load order, with their flags."
  (interactive)
  (message "Hell Emacs modules: %s"
           (mapconcat (lambda (key)
                        (string-join
                         (mapcar #'symbol-name
                                 (append (list (car key) (cdr key))
                                         (hell-module-get key :flags)))
                         " "))
                      (hell-module-list)
                      ", ")))

;;; Commands behind the infernal `C-c h' map (Phase 7) ------------------------

;;;###autoload
(defun hell-crucible-reload ()
  "Hot-reload code into the running JVM -- the Crucible.
What that means is the buffer's language's: `hell-reload-function'
(Java hot-swaps into a debug session, Clojure loads into its REPL)."
  (interactive)
  (if hell-reload-function
      (funcall hell-reload-function)
    (user-error "The Crucible is cold: nothing reloads from a %s buffer" mode-name)))
