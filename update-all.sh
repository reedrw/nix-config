#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

find . -type f -name "update-sources.sh" | while read -r updatescript; do
  pushd "$(dirname -- "$updatescript")" || exit
  ./update-sources.sh
  popd || exit
done

