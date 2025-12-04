#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bluetuith

set -x
set -e

loadLayout(){
  i3-msg "workspace $1; append_layout ~/.config/i3/workspace-$1.json"
}

launchPrograms(){
  case "$1" in
    # Browser
    "1" )
      (firefox &)
    ;;
    # Chat
    "2" )
      (mullvad-exclude discord &)
      (signal-desktop &)
      (Telegram &)
    ;;
    # Audio
    "4" )
      ("$TERMINAL" -e bluetuith &)
      (pwvucontrol &)
      (easyeffects &)
    ;;
  esac
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
    echo "Usage: load-layouts.sh <workspace>"
    exit 1
  fi
}

main "$@"
