#! /usr/bin/env nix-shell
#! nix-shell -i bash -p niv

PS4=''
set -x

niv init --no-nixpkgs
mv ./nix/sources.nix ./sources.nix
rm -rf ./nix
