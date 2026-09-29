;;; init.el --- Your Hellmacs init file -*- lexical-binding: t; -*-

;; Loaded after Hellmacs' core, but BEFORE any module. Use it to choose
;; which modules load (the `hellmacs!' block) and to set variables that
;; modules read while loading. Everything else belongs in config.el.
;;
;; This file lives in `hellmacs-user-dir' (~/.config/hellmacs/ by
;; default, or $HELLMACSDIR), outside the Hellmacs git checkout, so
;; upgrading Hellmacs never touches it. Without it, Hellmacs uses the
;; `hellmacs!' block below (it reads this very file from static/).
;;
;; After changing this block, run `bin/hellmacs sync' (or `C-c h S').
;;
;; Modules load in the order listed. Comment a line out to disable a
;; module; +flags turn on optional behavior, documented at the top of
;; each module's config.el (modules/<group>/<name>/config.el).
;;
;; The list below is every module Hellmacs has or could have. Enabled by
;; default: what a JVM project needs. Entries marked [planned] are on the
;; roadmap (docs/roadmap.md) and [idea] ones aren't yet; neither exists,
;; so enabling one only warns "Unknown module ..., skipped" until it
;; lands. Every language names the server it would use; modules that
;; don't exist yet name what one would most likely wrap. To write one
;; yourself, start from static/module-template/.

(hellmacs! :ui
           theme              ; the Hellmacs theme, line numbers, current line
           dashboard          ; startup dashboard with the sigil, C-c h s
           modeline           ; minimal doom-modeline in the Hellmacs palette
           ;;emoji            ; [idea] emoji input and display
           ;;hl-todo          ; highlight TODO/FIXME/HACK/NOTE in comments; M-x hl-todo-next, hl-todo-occur
           ;;indent-guides    ; [idea] indentation guides
           ;;ligatures        ; [idea] font ligatures in graphical frames
           ;;minimap          ; [idea] a code minimap
           ;;nav-flash        ; [idea] flash the line after a big jump
           popup              ; help, builds, tests, REPLs, xref at the bottom; q closes, C-c w t toggles
           ;;tabs             ; [idea] tab-line tabs per window
           ;;treemacs         ; [idea] a project file tree
           ;;unicode          ; [idea] fallback fonts for every script
           ;;vc-gutter        ; changed lines in the fringe or terminal margin (diff-hl), C-x v [ ] * n S
           ;;window-select    ; [idea] pick a window by number (ace-window)
           ;;workspaces       ; [planned] tab-bar workspaces, one per project
           ;;zen              ; [idea] distraction-free writing (olivetti)

           :editor
           undo               ; persistent undo history (undo-fu-session)
           ;;file-templates   ; [planned] templates for new files (a Java class, a test)
           ;;fold             ; [idea] code folding (hideshow, treesit-fold)
           ;;format           ; formatters: google-java-format, ktfmt, cljfmt, on C-c l = = (+onsave)
           ;;multiple-cursors ; [idea] multiple cursors, on stock keys
           ;;parinfer         ; [idea] indentation-driven Lisp editing
           ;;smartparens      ; [idea] structural editing for Lisps and brackets
           ;;snippets         ; [planned] code snippets (yasnippet, tempel)
           ;;word-wrap        ; [idea] soft wrap that respects indentation

           :completion
           vertico            ; minibuffer completion + consult commands
           corfu              ; in-buffer completion popup (+tab: TAB completes)

           :emacs
           ;;dired            ; [idea] dired tweaks (dired-x, wdired, icons)
           ;;electric         ; [idea] smarter electric indentation
           ;;eww              ; [idea] the built-in web browser
           ;;ibuffer          ; [idea] ibuffer grouped by project
           ;;vc               ; [idea] built-in version control tweaks

           :term
           ;;eshell           ; [idea] eshell with project-aware prompts
           ;;shell            ; [idea] comint shells
           ;;eat              ; [idea] a terminal emulator in pure Elisp
           ;;vterm            ; [idea] a real terminal (needs a C toolchain)

           :checkers
           ;;static           ; Checkstyle, PMD, SpotBugs results from your build, as flymake diagnostics (+sonarlint: SonarLint, 227 MB)
           ;;syntax           ; [idea] flycheck instead of flymake (lsp diagnostics use flymake)
           ;;spell            ; [idea] spell checking (jinx)
           ;;grammar          ; [idea] grammar checking (LanguageTool, harper-ls)

           :tools
           build              ; build/test with Gradle or Maven (C-x p c), clickable errors
           debugger           ; debug via dap-mode, C-c d (Java: breakpoints, tests, hot swap)
           direnv             ; per-project environments from .envrc (JAVA_HOME, MAVEN_OPTS...); needs direnv
           lsp                ; code intelligence via lsp-mode, C-c l
           magit              ; Git via Magit: C-x g status, C-x M-g dispatch, C-c M-g file
           run                ; run configurations (.hellmacs/run.eld, IntelliJ .run/, Eclipse .launch), C-c r
           test               ; test results (JUnit XML) and JaCoCo coverage marks, C-c t (+watch)
           ;;ansible          ; [idea] Ansible playbooks
           ;;biblio           ; [idea] citations and bibliographies
           ;;db               ; databases over JDBC: sql-mode + sqlline, .hellmacs/db.eld, passwords in auth-source
           ;;docker           ; containers, images, logs and Compose (docker.el), C-c o d; your docker or podman
           ;;editorconfig     ; [planned] honour .editorconfig files
           ;;eval             ; [idea] run code in a REPL or inline, per language
           ;;forge            ; [idea] GitHub/GitLab pull requests from Magit
           ;;kubernetes       ; pods, logs, port forwards and shells (kubel), C-c o k; your kubectl and context
           ;;llm              ; [idea] LLM chat and code actions (gptel)
           ;;lookup           ; [idea] documentation and definition lookup beyond LSP (devdocs, dash)
           ;;make             ; [idea] run Makefile targets
           ;;pass             ; [idea] the pass password store
           ;;pdf              ; [idea] read PDFs (pdf-tools)
           ;;http             ; IntelliJ .http files: restclient, env files (+httpyac: JS handlers, needs Node)
           ;;rgb              ; [idea] show colours in code (rainbow-mode)
           ;;taskrunner       ; [idea] run npm, just, make and Gradle tasks
           ;;tmux             ; [idea] send commands to tmux
           ;;upload           ; [idea] sync files to remote servers

           :os
           ;;macos            ; [idea] macOS integration (Cmd keys, trash, open)
           ;;tty              ; [idea] terminal Emacs: clipboard, mouse, cursor shape

           :lang
           ;; JVM (Hellmacs' own). Each language server is pinned and installed by `sync'.
           (java +lombok +spring) ; Java: JDTLS, Spring Boot; a JDK 21+ (+lombok, +spring, +tree-sitter)
           kotlin             ; Kotlin: kotlin-language-server; a JDK (+tree-sitter)
           clojure            ; Clojure: CIDER REPL + clojure-lsp (+tree-sitter: Emacs 30.1+)
           ;;groovy           ; [planned] Groovy, Gradle scripts, Jenkinsfiles: groovy-language-server
           ;;scala            ; [planned] Scala: Metals, sbt (+tree-sitter)
           ;; Everything else. The name after the colon is the language server the
           ;; module would run through :tools lsp.
           ;;agda             ; [idea] Agda: agda-mode (no LSP)
           ;;beancount        ; [idea] Beancount: beancount-language-server
           ;;cc               ; [idea] C, C++, Objective-C: clangd
           ;;cmake            ; [idea] CMake: neocmakelsp
           ;;common-lisp      ; [idea] Common Lisp: SLY (REPL, no LSP)
           ;;coq              ; [idea] Rocq/Coq: coq-lsp, Proof General
           ;;crystal          ; [idea] Crystal: crystalline
           ;;csharp           ; [idea] C#: csharp-ls (Roslyn)
           ;;dart             ; [idea] Dart and Flutter: the Dart analysis server
           ;;data             ; XML (pom.xml, Spring XML): lemminx, pinned jar on a JDK
           ;;dhall            ; [idea] Dhall: dhall-lsp-server
           ;;docker           ; Dockerfile and Compose: docker-language-server (+tree-sitter)
           ;;elixir           ; [idea] Elixir: Expert (elixir-ls)
           ;;elm              ; [idea] Elm: elm-language-server
           ;;emacs-lisp       ; [idea] Emacs Lisp extras: macrostep, elisp-demos (no LSP)
           ;;erlang           ; [idea] Erlang: ELP (erlang_ls)
           ;;ess              ; [idea] R: languageserver, ESS
           ;;fortran          ; [idea] Fortran: fortls
           ;;fsharp           ; [idea] F#: fsautocomplete
           ;;gdscript         ; [idea] Godot GDScript: the Godot editor's server
           ;;gleam            ; [idea] Gleam: gleam lsp
           ;;go               ; [idea] Go: gopls
           ;;graphql          ; [idea] GraphQL: graphql-lsp
           ;;graphviz         ; [idea] Graphviz dot files (no LSP)
           ;;haskell          ; [idea] Haskell: haskell-language-server
           ;;janet            ; [idea] Janet: janet-lsp
           ;;javascript       ; [idea] JavaScript, TypeScript, JSX: vtsls (typescript-language-server)
           ;;json             ; JSON: vscode-json-language-server; needs Node (+tree-sitter)
           ;;julia            ; [idea] Julia: LanguageServer.jl
           ;;latex            ; [idea] LaTeX: texlab, AUCTeX
           ;;lean             ; [idea] Lean 4: the Lean server
           ;;ledger           ; [idea] Ledger accounting (no LSP)
           ;;lua              ; [idea] Lua: lua-language-server
           ;;markdown         ; Markdown: marksman
           ;;nim              ; [idea] Nim: nimlangserver
           ;;nix              ; [idea] Nix: nixd (nil)
           ;;ocaml            ; [idea] OCaml: ocaml-lsp-server
           ;;odin             ; [idea] Odin: ols
           ;;org              ; [idea] Org mode (no LSP)
           ;;php              ; [idea] PHP: phpactor (intelephense)
           ;;plantuml         ; [idea] PlantUML diagrams (no LSP)
           ;;protobuf         ; [idea] Protocol Buffers: buf
           ;;purescript       ; [idea] PureScript: purescript-language-server
           ;;python           ; [idea] Python: basedpyright, ruff
           ;;racket           ; [idea] Racket: racket-langserver
           ;;rst              ; [idea] reStructuredText: esbonio
           ;;ruby             ; [idea] Ruby: ruby-lsp
           ;;rust             ; [idea] Rust: rust-analyzer
           ;;scheme           ; [idea] Scheme: Geiser (no LSP)
           ;;sh               ; Shell scripts, gradlew/mvnw: bash-language-server; needs Node (+tree-sitter)
           ;;sml              ; [idea] Standard ML: millet
           ;;solidity         ; [idea] Solidity: nomicfoundation-solidity-language-server
           ;;sql              ; [idea] SQL: sqls
           ;;swift            ; [idea] Swift: sourcekit-lsp
           ;;terraform        ; [idea] Terraform and HCL: terraform-ls
           ;;toml             ; [idea] TOML: taplo
           ;;web              ; [idea] HTML and CSS: vscode-html/css-language-server
           ;;yaml             ; YAML: yaml-language-server; needs Node (+tree-sitter)
           ;;zig              ; [idea] Zig: zls

           :app
           ;;calendar         ; [idea] calendars (calfw)
           ;;irc              ; [idea] IRC (circe, erc)
           ;;rss              ; [idea] RSS feeds (elfeed)

           :email
           ;;mu4e             ; [idea] email with mu4e
           ;;notmuch          ; [idea] email with notmuch

           :config
           default)           ; C-c leader groups: h, q, w; which-key

;; Look and feel (all optional):
;; (setq hellmacs-theme 'modus-vivendi)   ; another theme; nil loads none
;; (setq hellmacs-splash-enable nil)      ; start on *scratch*, not the Altar
;; (setq hellmacs-ux-enable nil)          ; stock quit prompt and error messages

;;; init.el ends here
