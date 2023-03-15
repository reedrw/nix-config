#! /usr/bin/env bash

cacheDir="$HOME/.cache"
cachefile="$cacheDir/outputdev"
idCacheFile="$cacheDir/outputid"

outputdev="$(gsettings \
  --schemadir ~/.nix-profile/share/gsettings-schemas/easyeffects-7.0.0/glib-2.0/schemas \
  get com.github.wwmm.easyeffects.streamoutputs output-device | cut -f2 -d\')"

if [[ -f "$cachefile" && -f "$idCacheFile" ]] && [[ "$(< "$cachefile")" == "$outputdev" ]]; then
  outputid="$(< "$idCacheFile")"
else
  mkdir -p "$cacheDir"
  echo "$outputdev" > "$cachefile"
  outputdesc="$(pactl list sinks | grep -e 'node.name' -e 'device.description' | grep -vi 'effects' | cut -f2 -d\" | grep -B 1 "$outputdev" | grep -v "$outputdev")"
  outputid="$(wpctl status | grep "Sinks" -A 20 | grep "$outputdesc" | grep -o -E '[0-9]+' | head -1)"
  echo "$outputid" > "$idCacheFile"
fi

if [[ "$1" == "mute" ]]; then
  wpctl set-mute "$outputid" toggle
  exit "$?"
fi

if [[ "$1" == "up" ]]; then
  pm="+"
else
  pm="-"
fi

wpctl set-volume "$outputid" "$2"%"$pm"
