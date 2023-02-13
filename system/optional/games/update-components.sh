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

getLatestWineGERelease(){
  curl -s "$apiURL/repos/GloriousEggroll/wine-ge-custom/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

wineGEVersion="$(getLatestWineGERelease)"
v="$wineGEVersion"
wineGEURL="https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton$v/wine-lutris-GE-Proton$v-x86_64.tar.xz"

getLatestLutrisRelease(){
  curl -s "$apiURL/repos/lutris/wine/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

lutrisVersion="$(getLatestLutrisRelease)"
v="$lutrisVersion"
lutrisURL="https://github.com/lutris/wine/releases/download/lutris-wine-$v/wine-lutris-$v-x86_64.tar.xz"

getLatestSodaRelease(){
  releases="$(curl -s "$apiURL/repos/bottlesdevs/wine/releases")"
  index="$(echo "$releases" | gron | grep 'Soda' | head -1 | awk -F'[^0-9]+' '{ print $2 }')"

  echo "$releases" | jq -r ".[$index].tag_name" | grep -oP '\d.*'
}

sodaVersion="$(getLatestSodaRelease)"
v="$sodaVersion"
sodaURL="https://github.com/bottlesdevs/wine/releases/download/soda-$v/soda-$v-x86_64.tar.xz"

iconURL="$(jq -r '.icon.url' ./components.json)"
iconSha265="$(jq -r '.icon.sha256' ./components.json)"

gron -u > components.json << EOF
json.icon = {};
json.icon.url = "$iconURL";
json.icon.sha256 = "$iconSha265";
json.dxvk = {};
json.dxvk.version = "$dxvkVersion";
json.dxvk.url = "$dxvkURL";
json.GEProton = {};
json.GEProton.version = "$protonGEVersion";
json.GEProton.url = "$protonGEURL";
json.wineGE = {};
json.wineGE.version = "$wineGEVersion";
json.wineGE.url = "$wineGEURL";
json.lutris = {};
json.lutris.version = "$lutrisVersion";
json.lutris.url = "$lutrisURL";
json.soda = {};
json.soda.version = "$sodaVersion";
json.soda.url = "$sodaURL";
EOF
