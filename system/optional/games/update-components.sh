#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq gron gnugrep curl

set -x

apiURL="https://api.github.com"

getLatestDXVKRelease(){
  curl -s "$apiURL/repos/doitsujin/dxvk/releases/latest" | jq -r '.tag_name'
}

dxvkVersion="$(getLatestDXVKRelease)"
dxvkVersion="${dxvkVersion#v}"
v="$dxvkVersion"
dxvkURL="https://github.com/doitsujin/dxvk/releases/download/v$v/dxvk-$v.tar.gz"

getLatestGEProtonRelease(){
  curl -s "$apiURL/repos/GloriousEggroll/proton-ge-custom/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

protonGEVersion="$(getLatestGEProtonRelease)"
v="$protonGEVersion"
protonGEURL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$v/GE-Proton$v.tar.gz"

gron -u > components.json << EOF
json.dxvk = {};
json.dxvk.version = "$dxvkVersion";
json.dxvk.url = "$dxvkURL";
json.GEProton = {};
json.GEProton.version = "$protonGEVersion";
json.GEProton.url = "$protonGEURL";
EOF
