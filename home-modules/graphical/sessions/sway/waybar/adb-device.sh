#!/usr/bin/env nix-shell
#! nix-shell -i bash -p android-tools libnotify gawk

icon() {
  if adb get-state 2>/dev/null | grep -qx "device"; then echo " "; fi
}

notify() {
  raw=$(adb shell '
    getprop ro.product.model; echo "---"
    getprop ro.build.version.release; echo "---"
    dumpsys battery; echo "---"
    df /sdcard | tail -1; echo "---"
    ip addr show wlan0
  ' 2>/dev/null) || exit 0

  section() { awk 'BEGIN{RS="---\r?\n"} NR=='"$1" <<< "$raw"; }

  model=$(section 1 | tr -d '\r\n')
  android_ver=$(section 2 | tr -d '\r\n')
  battery=$(section 3)

  level=$(awk  '$1 == "level:"       { print $2 }'                  <<< "$battery")
  temp=$(awk   '$1 == "temperature:" { printf "%.1f°C", $2 / 10 }' <<< "$battery")
  status=$(awk '$1 == "status:"      { print $2 }'                  <<< "$battery")
  ac=$(awk        '$1 == "AC"        { print $3 }'                  <<< "$battery")
  usb=$(awk       '$1 == "USB"       { print $3 }'                  <<< "$battery")
  wireless=$(awk  '$1 == "Wireless"  { print $3 }'                  <<< "$battery")

  case "$status" in
    2) bat_icon="󰂄" ;;
    5) bat_icon="󰂅" ;;
    *) bat_icon="󰁹" ;;
  esac

  charge_source=""
  if   [[ "$ac"       == "true" ]]; then charge_source=" (AC)"
  elif [[ "$usb"      == "true" ]]; then charge_source=" (USB)"
  elif [[ "$wireless" == "true" ]]; then charge_source=" (Wireless)"
  fi

  storage=$(section 4 | awk 'NF >= 4 { printf "%.0f / %.0f GB", $3/1024/1024, $2/1024/1024 }')

  ip=$(section 5 | awk '!found && /inet / { split($2, a, "/"); print a[1]; found=1 }')

  network="${ip:-Not connected}"

  title="$model · Android $android_ver"
  bat_line="$bat_icon $level%$charge_source · $temp"
  stor_line="󰋊 $storage"
  net_line="󰤨 $network"

  max=${#title}
  for line in "$bat_line" "$stor_line" "$net_line"; do
    (( ${#line} > max )) && max=${#line}
  done
  pad=$(printf '%*s' $(( (max - ${#title}) / 2 )) '')

  body=$(gawk \
    -v bat="$bat_line" -v stor="$stor_line" -v net="$net_line" -v max="$max" '
    function center_after_icon(line,    sp, icon, text, text_len, icon_len, offset, units) {
      sp = index(line, " ")
      if (sp == 0) return line
      icon = substr(line, 1, sp)
      text = substr(line, sp + 1)
      text_len = length(text)
      icon_len = length(icon)
      offset = int((max - text_len) / 2) - icon_len
      if (offset <= 0) return icon text
      units = int(offset * CHAR_PT * 1024)
      return icon "<span letter_spacing=\"" units "\"> </span>" text
    }
    BEGIN {
      CHAR_PT = 7
      print ""
      print center_after_icon(bat)
      print center_after_icon(stor)
      print center_after_icon(net)
    }')

  notify-send "${pad}${title}" "$body"
}

"${1:-notify}"
