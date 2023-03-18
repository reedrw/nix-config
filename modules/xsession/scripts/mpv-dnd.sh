#! /usr/bin/env bash

# Suspends programs while mpv player is active because I dont like notifications while I'm watching stuff
set -x

programs=( "$@" )

getActiveWindow(){
  xdotool getactivewindow getwindowclassname
}

stopPrograms(){
  for i in "${programs[@]}"; do
    pkill -STOP "$i"
  done
}

contPrograms(){
  for i in "${programs[@]}"; do
    pkill -CONT "$i"
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
    sleep 300
  fi
done
