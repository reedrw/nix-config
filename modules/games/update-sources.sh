#! /usr/bin/env nix-shell
#! nix-shell -i bash -p niv nix-prefetch gron jq

PS4=''
set -x

niv init
niv update

gronnedJson="$(gron ./nix/sources.json)"
# update AAGL's cargoSha256
# shellcheck disable=SC2016
aaglCargoSha="$(nix-prefetch '
  { sha256 }:
  let
    sources = import ./nix/sources.nix { };
    aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { };
  in
  aagl-gtk-on-nix.an-anime-game-launcher-gtk-unwrapped.cargoDeps.overrideAttrs (_: {
    src = sources.an-anime-game-launcher-gtk;
    cargoSha256 = sha256;
  })
')"
gronnedJson="$gronnedJson"$'\n'"json[\"an-anime-game-launcher-gtk\"].cargoSha256 = \"$aaglCargoSha\";"
gron -u <<< "$gronnedJson" | jq -r '.' --indent 4 > ./nix/sources.json