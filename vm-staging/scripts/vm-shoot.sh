#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils sshpass openssh

# vm-shoot — capture a screenshot from the staging VM.
#
# Usage:
#   ./vm-staging/scripts/vm-shoot.sh <port> <output.png>
#
# Examples:
#   vm-shoot.sh 2222 ./vm-staging/screenshots/sway-current.png
#
# Picks Wayland (grim) or X11 (maim) automatically via the
# `vm-screenshot-grab` script that's installed in every staging VM.
# Env: VM_USER (default reed), VM_PASSWORD (default vm)

set -euo pipefail

port="${1:?usage: vm-shoot <port> <output.png>}"
out="${2:?usage: vm-shoot <port> <output.png>}"

: "${VM_USER:=reed}"
: "${VM_PASSWORD:=vm}"

mkdir -p "$(dirname "$out")"

sshpass -p "$VM_PASSWORD" ssh \
  -o "UserKnownHostsFile=/dev/null" \
  -o "StrictHostKeyChecking=no" \
  -o "LogLevel=ERROR" \
  -p "$port" \
  "$VM_USER@localhost" \
  vm-screenshot-grab > "$out"

# Sanity: PNGs start with 89 50 4E 47. If we got something else, the
# grab failed silently — report it so agents don't blindly compare junk.
header="$(head -c 4 "$out" | od -An -tx1 | tr -d ' \n')"
if [ "$header" != "89504e47" ]; then
  echo "vm-shoot: $out is not a PNG (header: $header)" >&2
  echo "vm-shoot: dumping first 200 bytes for debug:" >&2
  head -c 200 "$out" >&2
  exit 1
fi

echo "vm-shoot: wrote $out ($(stat -c%s "$out") bytes)" >&2
