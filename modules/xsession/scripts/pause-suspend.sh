#!/usr/bin/env bash

# I wrote this because Elden Ring doesn't have a pause button,
# but it might be useful for other stuff

pid="$(xdotool getactivewindow getwindowpid)"

if grep -qE 'State:.*stopped)' "/proc/$pid/status"; then
  kill -CONT "$pid"
else
  kill -STOP "$pid"
fi
