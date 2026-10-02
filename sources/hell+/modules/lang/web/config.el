;;; lang/web/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

;; Web templates, HTML, CSS/SCSS/Less, Thymeleaf, Velocity, FreeMarker, JSP
;; in `web-mode' and built-in `css-mode'.

(use-package web-mode
  :mode ("\\.p?html?\\'"
         "\\.[gts]html?\\'"
         "\\.tpl\\.php\\'"
         "\\.[agj]sp\\'"
         "\\.as[cx]\\'"
         "\\.erb\\'"
         "\\.mustache\\'"
         "\\.djhtml\\'"
         "\\.ftl\\'"
         "\\.vm\\'"
         "\\.thymeleaf\\'")
  :init
  (setq web-mode-enable-auto-pairing t
        web-mode-enable-auto-closing t
        web-mode-enable-current-element-highlight t
        web-mode-enable-current-column-highlight t
        web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2)
  :config
  (add-hook 'web-mode-hook #'lsp-deferred))

(use-package css-mode
  :ensure nil
  :mode ("\\.css\\'" "\\.scss\\'" "\\.less\\'")
  :init
  (setq css-indent-offset 2)
  :config
  (add-hook 'css-mode-hook #'lsp-deferred))
