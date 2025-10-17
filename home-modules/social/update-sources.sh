#! /usr/bin/env bash

PS4='$ '
set -x

pushd "./sources" || exit
nix flake update
popd || exit
