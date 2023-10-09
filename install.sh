#!/usr/bin/env bash

set -e

dir="$(dirname "$0")"
pushd "$dir" > /dev/null || exit

if [[ "$1" == "--boot" ]]; then
  sudo nixos-rebuild boot --flake "$dir/.#" -L
else
  sudo nixos-rebuild switch --flake "$dir/.#" -L
  [[ "$USER" != "root" ]] && home-manager switch -L
fi

popd > /dev/null || exit
