#! /usr/bin/env bash
# Update pkgs/linuwux-runtime to the latest upstream release.
# Bumps `version` and refreshes the src hash and cargoHash in default.nix
# via nix-update (available in the dev shell: `nix develop`).

set -euo pipefail

if ! command -v nix-update >/dev/null 2>&1; then
  echo "error: nix-update not found; enter the dev shell first (\`nix develop\`)" >&2
  exit 1
fi

pushd ./sources || exit
  nix flake update
popd || exit

toplevel="$(git rev-parse --show-toplevel)"
cd "$toplevel"

# The flake requires the pipe-operator experimental feature.
export NIX_CONFIG="experimental-features = nix-command flakes pipe-operator"

nix-update -F linuwux-runtime
