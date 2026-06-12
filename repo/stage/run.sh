#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils gnused procps

# run — launch the nixos-vm staging VM in the background.
#
# Env overrides:
#   VM_PORT      host SSH forward port (default 2222)
#   VM_MEM       RAM in MiB (default 4096)
#   VM_CPUS      vCPUs (default 4)
#   VM_DISPLAY   QEMU display mode (default "none"; use "gtk" to see a window)
#
# Runtime files land in $XDG_RUNTIME_DIR/stage/ (or /tmp/stage-$UID/ as
# fallback) so nothing in-tree grows per-run.

set -euo pipefail

: "${VM_PORT:=2222}"
: "${VM_MEM:=4096}"
: "${VM_CPUS:=4}"
: "${VM_DISPLAY:=none}"

run_dir="${XDG_RUNTIME_DIR:-/tmp/stage-$UID}/stage"
mkdir -p "$run_dir"

host=nixos-vm
pidfile="$run_dir/$host.pid"
logfile="$run_dir/$host.log"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  echo "run: $host already running (pid $(cat "$pidfile"))" >&2
  echo "     stop it with stop.sh, or use VM_PORT to run a second instance" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

echo "run: building $host VM (fast after the first run)" >&2
vm_runner="$(nix build --no-link --print-out-paths \
  "$repo_root#nixosConfigurations.$host.config.system.build.vm")"

export QEMU_NET_OPTS="hostfwd=tcp::$VM_PORT-:22"
export QEMU_OPTS="-display $VM_DISPLAY -snapshot -m $VM_MEM -smp $VM_CPUS -audio none"

echo "run: starting QEMU (logs: $logfile)" >&2
export TMPDIR=/tmp
nohup "$vm_runner/bin/run-$host-vm" \
  >"$logfile" 2>&1 &
echo $! >"$pidfile"
disown

echo "run: pid $(cat "$pidfile"), SSH on localhost:$VM_PORT" >&2
