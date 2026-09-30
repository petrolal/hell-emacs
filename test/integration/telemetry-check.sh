#!/bin/sh
# test/integration/telemetry-check.sh -- the live check of "no telemetry" (12.9).
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
# Runs telemetry-e2e.el in a network namespace of its own (Linux user
# namespaces): only loopback, /etc/resolv.conf pointing at the Emacs
# running the session, and name lookups through DNS alone (not
# systemd-resolved, which would answer from outside). Every name looked up
# reaches that Emacs, which logs it and answers "no such host". On your
# synced profile (the modules you enable are the ones checked); set
# XDG_*_HOME and HELLMACSDIR for another. HELLMACS_TELEMETRY_SECONDS (90)
# is how long each server gets to start, and the session's final pause.
#
# The namespace is set up as root (of the namespace: loopback, the resolver
# files, and port 53 opened to everyone), then the session runs in a nested
# one mapped back to your own uid (util-linux 2.38 or later): as root, JVMs
# would take /root for home and miss your ~/.m2 and ~/.gradle.

set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
EMACS=${EMACS:-emacs}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hellmacs-telemetry.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

printf 'nameserver 127.0.0.1\noptions timeout:1 attempts:1\n' > "$TMP/resolv.conf"
printf 'hosts: files dns\n' > "$TMP/nsswitch.conf"

exec unshare --user --map-root-user --net --mount sh -c '
  ip link set lo up &&
  echo 0 > /proc/sys/net/ipv4/ip_unprivileged_port_start &&
  mount --bind "$1/resolv.conf" /etc/resolv.conf &&
  mount --bind "$1/nsswitch.conf" /etc/nsswitch.conf &&
  cd "$2" &&
  exec unshare --user --map-user="$4" --map-group="$5" \
    "$3" --batch -l early-init.el -l init.el -l test/integration/telemetry-e2e.el
' telemetry-check "$TMP" "$ROOT" "$EMACS" "$(id -u)" "$(id -g)"
