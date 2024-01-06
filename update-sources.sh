#!/usr/bin/env bash

nixCommand=(nix --experimental-features 'nix-command flakes' --accept-flake-config)
"${nixCommand[@]}" flake update
