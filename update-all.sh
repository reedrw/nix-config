#! /usr/bin/env bash

pwd="$PWD"

find -L "$(pwd)/" -type f -name "update-sources.sh" | while read -r updatescript; do
  (
    dir="$(dirname -- "$updatescript")"
    cd "$dir" || exit
    (
      relpath="$(realpath -s --relative-to="$pwd" "$updatescript")"
      echo -e "Running $relpath..." "\r"
      $updatescript
      echo
    )
  )
done
