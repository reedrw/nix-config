#!/usr/bin/env nix-shell
#! nix-shell -i bash -p xdotool

# I wrote this because Elden Ring doesn't have a pause button,
# but it might be useful for other stuff.
#
# To use, bind this script to a key combination in your window manager.
# For example, in i3, add this to your config:
# bindsym $mod+Escape exec --no-startup-id pause-suspend.sh
#
# Then, when you press the key combination, the currently focused window
# will be suspended. Press it again to resume it.

pid="$(xdotool getactivewindow getwindowpid)"

if grep -qE 'State:.*stopped)' "/proc/$pid/status"; then
  kill -CONT "$pid"
else
  kill -STOP "$pid"
fi
