#!/usr/bin/env bash

if [[ -n "$1" ]]; then
  json="$(readlink -f "$1")"
elif [[ -p /dev/stdin ]]; then
  json=/dev/stdin
fi

nix-instantiate -E --arg json "$json" '
  { json ? "" }:
  let
    v = builtins.fromJSON (builtins.readFile json);
  in
  builtins.trace v v
' |& tee /dev/stdout \
  | cut -f 2- -d ' ' \
  | alejandra -q
