#! /usr/bin/env bash

# Suspends programs while mpv player is active because I dont like notifications while I'm watching stuff
set -x

export DISPLAY=:0

programs=( "$@" )

getActiveWindow(){
  xdotool getactivewindow getwindowclassname
}

stopPrograms(){
  for i in "${programs[@]}"; do
    if pgrep "$i"; then
      pkill -STOP "$i"
    fi
  done
}

contPrograms(){
  for i in "${programs[@]}"; do
    if pgrep "$i"; then
      pkill -CONT "$i"
    fi
  done
}

while true; do
  if [[ "$(getActiveWindow)" == "mpv" ]]; then
    stopPrograms
    while [[ "$(getActiveWindow)" == "mpv" ]]; do
      sleep 5
    done
    contPrograms
  else
    sleep 180
  fi
done