;;; lang/solidity/config.el -*- lexical-binding: t; -*-

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
;; Ethereum Solidity smart contract language support.

;;; Code:

(use-package solidity-mode
  :mode ("\\.sol\\'" . solidity-mode)
  :config
  (add-hook 'solidity-mode-hook #'lsp-deferred))

(defun hell-solidity-build ()
  "Build the current Foundry project."
  (interactive)
  (compile "forge build"))

(defun hell-solidity-test ()
  "Run the current Foundry project's tests."
  (interactive)
  (compile "forge test"))

(hell-localleader-def 'solidity-mode
  "b" '("forge build" . hell-solidity-build)
  "t" '("forge test" . hell-solidity-test))

(provide 'lang-solidity-config)
;;; config.el ends here
