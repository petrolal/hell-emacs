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

;;; Commentary:

;; Plugin manager for Hell Emacs modules and third-party plugins (Phase 15).
;; Allows listing, searching, enabling, disabling and updating modules
;; both via CLI (`bin/hell plugins') and interactively (`M-x hell-plugins' on C-c h p).

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'tabulated-list)
(require 'hell-modules)

(declare-function hell-sync-child "config/default/autoload" ())

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
  "Return list of all available modules and plugins across catalog sources.
Each entry is a plist: (:group GROUP :name NAME :enabled ENABLED-P :desc DESC
:path PATH)."
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
                            (let ((_ver (read (current-buffer)))
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

;;; Editing init.el's hell! block ------------------------------------------------
;;
;; Enabling or disabling a module changes only its own line, inside its own
;; group of the `hell!' form: `:tools docker' and `:lang docker' are two
;; modules. The form is read with lisp/lib/block.el, as `bin/hell config
;; --add-defaults' reads it.

(declare-function hell-block-read "lib/block" (file))
(declare-function hell-block-spec "lib/block" (file))
(declare-function hell-block-modules "lib/block" (spec))
(declare-function hell-block-group-positions "lib/block" (start end))
(declare-function hell-block-end-of-group "lib/block" (group groups end))

(defun hell-plugins--group-keyword (group)
  "GROUP (`lang', `:lang' or \"lang\") as the keyword `hell!' uses."
  (intern (concat ":" (string-remove-prefix ":" (format "%s" group)))))

(defun hell-plugins--init-file ()
  "The init.el whose `hell!' block the plugin commands edit."
  (expand-file-name "init.el" (or hell-user-dir hell-dir)))

(defun hell-plugins--locate (group name start end)
  "Where module GROUP NAME is in the current buffer's `hell!' form.
START and END bound the form. Returns (active BEG . END), the module as
written, flags and all; (commented BEG . END), the comment marker of a
`;;NAME' line among GROUP's; (group) if GROUP is there without NAME;
nil if GROUP isn't there."
  (let* ((groups (hell-block-group-positions start end))
         (here (assq group groups))
         (depth (1+ (car (syntax-ppss start))))
         (name-re (concat "\\_<" (regexp-quote (symbol-name name)) "\\_>")))
    (when here
      (let ((beg (cdr here))
            (limit (if-let* ((next (cadr (memq here groups)))) (cdr next) (1- end))))
        (save-excursion
          (or (progn
                (goto-char beg)
                (catch 'found
                  (while (re-search-forward name-re limit t)
                    (let* ((mb (match-beginning 0))
                           (me (match-end 0))
                           (ppss (save-excursion (syntax-ppss mb))))
                      (unless (nth 8 ppss)    ; in a comment or a string
                        (cond ((= (car ppss) depth)
                               (throw 'found (cons 'active (cons mb me))))
                              ;; (NAME +flag ...)
                              ((and (= (car ppss) (1+ depth)) (eq (char-before mb) ?\())
                               (throw 'found (cons 'active (cons (1- mb) (scan-sexps (1- mb) 1)))))))))))
              (progn
                (goto-char beg)
                ;; Only the module on its line (with its flags and a comment):
                ;; never prose that starts with its name.
                (when (re-search-forward (concat "^[ \t]*\\(;+[ \t]*\\)\\(?:" name-re "\\|(" name-re
                                                 "[^()\n]*)\\)[ \t]*\\(?:;.*\\)?$")
                                         limit t)
                  (cons 'commented (cons (match-beginning 1) (match-end 1)))))
              (list 'group)))))))

(defun hell-plugins--group-column (group groups)
  "The column GROUP's keyword is at in GROUPS; else the first group's, else 11."
  (if-let* ((here (or (assq group groups) (car groups))))
      (save-excursion
        (goto-char (cdr here))
        (skip-chars-forward " \t")
        (current-column))
    11))

(defun hell-plugins--enable-here (group name start end where)
  "Enable GROUP NAME in the `hell!' form between START and END.
WHERE is from `hell-plugins--locate'. Returns non-nil if it changed it."
  (let ((groups (hell-block-group-positions start end)))
    (pcase where
      (`(active . ,_) nil)
      (`(commented ,b . ,e)
       ;; `;;name   ; why' becomes `name     ; why', still aligned.
       (let ((width (- e b)))
         (delete-region b e)
         (goto-char b)
         (forward-sexp)
         (when (looking-at "[ \t]+;")
           (insert (make-string width ?\s))))
       t)
      (`(group)
       (goto-char (hell-block-end-of-group group groups end))
       (insert (make-string (hell-plugins--group-column group groups) ?\s)
               (symbol-name name) "\n")
       t)
      (_
       (let ((indent (make-string (hell-plugins--group-column group groups) ?\s)))
         (goto-char (1- end))
         (insert "\n\n" indent (symbol-name group) "\n" indent (symbol-name name)))
       t))))

(defun hell-plugins--disable-here (group start end where)
  "Disable GROUP's module WHERE says is active, in the `hell!' form.
START and END bound the form; WHERE is from `hell-plugins--locate'.
Returns non-nil if it changed it."
  (pcase where
    (`(active ,b . ,e)
     (if (and (save-excursion (goto-char b) (skip-chars-backward " \t") (bolp))
              (save-excursion (goto-char e) (looking-at "[ \t]*\\(?:;.*\\)?$")))
         ;; Alone on its line: comment it out there, keeping the alignment.
         (progn
           (goto-char b)
           (insert ";;")
           (goto-char (+ e 2))
           (when (looking-at " \\{3,\\};")
             (delete-char 2)))
       ;; Sharing a line (`(hell! :ui theme', `lsp magit', `default)'): it
       ;; moves, commented, to a line of its own right there, at the group's
       ;; column; what followed it (the closing paren too) to the next line.
       (let* ((text (buffer-substring b e))
              (indent (make-string (hell-plugins--group-column
                                    group (hell-block-group-positions start end))
                                   ?\s))
              (rest (save-excursion (goto-char e) (skip-chars-forward " \t")
                                    (and (not (looking-at "$\\|;")) (point)))))
         (delete-region b (or rest e))
         (goto-char b)
         (delete-horizontal-space)
         (unless (bolp) (insert "\n"))
         (insert indent ";;" text (if rest (concat "\n" indent) ""))))
     t)))

(defun hell-plugins--edit (group name enable)
  "Enable module GROUP NAME in init.el's `hell!' block; ENABLE nil disables.
Only GROUP's lines change. init.el is copied to init.el~ first, and put
back if the result doesn't read back as asked. Returns non-nil if
anything changed."
  (hell-require 'hell-lib 'block)
  (let* ((init (hell-plugins--init-file))
         (group (hell-plugins--group-keyword group))
         (block (or (and (file-exists-p init) (hell-block-read init))
                    (error "No (hell! ...) block in %s" (abbreviate-file-name init))))
         (backup (concat init "~"))
         (key (cons group name))
         (before (mapcar #'car (hell-block-modules (nth 2 block))))
         changed)
    (with-temp-buffer
      (insert-file-contents init)
      (emacs-lisp-mode)
      (pcase-let* ((`(,start ,end ,_) block)
                   (where (hell-plugins--locate group name start end)))
        (setq changed (if enable
                          (hell-plugins--enable-here group name start end where)
                        (hell-plugins--disable-here group start end where))))
      (when changed
        (copy-file init backup t)
        (write-region nil nil init nil 'silent)))
    ;; Read back: that module changed, and no other.
    (when changed
      (unless (seq-set-equal-p
               (mapcar #'car (hell-block-modules (hell-block-spec init)))
               (if enable (cons key before) (remove key before)))
        (copy-file backup init t)
        (error "Couldn't %s %s %s in %s; it's unchanged"
               (if enable "enable" "disable") group name (abbreviate-file-name init))))
    changed))

(defun hell-plugin-find-in-init (init-file group-sym name-sym)
  "Search INIT-FILE's `hell!' block for module GROUP-SYM NAME-SYM.
Returns (FOUND-P . COMMENTED-P)."
  (hell-require 'hell-lib 'block)
  (if-let* ((block (and (file-exists-p init-file) (hell-block-read init-file))))
      (with-temp-buffer
        (insert-file-contents init-file)
        (emacs-lisp-mode)
        (pcase (car (hell-plugins--locate (hell-plugins--group-keyword group-sym) name-sym
                                          (nth 0 block) (nth 1 block)))
          ('active (cons t nil))
          ('commented (cons t t))
          (_ (cons nil nil))))
    (cons nil nil)))

(defun hell-plugin-enable (group name)
  "Enable module GROUP NAME in the user's `init.el'."
  (when (hell-plugins--edit group name t)
    (message "Enabled %s %s in %s (run `bin/hell sync' or C-c h S)"
             (hell-plugins--group-keyword group) name (hell-plugins--init-file))
    t))

(defun hell-plugin-disable (group name)
  "Disable (comment out) module GROUP NAME in the user's `init.el'."
  (when (hell-plugins--edit group name nil)
    (message "Disabled %s %s in %s (run `bin/hell sync' or C-c h S)"
             (hell-plugins--group-keyword group) name (hell-plugins--init-file))
    t))

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
