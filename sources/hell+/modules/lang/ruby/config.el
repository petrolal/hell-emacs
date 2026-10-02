;;; lang/ruby/config.el -*- lexical-binding: t; -*-

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

;; Ruby editing and language server integration.

(use-package ruby-mode
  :ensure nil                           ; built into Emacs
  :mode ("\\.\\(?:rb\\|rake\\|gemspec\\|ru\\)\\'"
         "\\(?:Gem\\|Rake\\|Cap\\|Vagrant\\|Guard\\)file\\'")
  :interpreter "ruby"
  :config
  (add-hook 'ruby-mode-hook #'lsp-deferred)
  (when (fboundp 'ruby-ts-mode)
    (add-hook 'ruby-ts-mode-hook #'lsp-deferred)))

(use-package inf-ruby
  :after ruby-mode
  :hook (ruby-mode . inf-ruby-minor-mode))

(hell-localleader-def '(ruby-mode ruby-ts-mode)
  "b" '("bundle exec" . (lambda () (interactive) (compile "bundle exec rake")))
  "t" '("test / rspec" . (lambda () (interactive) (compile "bundle exec rspec")))
  "s" '("inf-ruby console" . inf-ruby))
