#! /usr/bin/env bash

url="$1"

sha256="$(nix-prefetch-url "$url")"

cat > icon.json << EOF
{
    "url": "$url",
    "sha256": "$sha256"
}
EOF
