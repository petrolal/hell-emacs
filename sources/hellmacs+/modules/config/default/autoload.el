;;; config/default/autoload.el -*- lexical-binding: t; -*-

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

;; Commands behind the `C-c h' (Hellmacs) group.

;;;###autoload
(defun hellmacs-reload ()
  "Reload Hellmacs' init file, and with it your init.el and config.el."
  (interactive)
  (with-hellmacs-context 'reload
    (load-file (expand-file-name "init.el" hellmacs-dir))))

;;;###autoload
(defun hellmacs-visit-dir ()
  "Open a Dired buffer at the Hellmacs install directory."
  (interactive)
  (dired hellmacs-dir))

;;;###autoload
(defun hellmacs-visit-user-dir ()
  "Open a Dired buffer at your Hellmacs config (`hellmacs-user-dir').
Offers to create it with starter files if it doesn't exist yet."
  (interactive)
  (unless (file-directory-p hellmacs-user-dir)
    (if (y-or-n-p (format "%s doesn't exist. Create it? "
                          (abbreviate-file-name hellmacs-user-dir)))
        (hellmacs-init-user-dir)
      (user-error "No user config directory")))
  (dired hellmacs-user-dir))

;;;###autoload
(defun hellmacs-list-modules ()
  "Display the enabled Hellmacs modules, in load order, with their flags."
  (interactive)
  (message "Hellmacs modules: %s"
           (mapconcat (lambda (key)
                        (string-join
                         (mapcar #'symbol-name
                                 (append (list (car key) (cdr key))
                                         (hellmacs-module-get key :flags)))
                         " "))
                      (hellmacs-module-list)
                      ", ")))

;;; Commands behind the infernal `C-c h' map (Phase 7) ------------------------

;;;###autoload
(defun hellmacs-forge-find-file ()
  "Open a file in the current project -- the JVM Forge.
Outside a project, pick one first, then a file in it."
  (interactive)
  (require 'project)
  (defvar project-switch-commands)      ; bind it dynamically, as project.el reads it
  (if (project-current)
      (project-find-file)
    (let ((project-switch-commands #'project-find-file))
      (call-interactively #'project-switch-project))))

;;;###autoload
(defun hellmacs-reap ()
  "Reap memory: run the garbage collector now and report what's left."
  (interactive)
  (let* ((start (float-time))
         (stats (garbage-collect))
         (live (cl-loop for (_ size used) in stats
                        when (and (numberp size) (numberp used))
                        sum (* size used))))
    (message "[ALTAR] Reaped in %.3fs; %s still bound (%d garbage collections so far)."
             (- (float-time) start) (file-size-human-readable live) gcs-done)))

;;;###autoload
(defun hellmacs-crucible-reload ()
  "Hot-reload code into the running JVM -- the Crucible.
What that means is the buffer's language's: `hellmacs-reload-function'
(Java hot-swaps into a debug session, Clojure loads into its REPL)."
  (interactive)
  (if hellmacs-reload-function
      (funcall hellmacs-reload-function)
    (user-error "The Crucible is cold: nothing reloads from a %s buffer" mode-name)))
