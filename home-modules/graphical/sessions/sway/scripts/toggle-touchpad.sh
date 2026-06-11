#!/usr/bin/env nix-shell
#! nix-shell -i bash -p sway jq libnotify

set -euo pipefail

touchpad_id="$(swaymsg -t get_inputs | jq -r '[.[] | select(.type == "touchpad")] | first | .identifier // empty')"

if [[ -z "$touchpad_id" ]]; then
  echo "No touchpad found" >&2
  exit 1
fi

enabled="$(swaymsg -t get_inputs | jq -r --arg id "$touchpad_id" \
  '.[] | select(.identifier == $id) | .libinput.send_events')"

on(){
  swaymsg "input \"$touchpad_id\" events enabled"
  [[ "$#" -lt 1 ]] && notify-send "Touchpad enabled"
}

off(){
  swaymsg "input \"$touchpad_id\" events disabled"
  [[ "$#" -lt 1 ]] && notify-send "Touchpad disabled"
}

toggle(){
  if [[ "$enabled" == "disabled" ]]; then
    on "$@"
  else
    off "$@"
  fi
}

case "${1:-}" in
  enable)  shift; on  "$@" ;;
  disable) shift; off "$@" ;;
  *)             toggle "$@" ;;
esac
