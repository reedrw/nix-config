#!/usr/bin/env nix-shell
#! nix-shell -i bash -p swayfx jq killall

# I don't like it when programs try to "minimize" to the system tray
# while I don't have a system tray. I would rather have them just
# close when I close them. This script provides handling for programs
# that try to minimize to the system tray and don't have an option to
# disable that behavior.

main() {
  local focused
  focused="$(swaymsg -t get_tree | jq -r '.. | objects | select(.focused? == true) | .app_id // .window_properties.class // empty')"

  case "$focused" in
    steam)
      closeSteam
    ;;
    *)
      closeAny
    ;;
  esac
}

closeAny() {
  swaymsg kill
}

closeSteam() {
  # If we only have 1 steam window open, kill the process,
  # otherwise just close the window normally
  local numOpenWindows
  numOpenWindows="$(swaymsg -t get_tree | jq '[.. | objects | select(.app_id? == "steam" or .window_properties?.class? == "steam")] | length')"

  if [ "$numOpenWindows" -eq 1 ]; then
    killall steam
  else
    closeAny
  fi
}

main "$@" || closeAny
