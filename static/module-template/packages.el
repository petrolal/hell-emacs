;;; <group>/<name>/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; What this module installs and needs. Declarations only -- no
;; configuration, no side effects: this file is read before anything is
;; installed. See `package!' for the options (:recipe, :pin, :built-in,
;; :disable). Changes here take effect after `bin/hellmacs sync'.

;; Other modules this one needs; reported if they aren't enabled.
;; (depends-on! :tools lsp)

(package! example-package)

;; Only needed with the module's +extra flag:
(when (modulep! +extra)
  (package! example-extra))

;; Tree-sitter grammars (pinned) and the modes they enable; see
;; `hellmacs-treesit!'. Sync builds them, doctor checks them; the SBOM and
;; license report (`bin/hellmacs sbom', `licenses') take the :license.
;; (when (modulep! +tree-sitter)
;;   (hellmacs-treesit!
;;    :grammars ((example "https://github.com/..." "v1.0" "<full commit>" :license "MIT"))
;;    :remap ((example-mode . example-ts-mode))))
