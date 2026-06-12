#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils gnused procps

# vm-run — launch a staging VM in the background.
#
# Usage:
#   ./vm-staging/scripts/vm-run.sh <host>
#     <host>  one of: nixos-vm, nixos-vm-sway
#
# Env overrides:
#   VM_PORT      host SSH forward port (default 2222)
#   VM_MEM       RAM in MiB (default 4096)
#   VM_CPUS      vCPUs (default 4)
#   VM_DISPLAY   QEMU display mode (default "none"; use "gtk" to see a window)
#
# The VM uses QEMU's `-snapshot` flag so state is wiped on exit — the
# host's /nix/store is bind-mounted in, so a `nixos-rebuild test` from
# inside the VM picks up host-side changes after just a `git add`.
#
# Side effects:
#   ./vm-staging/run/<host>.pid     pidfile for vm-stop
#   ./vm-staging/run/<host>.log     stdout/stderr of QEMU
#   tcp localhost:$VM_PORT          forwarded to guest port 22 (SSH)

set -euo pipefail

host="${1:?usage: vm-run <nixos-vm|nixos-vm-sway>}"
case "$host" in
  nixos-vm|nixos-vm-sway) ;;
  *) echo "unknown host: $host (expected nixos-vm or nixos-vm-sway)" >&2; exit 2 ;;
esac

: "${VM_PORT:=2222}"
: "${VM_MEM:=4096}"
: "${VM_CPUS:=4}"
: "${VM_DISPLAY:=none}"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
run_dir="$repo_root/vm-staging/run"
mkdir -p "$run_dir"

pidfile="$run_dir/$host.pid"
logfile="$run_dir/$host.log"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  echo "vm-run: $host already running (pid $(cat "$pidfile"))" >&2
  echo "        stop it with vm-stop $host, or use VM_PORT to run a second instance" >&2
  exit 1
fi

echo "vm-run: building $host VM (this is fast after the first run)" >&2
vm_runner="$(nix build --no-link --print-out-paths \
  ".#nixosConfigurations.$host.config.system.build.vm")"

# The runner script normally execs QEMU directly. Wrap it with our args.
# Flags:
#   QEMU_NET_OPTS  — port-forward host:VM_PORT → guest:22
#   QEMU_OPTS      — headless, snapshot, RAM/CPU sizing, no audio
export QEMU_NET_OPTS="hostfwd=tcp::$VM_PORT-:22"
export QEMU_OPTS="-display $VM_DISPLAY -snapshot -m $VM_MEM -smp $VM_CPUS -audio none"

echo "vm-run: starting QEMU (logs: $logfile)" >&2
# Reset TMPDIR so QEMU's disk image doesn't land in a nix-shell build dir.
export TMPDIR=/tmp
nohup "$vm_runner/bin/run-$host-vm" \
  >"$logfile" 2>&1 &
echo $! >"$pidfile"
disown

echo "vm-run: pid $(cat "$pidfile"), SSH on localhost:$VM_PORT" >&2
echo "vm-run: wait for boot with: ./vm-staging/scripts/vm-wait.sh $VM_PORT" >&2
