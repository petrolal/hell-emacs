;;; lang/agda/doctor.el -*- lexical-binding: t; -*-

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

;;; Code:

(defvar elpaca-builds-directory)

(defun hell-agda--mode-version ()
  "The Agda version the installed agda2-mode needs, or nil."
  (let ((file (expand-file-name "agda2-mode/agda2-mode.el" elpaca-builds-directory)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (when (re-search-forward "^(defvar agda2-version \"\\([^\"]+\\)\"" nil t)
          (match-string 1))))))

;; Checked by `bin/hell doctor'.
(if-let* ((agda (executable-find "agda")))
    (let* ((output (cdr (hell-process-output agda "--version")))
           (version (and (string-match "Agda version \\([0-9.]+\\)" output)
                         (match-string 1 output)))
           (wanted (hell-agda--mode-version)))
      (if (and version wanted (not (equal version wanted)))
          (hell-doctor-error "agda is %s, but agda2-mode only starts with Agda %s; \
install Agda %s, or pin agda2-mode to your release's tag in your packages.el"
                             version wanted wanted)
        (hell-doctor-ok "Agda compiler: %s%s" (abbreviate-file-name agda)
                        (if version (format " (%s)" version) ""))))
  (hell-doctor-info "agda not found in PATH"))

(if-let* ((agda-mode (executable-find "agda-mode")))
    (hell-doctor-ok "Agda mode helper: %s" (abbreviate-file-name agda-mode))
  (hell-doctor-info "agda-mode helper not found in PATH"))

(provide 'lang-agda-doctor)
;;; doctor.el ends here
