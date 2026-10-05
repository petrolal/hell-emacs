;;; lang/racket/config.el -*- lexical-binding: t; -*-

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
;; Racket language ecosystem and racket-mode.

;;; Code:

(use-package racket-mode
  :mode ("\\.rkt\\'" . racket-mode))

(defun hell-racket-run ()
  "Run the current Racket file and switch to its REPL."
  (interactive)
  (if (fboundp 'racket-run-and-switch-to-repl)
      (racket-run-and-switch-to-repl)
    (compile (format "racket %s" (shell-quote-argument (buffer-file-name))))))

(defun hell-racket-test ()
  "Run the current Racket file's tests."
  (interactive)
  (if (fboundp 'racket-test)
      (racket-test)
    (compile (format "raco test %s" (shell-quote-argument (buffer-file-name))))))

(defun hell-racket-make ()
  "Byte-compile the current Racket file with raco make."
  (interactive)
  (compile (format "raco make %s" (shell-quote-argument (buffer-file-name)))))

(hell-localleader-def 'racket-mode
  "r" '("run racket" . hell-racket-run)
  "t" '("test racket" . hell-racket-test)
  "b" '("raco make" . hell-racket-make))

(provide 'lang-racket-config)
;;; config.el ends here
