#!/usr/bin/env nix-shell
#! nix-shell -i bash -p util-linux gnused libnotify

# shellcheck shell=bash
green="${1:-32CD32}"

day="$(date +'%-d ' | sed 's/\b[0-9]\b/ &/g')"
cal="$(cal | sed -e 's/^/ /g' -e 's/$/ /g' -e "s/$day/\<span color=\'#$green\'\>\<b\>$day\<\/b\>\<\/span\>/" -e '1d')"
top="$(cal | sed '1!d')"

id_file="${XDG_CACHE_HOME:-$HOME/.cache}/calnotify-id"
prev_id="$(cat "$id_file" 2>/dev/null || echo "")"

mkdir -p "$(dirname "$id_file")"

if [ -n "$prev_id" ]; then
  new_id="$(notify-send --print-id --replace-id "$prev_id" "$top" "$cal")"
else
  new_id="$(notify-send --print-id "$top" "$cal")"
fi

echo "$new_id" > "$id_file"
