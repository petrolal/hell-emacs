#!/bin/sh
# budgets.sh --- measure the Phase 12.7 performance budgets
#
# Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
#
# Author: petrolal <petrolalucas@gmail.com>
# URL: https://github.com/petrolal/hellmacs
# License: GPL-3.0-or-later
#
# This file is part of Hellmacs.
#
# Hellmacs is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Hellmacs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# The weekly budget job (.github/workflows/budgets.yml), runnable by hand:
#
#   test/integration/budgets.sh WORKDIR
#
# Everything goes under WORKDIR (several GB: a synced profile with every
# module on, the reference project, IntelliJ, build output); run it again
# with the same WORKDIR and the downloads are reused. Steps:
#
#   1. sync a profile with every module Hellmacs ships (budgets.el)
#   2. startup-bench.el in a terminal: the startup budget
#   3. java-parity.el on the reference project: import, completion, memory
#   4. intellij-baseline.el on the same project: IntelliJ's own numbers
#   5. budgets-check.el: the table, and a non-zero exit on a broken budget
#
# The measurements land in WORKDIR/budgets.txt, the logs next to it.
# Needs: emacs (or $EMACS), git, a JDK for JDTLS and one the reference
# project builds with ($JAVA_HOME), and `script' (util-linux). Linux.

set -u

[ $# -eq 1 ] || { echo "usage: $0 WORKDIR" >&2; exit 2; }
mkdir -p "$1" || exit 2
work=$(cd "$1" && pwd)
root=$(cd "$(dirname "$0")/../.." && pwd)
emacs=${EMACS:-emacs}

# A throwaway Hellmacs: its own config, data, cache and state, and the
# big downloads kept between runs.
export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
export XDG_CACHE_HOME="$work/cache" XDG_STATE_HOME="$work/state"
export HELLMACSDIR="$work/user"
export HELLMACS_REFERENCE_DIR="$work/reference" HELLMACS_INTELLIJ_DIR="$work/intellij"
export HELLMACS_BUDGET_OUT="$work/budgets.txt"
export HELLMACS_PARITY_REFERENCE="${HELLMACS_PARITY_REFERENCE:-spring-framework}"
export HELLMACS_PARITY_TIMEOUT="${HELLMACS_PARITY_TIMEOUT:-1800}"
export TMPDIR="$work/tmp"
mkdir -p "$HELLMACSDIR" "$TMPDIR"
rm -f "$HELLMACS_BUDGET_OUT" "$work/parity.log" "$work/intellij.log"

step() { printf '\n==> %s\n' "$*"; }

step "Sync a profile with every module on"
"$emacs" --batch -l "$root/early-init.el" \
  --eval "(load (expand-file-name \"test/integration/budgets\" hellmacs-dir) nil t)" \
  --eval "(budgets-write-enterprise-init \"$HELLMACSDIR\")" || exit 1
"$root/bin/hellmacs" sync > "$work/sync.log" 2>&1 || { tail -40 "$work/sync.log"; exit 1; }

step "Startup (terminal frame)"
# Twice: the first run warms the file cache, as any later start finds
# it, and records nothing (an empty HELLMACS_BUDGET_OUT).
bench() {
  rm -f "$work/startup-$1.txt"
  HELLMACS_BUDGET_OUT="$2" HELLMACS_BENCH_OUT="$work/startup-$1.txt" TERM=xterm-256color \
    script -qec "\"$emacs\" -nw --init-directory \"$root\" -l \"$root/test/integration/startup-bench.el\"" /dev/null \
    > /dev/null 2>&1 < /dev/null
}
bench warm ""
bench measured "$HELLMACS_BUDGET_OUT"
cat "$work/startup-measured.txt"

step "JDTLS on $HELLMACS_PARITY_REFERENCE (java-parity.el)"
HELLMACS_E2E_OUT="$work/parity.log" "$emacs" --batch -l "$root/early-init.el" -l "$root/init.el" \
  -l "$root/test/integration/java-parity.el" > /dev/null 2>&1
grep -E 'METRIC|FAIL|PASSED|FAILED' "$work/parity.log"

step "IntelliJ on $HELLMACS_PARITY_REFERENCE (intellij-baseline.el)"
HELLMACS_E2E_OUT="$work/intellij.log" "$emacs" --batch -l "$root/early-init.el" -l "$root/init.el" \
  -l "$root/test/integration/intellij-baseline.el" > /dev/null 2>&1
cat "$work/intellij.log"

step "Budgets"
"$emacs" --batch -l "$root/early-init.el" -l "$root/test/integration/budgets-check.el"
