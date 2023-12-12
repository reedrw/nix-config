#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq niv nodejs prefetch-npm-deps

PS4=''
set -x

niv init
niv update

latestTag="$(jq -r '.vencord.rev' ./nix/sources.json)"
tempDir="$(mktemp -d)"

pushd "$tempDir" || exit
  curl "https://raw.githubusercontent.com/Vendicated/Vencord/$latestTag/package.json" -o package.json
  npm install --legacy-peer-deps -f
  npmDepsHash="$(prefetch-npm-deps ./package-lock.json)"
popd || exit
cp -r "$tempDir/package-lock.json" ./nix/package-lock.json
rm -rf "$tempDir"

jq --arg npmDepsHash "$npmDepsHash" '.vencord.npmDepsHash = $npmDepsHash' ./nix/sources.json > ./nix/sources.json.tmp
cat ./nix/sources.json.tmp > ./nix/sources.json
rm ./nix/sources.json.tmp
