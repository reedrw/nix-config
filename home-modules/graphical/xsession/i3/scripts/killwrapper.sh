#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xdotool xorg.xwininfo killall

set -x

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
      closeLast steam steam
    ;;
    "TelegramDesktop")
      closeLast TelegramDesktop .telegram-desktop
    ;;
    *)
      closeAny
    ;;
  esac
}

closeAny() {
  i3-msg kill
}

closeLast() {
  # @param $1: The window class to search xwininfo for
  # @param $2: The process name to pkill
  local numOpenWindows
  numOpenWindows="$(xwininfo -tree -root \
    | grep "$1" \
    | grep -c --regexp '^        '
  )"

  if [ "$numOpenWindows" -eq 1 ]; then
    killall "$2"
  else
    i3-msg kill
  fi
}

main "$@" || closeAny
