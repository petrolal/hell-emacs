;;; lib/help.el --- Hellmacs Info manual and module help -*- lexical-binding: t; -*-

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

;; Phase 13: Integrated Help, Info Manual & Module Introspection
;; - `C-c h i': `hellmacs-info-manual'
;; - `C-c h d' / `M-x hellmacs-describe-module': module inspection buffer
;; - Info directory integration with docs/

(require 'info)
(require 'help-mode)
(require 'subr-x)

(defvar hellmacs-dir)
(declare-function hellmacs-module-list "hellmacs-modules")
(declare-function hellmacs-module-get "hellmacs-modules")
(declare-function hellmacs-module-locate-path "hellmacs-modules")
(declare-function hellmacs-module-metadata "hellmacs-modules")
(declare-function hellmacs-module-key-string "hellmacs-modules")
(declare-function hellmacs-list-modules "config/default/autoload")

;; Register docs/ in Info path
(let ((docs-dir (expand-file-name "docs/" hellmacs-dir)))
  (when (file-directory-p docs-dir)
    (add-to-list 'Info-directory-list docs-dir)
    (add-to-list 'Info-default-directory-list docs-dir)))

;;;###autoload
(defun hellmacs-info-manual ()
  "Open the official Hellmacs Info manual (C-c h i)."
  (interactive)
  (let ((info-file (expand-file-name "docs/hellmacs.info" hellmacs-dir)))
    (if (file-exists-p info-file)
        (info info-file)
      ;; Fallback to info top node if registered in Info-directory-list
      (condition-case nil
          (info "(hellmacs)")
        (error
         (user-error "Hellmacs Info manual not found at %s. Run makeinfo docs/hellmacs.texi" info-file))))))

(defun hellmacs-module-all-candidates ()
  "Return a list of all module keys as strings (e.g. `:lang java')."
  (let ((active (hellmacs-module-list))
        (all (hellmacs-module-list :all)))
    (delete-dups
     (mapcar (lambda (key) (hellmacs-module-key-string key))
             (append active all)))))

(defun hellmacs-module-parse-key (str)
  "Parse a module string like `:lang java' into a key cons `(:lang . java)'."
  (when (string-match "\\`\\(:[a-z]+\\)[ \t]+\\([a-z0-9-]+\\)\\'" (string-trim str))
    (cons (intern (match-string 1 str))
          (intern (match-string 2 str)))))

(defun hellmacs-module--find-description (dir)
  "Extract description from commentary in config.el or .hellmacsmodule in DIR."
  (let ((config-file (expand-file-name "config.el" dir)))
    (if (file-readable-p config-file)
        (with-temp-buffer
          (insert-file-contents config-file)
          (goto-char (point-min))
          (let (desc-lines
                in-header)
            (while (and (not (eobp))
                        (or (looking-at "^;;[ \t]*\\(.*\\)$")
                            (looking-at "^[ \t]*$")))
              (let ((line (if (looking-at "^;;[ \t]*\\(.*\\)$") (match-string 1) "")))
                (cond
                 ((string-match-p "\\(Copyright\\|Author\\|License\\|part of Hellmacs\\|Free Software\\|along with this program\\|-\\*- lexical\\|WARRANTY\\|MERCHANTABILITY\\|General Public License\\|distributed in the hope\\)" line)
                  (setq in-header t))
                 ((and in-header (string-empty-p (string-trim line)))
                  (setq in-header nil))
                 ((not in-header)
                  (push line desc-lines))))
              (forward-line 1))
            (let ((joined (string-trim (string-join (nreverse desc-lines) "\n"))))
              (if (not (string-empty-p joined))
                  joined
                "No description provided in config.el."))))
      "No configuration file found.")))

(defun hellmacs-module--find-packages (dir)
  "Extract declared package names from packages.el in DIR."
  (let ((pkg-file (and dir (expand-file-name "packages.el" dir))))
    (when (and pkg-file (file-readable-p pkg-file))
      (with-temp-buffer
        (insert-file-contents pkg-file)
        (goto-char (point-min))
        (let (pkgs)
          (while (re-search-forward "([ \t\n]*package![ \t\n]+\\([^ \t\n)]+\\)" nil t)
            (push (match-string 1) pkgs))
          (nreverse pkgs))))))

;;;###autoload
(defun hellmacs-describe-module (module)
  "Display complete information and documentation for MODULE.
Shows active status, flags, declared packages, file links, and keybindings."
  (interactive
   (let* ((candidates (hellmacs-module-all-candidates))
          (default (when-let* ((at-pt (thing-at-point 'symbol t)))
                     (car (member at-pt candidates))))
          (choice (completing-read
                   (format-prompt "Describe module" default)
                   candidates nil t nil nil default)))
     (list (hellmacs-module-parse-key choice))))
  (unless module
    (user-error "No module specified"))
  (let* ((group (car module))
         (name (cdr module))
         (key module)
         (active-p (member key (hellmacs-module-list)))
         (flags (and active-p (hellmacs-module-get key :flags)))
         (dir (hellmacs-module-locate-path group name))
         (meta (and dir (hellmacs-module-metadata dir key)))
         (version (or (plist-get meta :version) "0.9.0"))
         (buf-name (format "*Help: %s %s*" group name)))
    (with-current-buffer (get-buffer-create buf-name)
      (help-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "Module %s %s\n" group name) 'face 'bold))
        (insert (make-string 50 ?=) "\n\n")
        ;; Status
        (insert (propertize "Status:       " 'face 'bold))
        (if active-p
            (insert (propertize "ENABLED" 'face 'success)
                    (if flags (format " (active flags: %s)" (string-join (mapcar #'symbol-name flags) ", ")) ""))
          (insert (propertize "AVAILABLE (not enabled in current profile)" 'face 'shadow)))
        (insert "\n")
        ;; Version
        (insert (propertize "Version:      " 'face 'bold) version "\n")
        ;; Location
        (insert (propertize "Directory:    " 'face 'bold))
        (if dir
            (insert-text-button (abbreviate-file-name dir)
                                'action (lambda (_) (dired dir))
                                'follow-link t
                                'help-echo "Click to open in Dired")
          (insert "Not found"))
        (insert "\n\n")

        ;; Available module files
        (insert (propertize "Module Components:\n" 'face 'bold))
        (if dir
            (dolist (comp '("config.el" "packages.el" "doctor.el" "cli.el" "autoload.el" "+paths.el"))
              (let ((path (expand-file-name comp dir)))
                (when (file-exists-p path)
                  (insert "  · ")
                  (insert-text-button comp
                                      'action (lambda (_) (find-file path))
                                      'follow-link t
                                      'help-echo (format "Open %s" comp))
                  (insert (format " (%s)\n" (file-size-human-readable (file-attribute-size (file-attributes path))))))))
          (insert "  (No directory)\n"))
        (insert "\n")

        ;; Declared packages
        (insert (propertize "Declared Packages:\n" 'face 'bold))
        (let ((pkgs (hellmacs-module--find-packages dir)))
          (if pkgs
              (dolist (pkg pkgs)
                (insert (format "  ✓ %s\n" pkg)))
            (insert "  (None / built-in)\n")))
        (insert "\n")

        ;; Description
        (insert (propertize "Documentation & Summary:\n" 'face 'bold))
        (insert (if dir (hellmacs-module--find-description dir) "None") "\n\n")

        ;; Footer navigation
        (insert (propertize "Quick Actions:\n" 'face 'bold))
        (insert "  ")
        (insert-text-button "[ Open Hellmacs Manual (C-c h i) ]"
                            'action (lambda (_) (hellmacs-info-manual))
                            'follow-link t
                            'help-echo "Open Info manual")
        (insert "   ")
        (insert-text-button "[ View All Modules ]"
                            'action (lambda (_) (call-interactively #'hellmacs-list-modules))
                            'follow-link t
                            'help-echo "List active modules")
        (goto-char (point-min))))
    (display-buffer (get-buffer buf-name))))

(defalias 'describe-module #'hellmacs-describe-module)

(hellmacs-provide 'hellmacs-lib 'help)
;;; help.el ends here
