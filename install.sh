#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

nix-channel --add "$(jq -r '.["home-manager"].url' ./nix-home/nix/sources.json )" home-manager
nix-channel --update
home-manager switch

