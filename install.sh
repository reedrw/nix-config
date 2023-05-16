#!/usr/bin/env bash

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit
home-manager switch -L
sudo nixos-rebuild switch --flake "$dir/.#" -L

popd > /dev/null || exit
