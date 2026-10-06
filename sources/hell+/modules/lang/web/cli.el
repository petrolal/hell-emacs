;;; lang/web/cli.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

;; Extends bin/hell: `sync' also installs the pinned CSS server.

(hell-module-load "+paths")

(defun hell-web-css-sync-install-server ()
  "Install the pinned vscode-css-language-server. For `hell-sync-functions'."
  (if (hell-web-css-ls-installed-p)
      (hell-sync--log "vscode-css-language-server %s is installed" hell-web-css-ls-version)
    (hell-sync--log "Installing vscode-css-language-server %s with npm..." hell-web-css-ls-version)
    (hell-sync-npm-install "vscode-css-language-server" hell-web-css-ls-lock-dir hell-web-css-ls-dir)
    (hell-sync--log "vscode-css-language-server %s installed (lockfile verified)" hell-web-css-ls-version)))

(add-hook 'hell-sync-functions #'hell-web-css-sync-install-server)

(defun hell-web-css-bundle-paths ()
  "The installed server. For `hell-bundle-functions'."
  (list hell-web-css-ls-dir))

(add-hook 'hell-bundle-functions #'hell-web-css-bundle-paths)
