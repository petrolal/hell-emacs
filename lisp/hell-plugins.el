;;; hell-plugins.el --- Plugin and module management -*- lexical-binding: t; -*-

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

;; Plugin manager for Hell Emacs modules and third-party plugins (Phase 15).
;; Allows listing, searching, enabling, disabling and updating modules
;; both via CLI (`bin/hell plugins') and interactively (`M-x hell-plugins' on C-c h p).

(require 'cl-lib)
(require 'tabulated-list)
(require 'hell-modules)

(defvar hell-plugins-buffer "*hell-plugins*")

(defvar hell-third-party-plugins (make-hash-table :test #'equal)
  "Declared third-party plugins: NAME -> PLIST.")

(defmacro plugin! (name &rest plist)
  "Declare a third-party plugin NAME with properties PLIST.
Properties:
  :repo     Git repository URL
  :commit   Pinned commit hash (mandatory for reproducible supply chain)
  :depth    Module loading depth
  :trust    Whether this plugin has been verified and trusted by the user."
  (let ((name-str (if (symbolp name) (symbol-name name) name)))
    `(puthash ,name-str ',plist hell-third-party-plugins)))

(defun hell-plugins-all ()
  "Return a list of all available modules and plugins across catalog sources.
Each entry is a plist: (:group GROUP :name NAME :enabled ENABLED-P :desc DESC :path PATH)."
  (when (= (hash-table-count hell-modules) 0)
    (hell-modules-read-config))
  (let (plugins)
    (dolist (modules-dir hell-module-load-path)
      (when (file-directory-p modules-dir)
        (dolist (group-dir (directory-files modules-dir t "\\`[^.]"))
          (when (file-directory-p group-dir)
            (let ((group (intern (file-name-nondirectory group-dir))))
              (dolist (mod-dir (directory-files group-dir t "\\`[^.]"))
                (when (file-directory-p mod-dir)
                  (let* ((mod-name (intern (file-name-nondirectory mod-dir)))
                         (group-kw (intern (format ":%s" group)))
                         (enabled (hell-module-p group-kw mod-name))
                         (manifest (expand-file-name ".hellmodule" mod-dir))
                         (desc ""))
                    (when (and manifest (file-exists-p manifest))
                      (with-temp-buffer
                        (insert-file-contents manifest)
                        (goto-char (point-min))
                        (condition-case nil
                            (let ((ver (read (current-buffer)))
                                  (data (read (current-buffer))))
                              (setq desc (or (cdr (assq 'doc data)) "")))
                          (error nil))))
                    (push (list :group group
                                :name mod-name
                                :enabled (if enabled t nil)
                                :desc desc
                                :path mod-dir)
                          plugins)))))))))
    (maphash (lambda (k v)
               (push (list :group 'plugin
                           :name (intern k)
                           :enabled t
                           :desc (or (plist-get v :desc) (plist-get v :repo) "Third-party plugin")
                           :path (plist-get v :repo))
                     plugins))
             hell-third-party-plugins)
    (sort plugins (lambda (a b)
                    (let ((ga (symbol-name (plist-get a :group)))
                          (gb (symbol-name (plist-get b :group))))
                      (if (string-equal ga gb)
                          (string< (symbol-name (plist-get a :name))
                                   (symbol-name (plist-get b :name)))
                        (string< ga gb)))))))

(defun hell-plugin-find-in-init (init-file group-sym name-sym)
  "Search INIT-FILE for module GROUP-SYM and NAME-SYM.
Returns (FOUND-P . COMMENTED-P)."
  (if (not (file-exists-p init-file))
      (cons nil nil)
    (with-temp-buffer
      (insert-file-contents init-file)
      (goto-char (point-min))
      (let ((name-str (symbol-name name-sym))
            (pattern (format "\\([ \t]*;;[ \t]*\\|\\(?1:[ \t]*\\)\\)\\(?:(%s\\|%s\\_>\\)"
                             (regexp-quote (symbol-name name-sym))
                             (regexp-quote (symbol-name name-sym))))
            found commented)
        (while (and (not found) (re-search-forward pattern nil t))
          (setq found t)
          (setq commented (not (match-string 1))))
        (cons found commented)))))

(defun hell-plugin-enable (group name)
  "Enable module GROUP and NAME in the user's `init.el'."
  (let* ((user-dir (or hell-user-dir hell-dir))
         (init-file (expand-file-name "init.el" user-dir)))
    (unless (file-exists-p init-file)
      (error "init.el not found in %s" user-dir))
    (with-temp-buffer
      (insert-file-contents init-file)
      (goto-char (point-min))
      (let ((name-str (symbol-name name))
            (group-kw (intern (format ":%s" group)))
            modified)
        ;; Look for commented occurrence
        (while (re-search-forward (format "^[ \t]*;;+[ \t]*\\(%s\\_>\\|(%s[ \t+].*\\)"
                                          (regexp-quote name-str)
                                          (regexp-quote name-str))
                                  nil t)
          (let ((line (match-string 0)))
            (replace-match (string-trim-left (string-trim-left line "[ \t]*;;+[ \t]*")) t t)
            (setq modified t)))
        (unless modified
          ;; Insert under group keyword
          (goto-char (point-min))
          (if (re-search-forward (format "^[ \t]*%s\\_>" (regexp-quote (symbol-name group-kw))) nil t)
              (progn
                (forward-line 1)
                (insert (format "           %s\n" name-str))
                (setq modified t))
            ;; Append to hell! block
            (if (re-search-forward "(hell!" nil t)
                (progn
                  (goto-char (match-end 0))
                  (insert (format "\n           %s\n           %s" group-kw name-str))
                  (setq modified t))
              (error "Could not find (hell! ...) block in %s" init-file))))
        (write-region (point-min) (point-max) init-file)
        (message "Enabled %s in %s (run `bin/hell sync' or C-c h S)" name-str init-file)
        t))))

(defun hell-plugin-disable (group name)
  "Disable (comment out) module GROUP and NAME in the user's `init.el'."
  (let* ((user-dir (or hell-user-dir hell-dir))
         (init-file (expand-file-name "init.el" user-dir)))
    (unless (file-exists-p init-file)
      (error "init.el not found in %s" user-dir))
    (with-temp-buffer
      (insert-file-contents init-file)
      (goto-char (point-min))
      (let ((name-str (symbol-name name))
            modified)
        (while (re-search-forward (format "^\\([ \t]*\\)\\(%s\\_>\\|(%s[ \t+].*?\\)"
                                          (regexp-quote name-str)
                                          (regexp-quote name-str))
                                  nil t)
          (replace-match (concat (match-string 1) ";;" (match-string 2)) t t)
          (setq modified t))
        (when modified
          (write-region (point-min) (point-max) init-file)
          (message "Disabled %s in %s (run `bin/hell sync' or C-c h S)" name-str init-file)
          t)))))

;;; UI mode --------------------------------------------------------------------

(define-derived-mode hell-plugins-mode tabulated-list-mode "Hell Emacs Plugins"
  "Major mode for browsing and managing Hell Emacs modules and plugins."
  (setq tabulated-list-format
        [("Status" 10 t)
         ("Group" 14 t)
         ("Name" 18 t)
         ("Description" 0 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key '("Group" . nil))
  (tabulated-list-init-header))

(defun hell-plugins-refresh ()
  "Refresh the *hell-plugins* list buffer."
  (interactive)
  (let ((plugins (hell-plugins-all))
        entries)
    (dolist (p plugins)
      (let* ((enabled (plist-get p :enabled))
             (status (if enabled
                         (propertize "enabled" 'face 'success)
                       (propertize "disabled" 'face 'shadow)))
             (group (symbol-name (plist-get p :group)))
             (name (symbol-name (plist-get p :name)))
             (desc (plist-get p :desc)))
        (push (list (cons (plist-get p :group) (plist-get p :name))
                    (vector status group name desc))
              entries)))
    (setq tabulated-list-entries (nreverse entries))
    (tabulated-list-print t)))

(defun hell-plugins-enable-at-point ()
  "Enable the plugin/module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (hell-plugin-enable (car entry) (cdr entry))
      (hell-plugins-refresh))))

(defun hell-plugins-disable-at-point ()
  "Disable the plugin/module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (hell-plugin-disable (car entry) (cdr entry))
      (hell-plugins-refresh))))

(defun hell-plugins-describe-at-point ()
  "Show details of the module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (message "Module :%s %s" (car entry) (cdr entry)))))

(keymap-set hell-plugins-mode-map "+" #'hell-plugins-enable-at-point)
(keymap-set hell-plugins-mode-map "e" #'hell-plugins-enable-at-point)
(keymap-set hell-plugins-mode-map "-" #'hell-plugins-disable-at-point)
(keymap-set hell-plugins-mode-map "d" #'hell-plugins-disable-at-point)
(keymap-set hell-plugins-mode-map "g" #'hell-plugins-refresh)
(keymap-set hell-plugins-mode-map "S" #'hell-sync-child)
(keymap-set hell-plugins-mode-map "RET" #'hell-plugins-describe-at-point)
(keymap-set hell-plugins-mode-map "?" #'hell-plugins-describe-at-point)

;;;###autoload
(defun hell-plugins ()
  "Open the interactive Hell Emacs plugins and modules manager."
  (interactive)
  (let ((buf (get-buffer-create hell-plugins-buffer)))
    (with-current-buffer buf
      (hell-plugins-mode)
      (hell-plugins-refresh))
    (pop-to-buffer buf)))

(provide 'hell-plugins)
;;; hell-plugins.el ends here
