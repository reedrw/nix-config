#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils socat

# sendkey — inject keypresses into the staging VM via the QEMU monitor.
#
# Usage:
#   ./sendkey.sh <key> [<key>...]
#
# Each argument is a QEMU sendkey identifier (see `info mice`/QEMU docs):
#   single keys     : a, b, ..., f1, ..., ret, esc, spc, up, down, ...
#   media keys      : volumeup, volumedown, audiomute, audionext, audioprev,
#                     audioplay, audiostop
#   chords          : ctrl-alt-t, alt-f4   (dash-separated, sent as one stroke)
#
# Sway sees these as real key events from libinput, so XF86Audio* keybinds
# fire exactly as if a hardware key was pressed.
#
# Requires `run.sh` to be running so the monitor socket exists.

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: sendkey.sh <key> [<key>...]" >&2
  exit 1
fi

run_dir="${XDG_RUNTIME_DIR:-/tmp/stage-$UID}/stage"
socket="$run_dir/nixos-vm.monitor.sock"

if [ ! -S "$socket" ]; then
  echo "sendkey: no monitor socket at $socket — is the VM running?" >&2
  exit 1
fi

# HMP accepts one sendkey per line; pipe them all in one connection.
{
  for key in "$@"; do
    printf 'sendkey %s\n' "$key"
  done
} | socat - "UNIX-CONNECT:$socket" >/dev/null

echo "sendkey: sent $* to $socket" >&2
