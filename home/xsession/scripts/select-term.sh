#!/usr/bin/env nix-shell
#! nix-shell -i bash -p slop

export WINIT_X11_SCALE_FACTOR=1.0

read -r X Y W H <<< "$(slop -f "%x %y %w %h" -b 1 -t 0 -q)"
echo "$X $Y $W $H"
# Width and Height in px need to be converted to columns/rows
# To get these magic values, make a fullscreen st, and divide your screen width by ${tput cols}, height by ${tput lines}
(( W /= 5 ))
(( H /= 11 ))

# correct for border padding
(( W -= 5 ))
(( H -= 3 ))

alacritty -t float -o \
  window.dimensions.columns="$W" \
  window.dimensions.lines="$H" \
  window.position.x="$X" \
  window.position.y="$Y" &
disown
