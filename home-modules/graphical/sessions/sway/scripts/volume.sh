#! /usr/bin/env nix-shell
#! nix-shell -i bash -p glib pulseaudio

# This script is used to control the volume of the output currently selected in easyeffects.
# It uses the wpctl command from wireplumber to control the volume and
# uses gsettings to get the output device from easyeffects.
#
# Usage:
#  volume.sh up <amount>   - Increase volume by <amount> (default 5)
#  volume.sh down <amount> - Decrease volume by <amount> (default 5)
#  volume.sh mute          - Toggle mute

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

# Get the output device from easyeffects
outputdev="$(gsettings \
  --schemadir "$XDG_STATE_HOME"/nix/profile/share/gsettings-schemas/easyeffects-*/glib-*/schemas \
  get com.github.wwmm.easyeffects.streamoutputs output-device | cut -f2 -d\')"

main(){
  # If cache files exist and the output device hasn't changed, use the cached values
  # Otherwise, get the info and cache it
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
