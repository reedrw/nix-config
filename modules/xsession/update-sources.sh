#!/usr/bin/env nix-shell
#! nix-shell -i bash -p python3 niv jq

set -x

niv init
niv update

rev="$(jq -r '.[Unalix].rev' ./nix/sources.json)"

dir="$(mktemp -d)"

pushd "$dir" || exit
  git clone https://github.com/AmanoTeam/Unalix
  git checkout "$rev"
  pushd Unalix || exit
    python3 ./external/update_ca_bundle.py
    python3 ./external/update_rules_file.py
    git diff | tee ./update.patch
  popd || exit
popd || exit

cat "$dir/Unalix/update.patch" > ./update.patch

rm -rf "$dir"
