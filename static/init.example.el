;;; init.el --- Your Hell Emacs init file -*- lexical-binding: t; -*-

;; Loaded after Hell Emacs' core, but BEFORE any module. Use it to choose
;; which modules load (the `hell!' block) and to set variables that
;; modules read while loading. Everything else belongs in config.el.
;;
;; This file lives in `hell-user-dir' (~/.config/hell-emacs/ by
;; default, or $HELLDIR), outside the Hell Emacs git checkout, so
;; upgrading Hell Emacs never touches it. Without it, Hell Emacs uses the
;; `hell!' block below (it reads this very file from static/).
;;
;; After changing this block, run `bin/hell sync' (or `C-c h S').
;;
;; Modules load in the order listed. Comment a line out to disable a
;; module; +flags turn on optional behavior, documented at the top of
;; each module's config.el (sources/hell+/modules/<group>/<name>/config.el).
;;
;; The list below is every module Hell Emacs has or could have. Enabled by
;; default: what a JVM project needs. Entries marked [planned] are on the
;; roadmap (docs/roadmap.md) and [idea] ones aren't yet; neither exists,
;; so enabling one only warns "Unknown module ..., skipped" until it
;; lands. Every language names the server it would use; modules that
;; don't exist yet name what one would most likely wrap. To write one
;; yourself, start from static/module-template/.

(hell! :ui
           theme              ; the Hell Emacs theme, line numbers, current line
           ;;emoji            ; [idea] emoji input and display
           hl-todo            ; highlight TODO/FIXME/HACK/NOTE in comments; M-x hl-todo-next, hl-todo-occur
           indent-guides      ; indentation guides (highlight-indent-guides)
           ;;ligatures        ; [idea] font ligatures in graphical frames
           ;;minimap          ; [idea] a code minimap
           ;;nav-flash        ; [idea] flash the line after a big jump
           ;;tabs             ; [idea] tab-line tabs per window
           ;;treemacs         ; [idea] a project file tree
           ;;unicode          ; [idea] fallback fonts for every script
           ;;vc-gutter        ; changed lines in the fringe or terminal margin (diff-hl), C-x v [ ] * n S
           ;;window-select    ; [idea] pick a window by number (ace-window)
           ;;workspaces       ; tab-bar workspaces with project-named tabs, on stock C-x t
           ;;zen              ; [idea] distraction-free writing (olivetti)

           :editor
           undo               ; persistent undo history (undo-fu-session)
           file-templates     ; new files filled from a template (auto-insert): FooTest.java gets its package, imports and class; needs snippets
           fold               ; code folding on stock C-c @ (treesit-fold, hideshow)
           format             ; formatters: google-java-format, ktfmt, cljfmt, on C-c c f (+onsave)
           ;;multiple-cursors ; multiple cursors (mc/iedit), on stock keys + C-c c e/m
           ;;parinfer         ; indentation-driven Lisp editing (parinfer-rust-mode)
           ;;smartparens      ; structural editing for Lisps and brackets
           snippets           ; snippets (tempel): junit, controller, dataclass, deftest, munit; complete a name with C-M-i
           ;;word-wrap        ; [idea] soft wrap that respects indentation

           :completion
           vertico            ; minibuffer completion + consult commands
           corfu              ; in-buffer completion popup (+tab: TAB completes)

           :emacs
           dired              ; enhanced dired (nerd-icons, wdired)
           ;;eww              ; [idea] the built-in web browser
           ;;ibuffer          ; [idea] ibuffer grouped by project
           ;;vc               ; [idea] built-in version control tweaks

           :term
           ;;eshell           ; eshell with project-aware prompts, elisp-native, C-c o e
           ;;shell            ; comint shells, C-c o s
           eat                ; a terminal emulator in pure Elisp, C-c o T/o P
           ;;vterm            ; a real terminal (needs a C toolchain), C-c o t

           :checkers
           static             ; Checkstyle, PMD, SpotBugs results from your build, as flymake diagnostics (+sonarlint: SonarLint, 227 MB)
           ;;syntax           ; [idea] flycheck instead of flymake (lsp diagnostics use flymake)
           ;;spell            ; [idea] spell checking (jinx)
           ;;grammar          ; [idea] grammar checking (LanguageTool, harper-ls)

           :tools
           build              ; build/test with Gradle or Maven (C-x p c), clickable errors
           debugger           ; debug via dap-mode, C-c d (Java: breakpoints, tests, hot swap)
           direnv             ; per-project environments from .envrc (JAVA_HOME, MAVEN_OPTS...); needs direnv
           lsp                ; code intelligence via lsp-mode, C-c c (lsp-mode's own map on s-l)
           magit              ; Git via Magit: C-x g status, C-x M-g dispatch, C-c M-g file
           run                ; run configurations (.hell-emacs/run.eld, IntelliJ .run/, Eclipse .launch), C-c r
           test               ; test results (JUnit XML) and JaCoCo coverage marks, C-c l t (+watch)
           ;;ansible          ; [idea] Ansible playbooks
           ;;biblio           ; [idea] citations and bibliographies
           db                 ; databases over JDBC: sql-mode + sqlline, .hell-emacs/db.eld, passwords in auth-source
           docker             ; containers, images, logs and Compose (docker.el), C-c o d; your docker or podman
           editorconfig       ; the project's .editorconfig: indentation, charset, line endings (built in)
           ;;eval             ; quick inline run via quickrun, C-c c q/c Q
           forge              ; GitHub/GitLab pull requests from Magit
           kubernetes         ; pods, logs, port forwards and shells (kubel), C-c o k; your kubectl and context
           ;;llm              ; [idea] LLM chat and code actions (gptel)
           ;;lookup           ; documentation and definition lookup (devdocs)
           ;;make             ; run Makefile targets (makefile-executor)
           ;;pass             ; [idea] the pass password store
           ;;pdf              ; [idea] read PDFs (pdf-tools)
           http               ; IntelliJ .http files: restclient, env files (+httpyac: JS handlers, needs Node)
           ;;rgb              ; [idea] show colours in code (rainbow-mode)
           ;;taskrunner       ; [idea] run npm, just, make and Gradle tasks
           ;;tmux             ; [idea] send commands to tmux
           ;;upload           ; [idea] sync files to remote servers

           :os
           ;;macos            ; [idea] macOS integration (Cmd keys, trash, open)
           ;;tty              ; [idea] terminal Emacs: clipboard, mouse, cursor shape

           :lang
           ;; JVM (Hell Emacs' own). Each language server is pinned and installed by `sync'.
           (java +lombok +spring) ; Java: JDTLS, Spring Boot; a JDK 21+ (+lombok, +spring, +tree-sitter)
           kotlin             ; Kotlin: kotlin-language-server; a JDK (+tree-sitter)
           clojure            ; Clojure: CIDER REPL + clojure-lsp (+tree-sitter: Emacs 30.1+)
           groovy             ; Groovy, Gradle scripts, Jenkinsfiles: groovy-language-server (built by sync)
           scala              ; Scala: Metals, sbt (+tree-sitter)

           ;; Web, Data, Cloud & DevOps (bundled by default, matching IntelliJ IDEA Ultimate)
           data               ; XML, XSLT, XPath, .properties: lemminx on a JDK
           docker             ; Dockerfile and Compose: docker-language-server; built-in dockerfile-ts-mode
           javascript         ; JavaScript, TypeScript, JSX/TSX: typescript-language-server
           json               ; JSON: vscode-json-language-server; needs Node (+tree-sitter)
           markdown           ; Markdown: marksman
           openapi            ; OpenAPI and Swagger: schema validation for YAML/JSON
           protobuf           ; Protocol Buffers: protobuf-mode, protoc / bufls
           sh                 ; Shell scripts, gradlew/mvnw: bash-language-server; needs Node (+tree-sitter)
           sql                ; SQL: sql-mode, sql-indent, JDBC connections
           ;;terraform        ; Terraform and HCL: terraform-ls
           web                ; HTML, CSS, Less, SCSS, Thymeleaf, Velocity, FreeMarker, JSP
           yaml               ; YAML: yaml-language-server; needs Node; built-in yaml-ts-mode

           ;; Plugin languages (manage via `bin/hell plugins' or uncomment below)
           ;;cc               ; C, C++, Objective-C: clangd
           ;;go               ; Go: gopls
           ;;php              ; PHP: phpactor (intelephense)
           ;;python           ; Python: basedpyright, ruff
           ;;ruby             ; Ruby: ruby-lsp

           ;; Additional language modules
           ;;agda             ; [idea] Agda: agda-mode (no LSP)
           ;;beancount        ; [idea] Beancount: beancount-language-server
           ;;cmake            ; [idea] CMake: neocmakelsp
           common-lisp        ; Common Lisp: SLIME (REPL, compiler, evaluation, sblint)
           ;;coq              ; [idea] Rocq/Coq: coq-lsp, Proof General
           ;;crystal          ; [idea] Crystal: crystalline
           ;;csharp           ; [idea] C#: csharp-ls (Roslyn)
           ;;dart             ; [idea] Dart and Flutter: the Dart analysis server
           ;;dhall            ; [idea] Dhall: dhall-lsp-server
           ;;elixir           ; [idea] Elixir: Expert (elixir-ls)
           ;;elm              ; [idea] Elm: elm-language-server
           emacs-lisp         ; Emacs Lisp extras: macrostep, elisp-demos (no LSP)
           ;;erlang           ; [idea] Erlang: ELP (erlang_ls)
           ;;ess              ; [idea] R: languageserver, ESS
           ;;fortran          ; [idea] Fortran: fortls
           ;;fsharp           ; [idea] F#: fsautocomplete
           ;;gdscript         ; [idea] Godot GDScript: the Godot editor's server
           ;;gleam            ; [idea] Gleam: gleam lsp
           ;;glsl             ; [idea] GLSL (OpenGL shaders): glsl-language-server (glslls)
           ;;graphql          ; [idea] GraphQL: graphql-lsp
           ;;graphviz         ; [idea] Graphviz dot files (no LSP)
           ;;haskell          ; [idea] Haskell: haskell-language-server
           ;;janet            ; [idea] Janet: janet-lsp
           ;;julia            ; [idea] Julia: LanguageServer.jl
           ;;latex            ; [idea] LaTeX: texlab, AUCTeX
           ;;lean             ; [idea] Lean 4: the Lean server
           ;;ledger           ; [idea] Ledger accounting (no LSP)
           ;;lua              ; [idea] Lua: lua-language-server
           ;;nim              ; [idea] Nim: nimlangserver
           ;;nix              ; [idea] Nix: nixd (nil)
           ;;ocaml            ; [idea] OCaml: ocaml-lsp-server
           ;;odin             ; [idea] Odin: ols
           ;;org              ; [idea] Org mode (no LSP)
           ;;plantuml         ; [idea] PlantUML diagrams (no LSP)
           ;;purescript       ; [idea] PureScript: purescript-language-server
           ;;racket           ; [idea] Racket: racket-langserver
           ;;rst              ; [idea] reStructuredText: esbonio
           ;;rust             ; [idea] Rust: rust-analyzer
           ;;scheme           ; [idea] Scheme: Geiser (no LSP)
           ;;sml              ; [idea] Standard ML: millet
           ;;solidity         ; [idea] Solidity: nomicfoundation-solidity-language-server
           ;;swift            ; [idea] Swift: sourcekit-lsp
           ;;toml             ; [idea] TOML: taplo
           ;;zig              ; [idea] Zig: zls

           :app
           ;;calendar         ; [idea] calendars (calfw)
           ;;irc              ; [idea] IRC (circe, erc)
           ;;rss              ; [idea] RSS feeds (elfeed)

           :email
           ;;mu4e             ; [idea] email with mu4e
           ;;notmuch          ; [idea] email with notmuch

           :config
           default)           ; C-c leader groups (h c t w q), which-key, ibuffer on C-x C-b (+repeat)

;; Look and feel (all optional):
;; (setq hell-theme 'modus-vivendi)   ; another theme; nil loads none
;; (setq hell-splash-enable nil)      ; start on *scratch*, not the Altar
;; (setq hell-ux-enable nil)          ; stock quit prompt and error messages

;;; init.el ends here
