;;; packages.el --- Your extra packages -*- lexical-binding: t; no-byte-compile: t; -*-

;; Packages to install beyond what your modules provide. Read after
;; every module's packages.el, so it can also change their packages.
;; Configure them in config.el. See `package!' for all options.
;;
;; After changing this file, run `bin/hellmacs sync' (or `C-c h S').

;; From (M)ELPA:
;; (package! magit)

;; From a git repo:
;; (package! some-package :recipe (:host github :repo "user/some-package"))

;; Pinned to a commit or tag:
;; (package! some-package :pin "v1.2.0")

;; Turn off a package a module would install (its `use-package'
;; blocks are skipped too):
;; (package! undo-fu-session :disable t)

;;; packages.el ends here
