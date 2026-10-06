;;; tools/lsp/config.el -*- lexical-binding: t; -*-

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


;; Language-server support: completion, navigation, diagnostics and
;; refactoring from a language server. Language modules (`:lang java',
;; ...) start the server for their buffers; this module only sets up
;; the client.
;;
;; Keys, as Doom's: in a buffer with a server, the `C-c c' code group
;; gains the server's actions (`a' code action, `r' rename, `o' organize
;; imports, `f' format, `i' implementations, `t' type definition, `k'
;; documentation). lsp-mode's own keys are as it ships them (13.6): its
;; whole command map on `s-l' (`s-l w r' restart, `T' toggles, `g' goto,
;; ...), its mouse menu on `mouse-3', signature help on `C-S-SPC'. Diagnostics are
;; flymake's: `C-c s e' jumps to one. Emacs' xref keys work as
;; everywhere: `M-.' definition, `M-?' references, `M-,' back,
;; `C-M-.' search workspace symbols.
;;
;; The client is lsp-mode: lsp-java, dap-mode and the servers' own
;; extensions all build on it. Modules that need it say
;; `(depends-on! :tools lsp)' in their packages.el.

(defvar hell-lsp-read-process-output-max (* 1024 1024)
  "`read-process-output-max' while a language server runs.
Servers send large JSON payloads; lsp-mode recommends 1MB.")

(defun hell-lsp--tune-process-output-h ()
  "Read language-server output in large chunks."
  (setq read-process-output-max hell-lsp-read-process-output-max))


;;; lsp-mode ------------------------------------------------------------------

;; A Maven or Gradle build's output isn't watched: on Spring Framework,
;; Gradle's build/ and JDTLS's own bin/ took the watched directories
;; from 2726 to 6119 after one import and build, past
;; `lsp-file-watch-threshold', and the next session stopped to ask
;; (docs/roadmap.md, 12.7 Tuning). lsp-mode asks for the list from a
;; buffer whose file is under the workspace's root; only a JVM build's
;; root gets it, since elsewhere bin/ holds scripts.
(defun hell-lsp--ignore-build-output-a (dirs)
  "DIRS, and this workspace's build output (`hell-build-output-regexp')."
  (let ((root (and buffer-file-name (file-name-directory buffer-file-name))))
    (if (and root (seq-some (lambda (file) (file-exists-p (expand-file-name file root)))
                            hell-build-files))
        (cons (hell-build-output-regexp (file-truename root)) dirs)
      dirs)))

(defun hell-lsp-mode-used-p ()
  "Non-nil if lsp-mode is in use: declared (packages.el) and not disabled."
  (and (assq 'lsp-mode hell-packages)
       (not (hell-package-disabled-p 'lsp-mode))))

;; lsp-mode names its `s-l' groups for which-key, but needs which-key
;; loaded to: a file opened at startup can start lsp-mode first, and the
;; error would also stop the rest of the hook.
(declare-function lsp-enable-which-key-integration "lsp-mode")
(defun hell-lsp--which-key-h ()
  "Name lsp-mode's `s-l' groups in which-key, loading it if need be."
  (when (require 'which-key nil t)
    (lsp-enable-which-key-integration)))

(when (hell-lsp-mode-used-p)
  ;; Language servers allocate heavily; collect less often (lsp-mode's
  ;; performance guide). gcmh still collects when Emacs is idle.
  (setq gcmh-high-cons-threshold (* 128 1024 1024))

  (use-package lsp-mode
    ;; Loaded in the background after startup, so the first file that
    ;; needs a server doesn't also wait for lsp-mode itself. Its heavier
    ;; dependencies first, so no idle tick loads the whole tree at once.
    :defer-incrementally (dash f s ht spinner lv markdown-mode url-parse lsp-protocol
                          lsp-mode lsp-completion lsp-diagnostics lsp-modeline)
    :commands (lsp lsp-deferred)
    :custom
    (lsp-completion-provider :none)         ; plain completion-at-point, shown by corfu
    (lsp-diagnostics-provider :flymake)     ; built-in; no flycheck
    (lsp-log-io nil)
    (lsp-idle-delay 0.5)
    (lsp-keep-workspace-alive nil)
    (lsp-file-watch-threshold 5000)         ; big multi-module builds
    (lsp-headerline-breadcrumb-enable nil)
    (lsp-enable-snippet t)                  ; expanded by yasnippet (below)
    (lsp-session-file (hell-state-file "lsp-session"))
    :hook
    (lsp-mode . hell-lsp--which-key-h)
    (lsp-mode . hell-lsp--tune-process-output-h)
    (lsp-completion-mode . hell-lsp--setup-completion-h)))

;; The servers' snippets: completing a method inserts its arguments as
;; placeholders, and JDTLS's templates (`sysout', `foreach') and postfix
;; completion (`list.for', `x.nnull') expand. yasnippet expands them, and
;; only with `yas-minor-mode' on, so it's on where a server runs, with
;; no snippet directory read. Its keys are yasnippet's own (13.6): `TAB'
;; expands (and indents when there's nothing to expand), `C-c &' its
;; commands; inside an expansion `TAB' / `S-TAB' next / previous
;; placeholder, `C-g' leaves it.
(defvar yas-snippet-dirs)
(setq yas-snippet-dirs nil)
(add-hook 'lsp-mode-hook #'yas-minor-mode)

;; The server's actions in the `C-c c' code group (`:config default'),
;; only where lsp-mode runs. Diagnostics are flymake's, built into Emacs
;; (`lsp-diagnostics-provider' above), so Hell Emacs adds no key to them
;; (13.9): `C-c s e' jumps to one, `M-x flymake-goto-next-error' and
;; `M-x flymake-show-buffer-diagnostics' do the rest. Bound directly on
;; `lsp-mode-map' rather than via `hell-leader-def' so the keys exist
;; only where lsp-mode runs; `a r o f i t k' are reserved here and must
;; stay free in `:config default's leader "code" group.
(defvar lsp-mode-map)
(after! lsp-mode
  (keymap-set lsp-mode-map "C-c c a" (cons "code action" #'lsp-execute-code-action))
  (keymap-set lsp-mode-map "C-c c r" (cons "rename" #'lsp-rename))
  (keymap-set lsp-mode-map "C-c c o" (cons "organize imports" #'lsp-organize-imports))
  (keymap-set lsp-mode-map "C-c c f" (cons "format buffer" #'lsp-format-buffer))
  (keymap-set lsp-mode-map "C-c c i" (cons "find implementations" #'lsp-find-implementation))
  (keymap-set lsp-mode-map "C-c c t" (cons "find type definition" #'lsp-find-type-definition))
  (keymap-set lsp-mode-map "C-c c k" (cons "documentation at point" #'lsp-describe-thing-at-point)))

;; Cape's recipe for a server's completion: bust its cache as the input
;; changes, so candidates are fetched afresh rather than filtered from a
;; stale first list. Advised once, globally, so the completion functions
;; in each buffer stay lsp-mode's own (it adds and removes them itself).
;; cape comes with `:completion corfu'.
(when (hell-lsp-mode-used-p)
  (when (fboundp 'cape-wrap-buster)
    (advice-add 'lsp-completion-at-point :around #'cape-wrap-buster))
  (advice-add 'lsp-file-watch-ignored-directories :filter-return
              #'hell-lsp--ignore-build-output-a)

  ;; lsp-mode only uses plists if it was *compiled* with LSP_USE_PLISTS
  ;; set; if the variable says plists but the compiled code expects hash
  ;; tables, every server response is misread. `lsp-doctor' only checks
  ;; the variable, so check the compiled accessors themselves.
  (with-eval-after-load 'lsp-protocol
    (when (and (bound-and-true-p lsp-use-plists)
               (fboundp 'lsp:position-line)
               (not (equal (ignore-errors (lsp:position-line '(:line 3 :character 0))) 3)))
      (display-warning
       'hell
       "lsp-mode was compiled without LSP_USE_PLISTS, so it misreads language servers. \
Run `bin/hell sync' to rebuild it."
       :error))))
