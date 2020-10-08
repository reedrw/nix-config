#! /usr/bin/env nix-shell
#! nix-shell -i bash
pwd="$PWD"

find -L "$(pwd)/" -type f -name "update-sources.sh" | while read -r updatescript; do
  (
    dir="$(dirname -- "$updatescript")"
    cd "$dir" || exit
    (
      relpath="$(realpath -s --relative-to="$pwd" "$updatescript")"
      echo -e "Running $relpath..." "\r"
      $updatescript || exit 1
      echo
    )
  )
done

