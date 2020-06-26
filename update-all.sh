#!/usr/bin/env bash

find . -type f -name "update-sources.sh" | while read -r updatescript; do
  pushd "$(dirname -- "$updatescript")"
  sh ./update-sources.sh
  popd
done
