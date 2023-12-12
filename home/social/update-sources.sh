#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq niv nodejs prefetch-npm-deps

currentTag="$(jq -r '.vencord.rev' ./nix/sources.json)"

niv init
niv update

latestTag="$(jq -r '.vencord.rev' ./nix/sources.json)"

if [ "$currentTag" = "$latestTag" ]; then
  echo "No new version found"
  exit 0
fi

tempDir="$(mktemp -d)"

pushd "$tempDir" || exit
  curl "https://raw.githubusercontent.com/Vendicated/Vencord/$latestTag/package.json" -o package.json
  npm install --legacy-peer-deps -f
  npmDepsHash="$(prefetch-npm-deps ./package-lock.json)"
popd || exit

tee < "$tempDir/package-lock.json" ./nix/package-lock.json | jq '.'
rm -rf "$tempDir"

newJson="$(jq --indent 4 --arg npmDepsHash "$npmDepsHash" '.vencord.npmDepsHash = $npmDepsHash' ./nix/sources.json)"
tee <<< "$newJson" ./nix/sources.json | jq '.'
