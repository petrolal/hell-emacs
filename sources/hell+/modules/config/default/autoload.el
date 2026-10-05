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

(defun hell--sync-in-background (on-success)
  "Run `bin/hell sync' in a child Emacs, output in *hell-sync*; then ON-SUCCESS.
It doesn't block, and C-g doesn't stop it: an interrupted sync can leave
no profile to start from. Quitting Emacs while it runs asks first.
ON-SUCCESS is called with no arguments once it exits with 0; on failure
*hell-sync* is shown. Returns the process."
  (let ((buffer (get-buffer-create "*hell-sync*")))
    (when (process-live-p (get-buffer-process buffer))
      (user-error "A sync is already running; see *hell-sync*"))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)) (erase-buffer)))
    (message "Hell Emacs: syncing in the background (*hell-sync*)...")
    (make-process
     :name "hell-sync" :buffer buffer :connection-type 'pipe
     :command (append (list (expand-file-name "bin/hell" hell-dir))
                      (and hell-profile (list "--profile" hell-profile))
                      '("sync"))
     :sentinel (lambda (proc _event)
                 (unless (process-live-p proc)
                   (if (zerop (process-exit-status proc))
                       (funcall on-success)
                     (display-buffer buffer)
                     (message "Hell Emacs: sync failed; see *hell-sync*")))))))

;;;###autoload
(defun hell-reload ()
  "Sync, then reload the profile's init file, and with it your config.
As Doom's `doom/reload': `bin/hell sync' runs in a child Emacs, in the
background (its output in *hell-sync*), so this session never loads the
package manager; once it succeeds, the new init file loads here."
  (interactive)
  (hell--sync-in-background
   (lambda ()
     (with-hell-context 'reload
       (hell-start))
     (message "Hell Emacs: synced and reloaded"))))

;;;###autoload
(defun hell-sync-child ()
  "Sync in a child Emacs, in the background (output in *hell-sync*).
`C-c h R' (`hell-reload') also loads the result here."
  (interactive)
  (hell--sync-in-background
   (lambda () (message "Hell Emacs: synced; restart Emacs, or C-c h R, to use it"))))

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
