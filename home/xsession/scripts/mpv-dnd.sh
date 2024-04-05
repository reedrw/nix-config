#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xdotool procps

# Suspends programs while mpv player is active because I dont like notifications while I'm watching stuff
set -x

export DISPLAY=:0

# programs to suspend
programs=( "$@" )

# active window classes to trigger suspension
highPrio=( "mpv" "Zathura" )

# check if the active window is one of the high priority window classes
isHighPrio(){
  activeWindow="$(xdotool getactivewindow getwindowclassname)"
  for i in "${highPrio[@]}"; do
    if [[ "$activeWindow" == "$i" ]]; then
      return 0
    fi
  done
  return 1
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

for i in "${programs[@]}"; do
  if [[ "$i" == *"--resume"* ]]; then
    contPrograms
    exit 0
  fi
done

while true; do
  if isHighPrio; then
    stopPrograms
    while isHighPrio; do
      sleep 10
    done
    contPrograms
  else
    sleep 180
  fi
done
