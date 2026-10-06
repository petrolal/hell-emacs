;;; lang/web/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(hell-module-load "+paths")

(hell-doctor-ok "Web mode templates (HTML, Thymeleaf, FreeMarker, Velocity, JSP, CSS/SCSS)")
(hell-doctor-node "vscode-css-language-server" 18)
(hell-doctor-pinned "vscode-css-language-server" hell-web-css-ls-version
                    (hell-web-css-ls-installed-p) (file-exists-p hell-web-css-ls-executable)
                        :where hell-web-css-ls-dir)
