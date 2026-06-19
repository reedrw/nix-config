#!/usr/bin/env nix-shell
#! nix-shell -i bash -p gnused

journalctl --user --follow -u librepods -o cat --no-pager \
  | sed -u 's/\x1b\[[0-9;]*m//g' \
  | while IFS= read -r line; do
  [[ "$line" == *"Battery status"* ]] && echo "$line" \
    | sed 's/.*"\(.*\)".*/\1/' \
    | sed "s/, /\n/g" > /tmp/airpods_battery_status
  done
