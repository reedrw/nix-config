#!/usr/bin/env bash

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit

sudo nixos-rebuild switch --flake "$dir/.#" -L
home-manager switch -L

popd > /dev/null || exit
