#!/usr/bin/env bash

set -e

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit

sudo nixos-rebuild switch --flake "$dir/.#" -L
[[ "$USER" != "root" ]] && home-manager switch -L

popd > /dev/null || exit
