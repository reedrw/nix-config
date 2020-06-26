#!/usr/bin/env bash

find . -type f -name "update-sources.sh" | while read -r updatescript; do
  pushd "$(dirname -- "$updatescript")" || exit
  sh ./update-sources.sh
  popd || exit
done
