#! /usr/bin/env nix-shell
#! nix-shell -i bash -p xorg.xmodmap

set -x

while true; do
  # set page up and page down to forward and back
  xmodmap -e 'keycode 117 = XF86Forward'
  xmodmap -e 'keycode 112 = XF86Back'
  # set shift+esc to tilde
  xmodmap -e 'keycode 9 = Escape asciitilde Escape'
  # unset caps lock
  xmodmap -e 'keycode 66 = Control_L'
  sleep 20
done
