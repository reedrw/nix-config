#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils gnused procps sshpass openssh

# stage — build, boot, screenshot, and tear down the nixos-vm staging VM.
#
# Usage:
#   ./stage.sh [output.png]
#
#   output.png  where to write the screenshot (default:
#               repo/stage/screenshots/<timestamp>.png, gitignored)
#
# Env overrides (passed through to the primitive scripts):
#   VM_PORT, VM_MEM, VM_CPUS, VM_DISPLAY, VM_USER, VM_PASSWORD

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
: "${VM_PORT:=2222}"

screenshots_dir="$script_dir/screenshots"
mkdir -p "$screenshots_dir"

if [ -n "${1:-}" ]; then
  out="$1"
else
  out="$screenshots_dir/$(date +%Y%m%d-%H%M%S).png"
fi

# Warn if nothing is staged — the most common reason the VM shows stale output.
if git -C "$script_dir/../.." diff --cached --quiet 2>/dev/null; then
  echo "stage: warning: no staged changes — VM will reflect last committed state" >&2
  echo "stage: run 'git add <files>' if you meant to test uncommitted edits" >&2
fi

cleanup() { "$script_dir/stop.sh"; }
trap cleanup EXIT

echo "stage: starting VM" >&2
"$script_dir/run.sh"

echo "stage: waiting for boot" >&2
"$script_dir/wait.sh" "$VM_PORT"

echo "stage: capturing screenshot → $out" >&2
"$script_dir/shoot.sh" "$VM_PORT" "$out"

echo "stage: done — screenshot at $out" >&2
