;;; lang/coq/config.el -*- lexical-binding: t; -*-

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
;; Coq / Rocq interactive proof assistant support via Proof General.

;;; Code:

(use-package proof-general
  :mode ("\\.v\\'" . coq-mode))

(defun hell-coq-next-step ()
  "Assert the next proof step."
  (interactive)
  (if (fboundp 'proof-assert-next-command-interactive)
      (proof-assert-next-command-interactive)
    (forward-line 1)))

(defun hell-coq-undo-step ()
  "Undo the last successful proof step."
  (interactive)
  (if (fboundp 'proof-undo-last-successful-command)
      (proof-undo-last-successful-command)
    (forward-line -1)))

(defun hell-coq-to-point ()
  "Process the proof script up to point."
  (interactive)
  (when (fboundp 'proof-goto-point) (proof-goto-point)))

(defun hell-coq-retract-buffer ()
  "Retract the whole proof buffer."
  (interactive)
  (when (fboundp 'proof-retract-buffer) (proof-retract-buffer)))

(hell-localleader-def 'coq-mode
  "n" '("next step" . hell-coq-next-step)
  "u" '("undo step" . hell-coq-undo-step)
  "b" '("to point" . hell-coq-to-point)
  "r" '("retract buffer" . hell-coq-retract-buffer))

(provide 'lang-coq-config)
;;; config.el ends here
