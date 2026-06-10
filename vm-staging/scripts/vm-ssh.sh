#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils sshpass openssh

# vm-ssh — run a command on the staging VM and stream its output.
#
# Usage:
#   ./vm-staging/scripts/vm-ssh.sh <port> [-- command args...]
#
# Examples:
#   vm-ssh.sh 2222 -- systemctl --user status
#   vm-ssh.sh 2222 -- swaymsg -t get_outputs
#   vm-ssh.sh 2222          # interactive shell
#
# Env: VM_USER (default reed), VM_PASSWORD (default vm)

set -euo pipefail

port="${1:?usage: vm-ssh <port> [-- command...]}"; shift || true
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
