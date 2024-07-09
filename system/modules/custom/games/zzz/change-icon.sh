#! /usr/bin/env bash

json=./icon.json

url="$1"

sha256="$(nix-prefetch-url "$url")"

newJson="$(jq -r "
  .url = \"$url\" |
  .sha256 = \"$sha256\"
" "$json")"

echo "$newJson" > "$json"
