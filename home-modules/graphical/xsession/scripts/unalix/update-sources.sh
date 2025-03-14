#!/usr/bin/env nix-shell
#! nix-shell -i bash -p gron jq python3

pushd ./sources || exit
  nix flake update
popd || exit

rev="$(jq -r '.nodes.Unalix.locked.rev' ./sources/flake.lock)"

dir="$(mktemp -u -d)"

git clone https://gitlab.com/AmanoTeam/Unalix "$dir"
pushd "$dir" || exit
  git checkout "$rev"
  python3 ./external/update_ca_bundle.py
  python3 ./external/update_rules_file.py

  # \c isn't supported by python `re` regex.
  # Very few rules use it (only 1 at the time of writing), so we can just remove it.
  newJson="$(gron ./unalix/package_data/rulesets/data.min.json | grep -v '\\c' | gron -u)"
  echo "$newJson" > ./unalix/package_data/rulesets/data.min.json
  git diff > ./update.patch
popd || exit

cat "$dir/update.patch" > ./update.patch

rm -rf "$dir"
