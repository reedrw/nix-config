#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils sshpass openssh

# ssh — run a command on the staging VM and stream its output.
#
# Usage:
#   ./ssh.sh <port> [-- command args...]
#
# Examples:
#   ssh.sh 2222 -- systemctl --user status
#   ssh.sh 2222 -- swaymsg -t get_outputs
#   ssh.sh 2222          # interactive shell
#
# Env: VM_USER (default reed), VM_PASSWORD (default vm)

set -euo pipefail

port="${1:?usage: ssh.sh <port> [-- command...]}"; shift || true
if [ "${1:-}" = "--" ]; then shift; fi

: "${VM_USER:=reed}"
: "${VM_PASSWORD:=vm}"

exec sshpass -p "$VM_PASSWORD" ssh \
  -o "UserKnownHostsFile=/dev/null" \
  -o "StrictHostKeyChecking=no" \
  -o "LogLevel=ERROR" \
  -p "$port" \
  "$VM_USER@localhost" \
  "$@"
