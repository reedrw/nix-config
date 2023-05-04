#! /usr/bin/env bash

set -x

cacheDir="$HOME/.cache"
cachefile="$cacheDir/outputdev"
idCacheFile="$cacheDir/outputid"
descCacheFile="$cacheDir/outputdesc"

notifyCommand="dunstify -h string:x-dunst-stack-tag:volume"

getInfo(){
  mkdir -p "$cacheDir"
  echo "$outputdev" > "$cachefile"
  outputdesc="$(pactl list sinks | grep -e 'node.name' -e 'device.description' | grep -vi 'effects' | cut -f2 -d\" | grep -B 1 "$outputdev" | grep -v "$outputdev")"
  echo "$outputdesc" > "$descCacheFile"
  outputid="$(wpctl status | grep "Sinks" -A 20 | grep "$outputdesc" | grep -o -E '[0-9]+' | head -1)"
  echo "$outputid" > "$idCacheFile"
}

runCommand(){
  local runCommand="$1"
  local retry=0

  # device IDs sometimes change for seemingly no reason, so retry once if it fails.
  $runCommand || retry=1
  if [[ "$retry" == 1 ]]; then
    getInfo && $runCommand
  fi
}

outputdev="$(gsettings \
  --schemadir ~/.nix-profile/share/gsettings-schemas/easyeffects-*/glib-*/schemas \
  get com.github.wwmm.easyeffects.streamoutputs output-device | cut -f2 -d\')"

main(){
  if   [[ -f "$cachefile" && -f "$idCacheFile" && -f "$descCacheFile" ]] \
    && [[ "$(< "$cachefile")" == "$outputdev" ]]; then
    outputid="$(< "$idCacheFile")"
    outputdesc="$(< "$descCacheFile")"
  else
    getInfo
  fi

  if [[ "$1" == "mute" ]]; then
    command="wpctl set-mute $outputid toggle"
    runCommand "$command"
    return 0
  fi

  if [[ "$1" == "up" ]]; then
    pm="+"
  else
    pm="-"
  fi

  command="wpctl set-volume $outputid $2%$pm"
  runCommand "$command"
}

main "$@"
# Print with fixed with. hair space (U+200A) at the end
# so dunst doesn't cull the whitespace
status="$(wpctl get-volume "$outputid")"
status="$(printf '%-20s ' "$status")"
$notifyCommand "$outputdesc" "$status"