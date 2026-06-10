#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils procps

# vm-stop — terminate a running staging VM.
# Usage:
#   ./vm-staging/scripts/vm-stop.sh <host>
#     <host>  one of: nixos-vm, nixos-vm-sway

set -euo pipefail

host="${1:?usage: vm-stop <nixos-vm|nixos-vm-sway>}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pidfile="$repo_root/vm-staging/run/$host.pid"

if [ ! -f "$pidfile" ]; then
  echo "vm-stop: no pidfile for $host (already stopped?)" >&2
  exit 0
fi

pid="$(cat "$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  echo "vm-stop: killing $host (pid $pid)" >&2
  kill "$pid"
  for _ in 1 2 3 4 5; do
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "vm-stop: pid $pid did not exit on SIGTERM, sending SIGKILL" >&2
    kill -9 "$pid" || true
  fi
fi
rm -f "$pidfile"
echo "vm-stop: $host stopped" >&2
