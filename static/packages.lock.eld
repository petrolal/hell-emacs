((ace-window :source "elpaca-menu-lock-file" :recipe
	     (:package "ace-window" :repo "abo-abo/ace-window"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id ace-window :type git
		       :protocol https :inherit t :depth treeless :ref
		       "77115afc1b0b9f633084cf7479c767988106c196"))
 (adaptive-wrap :source "elpaca-menu-lock-file" :recipe
		(:package "adaptive-wrap" :repo
			  ("https://github.com/emacsmirror/gnu_elpa"
			   . "adaptive-wrap")
			  :tar "0.9" :host gnu :branch
			  "externals/adaptive-wrap" :files
			  ("*" (:exclude ".git")) :source "GNU ELPA"
			  :id adaptive-wrap :type git :protocol https
			  :inherit t :depth treeless :ref
			  "e929b38c12f17aa6f8d6270326301d61fbb09cab"))
 (agda2-mode :source "elpaca-menu-lock-file" :recipe
	     (:source "User Declaration" :package "agda2-mode" :id
		      agda2-mode :host github :repo "agda/agda" :files
		      ("src/data/emacs-mode/*.el") :ref
		      "cccf42fa88eae25ccbe2623f489021d2075f6f73" :type
		      git :protocol https :inherit t :depth treeless))
 (aio :source "elpaca-menu-lock-file" :recipe
      (:package "aio" :fetcher github :repo "skeeto/emacs-aio" :files
		("aio.el" "README.md" "UNLICENSE") :source "MELPA" :id
		aio :type git :protocol https :inherit t :depth
		treeless :ref
		"a20c99aafef021b77b0a00735659142d4cf49682"))
 (ansible :source "elpaca-menu-lock-file" :recipe
	  (:package "ansible" :fetcher gitlab :repo
		    "emacs-ansible/emacs-ansible" :files
		    (:defaults "snippets" "dict") :source "MELPA" :id
		    ansible :type git :protocol https :inherit t
		    :depth treeless :ref
		    "0d7bc93ad963677880d99c846a30ea6e6ed9eec5"))
 (apheleia :source "elpaca-menu-lock-file" :recipe
	   (:package "apheleia" :fetcher github :repo
		     "radian-software/apheleia" :files
		     (:defaults ("scripts" "scripts/formatters"))
		     :source "MELPA" :id apheleia :type git :protocol
		     https :inherit t :depth treeless :ref
		     "047119b7c6f18ffdbf5f88116a427f7e38653cc6"))
 (async :source "elpaca-menu-lock-file" :recipe
	(:package "async" :repo "jwiegley/emacs-async" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id async :type git :protocol https
		  :inherit t :depth treeless :ref
		  "4fdcb061a166e0d6ccc27d3829a28e04415ae825"))
 (auctex :source "elpaca-menu-lock-file" :recipe
	 (:package "auctex" :repo
		   ("https://git.savannah.gnu.org/git/auctex.git"
		    . "auctex")
		   :tar "14.2.0" :host gnu :branch "main" :files
		   ("*" (:exclude ".git")) :source "GNU ELPA" :id
		   auctex :type git :protocol https :inherit t :depth
		   treeless :ref
		   "966e78acd01e434a9342c8861905fe8507ccbebd"))
 (avy :source "elpaca-menu-lock-file" :recipe
      (:package "avy" :repo "abo-abo/avy" :fetcher github :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "MELPA" :id avy :type git :protocol https
		:inherit t :depth treeless :ref
		"933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (beancount :source "elpaca-menu-lock-file" :recipe
	    (:package "beancount" :repo
		      ("https://github.com/beancount/beancount-mode"
		       . "beancount")
		      :tar "0.9.0" :host nongnu :files
		      ("*" (:exclude ".git")) :source "NonGNU ELPA"
		      :id beancount :type git :protocol https :inherit
		      t :depth treeless :ref
		      "37648f983ff42426b1f364831ce7d2d0d735686b"))
 (bui :source "elpaca-menu-lock-file" :recipe
      (:package "bui" :repo "alezost/bui.el" :fetcher github :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "MELPA" :id bui :type git :protocol https
		:inherit t :depth treeless :ref
		"4319e1bf3ff94ff0568eed280ac1f980a4b68679"))
 (calfw :source "elpaca-menu-lock-file" :recipe
	(:package "calfw" :fetcher github :repo "kiwanami/emacs-calfw"
		  :files ("calfw.el" "calfw-compat.el") :source
		  "MELPA" :id calfw :type git :protocol https :inherit
		  t :depth treeless :ref
		  "24fa167af96a6e677aea7c6b9385f669b550ee2f"))
 (calfw-org :source "elpaca-menu-lock-file" :recipe
	    (:package "calfw-org" :fetcher github :repo
		      "kiwanami/emacs-calfw" :files
		      ("calfw-org.el" "calfw-compat.el") :source
		      "MELPA" :id calfw-org :type git :protocol https
		      :inherit t :depth treeless :ref
		      "24fa167af96a6e677aea7c6b9385f669b550ee2f"))
 (cape :source "elpaca-menu-lock-file" :recipe
       (:package "cape" :repo "minad/cape" :fetcher github :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id cape :type git :protocol https
		 :inherit t :depth treeless :ref
		 "50bc6187daf9af9df1a802fcbbd91fe4b952fc69"))
 (cfrs :source "elpaca-menu-lock-file" :recipe
       (:package "cfrs" :repo "Alexander-Miller/cfrs" :fetcher github
		 :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id cfrs :type git :protocol https
		 :inherit t :depth treeless :ref
		 "981bddb3fb9fd9c58aed182e352975bd10ad74c8"))
 (cider :source "elpaca-menu-lock-file" :recipe
	(:package "cider" :fetcher github :repo "clojure-emacs/cider"
		  :files
		  ("lisp/*.el" "bin/*.sh" "*.el" "clojure.sh"
		   "lein.sh" (:exclude ".dir-locals.el"))
		  :old-names (nrepl) :source "MELPA" :id cider :type
		  git :protocol https :inherit t :depth treeless :ref
		  "14d4a48c9c5f53d23be505302623fe72738e687b"))
 (circe :source "elpaca-menu-lock-file" :recipe
	(:package "circe" :repo "emacs-circe/circe" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id circe :type git :protocol https
		  :inherit t :depth treeless :ref
		  "50ac3bc96a0db359a877162a1033b41ba0d01bb8"))
 (citar :source "elpaca-menu-lock-file" :recipe
	(:package "citar" :repo "emacs-citar/citar" :fetcher github
		  :files (:defaults (:exclude "citar-embark.el"))
		  :old-names (bibtex-actions) :source "MELPA" :id
		  citar :type git :protocol https :inherit t :depth
		  treeless :ref
		  "5efc5ac78f235cdaafe361758d03c7a51a015dd1"))
 (citeproc :source "elpaca-menu-lock-file" :recipe
	   (:package "citeproc" :fetcher github :repo
		     "andras-simonyi/citeproc-el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id citeproc :type git :protocol
		     https :inherit t :depth treeless :ref
		     "4bde999a41803fe519ea80eab8b813d53503eebd"))
 (clipetty :source "elpaca-menu-lock-file" :recipe
	   (:package "clipetty" :repo "spudlyo/clipetty" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id clipetty :type git :protocol
		     https :inherit t :depth treeless :ref
		     "01b39044b9b65fa4ea7d3166f8b1ffab6f740362"))
 (clojure-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "clojure-mode" :repo
			 "clojure-emacs/clojure-mode" :fetcher github
			 :files ("clojure-mode.el") :source "MELPA"
			 :id clojure-mode :type git :protocol https
			 :inherit t :depth treeless :ref
			 "3c68569738f04a22d52f1ca28f593c2ee733bf04"))
 (clojure-ts-mode :source "elpaca-menu-lock-file" :recipe
		  (:package "clojure-ts-mode" :repo
			    "clojure-emacs/clojure-ts-mode" :fetcher
			    github :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id clojure-ts-mode :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "2bce67a68c270157d940ac9374ab393804c7e00d"))
 (closql :source "elpaca-menu-lock-file" :recipe
	 (:package "closql" :fetcher github :repo "magit/closql"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id closql :type git :protocol
		   https :inherit t :depth treeless :ref
		   "48955ae02cfc7dad93b6bdc9ffd8d4b760dfb62b"))
 (cmake-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "cmake-mode" :fetcher git :url
		       "https://gitlab.kitware.com/cmake/cmake.git"
		       :files ("Auxiliary/*.el") :source "MELPA" :id
		       cmake-mode :type git :protocol https :inherit t
		       :depth treeless :ref
		       "b6bb95a8bfed2c20e15cf0e12186c4fabecc2243"))
 (commenter :source "elpaca-menu-lock-file" :recipe
	    (:package "commenter" :fetcher github :repo
		      "yuutayamada/commenter" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id commenter :type git
		      :protocol https :inherit t :depth treeless :ref
		      "6d1885419434ba779270c6fda0e30d390bb074bd"))
 (compat :source "elpaca-menu-lock-file" :recipe
	 (:package "compat" :repo
		   ("https://github.com/emacs-compat/compat"
		    . "compat")
		   :tar "31.1.0.0" :host gnu :files
		   ("*" (:exclude ".git")) :source "GNU ELPA" :id
		   compat :type git :protocol https :inherit t :depth
		   treeless :ref
		   "90880f81419577e1d3f68424d2a3adf31e6d663e"))
 (concurrent :source "elpaca-menu-lock-file" :recipe
	     (:package "concurrent" :repo "kiwanami/emacs-deferred"
		       :fetcher github :files ("concurrent.el")
		       :source "MELPA" :id concurrent :type git
		       :protocol https :inherit t :depth treeless :ref
		       "2239671d94b38d92e9b28d4e12fd79814cfb9c16"))
 (cond-let :source "elpaca-menu-lock-file" :recipe
	   (:package "cond-let" :fetcher github :repo
		     "tarsius/cond-let" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id cond-let :type git :protocol
		     https :inherit t :depth treeless :ref
		     "09292a77001434f59ab55c775dec2b98cb18d028"))
 (consult :source "elpaca-menu-lock-file" :recipe
	  (:package "consult" :repo "minad/consult" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id consult :type git :protocol
		    https :inherit t :depth treeless :ref
		    "a64569f377b8bc0f62e1d2ae0f3ee48ba4a7cc1c"))
 (corfu :source "elpaca-menu-lock-file" :recipe
	(:package "corfu" :repo "minad/corfu" :files
		  (:defaults "extensions/corfu-*.el") :fetcher github
		  :source "MELPA" :id corfu :type git :protocol https
		  :inherit t :depth treeless :ref
		  "b468efac023dda39332acc943edc9895c80b5a6f"))
 (corfu-terminal :source "elpaca-menu-lock-file" :recipe
		 (:package "corfu-terminal" :repo
			   ("https://codeberg.org/akib/emacs-corfu-terminal"
			    . "corfu-terminal")
			   :tar "0.7" :host nongnu :files
			   ("*" (:exclude ".git")) :source
			   "NonGNU ELPA" :id corfu-terminal :type git
			   :protocol https :inherit t :depth treeless
			   :ref
			   "501548c3d51f926c687e8cd838c5865ec45d03cc"))
 (crystal-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "crystal-mode" :repo
			 "crystal-lang-tools/emacs-crystal-mode"
			 :fetcher github :files ("crystal-mode.el")
			 :source "MELPA" :id crystal-mode :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "f3b01df0bbe58852d0d7242bf5c0495931bb6fa6"))
 (csharp-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "csharp-mode" :fetcher github :repo
			"emacs-csharp/csharp-mode" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id csharp-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"02c61c219b2c22491eff9b7315fed661fab423d4"))
 (ctable :source "elpaca-menu-lock-file" :recipe
	 (:package "ctable" :repo "kiwanami/emacs-ctable" :fetcher
		   github :files ("ctable.el") :source "MELPA" :id
		   ctable :type git :protocol https :inherit t :depth
		   treeless :ref
		   "48b73742757a3ae5736d825fe49e00034cc453b5"))
 (dap-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "dap-mode" :repo "emacs-lsp/dap-mode" :fetcher
		     github :files (:defaults "icons") :source "MELPA"
		     :id dap-mode :type git :protocol https :inherit t
		     :depth treeless :ref
		     "7372c429031ad37adb88b42e4a2f4cfff246ce55"))
 (dart-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "dart-mode" :fetcher github :repo
		      "emacsorphanage/dart-mode" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id dart-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "ea9c2204f3e27b5419b9c5dba8b2078b22eb8461"))
 (dash :source "elpaca-menu-lock-file" :recipe
       (:package "dash" :fetcher github :repo "magnars/dash.el" :files
		 ("dash.el" "dash.texi") :source "MELPA" :id dash
		 :type git :protocol https :inherit t :depth treeless
		 :ref "d746dd9edcb67a108818beb0cdc78dc1cb466832"))
 (deferred :source "elpaca-menu-lock-file" :recipe
	   (:package "deferred" :repo "kiwanami/emacs-deferred"
		     :fetcher github :files ("deferred.el") :source
		     "MELPA" :id deferred :type git :protocol https
		     :inherit t :depth treeless :ref
		     "2239671d94b38d92e9b28d4e12fd79814cfb9c16"))
 (deflate :source "elpaca-menu-lock-file" :recipe
	  (:package "deflate" :fetcher github :repo "skuro/deflate"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id deflate :type git :protocol
		    https :inherit t :depth treeless :ref
		    "d3863855d213f73dc7a1a54736d94a75f8f7e9c5"))
 (devdocs :source "elpaca-menu-lock-file" :recipe
	  (:package "devdocs" :fetcher github :repo
		    "astoff/devdocs.el" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id devdocs :type git :protocol
		    https :inherit t :depth treeless :ref
		    "25c746024ddf73570195bf42b841f761a2fee10c"))
 (dhall-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "dhall-mode" :repo "psibi/dhall-mode" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id dhall-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "fca383a9c4622c1d9a39dc977572b34c7fa0b719"))
 (diff-hl :source "elpaca-menu-lock-file" :recipe
	  (:package "diff-hl" :fetcher github :repo "dgutov/diff-hl"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id diff-hl :type git :protocol
		    https :inherit t :depth treeless :ref
		    "8dfb5c27ea43b8c7ac1c008bb97090ad4f059285"))
 (docker :source "elpaca-menu-lock-file" :recipe
	 (:package "docker" :fetcher github :repo "Silex/docker.el"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id docker :type git :protocol
		   https :inherit t :depth treeless :ref
		   "08b9ae67f01431b3b07e7181388a08f3faba6824"))
 (eat :source "elpaca-menu-lock-file" :recipe
      (:package "eat" :repo "emacsmirror/eat" :tar "0.9.4" :host
		github :files
		("*.el" ("term" "term/*.el") "*.texi" "*.ti"
		 ("terminfo/e" "terminfo/e/*")
		 ("terminfo/65" "terminfo/65/*")
		 ("integration" "integration/*")
		 (:exclude ".dir-locals.el" "*-tests.el"))
		:source "NonGNU ELPA" :id eat :type git :protocol
		https :inherit t :depth treeless :ref
		"3a6f418f55d183b9d86f99c140caed4ba3d44f93"))
 (editorconfig :source "elpaca-menu-lock-file" :recipe
	       (:package "editorconfig" :fetcher github :repo
			 "editorconfig/editorconfig-emacs" :old-names
			 (editorconfig-core editorconfig-fnmatch)
			 :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id editorconfig :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "b18fcf7fdea1ce84b7fdc60360ad8016b5c00d79"))
 (elfeed :source "elpaca-menu-lock-file" :recipe
	 (:package "elfeed" :fetcher github :repo
		   "emacs-elfeed/elfeed" :files
		   (:defaults "README.md") :source "MELPA" :id elfeed
		   :type git :protocol https :inherit t :depth
		   treeless :ref
		   "f69b4da9b89be04e3b5bd0fecac77a48d914e64c"))
 (elfeed-org :source "elpaca-menu-lock-file" :recipe
	     (:package "elfeed-org" :repo "remyhonig/elfeed-org"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id elfeed-org :type git
		       :protocol https :inherit t :depth treeless :ref
		       "34c0b4d758942822e01a5dbe66b236e49a960583"))
 (elisp-demos :source "elpaca-menu-lock-file" :recipe
	      (:package "elisp-demos" :fetcher github :repo
			"xuchunyang/elisp-demos" :files
			(:defaults "*.org") :source "MELPA" :id
			elisp-demos :host github :ref
			"637001834b445e518a7b730266f8864fdcc1d294"
			:type git :protocol https :inherit t :depth
			treeless))
 (elixir-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "elixir-mode" :fetcher github :repo
			"elixir-editors/emacs-elixir" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id elixir-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"00d6580a040a750e019218f9392cf9a4c2dac23a"))
 (elm-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "elm-mode" :fetcher github :repo
		     "jcollard/elm-mode" :files (:defaults "elm.tags")
		     :source "MELPA" :id elm-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "90b72cd2c9bc4506f531bcdcd73fa2530d9f4f7c"))
 (elpaca :source
   "elpaca-menu-lock-file" :recipe
   (:source "User Declaration" :package "elpaca" :id elpaca :repo
	    "https://github.com/progfolio/elpaca.git" :ref
	    "78b8e7cc98c198c8dbeb18140649e2d668126712" :depth nil
	    :inherit ignore :files
	    (:defaults "elpaca-test.el" (:exclude "extensions"))
	    :build (:not elpaca-activate) :type git :protocol https))
 (emacsql :source "elpaca-menu-lock-file" :recipe
	  (:package "emacsql" :fetcher github :repo "magit/emacsql"
		    :files (:defaults "README.md" "sqlite") :source
		    "MELPA" :id emacsql :type git :protocol https
		    :inherit t :depth treeless :ref
		    "7a4c607912c8fdd1fca4def4915d68f43b12d4da"))
 (emamux :source "elpaca-menu-lock-file" :recipe
	 (:package "emamux" :repo "emacsorphanage/emamux" :fetcher
		   github :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id emamux :type git :protocol
		   https :inherit t :depth treeless :ref
		   "93bb7e8b8cfb0ced5b9b38044a031d40342201a1"))
 (emojify :source "elpaca-menu-lock-file" :recipe
	  (:package "emojify" :fetcher github :repo
		    "iqbalansari/emacs-emojify" :files
		    (:defaults "data" "images") :source "MELPA" :id
		    emojify :type git :protocol https :inherit t
		    :depth treeless :ref
		    "1b726412f19896abf5e4857d4c32220e33400b55"))
 (envrc :source "elpaca-menu-lock-file" :recipe
	(:package "envrc" :fetcher github :repo "purcell/envrc" :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id envrc :type git :protocol https
		  :inherit t :depth treeless :ref
		  "ab2853255e376719778ff94d8b718a37cf3e719a"))
 (epc :source "elpaca-menu-lock-file" :recipe
      (:package "epc" :repo "kiwanami/emacs-epc" :fetcher github
		:files ("epc.el" "epcs.el") :source "MELPA" :id epc
		:type git :protocol https :inherit t :depth treeless
		:ref "e1bfa5ca163273859336e3cc89b4b6460f7f8cda"))
 (erlang :source "elpaca-menu-lock-file" :recipe
	 (:package "erlang" :fetcher github :repo "erlang/otp"
		   :version-regexp "OTP-%v" :files
		   ("lib/tools/emacs/*.el"
		    (:exclude "lib/tools/emacs/erlang_appwiz.el"))
		   :source "MELPA" :id erlang :type git :protocol
		   https :inherit t :depth treeless :ref
		   "cfe4f037932061f9d82a2622cd9a9577ee4f0226"))
 (ess :source "elpaca-menu-lock-file" :recipe
      (:package "ess" :repo "emacs-ess/ESS" :fetcher github :files
		("lisp/*.el" "doc/ess.texi" ("etc" "etc/*")
		 ("obsolete" "lisp/obsolete/*") (:exclude "etc/other"))
		:source "MELPA" :id ess :type git :protocol https
		:inherit t :depth treeless :ref
		"bb8f50f08798928c71fce20c7ea92fa16dbece0a"))
 (f :source "elpaca-menu-lock-file" :recipe
    (:package "f" :fetcher github :repo "rejeep/f.el" :files
	      ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
	       "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
	       "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
	       "docs/*.texinfo"
	       (:exclude ".dir-locals.el" "test.el" "tests.el"
			 "*-test.el" "*-tests.el" "LICENSE" "README*"
			 "*-pkg.el"))
	      :source "MELPA" :id f :type git :protocol https :inherit
	      t :depth treeless :ref
	      "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
 (flycheck :source "elpaca-menu-lock-file" :recipe
	   (:package "flycheck" :repo "flycheck/flycheck" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id flycheck :type git :protocol
		     https :inherit t :depth treeless :ref
		     "9076d01a8a685bb0f03302e7bf3feaf41e6c34dc"))
 (flymake-languagetool :source "elpaca-menu-lock-file" :recipe
		       (:package "flymake-languagetool" :repo
				 "emacs-languagetool/flymake-languagetool"
				 :fetcher github :files
				 ("*.el" "*.el.in" "dir" "*.info"
				  "*.texi" "*.texinfo" "doc/dir"
				  "doc/*.info" "doc/*.texi"
				  "doc/*.texinfo" "lisp/*.el"
				  "docs/dir" "docs/*.info"
				  "docs/*.texi" "docs/*.texinfo"
				  (:exclude ".dir-locals.el" "test.el"
					    "tests.el" "*-test.el"
					    "*-tests.el" "LICENSE"
					    "README*" "*-pkg.el"))
				 :source "MELPA" :id
				 flymake-languagetool :type git
				 :protocol https :inherit t :depth
				 treeless :ref
				 "fcd9904535253ac4470c129549c9470c3bc80550"))
 (font-utils :source "elpaca-menu-lock-file" :recipe
	     (:package "font-utils" :repo "rolandwalker/font-utils"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id font-utils :type git
		       :protocol https :inherit t :depth treeless :ref
		       "abc572eb0dc30a26584c0058c3fe6c7273a10003"))
 (forge :source "elpaca-menu-lock-file" :recipe
	(:package "forge" :fetcher github :repo "magit/forge" :files
		  ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
		  "MELPA" :id forge :type git :protocol https :inherit
		  t :depth treeless :ref
		  "206756d30af543e660e660bb66569a2afeb7fd0a"))
 (fsharp-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "fsharp-mode" :fetcher github :repo
			"fsharp/emacs-fsharp-mode" :files
			(:defaults (:exclude "eglot-fsharp.el"))
			:source "MELPA" :id fsharp-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"5212c9359180c0a3c01f22060d9836d5165988a3"))
 (gcmh :source "elpaca-menu-lock-file" :recipe
       (:package "gcmh" :repo "koral/gcmh" :fetcher gitlab :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id gcmh :type git :protocol https
		 :inherit t :depth treeless :ref
		 "0089f9c3a6d4e9a310d0791cf6fa8f35642ecfd9"))
 (gdscript-mode :source "elpaca-menu-lock-file" :recipe
		(:package "gdscript-mode" :fetcher github :repo
			  "godotengine/emacs-gdscript-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id gdscript-mode :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "fc7b7ece95da9ca0ffaafc602ac9c861f533f331"))
 (geiser :source "elpaca-menu-lock-file" :recipe
	 (:package "geiser" :fetcher codeberg :repo "geiser/geiser"
		   :files ("elisp/*.el" "doc/dir" "doc/geiser.texi")
		   :source "MELPA" :id geiser :type git :protocol
		   https :inherit t :depth treeless :ref
		   "1d7b08e989df3933ea0b4414ebfbdd99c3cc24ed"))
 (ghub :source "elpaca-menu-lock-file" :recipe
       (:package "ghub" :fetcher github :repo "magit/ghub" :files
		 ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
		 "MELPA" :id ghub :type git :protocol https :inherit t
		 :depth treeless :ref
		 "01e2bc064ab4965d332efa11fafeda2a43f338d1"))
 (gleam-ts-mode :source "elpaca-menu-lock-file" :recipe
		(:package "gleam-ts-mode" :fetcher github :repo
			  "gleam-lang/gleam-mode" :files
			  ("gleam-ts-mode.el") :source "MELPA" :id
			  gleam-ts-mode :type git :protocol https
			  :inherit t :depth treeless :ref
			  "5fd0ad952e60ee0032688cb7c2d9fd09e79eff62"))
 (glsl-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "glsl-mode" :repo "jimhourihan/glsl-mode"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id glsl-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "515a2ba4dab3ec89c83a962902a123ddf81e3cfe"))
 (go-mode :source "elpaca-menu-lock-file" :recipe
	  (:package "go-mode" :repo "dominikh/go-mode.el" :fetcher
		    github :files ("go-mode.el") :source "MELPA" :id
		    go-mode :type git :protocol https :inherit t
		    :depth treeless :ref
		    "3a71d28ab47df685e54ca6046a7a3dd3e28b682c"))
 (gptel :source "elpaca-menu-lock-file" :recipe
	(:package "gptel" :repo "karthink/gptel" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id gptel :type git :protocol https
		  :inherit t :depth treeless :ref
		  "edb3fee3b5266e9060f6d121e9b3914eb7c3409d"))
 (graphql-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "graphql-mode" :repo "davazp/graphql-mode"
			 :fetcher github :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id graphql-mode :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "96bddee439e1409fc31a79e7e28c9ba79de443b2"))
 (graphviz-dot-mode :source "elpaca-menu-lock-file" :recipe
		    (:package "graphviz-dot-mode" :repo
			      "ppareit/graphviz-dot-mode" :fetcher
			      github :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "MELPA" :id graphviz-dot-mode
			      :type git :protocol https :inherit t
			      :depth treeless :ref
			      "0a4509e9f63c8eae8d050acc62eac642fd77ae59"))
 (groovy-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "groovy-mode" :fetcher github :repo
			"Groovy-Emacs-Modes/groovy-emacs-modes" :files
			("*groovy*.el") :source "MELPA" :id
			groovy-mode :type git :protocol https :inherit
			t :depth treeless :ref
			"7b8520b2e2d3ab1d62b35c426e17ac25ed0120bb"))
 (haskell-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "haskell-mode" :repo "haskell/haskell-mode"
			 :fetcher github :files
			 (:defaults "NEWS" "logo.svg") :source "MELPA"
			 :id haskell-mode :type git :protocol https
			 :inherit t :depth treeless :ref
			 "4bdd38c22d8a54d3284b517e889863a1d3971998"))
 (hcl-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "hcl-mode" :repo "hcl-emacs/hcl-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id hcl-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "1da895ed75d28d9f87cbf9b74f075d90ba31c0ed"))
 (highlight-indent-guides :source "elpaca-menu-lock-file" :recipe
			  (:package "highlight-indent-guides" :fetcher
				    github :repo
				    "bumblepup/highlight-indent-guides"
				    :files
				    ("*.el" "*.el.in" "dir" "*.info"
				     "*.texi" "*.texinfo" "doc/dir"
				     "doc/*.info" "doc/*.texi"
				     "doc/*.texinfo" "lisp/*.el"
				     "docs/dir" "docs/*.info"
				     "docs/*.texi" "docs/*.texinfo"
				     (:exclude ".dir-locals.el"
					       "test.el" "tests.el"
					       "*-test.el"
					       "*-tests.el" "LICENSE"
					       "README*" "*-pkg.el"))
				    :source "MELPA" :id
				    highlight-indent-guides :type git
				    :protocol https :inherit t :depth
				    treeless :ref
				    "08a0859d4af2d0ce95be2a1e9aa5d1fd5ac42792"))
 (hl-todo :source "elpaca-menu-lock-file" :recipe
	  (:package "hl-todo" :fetcher github :repo "tarsius/hl-todo"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id hl-todo :type git :protocol
		    https :inherit t :depth treeless :ref
		    "d25aa5a2e78f70331de2b3455d8ef85bd945356b"))
 (ht :source "elpaca-menu-lock-file" :recipe
     (:package "ht" :fetcher github :repo "Wilfred/ht.el" :files
	       ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		"doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		"lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		"docs/*.texinfo"
		(:exclude ".dir-locals.el" "test.el" "tests.el"
			  "*-test.el" "*-tests.el" "LICENSE" "README*"
			  "*-pkg.el"))
	       :source "MELPA" :id ht :type git :protocol https
	       :inherit t :depth treeless :ref
	       "1c49aad1c820c86f7ee35bf9fff8429502f60fef"))
 (hydra :source "elpaca-menu-lock-file" :recipe
	(:package "hydra" :repo "abo-abo/hydra" :fetcher github :files
		  (:defaults (:exclude "lv.el")) :source "MELPA" :id
		  hydra :type git :protocol https :inherit t :depth
		  treeless :ref
		  "59a2a45a35027948476d1d7751b0f0215b1e61aa"))
 (ibuffer-project :source "elpaca-menu-lock-file" :recipe
		  (:package "ibuffer-project" :fetcher github :repo
			    "muffinmad/emacs-ibuffer-project" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id ibuffer-project :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "9002abd9cb4c8753fe4f6c522d9407b4d52e7873"))
 (iedit :source "elpaca-menu-lock-file" :recipe
	(:package "iedit" :repo "victorhge/iedit" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id iedit :type git :protocol https
		  :inherit t :depth treeless :ref
		  "14161daa295332a49dda92b97c00d62efd38acfe"))
 (inf-ruby :source "elpaca-menu-lock-file" :recipe
	   (:package "inf-ruby" :repo "nonsequitur/inf-ruby" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id inf-ruby :type git :protocol
		     https :inherit t :depth treeless :ref
		     "274398a24288a7db430a656b580ffbf889ca02aa"))
 (inheritenv :source "elpaca-menu-lock-file" :recipe
	     (:package "inheritenv" :fetcher github :repo
		       "purcell/inheritenv" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id inheritenv :type git
		       :protocol https :inherit t :depth treeless :ref
		       "b9e67cc20c069539698a9ac54d0e6cc11e616c6f"))
 (janet-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "janet-mode" :repo "ALSchwalm/janet-mode"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id janet-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "9e3254a0249d720d5fa5603f1f8c3ed0612695af"))
 (jinx :source "elpaca-menu-lock-file" :recipe
       (:package "jinx" :repo "minad/jinx" :files
		 (:defaults "jinx-mod.c" "emacs-module.h") :fetcher
		 github :source "MELPA" :id jinx :type git :protocol
		 https :inherit t :depth treeless :ref
		 "bccb08062a3372629015bcd2c197490b7d005f37"))
 (julia-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "julia-mode" :repo
		       "JuliaEditorSupport/julia-emacs" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id julia-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "1b5a4c2f5b7c3f842785985bf8778b8805cc6766"))
 (kotlin-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "kotlin-mode" :repo
			"Emacs-Kotlin-Mode-Maintainers/kotlin-mode"
			:fetcher github :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id kotlin-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"fddd747e5b4736e8b27a147960f369b86179ddff"))
 (kotlin-ts-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "kotlin-ts-mode" :fetcher gitlab :repo
			   "bricka/emacs-kotlin-ts-mode" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id kotlin-ts-mode :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "292c9a05ff2243c39a48201b277840b1d25e1ea0"))
 (kubel :source "elpaca-menu-lock-file" :recipe
	(:package "kubel" :fetcher github :repo "abrochard/kubel"
		  :files (:defaults (:exclude "kubel-evil.el"))
		  :source "MELPA" :id kubel :type git :protocol https
		  :inherit t :depth treeless :ref
		  "23f8ee2cffd6080e39ac2ac06ab74f0de32a4da6"))
 (lean4-mode :source "elpaca-menu-lock-file" :recipe
	     (:source "User Declaration" :package "lean4-mode" :id
		      lean4-mode :host github :repo
		      "leanprover-community/lean4-mode" :files
		      ("*.el" "data") :type git :protocol https
		      :inherit t :depth treeless :ref
		      "6d4030e494039383664a0c08348a5c137eb4641c"))
 (ledger-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "ledger-mode" :fetcher github :repo
			"ledger/ledger-mode" :files
			("ledger-*.el" "doc/*.texi") :old-names
			(ldg-mode) :source "MELPA" :id ledger-mode
			:type git :protocol https :inherit t :depth
			treeless :ref
			"9539ff67a9ac491be4b382530bdbba9558379700"))
 (ligature :source "elpaca-menu-lock-file" :recipe
	   (:package "ligature" :fetcher github :repo
		     "mickeynp/ligature.el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id ligature :type git :protocol
		     https :inherit t :depth treeless :ref
		     "e0bc07ec41203b72386a2b878b6c8a65c28f4ced"))
 (list-utils :source "elpaca-menu-lock-file" :recipe
	     (:package "list-utils" :repo "rolandwalker/list-utils"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id list-utils :type git
		       :protocol https :inherit t :depth treeless :ref
		       "bbea0e7cc7ab7d96e7f062014bde438aa8ffcd43"))
 (llama :source "elpaca-menu-lock-file" :recipe
	(:package "llama" :fetcher github :repo "tarsius/llama" :files
		  ("llama.el" ".dir-locals.el") :source "MELPA" :id
		  llama :type git :protocol https :inherit t :depth
		  treeless :ref
		  "6850d0c91b629da14fdff2300c222289d1a0029a"))
 (lsp-docker :source "elpaca-menu-lock-file" :recipe
	     (:package "lsp-docker" :repo "emacs-lsp/lsp-docker"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id lsp-docker :type git
		       :protocol https :inherit t :depth treeless :ref
		       "f666fba72b496c7750bb3f349771b07aa51714f0"))
 (lsp-java :source "elpaca-menu-lock-file" :recipe
	   (:package "lsp-java" :repo "emacs-lsp/lsp-java" :fetcher
		     github :files (:defaults "icons") :source "MELPA"
		     :id lsp-java :type git :protocol https :inherit t
		     :depth treeless :ref
		     "f17a3808ede477d34c0c64c23a558e95bb439710"))
 (lsp-metals :source "elpaca-menu-lock-file" :recipe
	     (:package "lsp-metals" :repo "emacs-lsp/lsp-metals"
		       :fetcher github :files (:defaults "icons")
		       :source "MELPA" :id lsp-metals :type git
		       :protocol https :inherit t :depth treeless :ref
		       "afeacc7a528b80b9a9f2747428e5608c264201ec"))
 (lsp-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "lsp-mode" :repo "emacs-lsp/lsp-mode" :fetcher
		     github :files (:defaults "clients/*.*") :source
		     "MELPA" :id lsp-mode :type git :protocol https
		     :inherit t :depth treeless :ref
		     "638393e51decca14184b07513156652fa13215e4"))
 (lsp-sonarlint :source "elpaca-menu-lock-file" :recipe
		(:package "lsp-sonarlint" :fetcher github :repo
			  "emacs-lsp/lsp-sonarlint" :files
			  ("lsp-sonarlint.el"
			   ("languages" "languages/*/*.el")
			   ("server" "server/*"))
			  :source "MELPA" :id lsp-sonarlint :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "91794c7663fc24afd8d93a74e775793de8f2f811"))
 (lsp-treemacs :source "elpaca-menu-lock-file" :recipe
	       (:package "lsp-treemacs" :repo "emacs-lsp/lsp-treemacs"
			 :fetcher github :files (:defaults "icons")
			 :source "MELPA" :id lsp-treemacs :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "3519ac907ea391e18d9599375b116aeeb6f8a38a"))
 (lua-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "lua-mode" :repo "immerrr/lua-mode" :fetcher
		     github :files
		     (:defaults (:exclude "init-tryout.el")) :source
		     "MELPA" :id lua-mode :type git :protocol https
		     :inherit t :depth treeless :ref
		     "2f6b8d7a6317e42c953c5119b0119ddb337e0a5f"))
 (lv :source "elpaca-menu-lock-file" :recipe
     (:package "lv" :repo "abo-abo/hydra" :fetcher github :files
	       ("lv.el") :source "MELPA" :id lv :type git :protocol
	       https :inherit t :depth treeless :ref
	       "59a2a45a35027948476d1d7751b0f0215b1e61aa"))
 (macrostep :source "elpaca-menu-lock-file" :recipe
	    (:package "macrostep" :fetcher github :repo
		      "emacsorphanage/macrostep" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id macrostep :host github :ref
		      "d0928626b4711dcf9f8f90439d23701118724199" :type
		      git :protocol https :inherit t :depth treeless))
 (magit :source "elpaca-menu-lock-file" :recipe
	(:package "magit" :fetcher github :repo "magit/magit" :files
		  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
		   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
		   ("githooks" "githooks/*")
		   ("git-hooks" "git-hooks/*")
		   (:exclude "lisp/magit-section.el"))
		  :source "MELPA" :id magit :type git :protocol https
		  :inherit t :depth treeless :ref
		  "bd9bce524cce1557db37c4e2260b0a7874c1075c"))
 (magit-section :source "elpaca-menu-lock-file" :recipe
		(:package "magit-section" :fetcher github :repo
			  "magit/magit" :files
			  ("lisp/magit-section.el"
			   "docs/magit-section.texi"
			   "magit-section-pkg.el")
			  :source "MELPA" :id magit-section :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "bd9bce524cce1557db37c4e2260b0a7874c1075c"))
 (makefile-executor :source "elpaca-menu-lock-file" :recipe
		    (:package "makefile-executor" :repo
			      "Olivia5k/makefile-executor.el" :fetcher
			      github :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "MELPA" :id makefile-executor
			      :type git :protocol https :inherit t
			      :depth treeless :ref
			      "6514a34f21ffba5746cb0c7b3148bc656fd7c811"))
 (marginalia :source "elpaca-menu-lock-file" :recipe
	     (:package "marginalia" :repo "minad/marginalia" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id marginalia :type git
		       :protocol https :inherit t :depth treeless :ref
		       "42eafcfddbe88d92ed96521a00a5a90a49bac4dd"))
 (markdown-mode :source "elpaca-menu-lock-file" :recipe
		(:package "markdown-mode" :fetcher github :repo
			  "jrblevin/markdown-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id markdown-mode :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "76cb4ffecfdf95ee769e5cb4608e04202c3c1521"))
 (minimap :source "elpaca-menu-lock-file" :recipe
	  (:package "minimap" :repo
		    ("https://github.com/emacsmirror/gnu_elpa"
		     . "minimap")
		    :tar "1.4" :host gnu :branch "externals/minimap"
		    :files ("*" (:exclude ".git")) :source "GNU ELPA"
		    :id minimap :type git :protocol https :inherit t
		    :depth treeless :ref
		    "b295cab07c1932c11dd00f23ba29c1ff0de486ab"))
 (multiple-cursors :source "elpaca-menu-lock-file" :recipe
		   (:package "multiple-cursors" :fetcher github :repo
			     "magnars/multiple-cursors.el" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id multiple-cursors
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "94b8b07a4bab87f803123723b68227565429dfa1"))
 (nav-flash :source "elpaca-menu-lock-file" :recipe
	    (:package "nav-flash" :repo "rolandwalker/nav-flash"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id nav-flash :type git
		      :protocol https :inherit t :depth treeless :ref
		      "5d4b48567862f6be0ca973d6b1dca90e4815cb9b"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
	     (:package "nerd-icons" :repo
		       "rainstormstudio/nerd-icons.el" :fetcher github
		       :files (:defaults "data") :source "MELPA" :id
		       nerd-icons :type git :protocol https :inherit t
		       :depth treeless :ref
		       "17faac7977242b470732efd417d3bcc8eb5a830e"))
 (nerd-icons-completion :source "elpaca-menu-lock-file" :recipe
			(:package "nerd-icons-completion" :repo
				  "rainstormstudio/nerd-icons-completion"
				  :fetcher github :files
				  ("*.el" "*.el.in" "dir" "*.info"
				   "*.texi" "*.texinfo" "doc/dir"
				   "doc/*.info" "doc/*.texi"
				   "doc/*.texinfo" "lisp/*.el"
				   "docs/dir" "docs/*.info"
				   "docs/*.texi" "docs/*.texinfo"
				   (:exclude ".dir-locals.el"
					     "test.el" "tests.el"
					     "*-test.el" "*-tests.el"
					     "LICENSE" "README*"
					     "*-pkg.el"))
				  :source "MELPA" :id
				  nerd-icons-completion :type git
				  :protocol https :inherit t :depth
				  treeless :ref
				  "f924dd490c8c4c1066fd97a76e0dc31e303fca30"))
 (nerd-icons-corfu :source "elpaca-menu-lock-file" :recipe
		   (:package "nerd-icons-corfu" :fetcher github :repo
			     "LuigiPiucco/nerd-icons-corfu" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id nerd-icons-corfu
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "9b089b31a810328d9b740b35a19eb796eb7a2d8a"))
 (nerd-icons-dired :source "elpaca-menu-lock-file" :recipe
		   (:package "nerd-icons-dired" :repo
			     "rainstormstudio/nerd-icons-dired"
			     :fetcher github :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id nerd-icons-dired
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "104acd8879528b8115589f35f1bbcbe231ad732f"))
 (nerd-icons-ibuffer :source "elpaca-menu-lock-file" :recipe
		     (:package "nerd-icons-ibuffer" :repo
			       "seagle0128/nerd-icons-ibuffer"
			       :fetcher github :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "MELPA" :id nerd-icons-ibuffer
			       :type git :protocol https :inherit t
			       :depth treeless :ref
			       "22dcbeea8c7677c83c8464c34247cf968250ee18"))
 (nim-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "nim-mode" :fetcher github :repo
		     "nim-lang/nim-mode" :old-names (nimrod-mode)
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id nim-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "4502f83fbbd262a8a7e014db9affcbf05c8a1e79"))
 (nix-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "nix-mode" :fetcher github :repo "NixOS/nix-mode"
		     :files
		     (:defaults
		      (:exclude "nix-company.el" "nix-mode-mmm.el"))
		     :source "MELPA" :id nix-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "2c77e7e0b7540efbb20ccaee3557ef90a5dc77f0"))
 (notmuch :source "elpaca-menu-lock-file" :recipe
	  (:package "notmuch" :url
		    "https://git.notmuchmail.org/git/notmuch" :fetcher
		    git :files ("emacs/*.el" "emacs/*.svg") :source
		    "MELPA" :id notmuch :type git :protocol https
		    :inherit t :depth treeless :ref
		    "f5e58cdb9b93b10ac32379b36b452532a32b8ece"))
 (odin-mode :source "elpaca-menu-lock-file" :recipe
	    (:source "User Declaration" :package "odin-mode" :id
		     odin-mode :host github :repo "mattt-b/odin-mode"
		     :type git :protocol https :inherit t :depth
		     treeless :ref
		     "21c6ff8b49f5eaa2d3b9969feeb08de921f11e92"))
 (olivetti :source "elpaca-menu-lock-file" :recipe
	   (:package "olivetti" :fetcher github :repo "rnkn/olivetti"
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id olivetti :type git :protocol
		     https :inherit t :depth treeless :ref
		     "d2ccae56b442d9c5b06dd2481057abbd7eb82551"))
 (orderless :source "elpaca-menu-lock-file" :recipe
	    (:package "orderless" :repo "oantolin/orderless" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id orderless :type git
		      :protocol https :inherit t :depth treeless :ref
		      "3d2c2e6468ddf51e69c78e8212e5fd9006d2ce8a"))
 (parinfer-rust-mode :source "elpaca-menu-lock-file" :recipe
		     (:package "parinfer-rust-mode" :repo
			       "justinbarclay/parinfer-rust-mode"
			       :fetcher github :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "MELPA" :id parinfer-rust-mode
			       :type git :protocol https :inherit t
			       :depth treeless :ref
			       "6ee9f905c41f6368689ad12aa99516b9ee4fb06d"))
 (parsebib :source "elpaca-menu-lock-file" :recipe
	   (:package "parsebib" :fetcher github :repo
		     "joostkremers/parsebib" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id parsebib :type git :protocol
		     https :inherit t :depth treeless :ref
		     "5b837e0a5b91a69cc0e5086d8e4a71d6d86dac93"))
 (parseclj :source "elpaca-menu-lock-file" :recipe
	   (:package "parseclj" :repo "clojure-emacs/parseclj"
		     :fetcher github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id parseclj :type git :protocol
		     https :inherit t :depth treeless :ref
		     "249079da5c2655a8e503b33280c1ab1341e72de2"))
 (parseedn :source "elpaca-menu-lock-file" :recipe
	   (:package "parseedn" :repo "clojure-emacs/parseedn"
		     :fetcher github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id parseedn :type git :protocol
		     https :inherit t :depth treeless :ref
		     "6ab98d33ae175f28e4bbf1df874030e1ff7b7add"))
 (pass :source "elpaca-menu-lock-file" :recipe
       (:package "pass" :fetcher github :repo "NicolasPetton/pass"
		 :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id pass :type git :protocol https
		 :inherit t :depth treeless :ref
		 "143456809fd2dbece9f241f4361085e1de0b0e75"))
 (password-store :source "elpaca-menu-lock-file" :recipe
		 (:package "password-store" :fetcher git :url
			   "https://git.zx2c4.com/password-store"
			   :files ("contrib/emacs/password-store*.el")
			   :source "MELPA" :id password-store :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "3ca13cd8882cae4083c1c478858adbf2e82dd037"))
 (password-store-otp :source "elpaca-menu-lock-file" :recipe
		     (:package "password-store-otp" :repo
			       "volrath/password-store-otp.el"
			       :fetcher github :files
			       ("*.el" "*.el.in" "dir" "*.info"
				"*.texi" "*.texinfo" "doc/dir"
				"doc/*.info" "doc/*.texi"
				"doc/*.texinfo" "lisp/*.el" "docs/dir"
				"docs/*.info" "docs/*.texi"
				"docs/*.texinfo"
				(:exclude ".dir-locals.el" "test.el"
					  "tests.el" "*-test.el"
					  "*-tests.el" "LICENSE"
					  "README*" "*-pkg.el"))
			       :source "MELPA" :id password-store-otp
			       :type git :protocol https :inherit t
			       :depth treeless :ref
			       "be3a00a981921ed1b2f78012944dc25eb5a0beca"))
 (pcache :source "elpaca-menu-lock-file" :recipe
	 (:package "pcache" :repo "sigma/pcache" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id pcache :type git :protocol
		   https :inherit t :depth treeless :ref
		   "17d785afa4532043afa8b2dc9ae3d9733528e758"))
 (pdf-tools :source "elpaca-menu-lock-file" :recipe
	    (:package "pdf-tools" :fetcher github :repo
		      "vedang/pdf-tools" :files
		      (:defaults "README" ("build" "Makefile")
				 ("build" "server"))
		      :source "MELPA" :id pdf-tools :type git
		      :protocol https :inherit t :depth treeless :ref
		      "365f88238f46f9b1425685562105881800f10386"))
 (persistent-soft :source "elpaca-menu-lock-file" :recipe
		  (:package "persistent-soft" :repo
			    "rolandwalker/persistent-soft" :fetcher
			    github :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id persistent-soft :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "c94b34332529df573bad8a97f70f5a35d5da7333"))
 (pfuture :source "elpaca-menu-lock-file" :recipe
	  (:package "pfuture" :repo "Alexander-Miller/pfuture"
		    :fetcher github :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id pfuture :type git :protocol
		    https :inherit t :depth treeless :ref
		    "19b53aebbc0f2da31de6326c495038901bffb73c"))
 (php-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "php-mode" :repo "emacs-php/php-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id php-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "0e32f79ffca49578eba452d38b62e434e517df5e"))
 (plantuml-mode :source "elpaca-menu-lock-file" :recipe
		(:package "plantuml-mode" :fetcher github :repo
			  "skuro/plantuml-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id plantuml-mode :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "a4a63efa4a3980bfbd825bfb3a263c6664401e79"))
 (popon :source "elpaca-menu-lock-file" :recipe
	(:package "popon" :repo
		  ("https://codeberg.org/akib/emacs-popon" . "popon")
		  :tar "0.13" :host nongnu :files
		  ("*" (:exclude ".git")) :source "NonGNU ELPA" :id
		  popon :type git :protocol https :inherit t :depth
		  treeless :ref
		  "bf8174cb7e6e8fe0fe91afe6b01b6562c4dc39da"))
 (posframe :source "elpaca-menu-lock-file" :recipe
	   (:package "posframe" :fetcher github :repo
		     "tumashu/posframe" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id posframe :type git :protocol
		     https :inherit t :depth treeless :ref
		     "4b69cc261f5a1675b8f0f54e2634b1451cbc8c32"))
 (projectile :source "elpaca-menu-lock-file" :recipe
	     (:package "projectile" :fetcher github :repo
		       "bbatsov/projectile" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id projectile :type git
		       :protocol https :inherit t :depth treeless :ref
		       "4d2be8680fe445c4ca88177f0ed838051cadfe58"))
 (proof-general :source "elpaca-menu-lock-file" :recipe
		(:package "proof-general" :fetcher github :repo
			  "ProofGeneral/PG" :files
			  (:defaults "CHANGES" "AUTHORS" "COPYING"
				     "generic" "images" "lib"
				     ("coq" "coq/*.el") "easycrypt"
				     "phox" "qrhl" "pghaskell"
				     "pgocaml" "pgshell")
			  :source "MELPA" :id proof-general :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "9799d01c357f9c35634887dffb3276b6d7adb1ac"))
 (protobuf-mode :source "elpaca-menu-lock-file" :recipe
		(:package "protobuf-mode" :fetcher github :repo
			  "protocolbuffers/protobuf" :files
			  ("editors/protobuf-mode.el") :source "MELPA"
			  :id protobuf-mode :type git :protocol https
			  :inherit t :depth treeless :ref
			  "d99376110688a6530204b7ac8a00ab93804da589"))
 (purescript-mode :source "elpaca-menu-lock-file" :recipe
		  (:package "purescript-mode" :repo
			    "purescript-emacs/purescript-mode"
			    :fetcher github :files
			    (:defaults "NEWS" "snippets") :source
			    "MELPA" :id purescript-mode :type git
			    :protocol https :inherit t :depth treeless
			    :ref
			    "73a72afa016827343623604025952202dd4e2f3b"))
 (queue :source "elpaca-menu-lock-file" :recipe
	(:package "queue" :repo
		  ("https://github.com/emacsmirror/gnu_elpa" . "queue")
		  :tar "0.2" :host gnu :branch "externals/queue"
		  :files ("*" (:exclude ".git")) :source "GNU ELPA"
		  :id queue :type git :protocol https :inherit t
		  :depth treeless :ref
		  "f986fb68e75bdae951efb9e11a3012ab6bd408ee"))
 (quickrun :source "elpaca-menu-lock-file" :recipe
	   (:package "quickrun" :repo "emacsorphanage/quickrun"
		     :fetcher github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id quickrun :type git :protocol
		     https :inherit t :depth treeless :ref
		     "a25264bead36ea4cb8c6fe6ba3755508f5cb8d83"))
 (racket-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "racket-mode" :fetcher github :repo
			"greghendershott/racket-mode" :files
			(:defaults "*.rkt" ("racket" "racket/*")
				   (:exclude "racket/example/*"
					     "racket/test/*"))
			:source "MELPA" :id racket-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"112ede7765c19011f58d67b4dac9a5435846a07d"))
 (rainbow-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "rainbow-mode" :repo
			 ("https://github.com/emacsmirror/gnu_elpa"
			  . "rainbow-mode")
			 :tar "1.0.7" :host gnu :branch
			 "externals/rainbow-mode" :files
			 ("*" (:exclude ".git")) :source "GNU ELPA"
			 :id rainbow-mode :type git :protocol https
			 :inherit t :depth treeless :ref
			 "9d333d3a92132c2a9057d2a39e1ebd8cc575a1bb"))
 (reformatter :source "elpaca-menu-lock-file" :recipe
	      (:package "reformatter" :repo
			"purcell/emacs-reformatter" :fetcher github
			:files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id reformatter :type git
			:protocol https :inherit t :depth treeless
			:ref
			"2bd8818f3f2119a3876e574a437495214c87bc81"))
 (request :source "elpaca-menu-lock-file"
   :recipe
   (:package "request" :repo "tkf/emacs-request" :fetcher github
	     :files ("request.el") :source "MELPA" :id request :type
	     git :protocol https :inherit t :depth treeless :ref
	     "c22e3c23a6dd90f64be536e176ea0ed6113a5ba6"))
 (restclient :source "elpaca-menu-lock-file" :recipe
	     (:package "restclient" :fetcher github :repo
		       "emacsorphanage/restclient" :files
		       ("restclient.el") :source "MELPA" :id
		       restclient :type git :protocol https :inherit t
		       :depth treeless :ref
		       "d280632df39a175dac06037038105e32945624be"))
 (rust-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "rust-mode" :repo "rust-lang/rust-mode" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id rust-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "265e243732761b925e03ebb61930a3aeea034d0e"))
 (s :source "elpaca-menu-lock-file" :recipe
    (:package "s" :fetcher github :repo "magnars/s.el" :files
	      ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
	       "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
	       "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
	       "docs/*.texinfo"
	       (:exclude ".dir-locals.el" "test.el" "tests.el"
			 "*-test.el" "*-tests.el" "LICENSE" "README*"
			 "*-pkg.el"))
	      :source "MELPA" :id s :type git :protocol https :inherit
	      t :depth treeless :ref
	      "d7c04b84d03481a1ed62ee13dbe595224ccbe57c"))
 (sbt-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "sbt-mode" :fetcher github :repo
		     "hvesalai/emacs-sbt-mode" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id sbt-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "c353df6aa112c05dde6dc63ccf813c2203cb472b"))
 (scala-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "scala-mode" :fetcher github :repo
		       "hvesalai/emacs-scala-mode" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id scala-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "50bcafa181baec7054e27f4bca55d5f9277c6350"))
 (sesman :source "elpaca-menu-lock-file" :recipe
	 (:package "sesman" :repo "vspinu/sesman" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id sesman :type git :protocol
		   https :inherit t :depth treeless :ref
		   "7eb733acb33e610a53979fa7fc13393eeda3cc53"))
 (slime :source "elpaca-menu-lock-file" :recipe
	(:package "slime" :fetcher github :repo "slime/slime" :files
		  ("*.el" ("lib" "lib/hyperspec.el") "swank" "*.lisp"
		   "*.asd" "doc/slime.texi" "doc/slime.info" "doc/dir"
		   "ChangeLog" ("contrib" "contrib/*")
		   (:exclude "contrib/test" "contrib/Makefile"))
		  :source "MELPA" :id slime :host github :ref
		  "82dfda1a83e22de6fad93f54f3201f5dec6754fb" :type git
		  :protocol https :inherit t :depth treeless))
 (smartparens :source "elpaca-menu-lock-file" :recipe
	      (:package "smartparens" :fetcher github :repo
			"Fuco1/smartparens" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id smartparens :type git
			:protocol https :inherit t :depth treeless
			:ref
			"82d2cf084a19b0c2c3812e0550721f8a61996056"))
 (sml-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "sml-mode" :repo
		     ("https://github.com/emacsmirror/gnu_elpa"
		      . "sml-mode")
		     :tar "6.12" :host gnu :branch
		     "externals/sml-mode" :files
		     ("*" (:exclude ".git")) :source "GNU ELPA" :id
		     sml-mode :type git :protocol https :inherit t
		     :depth treeless :ref
		     "39ad5243eb761821e5342ed8cf1ba111d2492f48"))
 (solidity-mode :source "elpaca-menu-lock-file" :recipe
		(:package "solidity-mode" :fetcher github :repo
			  "ethereum/emacs-solidity" :files
			  (:defaults
			   (:exclude "company-solidity.el"
				     "solidity-flycheck.el"))
			  :source "MELPA" :id solidity-mode :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "8ba549e429e86778a0e079648f3bc3463fcb15f6"))
 (spinner :source "elpaca-menu-lock-file" :recipe
	  (:package "spinner" :repo
		    ("https://github.com/Malabarba/spinner.el"
		     . "spinner")
		    :tar "1.7.4" :host gnu :files
		    ("*" (:exclude ".git")) :source "GNU ELPA" :id
		    spinner :type git :protocol https :inherit t
		    :depth treeless :ref
		    "d4647ae87fb0cd24bc9081a3d287c860ff061c21"))
 (sql-indent :source "elpaca-menu-lock-file" :recipe
	     (:package "sql-indent" :repo
		       ("https://github.com/alex-hhh/emacs-sql-indent"
			. "sql-indent")
		       :tar "1.7" :host gnu :files
		       ("*" (:exclude ".git")) :source "GNU ELPA" :id
		       sql-indent :type git :protocol https :inherit t
		       :depth treeless :ref
		       "2ed4c6a26b8f3d651ac6231eaafb2565d77c918b"))
 (ssh-deploy :source "elpaca-menu-lock-file" :recipe
	     (:package "ssh-deploy" :repo
		       ("https://forgejo.cvj.se/cjohansson/emacs-ssh-deploy"
			. "ssh-deploy")
		       :tar "3.1.16" :host gnu :files
		       ("*" (:exclude ".git")) :source "GNU ELPA" :id
		       ssh-deploy :type git :protocol https :inherit t
		       :depth treeless :ref
		       "d33b081828c9a13730ff2af8dc548ad6eeeea61f"))
 (string-inflection :source "elpaca-menu-lock-file" :recipe
		    (:package "string-inflection" :fetcher github
			      :repo "akicho8/string-inflection" :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "MELPA" :id string-inflection
			      :type git :protocol https :inherit t
			      :depth treeless :ref
			      "4a2f87d7b47f5efe702a78f8a40a98df36eeba13"))
 (swift-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "swift-mode" :repo "swift-emacs/swift-mode"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id swift-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "a81a6e5edc3077ea34ded55a6179f5d6166a3008"))
 (tablist :source "elpaca-menu-lock-file" :recipe
	  (:package "tablist" :fetcher github :repo
		    "emacsorphanage/tablist" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id tablist :type git :protocol
		    https :inherit t :depth treeless :ref
		    "01f065e387ffe6b7a41f180f257cd12551c7a9c2"))
 (taskrunner :source "elpaca-menu-lock-file" :recipe
	     (:package "taskrunner" :fetcher github :repo
		       "emacs-taskrunner/emacs-taskrunner" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id taskrunner :type git
		       :protocol https :inherit t :depth treeless :ref
		       "716323aff410b4d864d137c9ebe4bbb5b8587f5e"))
 (tempel :source "elpaca-menu-lock-file" :recipe
	 (:package "tempel" :repo "minad/tempel" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id tempel :type git :protocol
		   https :inherit t :depth treeless :ref
		   "9299c5d0f35dbb02de2565404a082224c4d11654"))
 (terraform-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "terraform-mode" :repo
			   "hcl-emacs/terraform-mode" :fetcher github
			   :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id terraform-mode :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "01635df3625c0cec2bb4613a6f920b8569d41009"))
 (toml-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "toml-mode" :fetcher github :repo
		      "dryman/toml-mode.el" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id toml-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "f6c61817b00f9c4a3cab1bae9c309e0fc45cdd06"))
 (treemacs :source "elpaca-menu-lock-file" :recipe
	   (:package "treemacs" :fetcher github :repo
		     "Alexander-Miller/treemacs" :files
		     (:defaults "Changelog.org" "icons"
				"src/elisp/treemacs*.el"
				"src/scripts/treemacs*.py"
				(:exclude "src/extra/*"))
		     :source "MELPA" :id treemacs :type git :protocol
		     https :inherit t :depth treeless :ref
		     "2ab5a3c89fa01bbbd99de9b8986908b2bc5a7b49"))
 (treemacs-nerd-icons :source "elpaca-menu-lock-file" :recipe
		      (:package "treemacs-nerd-icons" :fetcher github
				:repo
				"rainstormstudio/treemacs-nerd-icons"
				:files
				("*.el" "*.el.in" "dir" "*.info"
				 "*.texi" "*.texinfo" "doc/dir"
				 "doc/*.info" "doc/*.texi"
				 "doc/*.texinfo" "lisp/*.el"
				 "docs/dir" "docs/*.info"
				 "docs/*.texi" "docs/*.texinfo"
				 (:exclude ".dir-locals.el" "test.el"
					   "tests.el" "*-test.el"
					   "*-tests.el" "LICENSE"
					   "README*" "*-pkg.el"))
				:source "MELPA" :id
				treemacs-nerd-icons :type git
				:protocol https :inherit t :depth
				treeless :ref
				"0c5ddcb978da639f01ddb023febc40fc755171e5"))
 (treepy :source "elpaca-menu-lock-file" :recipe
	 (:package "treepy" :repo "volrath/treepy.el" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id treepy :type git :protocol
		   https :inherit t :depth treeless :ref
		   "806c000bd40153d17dfa5709c6d19546d507a416"))
 (treesit-fold :source "elpaca-menu-lock-file" :recipe
	       (:package "treesit-fold" :repo
			 "emacs-tree-sitter/treesit-fold" :tar "0.2.1"
			 :host github :files ("*" (:exclude ".git"))
			 :source "NonGNU ELPA" :id treesit-fold :ref
			 "cc1003b730a3167b972cc8400dffe19be7988fc7"
			 :type git :protocol https :inherit t :depth
			 treeless))
 (tuareg :source "elpaca-menu-lock-file" :recipe
	 (:package "tuareg" :fetcher github :repo "ocaml/tuareg"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id tuareg :type git :protocol
		   https :inherit t :depth treeless :ref
		   "696fdc59e3a35cc44cd1c2d0607d782e0f0c9e71"))
 (ucs-utils :source "elpaca-menu-lock-file" :recipe
	    (:package "ucs-utils" :repo "rolandwalker/ucs-utils"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id ucs-utils :type git
		      :protocol https :inherit t :depth treeless :ref
		      "91b9e0207fff5883383fd39c45ad5522e9b90e65"))
 (undo-fu-session :source "elpaca-menu-lock-file" :recipe
		  (:package "undo-fu-session" :fetcher codeberg :repo
			    "emacsmirror/undo-fu-session" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id undo-fu-session :host
			    github :type git :protocol https :inherit
			    t :depth treeless :ref
			    "92d733a5b162a70c572fac17b9f9e872426df547"))
 (unicode-fonts :source "elpaca-menu-lock-file" :recipe
		(:package "unicode-fonts" :repo
			  "rolandwalker/unicode-fonts" :fetcher github
			  :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id unicode-fonts :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "d4a0648a2206d9a896433817110957b3b9e1c17a"))
 (vertico :source "elpaca-menu-lock-file" :recipe
	  (:package "vertico" :repo "minad/vertico" :files
		    (:defaults "extensions/vertico-*.el") :fetcher
		    github :source "MELPA" :id vertico :type git
		    :protocol https :inherit t :depth treeless :ref
		    "a9998a777f1d92348f84d091bb15b87df933a7a2"))
 (vterm :source "elpaca-menu-lock-file" :recipe
	(:package "vterm" :fetcher github :repo
		  "akermu/emacs-libvterm" :files
		  ("CMakeLists.txt" "elisp.c" "elisp.h"
		   "emacs-module.h" "etc" "utf8.c" "utf8.h" "vterm.el"
		   "vterm-module.c" "vterm-module.h")
		  :source "MELPA" :id vterm :type git :protocol https
		  :inherit t :depth treeless :ref
		  "6d715a93fa0e5182bc137d4db09f376e06938aa5"))
 (web-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "web-mode" :repo "fxbois/web-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id web-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "ce24723eb900c455b488d224910519bd36af580a"))
 (which-key :source "elpaca-menu-lock-file" :recipe
	    (:package "which-key" :repo "justbur/emacs-which-key"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id which-key :type git
		      :protocol https :inherit t :depth treeless :ref
		      "38d4308d1143b61e4004b6e7a940686784e51500"))
 (with-editor :source "elpaca-menu-lock-file" :recipe
	      (:package "with-editor" :fetcher github :repo
			"magit/with-editor" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id with-editor :type git
			:protocol https :inherit t :depth treeless
			:ref
			"ca956bbfd1c9f163d2a8390716fcd39799d23f34"))
 (yaml :source "elpaca-menu-lock-file" :recipe
       (:package "yaml" :repo "zkry/yaml.el" :fetcher github :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id yaml :type git :protocol https
		 :inherit t :depth treeless :ref
		 "5546f36bde24a9a8c1934e0f6ce205cd41d72537"))
 (yaml-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "yaml-mode" :repo "yoshiki/yaml-mode" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id yaml-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "93dba98c050e9abfc623ec66aa499dbbb46b2fe1"))
 (yasnippet :source "elpaca-menu-lock-file" :recipe
	    (:package "yasnippet" :fetcher github :repo
		      "joaotavora/yasnippet" :files
		      (:defaults ("doc" "doc/*.org")) :source "MELPA"
		      :id yasnippet :type git :protocol https :inherit
		      t :depth treeless :ref
		      "c1e6ff23e9af16b856c88dfaab9d3ad7b746ad37"))
 (zig-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "zig-mode" :repo "ziglang/zig-mode" :fetcher
		     codeberg :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id zig-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "62bfbaced0222e2bfbc086fa8556adf6b3298476")))
