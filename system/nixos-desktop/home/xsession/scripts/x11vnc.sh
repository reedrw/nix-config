#! /usr/bin/env nix-shell
#! nix-shell -i bash -p x11vnc

set -x

x11vnc \
  -ncache 10 \
  -forever \
  -display :0 \
  -auth /var/run/lightdm/reed/xauthority \
  -rfbport 5900 \
  -viewonly
