#!/usr/bin/env nix
#! nix-shell -i bash -p libnotify

icon() {
  if systemctl is-active --user --quiet librepods.service 2>/dev/null; then echo " 󱡏  "; fi
}

notify() {
  local body
  body="$(echo; cat /tmp/airpods_battery_status)"

  notify-send "AirPods Status" "$body"
}

"${1:-notify}"
