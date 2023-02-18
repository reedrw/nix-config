#!/usr/bin/env bash

if [[ "$1" == "add" ]]; then
  shift;
fi

apiOutput="$(curl -s https://api.github.com/repos/NixOS/nixpkgs/pulls/"$1")"

name="pr-$1"
repo="$(jq -r '.head.repo.full_name' <<< "$apiOutput")"
branch="$(jq -r '.head.ref' <<< "$apiOutput")"

niv add "$repo" \
  --name "$name" \
  --branch "$branch"

