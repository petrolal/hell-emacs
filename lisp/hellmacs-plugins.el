;;; hellmacs-plugins.el --- Plugin and module management -*- lexical-binding: t; -*-

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

;; Plugin manager for Hellmacs modules and third-party plugins (Phase 15).
;; Allows listing, searching, enabling, disabling and updating modules
;; both via CLI (`bin/hellmacs plugins') and interactively (`M-x hellmacs-plugins' on C-c h p).

(require 'cl-lib)
(require 'tabulated-list)
(require 'hellmacs-modules)

(defvar hellmacs-plugins-buffer "*hellmacs-plugins*")

(defvar hellmacs-third-party-plugins (make-hash-table :test #'equal)
  "Declared third-party plugins: NAME -> PLIST.")

(defmacro plugin! (name &rest plist)
  "Declare a third-party plugin NAME with properties PLIST.
Properties:
  :repo     Git repository URL
  :commit   Pinned commit hash (mandatory for reproducible supply chain)
  :depth    Module loading depth
  :trust    Whether this plugin has been verified and trusted by the user."
  (let ((name-str (if (symbolp name) (symbol-name name) name)))
    `(puthash ,name-str ',plist hellmacs-third-party-plugins)))

(defun hellmacs-plugins-all ()
  "Return a list of all available modules and plugins across catalog sources.
Each entry is a plist: (:group GROUP :name NAME :enabled ENABLED-P :desc DESC :path PATH)."
  (when (= (hash-table-count hellmacs-modules) 0)
    (hellmacs-modules-read-config))
  (let (plugins)
    (dolist (modules-dir hellmacs-module-load-path)
      (when (file-directory-p modules-dir)
        (dolist (group-dir (directory-files modules-dir t "\\`[^.]"))
          (when (file-directory-p group-dir)
            (let ((group (intern (file-name-nondirectory group-dir))))
              (dolist (mod-dir (directory-files group-dir t "\\`[^.]"))
                (when (file-directory-p mod-dir)
                  (let* ((mod-name (intern (file-name-nondirectory mod-dir)))
                         (group-kw (intern (format ":%s" group)))
                         (enabled (hellmacs-module-p group-kw mod-name))
                         (manifest (expand-file-name ".hellmacsmodule" mod-dir))
                         (desc ""))
                    (when (file-exists-p manifest)
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
             hellmacs-third-party-plugins)
    (sort plugins (lambda (a b)
                    (let ((ga (symbol-name (plist-get a :group)))
                          (gb (symbol-name (plist-get b :group))))
                      (if (string-equal ga gb)
                          (string< (symbol-name (plist-get a :name))
                                   (symbol-name (plist-get b :name)))
                        (string< ga gb)))))))

(defun hellmacs-plugin-find-in-init (init-file group-sym name-sym)
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

(defun hellmacs-plugin-enable (group name)
  "Enable module GROUP and NAME in the user's `init.el'."
  (let* ((user-dir (or hellmacs-user-dir hellmacs-dir))
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
            ;; Append to hellmacs! block
            (if (re-search-forward "(hellmacs!" nil t)
                (progn
                  (goto-char (match-end 0))
                  (insert (format "\n           %s\n           %s" group-kw name-str))
                  (setq modified t))
              (error "Could not find (hellmacs! ...) block in %s" init-file))))
        (write-region (point-min) (point-max) init-file)
        (message "Enabled %s in %s (run `bin/hellmacs sync' or C-c h S)" name-str init-file)
        t))))

(defun hellmacs-plugin-disable (group name)
  "Disable (comment out) module GROUP and NAME in the user's `init.el'."
  (let* ((user-dir (or hellmacs-user-dir hellmacs-dir))
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
          (message "Disabled %s in %s (run `bin/hellmacs sync' or C-c h S)" name-str init-file)
          t)))))

;;; UI mode --------------------------------------------------------------------

(define-derived-mode hellmacs-plugins-mode tabulated-list-mode "Hellmacs Plugins"
  "Major mode for browsing and managing Hellmacs modules and plugins."
  (setq tabulated-list-format
        [("Status" 10 t)
         ("Group" 14 t)
         ("Name" 18 t)
         ("Description" 0 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key '("Group" . nil))
  (tabulated-list-init-header))

(defun hellmacs-plugins-refresh ()
  "Refresh the *hellmacs-plugins* list buffer."
  (interactive)
  (let ((plugins (hellmacs-plugins-all))
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

(defun hellmacs-plugins-enable-at-point ()
  "Enable the plugin/module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (hellmacs-plugin-enable (car entry) (cdr entry))
      (hellmacs-plugins-refresh))))

(defun hellmacs-plugins-disable-at-point ()
  "Disable the plugin/module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (hellmacs-plugin-disable (car entry) (cdr entry))
      (hellmacs-plugins-refresh))))

(defun hellmacs-plugins-describe-at-point ()
  "Show details of the module under point."
  (interactive)
  (let ((entry (tabulated-list-get-id)))
    (if (not entry)
        (user-error "No module under point")
      (message "Module :%s %s" (car entry) (cdr entry)))))

(keymap-set hellmacs-plugins-mode-map "+" #'hellmacs-plugins-enable-at-point)
(keymap-set hellmacs-plugins-mode-map "e" #'hellmacs-plugins-enable-at-point)
(keymap-set hellmacs-plugins-mode-map "-" #'hellmacs-plugins-disable-at-point)
(keymap-set hellmacs-plugins-mode-map "d" #'hellmacs-plugins-disable-at-point)
(keymap-set hellmacs-plugins-mode-map "g" #'hellmacs-plugins-refresh)
(keymap-set hellmacs-plugins-mode-map "S" #'hellmacs-sync-child)
(keymap-set hellmacs-plugins-mode-map "RET" #'hellmacs-plugins-describe-at-point)
(keymap-set hellmacs-plugins-mode-map "?" #'hellmacs-plugins-describe-at-point)

;;;###autoload
(defun hellmacs-plugins ()
  "Open the interactive Hellmacs plugins and modules manager."
  (interactive)
  (let ((buf (get-buffer-create hellmacs-plugins-buffer)))
    (with-current-buffer buf
      (hellmacs-plugins-mode)
      (hellmacs-plugins-refresh))
    (pop-to-buffer buf)))

(provide 'hellmacs-plugins)
;;; hellmacs-plugins.el ends here
