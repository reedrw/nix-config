#!/usr/bin/env nix-shell
#! nix-shell -i bash -p wf-recorder slurp libnotify

set -euo pipefail

startrec(){
  region="$(slurp)"
  wf-recorder \
    --audio \
    -g "$region" \
    -f ~/"record-$(date '+%a %b %d - %l:%M %p').mp4"
}

if pid="$(pgrep -x wf-recorder)"; then
  kill -SIGINT "$pid"
  sleep .3
  notify-send "recording stopped"
else
  startrec
fi
