#!/usr/bin/env bash

set -e

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit

sudo nixos-rebuild switch --flake "$dir/.#" -L
home-manager switch -L

popd > /dev/null || exit
