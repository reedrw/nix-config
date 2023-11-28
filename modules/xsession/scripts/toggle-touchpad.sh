#! /usr/bin/env nix-shell
#! nix-shell -i bash -p libnotify

# Toggle touchpad on/off

set -x

# Get touchpad id
id="$(xinput | grep -o 'Synaptics.*id=[0-9]*' | cut -d '=' -f 2)"

if [ -z "$id" ]; then
  id="$(xinput | grep -o 'Touchpad.*id=[0-9]*' | cut -d '=' -f 2)"
fi

if [ -z "$id" ]; then
  echo "No touchpad found"
  exit 1
fi

on(){
  xinput --enable "$id"
  if [ "$#" -lt 1 ]; then
    notify-send "Touchpad input enabled"
  fi
}

off(){
  xinput --disable "$id"
  if [ "$#" -lt 1 ]; then
    notify-send "Touchpad disabled"
  fi
}

toggle(){
  # Get touchpad state
  state="$(xinput list-props "$id" | grep 'Device Enabled' | grep -o '[01]$')"

  if [ "$state" -eq '0' ]; then
    on
  else
    off
  fi
}

if [[ "$#" == '0' ]]; then
  toggle
  exit 0
fi

case "$1" in
  enable)
    shift;
    on "$@"
    ;;
  disable)
    shift;
    off "$@"
    ;;
  *)
    toggle
    ;;
esac
