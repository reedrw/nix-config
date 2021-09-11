#! /usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils curl gawk git

PS4=''
set -x

tag=$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --tags --sort='v:refname' \
  https://github.com/Mic92/nix-index-database | \
  awk 'END {match($2, /([^/]+)$/, m); print m[0]}')

url="https://github.com/Mic92/nix-index-database/releases/download/$tag/index-x86_64-linux"

sha256="$(nix-prefetch-url "$url")"

cat > source.json << EOF
{
    "url": "$url",
    "sha256": "$sha256"
}
EOF
