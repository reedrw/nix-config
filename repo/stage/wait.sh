#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils sshpass openssh

# wait — block until the staging VM accepts SSH and a graphical session is up.
# Times out after ~120s.
#
# Usage:
#   ./wait.sh [VM_PORT]
#
# Exit codes:
#   0  ssh ok and a display server (sway or Xorg) is running
#   1  timed out waiting for ssh
#   2  ssh works but no graphical session appeared

set -euo pipefail

port="${1:-2222}"
: "${VM_USER:=reed}"
: "${VM_PASSWORD:=vm}"

ssh_opts=(
  -o "UserKnownHostsFile=/dev/null"
  -o "StrictHostKeyChecking=no"
  -o "LogLevel=ERROR"
  -o "ConnectTimeout=3"
  -p "$port"
)

echo -n "wait: waiting for SSH on localhost:$port" >&2
for i in $(seq 1 60); do
  if sshpass -p "$VM_PASSWORD" \
      ssh "${ssh_opts[@]}" "$VM_USER@localhost" true 2>/dev/null; then
    echo " ok ($((i * 2))s)" >&2
    break
  fi
  echo -n "." >&2
  sleep 2
  if [ "$i" -eq 60 ]; then
    echo " timeout" >&2
    exit 1
  fi
done

echo -n "wait: waiting for graphical session" >&2
for i in $(seq 1 30); do
  if sshpass -p "$VM_PASSWORD" \
      ssh "${ssh_opts[@]}" "$VM_USER@localhost" \
        'pgrep -x sway >/dev/null 2>&1 || pgrep -x Xorg >/dev/null 2>&1' \
      2>/dev/null; then
    echo " ok ($((i * 2))s)" >&2
    exit 0
  fi
  echo -n "." >&2
  sleep 2
done
echo " timeout (ssh works but no display server)" >&2
exit 2
