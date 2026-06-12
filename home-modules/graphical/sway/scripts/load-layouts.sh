#!/usr/bin/env nix-shell
#! nix-shell -i bash -p sway kitty bluetuith

set -euo pipefail

# Focus a tiled (non-floating) window with the given app_id, retrying
# until one exists. Returns with the window already focused.
# This skips transient floating splash windows (e.g. Discord's updater).
focus_tiled() {
  until swaymsg "[app_id=$1 tiling] focus" > /dev/null 2>&1; do
    sleep 0.3
  done
}

layout_chat(){
  # Open discord inside a dedicated tabbed container
  discord &
  focus_tiled discord
  swaymsg "layout splith"
  swaymsg "split v"
  swaymsg "layout tabbed"

  # Signal joins as a second tab
  signal-desktop &
  focus_tiled signal

  # Escape the tabbed container back to workspace level so telegram
  # opens as a sibling to the tabbed group rather than another tab.
  swaymsg "focus parent"
  swaymsg "focus parent"
  # Re-assert splith in case the escape landed on a splitv container.
  swaymsg "layout splith"

  Telegram &
  focus_tiled org.telegram.desktop
  swaymsg "resize set width 20 ppt"
}

layout_audio(){
  (kitty --app-id=bluetuith -e bluetuith)&
  focus_tiled bluetuith
  swaymsg "layout splitv"

  pwvucontrol &
  focus_tiled com.saivert.pwvucontrol

  swaymsg "focus parent"
  swaymsg "focus parent"
  swaymsg "split h"
  easyeffects &
  focus_tiled com.github.wwmm.easyeffects
}

launchPrograms(){
  case "$1" in
    "1")
      swaymsg "workspace 1"
      firefox &
      ;;
    "2")
      swaymsg "workspace 2"
      layout_chat
      ;;
    "4")
      swaymsg "workspace 4"
      layout_audio
      ;;
  esac
}

main(){
  if [[ -z "${1:-}" ]]; then
    echo "Usage: load-layouts <workspace>" >&2
    exit 1
  fi

  case "$1" in
    "0") swaymsg "workspace 10" && launchPrograms 10 ;;
    *)   swaymsg "workspace $1" && launchPrograms "$1" ;;
  esac
}

main "$@"
