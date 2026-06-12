#! /usr/bin/env nix-shell
#! nix-shell -i bash -p brightnessctl bc

# This script is used to increase or decrease the brightness of the screen
# based on the current brightness. This is useful for adjusting brightness to
# very low levels when working in the dark.

set -x

current="$(brightnessctl g)"
percentage="$2"

notifyCommand="dunstify -h string:x-dunst-stack-tag:brightness"

sendNotification(){
  local p;
  p="$(brightnessctl i | cut -d '(' -f2 | cut -d ')' -f1 | sed -n 2p)"
  text="$(printf "Current brightness: %s\n" "$p")"
  $notifyCommand "$text"
}

downStep(){
  local x;
  local p;
  local out;
  x="$current"
  p="$percentage"
  out="$(bc <<< "scale=10;f=($x-($x*($p/100)));scale=0;f/1")"
  echo "$out"
}

upStep(){
  local x;
  local p;
  local out;
  x="$current"
  p="$percentage"
  out="$(bc <<< "scale=10;f=($x/(1-($p/100)));scale=0;f/1")"
  if [[ "$out" == "$current" ]]; then
    out=$((current+$((percentage/10))))
  fi
  echo "$out"
}

if [[ $1 == "up" ]]; then
    brightnessctl s "$(upStep)"
elif [[ $1 == "down" ]]; then
    brightnessctl s "$(downStep)"
fi
sendNotification
