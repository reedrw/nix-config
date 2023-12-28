#!/usr/bin/env nix-shell
#! nix-shell -i bash -p python3 niv jq

set -x

niv init
niv update

rev="$(jq -r '.["Unalix"].rev' ./nix/sources.json)"

dir="$(mktemp -u -d)"

git clone https://github.com/AmanoTeam/Unalix "$dir"
pushd "$dir" || exit
  git checkout "$rev"
  python3 ./external/update_ca_bundle.py
  python3 ./external/update_rules_file.py
  git diff > ./update.patch
popd || exit

cat "$dir/update.patch" > ./update.patch

rm -rf "$dir"
