#!/usr/bin/env nix-shell
#! nix-shell -i bash -p python3 niv jq

set -x

old_rev="$(jq -r '.["Unalix"].rev' ./nix/sources.json)"

niv init
niv update

rev="$(jq -r '.["Unalix"].rev' ./nix/sources.json)"

if [ "$old_rev" = "$rev" ]; then
  echo "No update needed"
  exit 0
fi

dir="$(mktemp -u -d)"

git clone https://github.com/AmanoTeam/Unalix "$dir"
pushd "$dir" || exit
  git checkout "$rev"
  python3 ./external/update_ca_bundle.py
  python3 ./external/update_rules_file.py
  git diff > ./update.patch
popd || exit

cat "$dir/Unalix/update.patch" > ./update.patch

rm -rf "$dir"
