;;; hellmacs-inferno-theme.el --- Hellmacs' infernal dark theme -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; A self-contained `deftheme' (no dependencies), built from one token
;; table, `hellmacs-inferno-palette', so every colour is defined once:
;;
;;   bg-main          #16171d  deep charcoal altar: the background
;;   bg-alt           #1c1e24  mode-line, popups, current line
;;   fg-main          #bbc2cf  bone white text
;;   inferno-crimson  #ff6c6b  primary flame: headers, errors, cursor
;;   ember-amber      #da8548  secondary fire: warnings, subheadings, keywords
;;   reap-gold        #ecbe7b  sigil accents, operators, functions, shortcuts
;;   forge-gray       #5b6268  borders, fringes, inactive line numbers
;;
;; plus two colours the seven tokens lack (docs/roadmap.md, Phase 9):
;;
;;   venom-green      #98be65  success, strings, added lines
;;   forge-gray-hi    #868f96  comments, doc strings, dimmed text
;;
;; forge-gray is 2.9:1 on bg-main, too faint to read, so it is kept for
;; borders and inactive line numbers and anything read uses
;; forge-gray-hi (5.4:1). Every other text colour is 5.9:1 or better on
;; both backgrounds.
;;
;; The derived shades (the second half of the table) are surfaces only:
;; selection, highlights, diff tints. Each is dark enough that the text
;; drawn on it here stays at 4.5:1 or better.
;;
;; Covers the built-in faces, font-lock (tree-sitter included), the
;; completion stack (vertico, orderless, marginalia, consult, corfu,
;; which-key), line numbers, mode-lines, compilation, flymake, eglot,
;; comint and CIDER, lsp-mode, dap-mode, Magit, the dashboard and
;; doom-modeline, and Hellmacs' own faces.
;;
;; Load it with (load-theme 'hellmacs-inferno t); the `:ui theme'
;; module does.

;;; Code:

(deftheme hellmacs-inferno
  "Infernal dark theme: charcoal altar, crimson flame, amber and gold.")

(eval-and-compile
  (defconst hellmacs-inferno-palette
    '(;; The tokens.
      (bg-main         . "#16171d")
      (bg-alt          . "#1c1e24")
      (fg-main         . "#bbc2cf")
      (inferno-crimson . "#ff6c6b")
      (ember-amber     . "#da8548")
      (reap-gold       . "#ecbe7b")
      (forge-gray      . "#5b6268")
      (venom-green     . "#98be65")
      (forge-gray-hi   . "#868f96")
      ;; Derived shades: backgrounds only.
      (bg-hl           . "#23262e")   ; hover, `highlight', lsp symbol highlights
      (bg-deep         . "#111217")   ; inactive mode-line
      (bg-soot         . "#2c2f38")   ; matching paren, secondary selection
      (bg-ember        . "#42252b")   ; region; removed lines, highlighted
      (bg-smolder      . "#2f1f24")   ; popup candidate, removed lines, debug marker
      (bg-rust         . "#3a2a1a")   ; lazy search matches
      (bg-moss         . "#1e2a1c")   ; added lines
      (bg-moss-hl      . "#2a3b25"))  ; added lines, highlighted
    "Every colour of the `hellmacs-inferno' theme, by name."))

(defmacro hellmacs-inferno--with-palette (&rest body)
  "Run BODY with each colour of `hellmacs-inferno-palette' bound by name."
  (declare (indent 0))
  `(let ,(mapcar (lambda (c) (list (car c) (cdr c))) hellmacs-inferno-palette)
     ,@body))

(hellmacs-inferno--with-palette
  (custom-theme-set-faces
   'hellmacs-inferno

   ;;; Basics
   `(default ((t (:background ,bg-main :foreground ,fg-main))))
   `(cursor ((t (:background ,inferno-crimson))))
   `(fringe ((t (:background ,bg-main :foreground ,forge-gray))))
   `(region ((t (:background ,bg-ember :extend t))))
   `(secondary-selection ((t (:background ,bg-soot :extend t))))
   `(highlight ((t (:background ,bg-hl :foreground ,reap-gold))))
   `(hl-line ((t (:background ,bg-alt :extend t))))
   `(shadow ((t (:foreground ,forge-gray-hi))))
   `(vertical-border ((t (:foreground ,forge-gray))))
   `(window-divider ((t (:foreground ,forge-gray))))
   `(window-divider-first-pixel ((t (:foreground ,forge-gray))))
   `(window-divider-last-pixel ((t (:foreground ,forge-gray))))
   `(minibuffer-prompt ((t (:foreground ,reap-gold :weight bold))))
   `(link ((t (:foreground ,reap-gold :underline t))))
   `(link-visited ((t (:foreground ,ember-amber :underline t))))
   `(button ((t (:inherit link))))
   `(escape-glyph ((t (:foreground ,inferno-crimson))))
   `(homoglyph ((t (:foreground ,inferno-crimson))))
   `(trailing-whitespace ((t (:background ,inferno-crimson))))
   `(tooltip ((t (:background ,bg-alt :foreground ,fg-main))))
   `(header-line ((t (:background ,bg-alt :foreground ,fg-main))))
   `(error ((t (:foreground ,inferno-crimson :weight bold))))
   `(warning ((t (:foreground ,ember-amber :weight bold))))
   `(success ((t (:foreground ,venom-green :weight bold))))
   `(match ((t (:foreground ,bg-main :background ,reap-gold))))
   `(isearch ((t (:foreground ,bg-main :background ,reap-gold :weight bold))))
   `(isearch-fail ((t (:foreground ,bg-main :background ,inferno-crimson))))
   `(lazy-highlight ((t (:foreground ,reap-gold :background ,bg-rust))))
   `(show-paren-match ((t (:foreground ,reap-gold :background ,bg-soot :weight bold))))
   `(show-paren-mismatch ((t (:foreground ,bg-main :background ,inferno-crimson :weight bold))))

   ;;; Line numbers
   `(line-number ((t (:foreground ,forge-gray :background ,bg-main))))
   `(line-number-current-line ((t (:foreground ,inferno-crimson :background ,bg-alt :weight bold))))
   `(line-number-major-tick ((t (:inherit line-number :weight bold))))
   `(line-number-minor-tick ((t (:inherit line-number))))

   ;;; Mode-line
   `(mode-line ((t (:background ,bg-alt :foreground ,fg-main :box (:line-width 1 :color ,bg-alt)))))
   `(mode-line-active ((t (:inherit mode-line))))
   `(mode-line-inactive ((t (:background ,bg-deep :foreground ,forge-gray-hi :box (:line-width 1 :color ,bg-deep)))))
   `(mode-line-buffer-id ((t (:foreground ,reap-gold :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,inferno-crimson :weight bold))))
   `(mode-line-highlight ((t (:box (:line-width 1 :color ,reap-gold)))))

   ;;; Tab-bar / Workspaces (:ui workspaces)
   `(tab-bar ((t (:background ,bg-deep :foreground ,forge-gray-hi))))
   `(tab-bar-tab ((t (:background ,bg-alt :foreground ,reap-gold :weight bold :box (:line-width (1 . 1) :color ,ember-amber)))))
   `(tab-bar-tab-inactive ((t (:background ,bg-deep :foreground ,forge-gray-hi :box (:line-width (1 . 1) :color ,bg-deep)))))
   `(tab-bar-tab-group-current ((t (:inherit tab-bar-tab))))
   `(tab-bar-tab-group-inactive ((t (:inherit tab-bar-tab-inactive))))

   ;;; Font-lock
   `(font-lock-keyword-face ((t (:foreground ,ember-amber :weight bold))))
   `(font-lock-builtin-face ((t (:foreground ,ember-amber))))
   `(font-lock-function-name-face ((t (:foreground ,reap-gold))))
   `(font-lock-function-call-face ((t (:foreground ,reap-gold))))
   `(font-lock-string-face ((t (:foreground ,venom-green))))
   `(font-lock-doc-face ((t (:foreground ,forge-gray-hi :slant italic))))
   `(font-lock-doc-markup-face ((t (:foreground ,reap-gold :slant italic))))
   `(font-lock-comment-face ((t (:foreground ,forge-gray-hi :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:inherit font-lock-comment-face))))
   `(font-lock-type-face ((t (:foreground ,fg-main :weight bold))))
   `(font-lock-constant-face ((t (:foreground ,inferno-crimson))))
   `(font-lock-number-face ((t (:foreground ,ember-amber))))
   `(font-lock-variable-name-face ((t (:foreground ,fg-main))))
   `(font-lock-variable-use-face ((t (:foreground ,fg-main))))
   `(font-lock-property-name-face ((t (:foreground ,fg-main))))
   `(font-lock-property-use-face ((t (:foreground ,fg-main))))
   `(font-lock-preprocessor-face ((t (:foreground ,ember-amber :slant italic))))
   `(font-lock-warning-face ((t (:foreground ,ember-amber :weight bold))))
   `(font-lock-negation-char-face ((t (:foreground ,inferno-crimson))))
   `(font-lock-escape-face ((t (:foreground ,inferno-crimson))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,inferno-crimson))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,reap-gold))))
   `(font-lock-operator-face ((t (:foreground ,reap-gold))))
   `(font-lock-bracket-face ((t (:foreground ,fg-main))))
   `(font-lock-delimiter-face ((t (:foreground ,fg-main))))
   `(font-lock-punctuation-face ((t (:foreground ,fg-main))))
   `(font-lock-misc-punctuation-face ((t (:foreground ,fg-main))))

   ;;; Built-in completion
   `(completions-common-part ((t (:foreground ,reap-gold :weight bold))))
   `(completions-first-difference ((t (:foreground ,inferno-crimson :weight bold))))
   `(completions-annotations ((t (:foreground ,forge-gray-hi :slant italic))))
   `(completions-highlight ((t (:background ,bg-hl :foreground ,reap-gold))))

   ;;; Vertico / orderless / marginalia / consult
   `(vertico-current ((t (:background ,bg-hl :foreground ,reap-gold :weight bold :extend t))))
   `(vertico-group-title ((t (:foreground ,ember-amber :slant italic))))
   `(vertico-group-separator ((t (:foreground ,forge-gray :strike-through t))))
   `(vertico-multiline ((t (:foreground ,forge-gray-hi))))
   `(orderless-match-face-0 ((t (:foreground ,reap-gold :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,venom-green :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,inferno-crimson :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,ember-amber :weight bold :underline t))))
   `(marginalia-documentation ((t (:foreground ,forge-gray-hi :slant italic))))
   `(marginalia-key ((t (:foreground ,reap-gold))))
   `(marginalia-file-priv-dir ((t (:foreground ,ember-amber))))
   `(consult-preview-line ((t (:background ,bg-alt :extend t))))
   `(consult-preview-match ((t (:inherit isearch))))
   `(consult-file ((t (:foreground ,fg-main))))
   `(consult-bookmark ((t (:foreground ,reap-gold))))

   ;;; Corfu
   `(corfu-default ((t (:background ,bg-alt :foreground ,fg-main))))
   `(corfu-current ((t (:background ,bg-smolder :foreground ,reap-gold :weight bold))))
   `(corfu-bar ((t (:background ,inferno-crimson))))
   `(corfu-border ((t (:background ,forge-gray))))
   `(corfu-annotations ((t (:foreground ,forge-gray-hi :slant italic))))
   `(corfu-deprecated ((t (:foreground ,forge-gray-hi :strike-through t))))
   `(corfu-popupinfo ((t (:inherit corfu-default))))

   ;;; which-key
   `(which-key-key-face ((t (:foreground ,reap-gold :weight bold))))
   `(which-key-separator-face ((t (:foreground ,forge-gray))))
   `(which-key-command-description-face ((t (:foreground ,fg-main))))
   `(which-key-group-description-face ((t (:foreground ,inferno-crimson))))
   `(which-key-local-map-description-face ((t (:foreground ,venom-green))))
   `(which-key-note-face ((t (:foreground ,forge-gray-hi))))

   ;;; Compilation, diagnostics, REPLs
   `(compilation-error ((t (:foreground ,inferno-crimson :weight bold))))
   `(compilation-warning ((t (:foreground ,ember-amber :weight bold))))
   `(compilation-info ((t (:foreground ,venom-green))))
   `(compilation-line-number ((t (:foreground ,forge-gray-hi))))
   `(compilation-column-number ((t (:foreground ,forge-gray-hi))))
   `(compilation-mode-line-exit ((t (:foreground ,venom-green :weight bold))))
   `(compilation-mode-line-fail ((t (:foreground ,inferno-crimson :weight bold))))
   `(flymake-error ((t (:underline (:style wave :color ,inferno-crimson)))))
   `(flymake-warning ((t (:underline (:style wave :color ,ember-amber)))))
   `(flymake-note ((t (:underline (:style wave :color ,venom-green)))))
   `(eglot-highlight-symbol-face ((t (:background ,bg-soot :weight bold))))
   `(eglot-mode-line ((t (:foreground ,venom-green :weight bold))))
   `(comint-highlight-prompt ((t (:foreground ,reap-gold :weight bold))))
   `(comint-highlight-input ((t (:foreground ,fg-main :weight bold))))
   `(cider-result-overlay-face ((t (:foreground ,venom-green :background ,bg-alt))))
   `(cider-repl-result-face ((t (:foreground ,venom-green))))
   `(cider-error-highlight-face ((t (:underline (:style wave :color ,inferno-crimson)))))

   ;;; lsp-mode
   `(lsp-face-highlight-textual ((t (:background ,bg-soot))))
   `(lsp-face-highlight-read ((t (:background ,bg-soot :underline (:color ,venom-green)))))
   `(lsp-face-highlight-write ((t (:background ,bg-soot :underline (:color ,inferno-crimson) :weight bold))))
   `(lsp-face-rename ((t (:background ,bg-ember :foreground ,fg-main))))
   `(lsp-rename-placeholder-face ((t (:foreground ,reap-gold))))
   `(lsp-lens-face ((t (:foreground ,forge-gray-hi :height 0.9))))
   `(lsp-lens-mouse-face ((t (:foreground ,reap-gold :underline t :height 0.9))))
   `(lsp-inlay-hint-face ((t (:foreground ,forge-gray-hi :slant italic))))
   `(lsp-signature-highlight-function-argument ((t (:foreground ,reap-gold :weight bold))))
   `(lsp-details-face ((t (:foreground ,forge-gray-hi :height 0.9))))
   `(lsp-modeline-code-actions-face ((t (:foreground ,reap-gold))))
   `(lsp-modeline-code-actions-preferred-face ((t (:foreground ,venom-green :weight bold))))
   `(lsp-installation-buffer-face ((t (:foreground ,ember-amber))))
   `(lsp-installation-finished-buffer-face ((t (:foreground ,venom-green))))

   ;;; dap-mode
   `(dap-ui-pending-breakpoint-face ((t (:underline (:color ,forge-gray)))))
   `(dap-ui-verified-breakpoint-face ((t (:background ,bg-ember :extend t))))
   `(dap-ui-breakpoint-verified-fringe ((t (:foreground ,inferno-crimson :weight bold))))
   `(dap-ui-marker-face ((t (:background ,bg-smolder :extend t))))
   `(dap-ui-compile-errline ((t (:foreground ,inferno-crimson :weight bold))))
   `(dap-result-overlay-face ((t (:foreground ,venom-green :background ,bg-alt))))
   `(dap-ui-sessions-active-session-face ((t (:foreground ,reap-gold :weight bold))))
   `(dap-ui-sessions-running-face ((t (:foreground ,venom-green))))
   `(dap-ui-sessions-terminated-face ((t (:foreground ,forge-gray-hi))))
   `(dap-ui-sessions-terminated-active-face ((t (:foreground ,forge-gray-hi :weight bold))))
   `(dap-ui-sessions-thread-face ((t (:foreground ,fg-main))))
   `(dap-ui-sessions-thread-active-face ((t (:foreground ,reap-gold))))
   `(dap-ui-sessions-stack-frame-face ((t (:foreground ,fg-main))))
   `(dap-ui-locals-scope-face ((t (:foreground ,ember-amber :weight bold))))
   `(dap-ui-locals-variable-face ((t (:foreground ,fg-main :weight bold))))
   `(dap-ui-locals-variable-leaf-face ((t (:foreground ,fg-main))))

   ;;; Magit
   `(magit-section-heading ((t (:foreground ,ember-amber :weight bold))))
   `(magit-section-secondary-heading ((t (:foreground ,reap-gold))))
   `(magit-section-highlight ((t (:background ,bg-alt :extend t))))
   `(magit-section-heading-selection ((t (:foreground ,inferno-crimson :weight bold))))
   `(magit-section-child-count ((t (:foreground ,forge-gray-hi))))
   `(magit-header-line ((t (:foreground ,inferno-crimson :weight bold))))
   `(magit-dimmed ((t (:foreground ,forge-gray-hi))))
   `(magit-hash ((t (:foreground ,forge-gray-hi))))
   `(magit-tag ((t (:foreground ,reap-gold))))
   `(magit-filename ((t (:foreground ,fg-main))))
   `(magit-branch-local ((t (:foreground ,reap-gold))))
   `(magit-branch-remote ((t (:foreground ,venom-green))))
   `(magit-branch-remote-head ((t (:foreground ,venom-green :box (:line-width 1 :color ,venom-green)))))
   `(magit-branch-current ((t (:foreground ,reap-gold :box (:line-width 1 :color ,reap-gold)))))
   `(magit-branch-upstream ((t (:slant italic))))
   `(magit-branch-warning ((t (:foreground ,ember-amber))))
   `(magit-head ((t (:foreground ,reap-gold :weight bold))))
   `(magit-keyword ((t (:foreground ,venom-green))))
   `(magit-log-author ((t (:foreground ,ember-amber))))
   `(magit-log-date ((t (:foreground ,forge-gray-hi))))
   `(magit-log-graph ((t (:foreground ,forge-gray-hi))))
   `(magit-diff-file-heading ((t (:foreground ,fg-main :weight bold))))
   `(magit-diff-file-heading-highlight ((t (:background ,bg-alt :weight bold))))
   `(magit-diff-file-heading-selection ((t (:background ,bg-alt :foreground ,reap-gold))))
   `(magit-diff-hunk-heading ((t (:background ,bg-alt :foreground ,forge-gray-hi :extend t))))
   `(magit-diff-hunk-heading-highlight ((t (:background ,bg-soot :foreground ,fg-main :extend t))))
   `(magit-diff-hunk-heading-selection ((t (:background ,bg-soot :foreground ,reap-gold :extend t))))
   `(magit-diff-hunk-region ((t (:inherit bold))))
   `(magit-diff-context ((t (:foreground ,forge-gray-hi :extend t))))
   `(magit-diff-context-highlight ((t (:background ,bg-alt :foreground ,fg-main :extend t))))
   `(magit-diff-added ((t (:background ,bg-moss :foreground ,venom-green :extend t))))
   `(magit-diff-added-highlight ((t (:background ,bg-moss-hl :foreground ,venom-green :extend t))))
   `(magit-diff-removed ((t (:background ,bg-smolder :foreground ,inferno-crimson :extend t))))
   `(magit-diff-removed-highlight ((t (:background ,bg-ember :foreground ,fg-main :extend t))))
   `(magit-diff-lines-heading ((t (:background ,reap-gold :foreground ,bg-main))))
   `(magit-diff-whitespace-warning ((t (:background ,inferno-crimson))))
   `(magit-diffstat-added ((t (:foreground ,venom-green))))
   `(magit-diffstat-removed ((t (:foreground ,inferno-crimson))))
   `(magit-blame-heading ((t (:background ,bg-alt :foreground ,forge-gray-hi :extend t))))
   `(magit-blame-highlight ((t (:background ,bg-alt :foreground ,fg-main :extend t))))
   `(magit-blame-hash ((t (:foreground ,forge-gray-hi))))
   `(magit-blame-name ((t (:foreground ,ember-amber))))
   `(magit-blame-date ((t (:foreground ,forge-gray-hi))))
   `(magit-blame-summary ((t (:foreground ,fg-main))))
   `(magit-process-ok ((t (:foreground ,venom-green :weight bold))))
   `(magit-process-ng ((t (:foreground ,inferno-crimson :weight bold))))
   `(magit-mode-line-process ((t (:foreground ,ember-amber))))
   `(magit-mode-line-process-error ((t (:foreground ,inferno-crimson :weight bold))))
   `(magit-signature-good ((t (:foreground ,venom-green))))
   `(magit-signature-bad ((t (:foreground ,inferno-crimson :weight bold))))
   `(magit-signature-untrusted ((t (:foreground ,ember-amber))))
   `(magit-cherry-equivalent ((t (:foreground ,reap-gold))))
   `(magit-cherry-unmatched ((t (:foreground ,venom-green))))
   `(git-commit-summary ((t (:foreground ,fg-main :weight bold))))
   `(git-commit-overlong-summary ((t (:foreground ,inferno-crimson :weight bold))))
   `(git-commit-nonempty-second-line ((t (:foreground ,inferno-crimson :weight bold))))
   `(git-commit-keyword ((t (:foreground ,reap-gold))))
   `(git-commit-trailer-token ((t (:foreground ,ember-amber))))
   `(git-commit-trailer-value ((t (:foreground ,fg-main))))
   `(git-commit-comment-heading ((t (:foreground ,ember-amber :slant italic))))
   `(git-commit-comment-file ((t (:foreground ,fg-main :slant italic))))
   `(git-commit-comment-branch-local ((t (:foreground ,reap-gold))))
   `(git-commit-comment-branch-remote ((t (:foreground ,venom-green))))

   ;;; Dashboard (:ui dashboard)
   `(dashboard-banner-logo-title ((t (:foreground ,inferno-crimson :weight bold))))
   `(dashboard-text-banner ((t (:foreground ,inferno-crimson :weight bold))))
   `(dashboard-heading ((t (:foreground ,ember-amber :weight bold))))
   `(dashboard-items-face ((t (:foreground ,fg-main :weight normal))))
   `(dashboard-no-items-face ((t (:foreground ,forge-gray-hi :slant italic))))
   `(dashboard-navigator ((t (:foreground ,reap-gold))))
   `(dashboard-footer-face ((t (:foreground ,reap-gold :slant italic))))
   `(dashboard-footer-icon-face ((t (:foreground ,inferno-crimson))))

   ;;; doom-modeline (:ui modeline). The rest of its faces inherit these.
   `(doom-modeline ((t (:foreground ,fg-main))))
   `(doom-modeline-bar ((t (:background ,inferno-crimson))))
   `(doom-modeline-bar-inactive ((t (:background ,bg-deep))))
   `(doom-modeline-emphasis ((t (:foreground ,inferno-crimson))))
   `(doom-modeline-highlight ((t (:foreground ,reap-gold))))
   `(doom-modeline-panel ((t (:foreground ,bg-main :background ,reap-gold))))
   `(doom-modeline-buffer-file ((t (:foreground ,reap-gold :weight bold))))
   `(doom-modeline-buffer-path ((t (:foreground ,forge-gray-hi :weight bold))))
   `(doom-modeline-buffer-modified ((t (:foreground ,inferno-crimson :weight bold))))
   `(doom-modeline-buffer-major-mode ((t (:foreground ,ember-amber :weight bold))))
   `(doom-modeline-project-dir ((t (:foreground ,venom-green :weight bold))))
   `(doom-modeline-project-root-dir ((t (:foreground ,ember-amber :weight bold))))
   `(doom-modeline-info ((t (:foreground ,venom-green :weight bold))))
   `(doom-modeline-warning ((t (:foreground ,ember-amber :weight bold))))
   `(doom-modeline-urgent ((t (:foreground ,inferno-crimson :weight bold))))
   `(doom-modeline-debug ((t (:foreground ,forge-gray-hi))))
   `(doom-modeline-debug-visual ((t (:foreground ,bg-main :background ,ember-amber))))
   `(doom-modeline-vcs-default ((t (:foreground ,reap-gold))))
   `(doom-modeline-compilation ((t (:foreground ,ember-amber :slant italic))))

   ;;; Hellmacs JVM status (the :lang java mode-line segment, Phase 6.2)
   `(hellmacs-jvm-busy ((t (:foreground ,ember-amber :weight bold))))
   `(hellmacs-jvm-ready ((t (:foreground ,venom-green :weight bold))))
   `(hellmacs-jvm-failed ((t (:foreground ,inferno-crimson :weight bold))))

   ;;; Hellmacs' own faces (defined in modules/hellmacs/+splash.el and
   ;;; modules/hellmacs/+ux.el, with these colours as defaults)
   `(hellmacs-splash-sigil ((t (:foreground ,inferno-crimson :weight bold))))
   `(hellmacs-splash-tagline ((t (:foreground ,reap-gold :weight bold))))
   `(hellmacs-splash-altar ((t (:foreground ,venom-green :weight bold))))
   `(hellmacs-splash-hint ((t (:foreground ,forge-gray-hi))))
   `(hellmacs-splash-border ((t (:foreground ,inferno-crimson :weight bold))))
   `(hellmacs-splash-section-heading ((t (:foreground ,ember-amber :weight bold))))
   `(hellmacs-splash-item ((t (:foreground ,fg-main))))
   `(hellmacs-splash-item-active ((t (:foreground ,reap-gold :underline t :weight bold))))
   `(hellmacs-splash-button ((t (:box (:line-width (1 . 1) :color ,bg-alt) :background ,bg-alt :foreground ,fg-main :weight bold))))
   `(hellmacs-splash-button-active ((t (:box (:line-width (1 . 1) :color ,inferno-crimson) :background ,bg-hl :foreground ,reap-gold :weight bold))))
   `(hellmacs-fatality ((t (:foreground ,inferno-crimson :weight bold))))))

;;;###autoload
(when (and (boundp 'custom-theme-load-path) load-file-name)
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'hellmacs-inferno)
;;; hellmacs-inferno-theme.el ends here
