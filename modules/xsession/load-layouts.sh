#!/usr/bin/env bash

set -x
set -e

loadLayout(){
  i3-msg "workspace $1; append_layout ~/.config/i3/workspace-$1.json"
}

windowExists(){
  if (( "$#" == 1 )); then
    wmctrl -lx | grep -q "$1"
  else
    for window in "$@"; do
      windowExists "$window"
    done
  fi
}

main(){
  # Load workspace 1
  loadLayout 1

  (firefox &)
  until windowExists Firefox; do
    sleep 1
  done

  # Load workspace 4
  loadLayout 4

  (blueman-manager &)
  (pavucontrol &)
  (easyeffects &)

  until windowExists \
    .blueman-manager-wrapped \
    Pavucontrol \
    easyeffects
  do
    sleep 1
  done

  # Load workspace 2
  # Should always be last since Discord's updater is problematic otherwise
  loadLayout 2

  (Discord &)
  (telegram-desktop &)
}

main "$@"
