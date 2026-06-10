#!/usr/bin/env nix-shell
#! nix-shell -i bash -p slurp sway

set -euo pipefail

# Use a unique title so the for_window rule targets only this instance
title="float-$$"

# Read region from user selection
read -r X Y W H <<< "$(slurp -f '%x %y %w %h')"

# Register a one-shot rule before launching kitty
swaymsg "for_window [app_id=\"kitty\" title=\"^${title}$\"] \
  floating enable, \
  move position ${X} ${Y}, \
  resize set ${W} ${H}"

kitty --title "${title}" &
