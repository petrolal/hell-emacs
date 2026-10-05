# Installing Hell Emacs (install, sync, doctor), and developer checks for
# its engine (lisp/). The checks run Emacs the way bin/hell does: batch,
# early-init.el first, with HELLDIR and the XDG directories pointing into a
# throwaway directory, so your own config and packages are never read or
# touched. install, sync and doctor are bin/hell's, on your real ones.

EMACS ?= emacs
# Gitignored, as every root dotfile.
TMP   := $(CURDIR)/.make-tmp

# The variables below point the checks away from your directories. Your own
# values of them, if you set any, as NAME='VALUE' for env(1): install, sync
# and doctor run bin/hell with these, and without the checks' ones.
USER_DIRS := HELLDIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
USER_ENV  := $(foreach v,$(USER_DIRS),$(if $(filter environment%,$(origin $(v))),'$(v)=$($(v))'))
HELL      := env $(addprefix -u ,$(USER_DIRS)) $(USER_ENV) $(CURDIR)/bin/hell

export HELLDIR        := $(TMP)/config
export XDG_CONFIG_HOME := $(TMP)/xdg/config
export XDG_DATA_HOME  := $(TMP)/xdg/data
export XDG_CACHE_HOME := $(TMP)/xdg/cache
export XDG_STATE_HOME := $(TMP)/xdg/state

BATCH := $(EMACS) -Q --batch -l early-init.el --eval "(require 'hell-cli)"

# hell-elpaca.el is Elpaca's installer, never byte-compiled.
CORE  := $(filter-out lisp/hell-elpaca.el,$(wildcard lisp/hell-*.el)) \
         $(wildcard lisp/cli/*.el lisp/lib/*.el)
TESTS := $(wildcard test/*-test.el)

.PHONY: all install sync doctor compile checkdoc test lock clean

all: compile test

## install: install Hell Emacs for you, as `bin/hell install' does: your
## config (~/.config/hell-emacs), packages, language servers, grammars, then
## doctor. Options go in ARGS: make install ARGS="--no-env --aot".
## sync: install what your config declares, after changing it (bin/hell sync).
## doctor: check Emacs, tools and your config for problems (bin/hell doctor).
install sync doctor:
	@$(HELL) $@ $(ARGS)

## compile: byte-compile the engine; any warning fails. The .elc files go to
## a temporary directory, never next to the sources.
compile:
	@$(BATCH) \
	  --eval "(setq byte-compile-error-on-warn t \
	                byte-compile-dest-file-function \
	                (lambda (f) (expand-file-name (concat (file-name-base f) \".elc\") \"$(TMP)\")))" \
	  -f batch-byte-compile $(CORE) $(TESTS)

## checkdoc: report docstring and header style (one space after a period,
## see .dir-locals.el). Advisory: some warnings are false positives.
checkdoc:
	@for f in early-init.el $(CORE) $(TESTS); do \
	  $(EMACS) -Q --batch --eval "(setq sentence-end-double-space nil)" \
	    --eval "(checkdoc-file \"$$f\")" 2>&1 | grep -v '^Warning (emacs): *$$' | grep . ; \
	done; true

## test: run the ERT suite in test/.
test:
	@$(BATCH) -L test $(addprefix -l ,$(TESTS)) -f ert-run-tests-batch-and-exit

## lock: regenerate static/packages.lock.eld, the commits a fresh install gets:
## every module's packages, newest (or :pin), in its own HELLDIR. Slow and
## needs the network; test the result before committing it.
lock: export HELLDIR := $(TMP)/lock
lock:
	@$(BATCH) -l scripts/default-lock.el

clean:
	@rm -rf $(TMP)
