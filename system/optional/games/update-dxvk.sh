#!/usr/bin/env bash
#! nix-shell -i bash -p jq gron

[[ "$1" == "-x" ]] && set -x

# DXVK jsons
asyncJson="./dxvk/async.json"
vanillaJson="./dxvk/vanilla.json"
# GEProtonJson="./ge-proton.json"
# wineGEProtonJson="./wine-ge-proton.json"

# TODO unify version getters into 1 function
getNewDxvkAsyncVersions(){
  local dxvkAsyncReleasesJson
  local currentDxvkAsync
  local latestDxvkAsync

  # Get release information from GitHub API
  dxvkAsyncReleasesJson="$(curl -s 'https://api.github.com/repos/sporif/dxvk-async/releases')"

  # get currently tracked and latest dxvk-async release versions
  currentDxvkAsync="$(jq -r '.[0].version' "$asyncJson" | sed 's/-async//g')"
  latestDxvkAsync="$(jq -r '.[0].tag_name' <(echo "$dxvkAsyncReleasesJson"))"

  # if currentDxvkAsync and latestDxvkAsync are the same, already up to date
  [[ "$currentDxvkAsync" == "$latestDxvkAsync" ]] && return 0

  # Echo each version until we hit currently tracked version
  for version in $(jq -r '.[].tag_name' <(echo "$dxvkAsyncReleasesJson")); do
    if [[ "$currentDxvkAsync" == "$version" ]]; then
      break
    else
      echo "$version"
    fi
  done | tac
}

updateDxvkAsync(){
  local newDxvkAsyncVersions

  newDxvkAsyncVersions="$(getNewDxvkAsyncVersions)"
  [[ -z "$newDxvkAsyncVersions" ]] && return 0

  # build json object for each new version
  for version in $newDxvkAsyncVersions; do
    echo "$version"
    {
      echo "json.name = \"dxvk-async-$version\";"
      echo "json.recommended = true;"
      echo "json.uri = \"https://github.com/Sporif/dxvk-async/releases/download/$version/dxvk-async-$version.tar.gz\";"
      echo "json.version = \"$version-async\";"
    } | gron -u | tee "$tmpFile";
    jsonObject="$(cat "$tmpFile")"
    jq -r ". |= [$jsonObject] + ." "$asyncJson" > "$tmpFile"
    cat "$tmpFile" > "$asyncJson"
  done
}

getNewDxvkVersions(){
  local dxvkReleasesJson
  local currentDxvk
  local latestDxvk

  # Get release information from GitHub API
  dxvkReleasesJson="$(curl -s 'https://api.github.com/repos/doitsujin/dxvk/releases')"

  # get currently tracked and latest dxvk release versions
  currentDxvk="$(jq -r '.[0].version' "$vanillaJson")"
  latestDxvk="$(jq -r '.[0].tag_name' <(echo "$dxvkReleasesJson") | sed 's/v//g')"

  # if currentDxvk and latestDxvk are the same, already up to date
  [[ "$currentDxvk" == "$latestDxvk" ]] && return 0

  # Echo each version until we hit currently tracked version
  for version in $(jq -r '.[].tag_name' <(echo "$dxvkReleasesJson") | sed 's/v//g'); do
    if [[ "$currentDxvk" == "$version" ]]; then
      break
    else
      echo "$version"
    fi
  done | tac
}

updateDxvk(){
  local newDxvkVersions

  newDxvkVersions="$(getNewDxvkVersions)"
  [[ -z "$newDxvkVersions" ]] && return 0

  # build json object for each new version
  for version in $newDxvkVersions; do
    echo "$version"
    {
      echo "json.name = \"dxvk-$version\";"
      echo "json.recommended = true;"
      echo "json.uri = \"https://github.com/doitsujin/dxvk/releases/download/$version/dxvk-$version.tar.gz\";"
      echo "json.version = \"$version\";"
    } | gron -u | tee "$tmpFile";
    jsonObject="$(cat "$tmpFile")"
    jq -r ". |= [$jsonObject] + ." "$vanillaJson" > "$tmpFile"
    cat "$tmpFile" > "$vanillaJson"
  done
}

# getNewGEProtonVersions(){
#   local GEProtonReleasesJson
#   local currentGEProton
#   local latestGEProton
#
#   # Get release information from GitHub API
#   GEProtonReleasesJson="$(curl -s 'https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases')"
#
#   # get currently tracked and latest release versions
#   currentGEProton="$(jq -r '.[0].name' "$GEProtonJson")"
#   latestGEProton="$(jq -r '.[0].tag_name' <(echo "$GEProtonReleasesJson"))"
#
#   # if current and latest are the same, already up to date
#   [[ "$currentGEProton" == "$latestGEProton" ]] && return 0
#
#   # Echo each version until we hit currently tracked version
#   for version in $(jq -r '.[].tag_name' <(echo "$GEProtonReleasesJson")); do
#     if [[ "$currentGEProton" == "$version" ]]; then
#       break
#     else
#       echo "$version"
#     fi
#   done | tac
# }
#
# updateGEProton(){
#   local newGEProtonVersions
#
#   newGEProtonVersions="$(getNewGEProtonVersions)"
#   [[ -z "$newGEProtonVersions" ]] && return 0
#
#   # build json object for each new version
#   for version in $newGEProtonVersions; do
#     echo "$version"
#     title="$(echo "$version" | sed -r 's/([0-9]+).*/ &/g')"
#     {
#       echo "json.name = \"$version\";"
#       echo "json.title = \"$title\";"
#       echo "json.uri = \"https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$version/$version.tar.gz\";"
#       echo "json.files = {};"
#       echo "json.files.wine = \"bin/wine\";"
#       echo "json.files.wine64 = \"files/bin/wine64\";"
#       echo "json.files.wineserver = \"files/bin/wineserver\";"
#       echo "json.files.wineboot = \"files/bin/wineboot\";"
#       echo "json.files.winecfg = \"files/lib64/wine/x86_64-windows/winecfg.exe\";"
#       echo "json.recommended = true;"
#     } | gron -u | tee "$tmpFile";
#     jsonObject="$(cat "$tmpFile")"
#     jq -r ". |= [$jsonObject] + ." "$GEProtonJson" > "$tmpFile"
#     cat "$tmpFile" > "$GEProtonJson"
#   done
# }
#
# getNewWineGEProtonVersions(){
#   local wineGEProtonReleasesJson
#   local currentWineGEProton
#   local latestWineGEProton
#
#   # Get release information from GitHub API
#   wineGEProtonReleasesJson="$(curl -s 'https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases')"
#
#   # get currently tracked and latest release versions
#   currentWineGEProton="$(jq -r '.[0].name' "$wineGEProtonJson" | sed -e 's/-x86_64//g' -e 's/lutris-//g' )"
#   latestWineGEProton="$(jq -r '.[0].tag_name' <(echo "$wineGEProtonReleasesJson"))"
#
#   # if current and latest are the same, already up to date
#   [[ "$currentWineGEProton" == "$latestWineGEProton" ]] && return 0
#
#   # Echo each version until we hit currently tracked version
#   for version in $(jq -r '.[].tag_name' <(echo "$wineGEProtonReleasesJson")); do
#     if [[ "$currentWineGEProton" == "$version" ]]; then
#       break
#     else
#       echo "$version"
#     fi
#   done | tac
# }
#
# updateWineGEProton(){
#   local newWineGEProtonVersions
#
#   newWineGEProtonVersions="$(getNewWineGEProtonVersions)"
#   [[ -z "$newWineGEProtonVersions" ]] && return 0
#
#   # build json object for each new version
#   for version in $newWineGEProtonVersions; do
#     echo "$version"
#     title="$(echo "Wine-$version" | sed -r 's/([0-9]+).*/ &/g')"
#     echo "$title"
#     {
#       echo "json.name = \"lutris-$version-x86_64\";"
#       echo "json.title = \"$title\";"
#       echo "json.uri = \"https://github.com/GloriousEggroll/wine-ge-custom/releases/download/$version/wine-lutris-$version-x86_64.tar.xz\";"
#       echo "json.files = {};"
#       echo "json.files.wine = \"bin/wine\";"
#       echo "json.files.wine64 = \"bin/wine64\";"
#       echo "json.files.wineserver = \"bin/wineserver\";"
#       echo "json.files.wineboot = \"bin/wineboot\";"
#       echo "json.files.winecfg = \"lib64/wine/x86_64-windows/winecfg.exe\";"
#       echo "json.recommended = true;"
#     } | gron -u | tee "$tmpFile";
#     jsonObject="$(cat "$tmpFile")"
#     jq -r ". |= [$jsonObject] + ." "$wineGEProtonJson" > "$tmpFile"
#     cat "$tmpFile" > "$wineGEProtonJson"
#   done
# }

dir="$(realpath "$(mktemp -d)")"
rev="$(jq -r '.["components"].rev ./nix/sources.json')"
pushd "$dir" || exit
  tmpFile="$(realpath "$(mktemp)")"
  git clone https://github.com/an-anime-team/components
  pushd components || exit
    git checkout "$rev"
    updateDxvk
    updateDxvkAsync
    diff=$(git diff)
    [[ -n "$diff" ]] && echo "$diff" > update-dxvk.patch
  popd || exit
popd || exit
rm "$tmpFile"
