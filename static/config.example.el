;;; config.el --- Your Hell Emacs config -*- lexical-binding: t; -*-

;; Loaded after every module. Put your own settings and keybindings
;; here, and configure the packages you declared in packages.el.
;;
;; Hell Emacs' helper macros are available: `after!', `add-hook!',
;; `setq-hook!', `defadvice!' and `cmd!' (see lisp/hell-lib.el).

;; Settings for a built-in feature:
;; (setq fill-column 100)

;; Per-mode settings:
;; (setq-hook! 'java-ts-mode-hook tab-width 4 fill-column 120)

;; Configure a package once it has loaded:
;; (after! consult
;;   (setq consult-preview-key "M-."))

;; Your own keys under the C-c leader (C-c y w here):
;; (hell-leader-def
;;   "y"   "yours"
;;   "y w" '("whitespace" . whitespace-mode))

;; Configure a package declared in packages.el:
;; (use-package magit
;;   :bind ("C-c y m" . magit-status))   ; your keys: C-c and a letter of your own

;; Check which modules/flags are on:
;; (when (modulep! :completion corfu +tab) ...)

;;; config.el ends here
