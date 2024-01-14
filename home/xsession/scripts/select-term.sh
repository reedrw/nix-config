#!/usr/bin/env nix-shell
#! nix-shell -i bash -p slop

set -x
export WINIT_X11_SCALE_FACTOR=1.0

# Select an area to put the terminal in
read -r X Y W H <<< "$(slop -f "%x %y %w %h" -b 1 -t 0 -q)"
echo "$X $Y $W $H"

# Create a layout file for i3.
terminalClass="kitty"
layoutTemplate='
{
  "border": "pixel",
  "floating": "auto_off",
  "layout": "splith",
  "marks": [],
  "percent": null,
  "rect": {
    "height": HEIGHT,
    "width": WIDTH,
    "x": XPOS,
    "y": YPOS
  },
  "type": "floating_con",
  "nodes": [
    {
      "border": "pixel",
      "current_border_width": 0,
      "floating": "user_on",
      "geometry": {
        "height": HEIGHT,
        "width": WIDTH,
        "x": 0,
        "y": 0
      },
      "marks": [],
      "name": "terminalClass",
      "percent": 1,
      "swallows": [
        {
          "class": "^terminalClass$"
        }
      ],
      "type": "con"
    }
  ]
}'

layout=$(echo "$layoutTemplate" | sed \
  -e "s/terminalClass/$terminalClass/" \
  -e "s/HEIGHT/$H/" \
  -e "s/WIDTH/$W/" \
  -e "s/XPOS/$X/" \
  -e "s/YPOS/$Y/")

layoutFile=$(mktemp --suffix=.json)
echo "$layout" > "$layoutFile"

i3-msg "append_layout $layoutFile"
rm "$layoutFile"
kitty -T float
