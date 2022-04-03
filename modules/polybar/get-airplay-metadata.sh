#!/usr/bin/env bash

set -e

getData() {
  local artist
  local title

  data="$(
    timeout 10 shairport-sync-metadata-reader < /tmp/shairport-sync-metadata \
      | grep -m 2 -e 'Artist\|Title' \
      | awk -F'"' '$0=$2'
  )" || [ $? -eq 141 ] || [ $? -eq 124 ] && true

  while read -r artist && read -r title; do
    output="$artist - $title"
    echo "$output"
  done <<< "${data}"
}

if pw-cli ls Node | grep -q "Shairport Sync"; then
  data="$(getData)"
  [ -z "$data" ] || echo "$data"
else
  echo ""
fi
