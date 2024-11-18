#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xdotool xorg.xwininfo killall

# I don't like it when programs try to "minimize" to the system tray
# while I don't have a system tray. I would rather have them just
# close when I close them. This script provides handling for programs
# that try to minimize to the system tray and don't have an option to
# disable that behavior.

main() {
  local activewindowclass
  activewindowclass="$(xdotool getactivewindow getwindowclassname)"

  case "$activewindowclass" in
    "steam")
      closeSteam
    ;;
    *)
      i3-msg kill
    ;;
  esac
}

closeSteam() {
  # If we only have 1 steam window open, kill the process,
  # otherwise just close the window normally using i3-msg
  local numOpenWindows
  numOpenWindows="$(xwininfo -tree -root \
    | grep 'steam' \
    | grep -c --regexp '^        '
  )"

  if [ "$numOpenWindows" -eq 1 ]; then
    killall steam
  else
    i3-msg kill
  fi
}

main "$@"
