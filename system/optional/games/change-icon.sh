#! /usr/bin/env bash

json=./components.json

url="$1"

sha256="$(nix-prefetch-url "$url")"

newJson="$(jq -r "
  .icon.url = \"$url\" |
  .icon.sha256 = \"$sha256\"
" "$json")"

echo "$newJson" > "$json"
