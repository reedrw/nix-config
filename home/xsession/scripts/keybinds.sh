#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xorg.xmodmap

set -x

while true; do
  xmodmap -e 'keycode 117 = XF86Forward'
  xmodmap -e 'keycode 112 = XF86Back'
  xmodmap -e 'keycode 9 = Escape asciitilde Escape'
  sleep 20
done
