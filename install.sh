#! /usr/bin/env bash

nix-channel --add "$(nix run nixpkgs.jq -c jq -r '.["home-manager"].url' ./nix-home/nix/sources.json)" home-manager
nix-channel --update
nix-shell --run "home-manager switch"

