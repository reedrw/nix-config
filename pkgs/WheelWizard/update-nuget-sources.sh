#! /usr/bin/env nix-shell
#! nix-shell -i bash -p dotnet-sdk_8 nuget-to-json

set -x
set -e

version="$(nix eval --impure --raw --expr "(builtins.getFlake \"$(realpath ../../.)\").packages.x86_64-linux.WheelWizard.version")"

currentDir="$(pwd)"
tmpDir="$(mktemp -d)"

pushd "$tmpDir" || exit 1
  git clone --branch "$version" --depth 1 "https://github.com/TeamWheelWizard/WheelWizard.git" .
  dotnet restore --packages deps
  nuget-to-json deps > "$currentDir/deps.json"
popd || exit 1

rm -rf "$tmpDir"
