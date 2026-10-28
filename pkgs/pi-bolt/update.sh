#!/usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils curl gnused jq nix

# Bump pkgs/pi-bolt to a Pi-Bolt release. Takes an optional tag or version
# (bolt-v1.0.0 or 1.0.0); with no argument it takes the latest release.
#
# The archives are not downloaded: the hashes come from the release's own
# SHA256SUMS, whose first line names the release, so a stale or swapped file
# fails the check below instead of silently updating to a mix of versions.

set -euo pipefail

cd -- "$(dirname "$(readlink -f "$0")")"

release="${1:-}"
if [[ -z "$release" ]]; then
  release=$(curl -fsSL https://api.github.com/repos/opensec-git/Pi-Bolt/releases/latest | jq -r '.tag_name')
fi
version="${release#bolt-v}"

echo "Pi-Bolt ${version}"

sums=$(mktemp)
sources=$(mktemp)
trap 'rm -f "$sums" "$sources"' EXIT
curl -fsSL "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${version}/SHA256SUMS" -o "$sums"
curl -fsSL "https://raw.githubusercontent.com/opensec-git/Pi-Bolt/bolt-v${version}/sources.json" -o "$sources"

if [[ "$(head -n 1 "$sums")" != "# pi-bolt ${version}" ]]; then
  echo "error: SHA256SUMS is not for Pi-Bolt ${version}" >&2
  exit 1
fi

sed -i "s/^  version = \"[^\"]*\";/  version = \"${version}\";/" default.nix
pi_version=$(jq -r '.pi.tag | ltrimstr("v")' "$sources")
sed -i "s/^    piVersion = \"[^\"]*\";/    piVersion = \"${pi_version}\";/" default.nix

for variant in x64 x64-baseline x64-jit arm64 arm64-jit; do
  asset="pi-bolt-linux-${variant}.tar.xz"
  hex=$(awk -v asset="$asset" '$2 == asset { print $1 }' "$sums")
  if [[ -z "$hex" ]]; then
    echo "error: ${asset} is not listed in SHA256SUMS" >&2
    exit 1
  fi
  sri=$(nix-hash --type sha256 --to-sri "$hex")
  sed -i "s#^    ${variant} = \"sha256-[^\"]*\";#    ${variant} = \"${sri}\";#" default.nix
done

# `pi-bolt compile` assets (see compileHashes): one Bun runtime and one compile
# kit per platform.
for flavour in x64 arm64; do
  for asset in runtime kit; do
    file="pi-bolt-${asset}-linux-${flavour}.tar.gz"
    hex=$(awk -v asset="$file" '$2 == asset { print $1 }' "$sums")
    if [[ -z "$hex" ]]; then
      echo "error: ${file} is not listed in SHA256SUMS" >&2
      exit 1
    fi
    sri=$(nix-hash --type sha256 --to-sri "$hex")
    sed -i "s#^    ${flavour}-${asset} = \"sha256-[^\"]*\";#    ${flavour}-${asset} = \"${sri}\";#" default.nix
  done
done
