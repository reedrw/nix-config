#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils sshpass openssh

# shoot — capture a screenshot from the staging VM.
#
# Usage:
#   ./shoot.sh <port> <output.png>
#
# Picks Wayland (grim) or X11 (maim) automatically via the
# vm-screenshot-grab script installed in every staging VM.
# Env: VM_USER (default reed), VM_PASSWORD (default vm)

set -euo pipefail

port="${1:?usage: shoot.sh <port> <output.png>}"
out="${2:?usage: shoot.sh <port> <output.png>}"

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

# PNGs start with 89 50 4E 47; anything else means the grab failed silently.
header="$(head -c 4 "$out" | od -An -tx1 | tr -d ' \n')"
if [ "$header" != "89504e47" ]; then
  echo "shoot: $out is not a PNG (header: $header)" >&2
  echo "shoot: dumping first 200 bytes for debug:" >&2
  head -c 200 "$out" >&2
  exit 1
fi

echo "shoot: wrote $out ($(stat -c%s "$out") bytes)" >&2
