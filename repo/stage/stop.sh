#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils procps

# stop — terminate the running nixos-vm staging VM.

set -euo pipefail

run_dir="${XDG_RUNTIME_DIR:-/tmp/stage-$UID}/stage"
pidfile="$run_dir/nixos-vm.pid"

if [ ! -f "$pidfile" ]; then
  echo "stop: no pidfile (already stopped?)" >&2
  exit 0
fi

pid="$(cat "$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  echo "stop: killing nixos-vm (pid $pid)" >&2
  kill "$pid"
  for _ in 1 2 3 4 5; do
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "stop: pid $pid did not exit on SIGTERM, sending SIGKILL" >&2
    kill -9 "$pid" || true
  fi
fi
rm -f "$pidfile"
echo "stop: nixos-vm stopped" >&2
