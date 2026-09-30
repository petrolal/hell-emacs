;;; hellmacs-splash.el --- The Altar: Hellmacs' startup screen -*- lexical-binding: t; -*-

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

;; Replaces the GNU splash screen (already off: `inhibit-startup-screen'
;; in early-init.el) with the Altar: a read-only `*hellmacs*' buffer
;; showing the horned cyber-cat sigil, the tagline, and how long startup
;; took.
;;
;; It is shown at startup through `initial-buffer-choice', and in new
;; `emacsclient -c' frames too. `C-c h s' (`hellmacs-splash') returns to
;; it at any time. It's a `special-mode' buffer, so the usual Emacs keys
;; apply: TAB and S-TAB move between the buttons, RET follows one, `g'
;; redraws, `q' buries it. Every global key (`C-x C-f', `C-x b', ...)
;; works as anywhere else.
;;
;; Set `hellmacs-splash-enable' to nil, in your init.el or config.el, to
;; start on *scratch* instead.

;;; Code:

(defgroup hellmacs-splash nil
  "The Hellmacs startup screen."
  :group 'hellmacs)

(defcustom hellmacs-splash-enable t
  "Whether Emacs starts on the Altar (`*hellmacs*') instead of *scratch*."
  :type 'boolean)

;; The defaults follow whatever theme is loaded; the Hellmacs theme gives
;; these faces its own colours.
(defface hellmacs-splash-sigil '((t (:inherit error :weight bold)))
  "Face for the splash screen's sigil (the horned cyber-cat).")

(defface hellmacs-splash-tagline '((t (:inherit warning :weight bold)))
  "Face for the splash screen's tagline.")

(defface hellmacs-splash-altar '((t (:inherit success)))
  "Face for the splash screen's startup-time line.")

(defface hellmacs-splash-hint '((t (:inherit shadow)))
  "Face for the splash screen's key hints.")

(defconst hellmacs-splash-buffer-name "*hellmacs*"
  "Name of the splash screen buffer.")

(defconst hellmacs-splash-sigil
  '("|`-._                                   _.-'|"
    " \\    `-._      /\\            /\\    _.-'    /"
    "  `-.     `-.  /  \\__________/  \\  .-'     .-'"
    "     `-.     `|  /\\          /\\  |'     .-'"
    "        `-.   | /  \\        /  \\ |   .-'"
    "           `-.|                  |.-'"
    "              |   <@>      <@>   |"
    "              |        /\\        |"
    "               \\    \\__/\\__/    /"
    "                `-._[||||||]_.-'"
    "                    `-.__.-'")
  "The horned cyber-cat: horns sweeping out of a cat's head, glowing eyes,
and a vent-grille jaw. Plain ASCII, so it renders in any font.")

(defconst hellmacs-splash-tagline
  "HELLMACS // [ JVM FORGE IGNITED ] // Heavy metal syntax. Bytecode subjugated."
  "The line under the sigil.")

(defvar hellmacs-splash--init-gcs nil
  "`gcs-done' when startup finished, or nil before.
The startup screen is redrawn later, and by then more collections may
have run; the line reports startup's.")

(add-hook 'hellmacs-after-init-hook
          (defun hellmacs-splash--record-gcs-h ()
            (setq hellmacs-splash--init-gcs gcs-done))
          -90)

(defun hellmacs-splash-startup-line ()
  "Return the line saying how long startup took, or a placeholder before.
Shared by the Altar and the :ui dashboard."
  (if hellmacs-init-time
      (let ((gcs (or hellmacs-splash--init-gcs gcs-done)))
        (format "[ALTAR] Bound in %.2f seconds with %d garbage collection%s."
                hellmacs-init-time gcs (if (= gcs 1) "" "s")))
    "[ALTAR] Binding..."))

(defun hellmacs-splash--insert-centered (text face width)
  "Insert TEXT in FACE, centered in WIDTH columns, then a newline."
  (insert (make-string (max 0 (/ (- width (string-width text)) 2)) ?\s)
          (propertize text 'face face)
          "\n"))

(defun hellmacs-splash--button (label action help)
  "Insert a button showing LABEL that calls ACTION, described by HELP."
  (insert-text-button label
                      'action (lambda (_) (call-interactively action))
                      'follow-link t
                      'help-echo help))

(defun hellmacs-splash--render ()
  "Draw the splash screen into the current buffer, centered in its window."
  (let* ((inhibit-read-only t)
         (window (get-buffer-window (current-buffer)))
         (width (if window (window-width window) (frame-width)))
         (height (if window (window-body-height window) (frame-height)))
         (sigil-width (apply #'max (mapcar #'string-width hellmacs-splash-sigil)))
         (sigil-indent (make-string (max 0 (/ (- width sigil-width) 2)) ?\s))
         ;; sigil + blank + tagline + altar + blank + buttons + blank + hint
         (content-height (+ (length hellmacs-splash-sigil) 7)))
    (erase-buffer)
    (insert (make-string (max 0 (/ (- height content-height) 3)) ?\n))
    ;; The sigil is one block, so it's indented as one to keep its shape.
    (dolist (line hellmacs-splash-sigil)
      (insert sigil-indent (propertize line 'face 'hellmacs-splash-sigil) "\n"))
    (insert "\n")
    (hellmacs-splash--insert-centered hellmacs-splash-tagline 'hellmacs-splash-tagline width)
    (hellmacs-splash--insert-centered (hellmacs-splash-startup-line) 'hellmacs-splash-altar width)
    (insert "\n")
    (let* ((buttons '(("[ scratch ]" scratch-buffer "Open the *scratch* buffer")
                      ("[ find file ]" find-file "Find a file (C-x C-f)")
                      ("[ recent files ]" hellmacs-splash-recent-files "Open a recently visited file")
                      ("[ project ]" project-switch-project "Open a project (C-x p p)")))
           (gap "   ")
           (row-width (+ (apply #'+ (mapcar (lambda (b) (string-width (car b))) buttons))
                         (* (string-width gap) (1- (length buttons))))))
      (insert (make-string (max 0 (/ (- width row-width) 2)) ?\s))
      (dolist (b buttons)
        (apply #'hellmacs-splash--button b)
        (unless (eq b (car (last buttons)))
          (insert gap))))
    (insert "\n\n")
    (hellmacs-splash--insert-centered
     "TAB next · RET open · C-x C-f find file · C-x b switch buffer · C-c h f forge"
     'hellmacs-splash-hint width)
    (goto-char (point-min))
    (forward-button 1 nil nil t)))

(defun hellmacs-splash-recent-files ()
  "Open a recently visited file, starting `recentf-mode' if needed.
Hellmacs only starts it at the first opened file (see hellmacs.el)."
  (interactive)
  (recentf-mode 1)
  (call-interactively #'recentf-open))

(define-derived-mode hellmacs-splash-mode special-mode "Altar"
  "Major mode for the Hellmacs splash screen.
Read-only; TAB/S-TAB move between buttons, RET follows one, `g'
redraws, `q' buries the buffer.

\\{hellmacs-splash-mode-map}"
  (setq-local revert-buffer-function (lambda (&rest _) (hellmacs-splash--render))
              cursor-type nil
              truncate-lines t
              mode-line-format nil
              buffer-undo-list t)
  (setq-local display-line-numbers nil)
  ;; Stay centered when the window is resized, and draw properly the
  ;; first time it's displayed (at startup it's drawn before it has a
  ;; window to measure).
  (add-hook 'window-size-change-functions #'hellmacs-splash--resize-h nil t))

(defun hellmacs-splash--resize-h (window)
  "Redraw the splash screen shown in WINDOW, which changed size."
  (with-current-buffer (window-buffer window)
    (hellmacs-splash--render)))

(defun hellmacs-splash--get-buffer ()
  "Return the splash buffer, in its mode, without drawing it."
  (let ((buffer (get-buffer-create hellmacs-splash-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'hellmacs-splash-mode)
        (hellmacs-splash-mode)))
    buffer))

(defun hellmacs-splash-buffer ()
  "Return the splash buffer, (re)drawn."
  (with-current-buffer (hellmacs-splash--get-buffer)
    (hellmacs-splash--render)
    (current-buffer)))

;;;###autoload
(defun hellmacs-splash ()
  "Return to the Altar: show the Hellmacs splash screen."
  (interactive)
  (switch-to-buffer (hellmacs-splash--get-buffer))
  ;; Drawn once it's in the window it centers itself in.
  (hellmacs-splash--render))

(defvar hellmacs-splash-buffer-function #'hellmacs-splash-buffer
  "Function returning the startup screen's buffer.
A module with its own startup screen (:ui dashboard) sets it; the
rules for when it is shown stay in `hellmacs-splash--initial-buffer'.")

(defun hellmacs-splash--initial-buffer ()
  "Value for `initial-buffer-choice': the splash screen, unless disabled.
When Emacs was started with a file or directory, return that buffer
instead: Emacs then shows only it, rather than splitting the frame
to show the splash screen next to it."
  (cond ((or buffer-file-name (derived-mode-p 'dired-mode))
         (current-buffer))
        (hellmacs-splash-enable
         (funcall hellmacs-splash-buffer-function))
        (t
         (get-scratch-buffer-create))))

(setq initial-buffer-choice #'hellmacs-splash--initial-buffer)

;; Startup time is only known once every package is activated, which
;; can be after the splash first appears (see `hellmacs-finalize'). It's
;; also the first moment the buffer is in a window to center itself in.
(add-hook 'hellmacs-after-init-hook
          (defun hellmacs-splash--refresh-h ()
            (when-let* ((buffer (get-buffer hellmacs-splash-buffer-name)))
              (with-current-buffer buffer
                (hellmacs-splash--render)))))

(provide 'hellmacs-splash)
;;; hellmacs-splash.el ends here
