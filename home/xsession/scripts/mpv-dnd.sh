#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xdotool procps

# Suspends programs while mpv player is active because I dont like notifications while I'm watching stuff
set -x

export DISPLAY=:0

programs=( "$@" )

getActiveWindow(){
  xdotool getactivewindow getwindowclassname
}

# given a window class name, find the pids of all windows with that class name
findWindowPids(){
  ids="$(xdotool search --class "$1")"

  for i in $ids; do
    xprop -id "$i" | awk '/_NET_WM_PID/ {print $3}'
  done
}

stopPrograms(){
  for i in "${programs[@]}"; do
    # shellcheck disable=SC2207
    pids=( $(findWindowPids "$i") )
    for pid in "${pids[@]}"; do
      kill -STOP "$pid"
    done
  done
}

contPrograms(){
  for i in "${programs[@]}"; do
    # shellcheck disable=SC2207
    pids=( $(findWindowPids "$i") )
    for pid in "${pids[@]}"; do
      kill -CONT "$pid"
    done
  done
}

if [[ "$1" == "--resume" ]]; then
  shift
  programs=( "$@" )
  contPrograms
  exit 0
fi

while true; do
  if [[ "$(getActiveWindow)" == "mpv" ]]; then
    stopPrograms
    while [[ "$(getActiveWindow)" == "mpv" ]]; do
      sleep 10
    done
    contPrograms
  else
    sleep 180
  fi
done
