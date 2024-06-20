#!/usr/bin/env nix-shell
#! nix-shell -i bash -p wmctrl

set -x
set -e

loadLayout(){
  i3-msg "workspace $1; append_layout ~/.config/i3/workspace-$1.json"
}

launchPrograms(){
  case "$1" in
    "1" )
      (firefox &)
    ;;
    "2" )
      (vesktop &)
      (telegram-desktop &)
    ;;
    "3")
      (steam &)
    ;;
    "4" )
      (blueberry &)
      (pwvucontrol &)
      (easyeffects &)
    ;;
  esac
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
  if [[ -n "$1" ]]; then
    case "$1" in
      "0")
        loadLayout 10
        launchPrograms 10
      ;;
      *)
        loadLayout "$1"
        launchPrograms "$1"
      ;;
    esac
  else
    # Load workspace 1
    loadLayout 1
    launchPrograms 1

    until windowExists Firefox; do
      sleep 1
    done

    # Load workspace 4
    loadLayout 4
    launchPrograms 4

    until windowExists \
      blueberry.py \
      Pavucontrol \
      easyeffects
    do
      sleep 1
    done

    # Load workspace 2
    # Should always be last since Discord's updater is problematic otherwise
    loadLayout 2
    launchPrograms 2
  fi
}

main "$@"
