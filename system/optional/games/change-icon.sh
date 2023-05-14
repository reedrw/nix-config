#! /usr/bin/env bash

json=./components.json

game="$1"

url="$2"

sha256="$(nix-prefetch-url "$url")"

newJson="$(jq -r "
  .$game.icon.url = \"$url\" |
  .$game.icon.sha256 = \"$sha256\"
" "$json")"

echo "$newJson" > "$json"
