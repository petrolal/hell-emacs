;;; lang/javascript/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;; License: GPL-3.0-or-later

(depends-on! :tools lsp)

;; TypeScript and TSX open in Emacs' own `typescript-ts-mode' and
;; `tsx-ts-mode' (13.7): `bin/hell sync' builds both grammars, the commit
;; Emacs 31's own modes recommend. No third-party typescript-mode.
;; JavaScript and JSX stay in Emacs' classic `js-mode', which needs none.
(hell-treesit!
 :grammars ((typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2"
                        "8e13e1db35b941fc57f2bd2dd4628180448c17d5" "typescript" :license "MIT")
            (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2"
                 "8e13e1db35b941fc57f2bd2dd4628180448c17d5" "tsx" :license "MIT")))
