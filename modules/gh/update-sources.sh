#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnused jq

savedUrl="$(jq -r '.url' ./sources.json)"

tag="$(git ls-remote --tags --sort="v:refname" --refs https://github.com/github/gh-copilot \
  | tail -1 \
  | sed 's/.*\///; s/\^{}//')"

url="https://github.com/github/gh-copilot/releases/download/$tag/linux-amd64"

if [[ "$savedUrl" == "$url" ]]; then
  echo "No update needed"
  exit 0
fi

sha256="$(nix-prefetch-url "$url")"

cat > sources.json << EOF
{
  "url": "$url",
  "sha256": "$sha256",
  "tag": "$tag"
}
EOF
