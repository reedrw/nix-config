#! /usr/bin/env nix-shell
#! nix-shell -i bash -p coreutils git gnugrep jq gron niv

PS4=''
set -x

niv update

here=$PWD
version=$(jq -r '.["base16-nix"].rev' ./nix/sources.json)
checkout=$(mktemp -d)
git clone https://github.com/atpotts/base16-nix "$checkout"
pushd "$checkout" || exit

git checkout "$version"

./update_sources.sh
mv -v templates.json templates.old.json
mv -v schemes.json schemes.old.json
gron templates.old.json | grep 'url\|rev\|sha256\|fetchSubmodules' | gron --ungron > templates.json
gron schemes.old.json | grep 'url\|rev\|sha256\|fetchSubmodules' | gron --ungron > schemes.json
rm -v templates.old.json
rm -v schemes.old.json

git add -f schemes.json templates.json
git diff HEAD -- schemes.json templates.json > "$here"/update-base16.patch

popd || exit
rm -rf "$checkout"
