#!/usr/bin/env nix-shell
#! nix-shell -i bash -p slurp swayfx jq

set -euo pipefail

title="float-$$"
read -r X Y W H <<< "$(slurp -f '%x %y %w %h')"

swaymsg "for_window [app_id=\"kitty\" title=\"^${title}$\"] opacity 0"
swaymsg "for_window [app_id=\"kitty\" title=\"^${title}$\"] floating enable"

swaymsg -t subscribe '["window"]' -m \
  | jq --unbuffered -rc 'select(.change == "focus") | .container.name' \
  | while IFS= read -r name; do
      if [[ "$name" == "$title" ]]; then
        swaymsg "[app_id=\"kitty\" title=\"^${title}$\"] resize set ${W} ${H}"
        swaymsg "[app_id=\"kitty\" title=\"^${title}$\"] move absolute position ${X} ${Y}"
        swaymsg "[app_id=\"kitty\" title=\"^${title}$\"] opacity 1"
        break
      fi
    done &

kitty --title "${title}" &
