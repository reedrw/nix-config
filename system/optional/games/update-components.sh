#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq gron gnugrep curl

set -x

apiURL="https://api.github.com"

if [[ -n "$GITHUB_TOKEN" ]]; then
  curl="curl -s --request GET \
    --header \"Accept: application/vnd.github+json\" \
    --header \"Authorization: Bearer $GITHUB_TOKEN\" --url"
else
  curl="curl -s"
fi

getLatestDXVKRelease(){
  $curl "$apiURL/repos/doitsujin/dxvk/releases/latest" | jq -r '.tag_name'
}

dxvkVersion="$(getLatestDXVKRelease)"
dxvkVersion="${dxvkVersion#v}"
v="$dxvkVersion"
dxvkURL="https://github.com/doitsujin/dxvk/releases/download/v$v/dxvk-$v.tar.gz"

getLatestGEProtonRelease(){
  $curl "$apiURL/repos/GloriousEggroll/proton-ge-custom/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

protonGEVersion="$(getLatestGEProtonRelease)"
v="$protonGEVersion"
protonGEURL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$v/GE-Proton$v.tar.gz"

getLatestWineGERelease(){
  $curl "$apiURL/repos/GloriousEggroll/wine-ge-custom/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

wineGEVersion="$(getLatestWineGERelease)"
v="$wineGEVersion"
wineGEURL="https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton$v/wine-lutris-GE-Proton$v-x86_64.tar.xz"

getLatestLutrisRelease(){
  $curl "$apiURL/repos/lutris/wine/releases/latest" | jq -r '.tag_name' | grep -oP '\d.*'
}

lutrisVersion="$(getLatestLutrisRelease)"
v="$lutrisVersion"
lutrisURL="https://github.com/lutris/wine/releases/download/lutris-wine-$v/wine-lutris-$v-x86_64.tar.xz"

getLatestSodaRelease(){
  releases="$($curl "$apiURL/repos/bottlesdevs/wine/releases")"
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
json.customDxvk = {};
json.customDxvk.version = "$dxvkVersion";
json.customDxvk.url = "$dxvkURL";
json.customGEProton = {};
json.customGEProton.version = "$protonGEVersion";
json.customGEProton.url = "$protonGEURL";
json.customWineGEProton = {};
json.customWineGEProton.version = "$wineGEVersion";
json.customWineGEProton.url = "$wineGEURL";
json.customLutris = {};
json.customLutris.version = "$lutrisVersion";
json.customLutris.url = "$lutrisURL";
json.customSoda = {};
json.customSoda.version = "$sodaVersion";
json.customSoda.url = "$sodaURL";
EOF
