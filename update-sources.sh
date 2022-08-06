#! /usr/bin/env nix-shell
#! nix-shell -i bash -p niv nix-prefetch gron

PS4=''
set -x

niv init
niv update

gronnedJson="$(gron ./nix/sources.json)"
# shellcheck disable=SC2016
aaglCargoSha="$(nix-prefetch '
  { sha256 }:
  let
    sources = import ./nix/sources.nix { };
    nur = import "${sources.NUR}" {
      inherit pkgs;
    };
  in
  nur.repos.reedrw.an-anime-game-launcher-gtk-unwrapped.cargoDeps.overrideAttrs (_:
    {
      src = sources.an-anime-game-launcher-gtk;
      cargoSha256 = sha256;
    }
  )
')"
gronnedJson="$gronnedJson"$'\n'"json[\"an-anime-game-launcher-gtk\"].cargoSha256 = \"$aaglCargoSha\";"
gron -u <<< "$gronnedJson" > ./nix/sources.json
