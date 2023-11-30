#! /usr/bin/env bash
nixCommand=(nix --experimental-features 'nix-command flakes')
"${nixCommand[@]}" flake update
