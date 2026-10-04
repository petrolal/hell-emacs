# Developer checks for Hell Emacs' engine (lisp/). Every target runs Emacs
# the way bin/hell does: batch, early-init.el first. HELLDIR and the XDG
# directories point into a throwaway directory, so your own config and
# packages are never read or touched.

EMACS ?= emacs
# Gitignored, as every root dotfile.
TMP   := $(CURDIR)/.make-tmp

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

.PHONY: all compile checkdoc test lock clean

all: compile test

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
