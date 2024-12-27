#! /usr/bin/env bash

PS4='$ '
set -x

pushd "./plugins" || exit
  nix flake update
popd || exit
