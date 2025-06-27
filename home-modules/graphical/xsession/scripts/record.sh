#!/usr/bin/env nix-shell
#! nix-shell -i bash -p slop ffmpeg-full libnotify

startrec(){
  # shellcheck disable=SC2046
  set $(slop -q -o -f '%x %y %w %h')
  ffmpeg -loglevel error \
    -show_region 1 \
    -s "${3}x${4}" \
    -framerate 60 \
    -f x11grab \
    -i "$DISPLAY".0+"${1},${2}" \
    -crf 16 \
    -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
    ~/"record-$(date '+%a %b %d - %l:%M %p')".mp4
}

if pid="$(pgrep -f x11grab)"; then
  kill -SIGINT "$pid"
  sleep .3
  notify-send "recording stopped"
else
  startrec
fi
