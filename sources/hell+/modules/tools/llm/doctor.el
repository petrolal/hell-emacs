;;; tools/llm/doctor.el -*- lexical-binding: t; -*-

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

;; Health checks for the `:tools llm' agentic stack (`bin/hell doctor').

;;; Code:

(declare-function hell-doctor-ok "bin/hell-doctor" (format-string &rest args))
(declare-function hell-doctor-info "bin/hell-doctor" (format-string &rest args))

(hell-doctor-ok "Agentic AI stack (agent-shell/acp, gptel/mcp, minuet FIM) configured")

(let ((agents (delq nil
                    (mapcar (lambda (bin)
                              (and (executable-find bin) bin))
                            '("claude" "gemini" "opencode" "codex")))))
  (if agents
      (hell-doctor-ok "ACP agent CLIs found on PATH: %s" (string-join agents ", "))
    (hell-doctor-info "No external ACP agent CLI (claude, gemini, opencode, codex) found on PATH for agent-shell")))

(if-let* ((ollama (executable-find "ollama")))
    (hell-doctor-ok "Local LLM runtime (ollama): %s" (abbreviate-file-name ollama))
  (hell-doctor-info "ollama CLI not found on PATH; gptel and minuet will use remote API keys if configured"))

(provide 'tools-llm-doctor)
;;; doctor.el ends here
