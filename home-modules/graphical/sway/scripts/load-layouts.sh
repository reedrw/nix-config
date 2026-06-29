#!/usr/bin/env nix-shell
#! nix-shell -i bash -p swayfx kitty bluetuith

set -euo pipefail

# Launch an app on the currently-focused workspace.
#
# Sway pins any window mapped by a descendant of a keybind `exec` to the
# workspace that keybind was pressed from. It uses two independent
# mechanisms: an env-borne activation token (XDG_ACTIVATION_TOKEN for
# Wayland clients, DESKTOP_STARTUP_ID for X11/GTK), and a parent-PID walk
# at window-map time. The script does `swaymsg workspace N` before
# launching the apps, but both mechanisms override that — symptom: the
# "ws4 flashes then bounces back" bug, where the bluetuith window pulls
# focus + every subsequent layout_audio window onto the originating
# workspace. Killing either one alone isn't enough (firefox still respects
# the activation token via setsid; bluetuith still respects the PID chain
# via env unset), so do both.
spawn() {
  env -u XDG_ACTIVATION_TOKEN -u DESKTOP_STARTUP_ID \
    setsid -f "$@" </dev/null >/dev/null 2>&1
}

# Focus a tiled (non-floating) window with the given app_id. Skips
# transient floating splash windows (e.g. Discord's updater) and blocks
# on sway window events between attempts, so we wake the instant a
# matching window maps instead of paying up to 0.3s of poll latency.
focus_tiled() {
  while ! swaymsg "[app_id=$1 tiling] focus" > /dev/null 2>&1; do
    read -r _ || sleep 0.3
  done < <(swaymsg -t subscribe -m '["window"]' 2>/dev/null)
}

layout_chat(){
  # Open discord inside a dedicated tabbed container
  spawn discord
  focus_tiled discord
  swaymsg "layout splith"
  swaymsg "split v"
  swaymsg "layout tabbed"

  # Signal joins as a second tab
  spawn signal-desktop
  focus_tiled signal

  # Escape the tabbed container back to workspace level so telegram
  # opens as a sibling to the tabbed group rather than another tab.
  swaymsg "focus parent"
  swaymsg "focus parent"
  # Re-assert splith in case the escape landed on a splitv container.
  swaymsg "layout splith"

  spawn Telegram
  focus_tiled org.telegram.desktop
  swaymsg "resize set width 20 ppt"
}

layout_audio(){
  spawn kitty --app-id=bluetuith -e bluetuith
  focus_tiled bluetuith
  swaymsg "layout splitv"

  spawn pwvucontrol
  focus_tiled com.saivert.pwvucontrol

  swaymsg "focus parent"
  swaymsg "focus parent"
  swaymsg "split h"
  spawn easyeffects
  focus_tiled com.github.wwmm.easyeffects
}

launchPrograms(){
  case "$1" in
    "1")
      swaymsg "workspace 1"
      spawn firefox
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
