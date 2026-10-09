;;; config/default/doctor.el -*- lexical-binding: t; no-byte-compile: t; -*-

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

;; Checked by `bin/hell doctor'.

;; `hell-handoff-open-file' (`C-c h e', lib/intellij.el): without a
;; working binary it still copies "file:line" to the kill ring, so
;; this is a warning, not an error -- there's always a fallback.
(hell-require 'hell-lib 'intellij)

(if (not (eq hell-handoff-editor 'auto))
    (let ((bin (hell-handoff--executable hell-handoff-editor)))
      (if bin
          (hell-doctor-ok "Handoff editor (%s): %s" hell-handoff-editor (abbreviate-file-name bin))
        (hell-doctor-warn :topic 'tools
                              "`hell-handoff-editor' is `%s', but no %s was found on the PATH; `C-c h e' will only copy \"file:line\""
                              hell-handoff-editor hell-handoff-editor)))
  (let ((found (hell-handoff--detect-editor)))
    (if found
        (hell-doctor-ok "Handoff editor: %s (auto-detected)" found)
      (hell-doctor-warn :topic 'tools
                            "No IntelliJ IDEA, Eclipse or VS Code found on the PATH for `C-c h e'; it will only copy \"file:line\""))))

;;; doctor.el ends here
